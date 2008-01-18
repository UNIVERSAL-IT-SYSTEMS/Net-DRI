## Domain Registry Interface, RRI Domain commands (DENIC-11)
##
## Copyright (c) 2007 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>. All rights reserved.
##
## This file is part of Net::DRI
##
## Net::DRI is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## See the LICENSE file that comes with this distribution for more details.
#
# 
#
####################################################################################################

package Net::DRI::Protocol::RRI::Domain;

use strict;

use Net::DRI::Util;
use Net::DRI::Exception;
use Net::DRI::Data::Hosts;
use Net::DRI::Data::ContactSet;
use Net::DRI::Protocol::RRI;

use IDNA::Punycode;
use Net::IP;

use DateTime::Format::ISO8601;

our $VERSION=do { my @r=(q$Revision: 1.13 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::RRI::Domain - RRI Domain commands (DENIC-11) for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>tonnerre.lombard@sygroup.chE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://oss.bsdprojects.net/projects/netdri/E<gt>

=head1 AUTHOR

Tonnerre Lombard, E<lt>tonnerre.lombard@sygroup.chE<gt>

=head1 COPYRIGHT

Copyright (c) 2007 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub register_commands
{
 my ($class,$version)=@_;
 my %tmp=(
           check  => [ \&check, \&check_parse ],
           info   => [ \&info, \&info_parse ],
           transfer_query  => [ \&transfer_query, \&transfer_parse ],
           create => [ \&create, \&create_parse ],
           delete => [ \&delete ],
           renew => [ \&renew, undef ],
           transfer_request => [ \&transfer_request, undef ],
           transfer_cancel  => [ \&transfer_cancel, undef ],
           transfer_answer  => [ \&transfer_answer, undef ],
           update => [ \&update ],
           review_complete => [ undef, \&pandata_parse ],
         );

 $tmp{check_multi} = $tmp{check};
 return { 'domain' => \%tmp };
}

sub build_command
{
 my ($msg, $command, $domain, $domainattr, $dns) = @_;
 my @dom = (ref($domain))? @$domain : ($domain);
 Net::DRI::Exception->die(1,'protocol/EPP', 2, "Domain name needed")
	unless @dom;
 foreach my $d (@dom)
 {
  Net::DRI::Exception->die(1, 'protocol/EPP', 2, 'Domain name needed')
	unless defined($d) && $d;
  Net::DRI::Exception->die(1, 'protocol/EPP', 10, 'Invalid domain name: ' . $d)
	unless Net::DRI::Util::is_hostname($d);
 }

 my $tcommand = (ref($command)) ? $command->[0] : $command;
 my @ns = @{$msg->ns->{domain}};
 $msg->command(['domain', $tcommand, (defined($dns) ? $dns : $ns[0]), $domainattr]);

 my @d;

 foreach my $domain (@dom)
 {
  my $ace = join('.', map { decode_punycode($_) } split(/\./, $domain));
  push(@d, ['domain:handle', $domain]);
  push(@d, ['domain:ace', $domain]);
 }
 return @d;
}

sub build_period
{
 my $dtd=shift; ## DateTime::Duration
 my ($y,$m)=$dtd->in_units('years','months'); ## all values are integral, but may be negative
 ($y,$m)=(0,$m+12*$y) if ($y && $m);
 my ($v,$u);
 if ($y)
 {
  Net::DRI::Exception::usererr_invalid_parameters("years must be between 1 and 99") unless ($y >= 1 && $y <= 99);
  $v=$y;
  $u='y';
 } else
 {
  Net::DRI::Exception::usererr_invalid_parameters("months must be between 1 and 99") unless ($m >= 1 && $m <= 99);
  $v=$m;
  $u='m';
 }
 
 return ['domain:period',$v,{'unit' => $u}];
}

####################################################################################################
########### Query commands

sub check
{
 my ($epp, $domain, $rd)=@_;
 my $mes = $epp->message();
 my @d = build_command($mes, 'check', $domain);
 $mes->command_body(\@d);
}


sub check_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes = $po->message();
 return unless $mes->is_success();

 my $chkdata = $mes->get_content('checkData',$mes->ns('domain'));
 return unless $chkdata;
 my @d = $chkdata->getElementsByTagNameNS($mes->ns('domain'),'handle');
 my @s = $chkdata->getElementsByTagNameNS($mes->ns('domain'),'status');
 return unless (@d && @s);

 my $dom = $d[0]->getFirstChild()->getData();
 my $st = ($s[0]->getFirstChild()->getData() eq 'free');

 $rinfo->{domain}->{$dom}->{action} = 'check';
 $rinfo->{domain}->{$dom}->{exist} = 1 - $st;
}

sub verify_rd
{
 my ($rd, $key) = @_;
 return 0 unless (defined($key) && $key);
 return 0 unless (defined($rd) && (ref($rd) eq 'HASH') &&
	exists($rd->{$key}) && defined($rd->{$key}));
 return 1;
}

sub info
{
 my ($epp, $domain, $rd)=@_;
 my $mes = $epp->message();
 my @d = build_command($mes, 'info', $domain,
	{recursive => 'false', withProvider => 'false'});
 $mes->command_body(\@d);
}

sub info_parse
{
 my ($po, $otype, $oaction, $oname, $rinfo) = @_;
 my $mes = $po->message();
 return unless $mes->is_success();
 my $infdata = $mes->get_content('infoData', $mes->ns('domain'));
 return unless $infdata;
 my $cs = Net::DRI::Data::ContactSet->new();
 my $ns = Net::DRI::Data::Hosts->new();
 my $cf = $po->factories()->{contact};
 my $c = $infdata->getFirstChild();

 while ($c)
 {
  next unless ($c->nodeType() == 1); ## only for element nodes
  my $name = $c->localname() || $c->nodeName();
  next unless $name;

  if ($name eq 'handle')
  {
   $oname = lc($c->getFirstChild()->getData());
   $rinfo->{domain}->{$oname}->{action} = 'info';
   $rinfo->{domain}->{$oname}->{exist} = 1;
  }
  elsif ($name eq 'status')
  {
   my $val = $c->getFirstChild()->getData();
   $rinfo->{domain}->{$oname}->{exist} = ($val eq 'connect');
  }
  elsif ($name eq 'contact')
  {
   my $role = $c->getAttribute('role');
   my %rmap = (holder => 'registrant', 'admin-c' => 'admin',
	'tech-c' => 'tech', 'zone-c' => 'zone');
   $role = $rmap{$role} if (defined($rmap{$role}));
   $cs->add($cf->()->srid($c->getFirstChild()->getFirstChild()->getData()),
	$role);
  }
  elsif ($name eq 'dnsentry')
  {
   $ns->add(parse_ns($c));
  }
  elsif ($name eq 'regAccId')
  {
   $rinfo->{domain}->{$oname}->{clID} =
   $rinfo->{domain}->{$oname}->{crID} =
   $rinfo->{domain}->{$oname}->{upID} = $c->getFirstChild()->getData();
  }
  elsif ($name eq 'changed')
  {
   $rinfo->{domain}->{$oname}->{crDate} =
   $rinfo->{domain}->{$oname}->{upDate} =
	DateTime::Format::ISO8601->new()->
		parse_datetime($c->getFirstChild()->getData());
  }
  elsif ($name eq 'chprovData')
  {
   # FIXME: Implement this one as well
  }
 } continue { $c = $c->getNextSibling(); }

 $rinfo->{domain}->{$oname}->{contact} = $cs;
 $rinfo->{domain}->{$oname}->{status} = $po->create_local_object('status');
 $rinfo->{domain}->{$oname}->{ns} = $ns;
}

sub parse_ns
{
 my $node = shift;
 my $n = $node->getFirstChild();
 my $hostname = '';
 my @ip4 = ();
 my @ip6 = ();

 while ($n)
 {
  next unless ($n->nodeType() == 1); ## only for element nodes
  my $name = $n->localname() || $n->nodeName();
  next unless $name;

  if ($name eq 'rdata')
  {
   my $nn = $n->getFirstChild();
   while ($nn)
   {
    next unless ($nn->nodeType() == 1); ## only for element nodes
    my $name2 = $nn->localname() || $nn->nodeName();
    next unless $name2;
    if ($name2 eq 'nameserver')
    {
     $hostname = $nn->getFirstChild()->getData();
    }
    elsif ($name2 eq 'address')
    {
     my $ip = new Net::IP($nn->getFirstChild()->getData());
     if ($ip->version() == 6)
     {
      push(@ip6, $ip->short());
     }
     else
     {
      push(@ip4, $ip->ip());
     }
    }
   } continue { $nn = $nn->getNextSibling(); }
  }
 } continue { $n = $n->getNextSibling(); }

 return ($hostname, \@ip4, \@ip6);
}

sub transfer_query
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = build_command($mes, 'info', $domain,
	{recursive => 'true', withProvider => 'false'});
 $mes->command_body(\@d);
}

sub transfer_parse
{
 my ($po, $otype, $oaction, $oname, $rinfo) = @_;
 my $mes = $po->message();
 return unless $mes->is_success();

 my $infodata = $mes->get_content('infoData', $mes->ns('domain'));
 return unless $infodata;
 my $namedata = ($infodata->getElementsByTagNameNS($mes->ns('domain'),
	'handle'))[0];
 return unless $namedata;
 my $trndata = ($infodata->getElementsByTagNameNS($mes->ns('domain'),
	'chprovData'))[0];
 return unless $trndata;

 $oname = lc($namedata->getFirstChild()->getData());
 $rinfo->{domain}->{$oname}->{action} = 'transfer';
 $rinfo->{domain}->{$oname}->{exist} = 1;
 $rinfo->{domain}->{$oname}->{trStatus} = undef;

 my $c = $trndata->getFirstChild();
 while ($c)
 {
  next unless ($c->nodeType() == 1); ## only for element nodes
  my $name = $c->localname() || $c->nodeName();
  next unless $name;

  if ($name eq 'chprovTo')
  {
   $rinfo->{domain}->{$oname}->{reID} = $c->getFirstChild()->getData();
  }
  elsif ($name eq 'chprovStatus')
  {
   my %stmap = (ACTIVE => 'pending', REMINDED => 'pending');
   my $val = $c->getFirstChild()->getData();
   $rinfo->{domain}->{$oname}->{trStatus} =
	(defined($stmap{$val}) ? $stmap{$val} : $val);
  }
  elsif ($name =~ m/^(chprovStart|chprovReminder|chprovEnd)$/)
  {
   my %tmmap = (chprovStart => 'reDate', chprovReminder => 'acDate',
	chprovEnd => 'exDate');
   $rinfo->{domain}->{$oname}->{$tmmap{$1}} = DateTime::Format::ISO8601->
	new()->parse_datetime($c->getFirstChild()->getData());
  }
 } continue { $c = $c->getNextSibling(); }
}

############ Transform commands

sub create
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my %ns = map { $_ => $mes->ns->{$_}->[0] } qw(domain dnsentry xsi);
 my @d = build_command($mes, 'create', $domain, undef, \%ns);
 
 my $def = $epp->default_parameters();
 if ($def && (ref($def) eq 'HASH') && exists($def->{domain_create}) &&
	(ref($def->{domain_create}) eq 'HASH'))
 {
  $rd = {} unless ($rd && (ref($rd) eq 'HASH') && keys(%$rd));
  while (my ($k, $v) = each(%{$def->{domain_create}}))
  {
   next if exists($rd->{$k});
   $rd->{$k} = $v;
  }
 }

 ## Contacts, all OPTIONAL
 if (verify_rd($rd, 'contact') &&
	UNIVERSAL::isa($rd->{contact},'Net::DRI::Data::ContactSet'))
 {
  my $cs = $rd->{contact};
  push @d,build_contact($cs);
 }

 ## Nameservers, OPTIONAL
 push @d,build_ns($epp,$rd->{ns},$domain) if (verify_rd($rd,'ns') && UNIVERSAL::isa($rd->{ns},'Net::DRI::Data::Hosts') && !$rd->{ns}->is_empty());

 $mes->command_body(\@d);
}

sub build_contact
{
 my $cs = shift;
 my @d;

 my %trans = ('registrant' => 'holder', 'admin' => 'admin-c',
	'tech' => 'tech-c', 'zone' => 'zone-c');

 # All nonstandard contacts go into the extension section
 foreach my $t (sort(grep { $_ eq 'registrant' || $_ eq 'admin' ||
	$_ eq 'tech' || $_ eq 'billing' || $_ eq 'onsite' } $cs->types()))
 {
  my @o = $cs->get($t);
  my $c = (defined($trans{$t}) ? $trans{$t} : $t);
  push @d, map { ['domain:contact', $_->srid(), {'role' => $c}] } @o;
 }
 return @d;
}

sub build_ns
{
 my ($epp, $ns, $domain, $xmlns) = @_;

 my @d;
 my $asattr = $epp->{hostasattr};

 if ($asattr)
 {
  foreach my $i (1..$ns->count())
  {
   my ($n, $r4, $r6) = $ns->get_details($i);
   my @h;
   push @h, ['domain:hostName', $n];
   if (($n=~m/\S+\.${domain}$/i) || (lc($n) eq lc($domain)) || ($asattr == 2))
   {
    push @h, map { ['domain:hostAddr', $_, {ip =>' v4'}] } @$r4 if @$r4;
    push @h, map { ['domain:hostAddr', $_, {ip =>' v6'}] } @$r6 if @$r6;
   }
   push @d, ['domain:hostAttr', @h];
  }
 } else
 {
  @d = map { ['dnsentry:dnsentry', {'xsi:type' => 'dnsentry:NS'},
	['dnsentry:owner', $domain],
	['dnsentry:rdata', ['dnsentry:nameserver', $_ ] ] ] } $ns->get_names();
 }

 $xmlns = 'dnsentry' unless defined($xmlns);
 return @d;
}

sub create_parse
{
 my ($po, $otype, $oaction, $oname, $rinfo) = @_;
 my $mes = $po->message();
 return unless $mes->is_success();

 my $credata = $mes->get_content('creData', $mes->ns('domain'));
 return unless $credata;

 my $c = $credata->getFirstChild();
 while ($c)
 {
  next unless ($c->nodeType() == 1); ## only for element nodes
  my $name = $c->localname() || $c->nodeName();
  next unless $name;

  if ($name eq 'name')
  {
   $oname = lc($c->getFirstChild()->getData());
   $rinfo->{domain}->{$oname}->{action} = 'create';
   $rinfo->{domain}->{$oname}->{exist} = 1;
  }
  elsif ($name =~ m/^(crDate|exDate)$/)
  {
   $rinfo->{domain}->{$oname}->{$1} = DateTime::Format::ISO8601->new()->
	parse_datetime($c->getFirstChild()->getData());
  }
 } continue { $c = $c->getNextSibling(); }
}

sub delete
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = build_command($mes, 'delete', $domain);

 ## Holder contact
 if (verify_rd($rd, 'contact') &&
	UNIVERSAL::isa($rd->{contact}, 'Net::DRI::Data::ContactSet'))
 {
  my $ocs = $rd->{contact};
  my $cs = new Net::DRI::Data::ContactSet;
  foreach my $c ($ocs->get('registrant'))
  {
   $cs->add($c, 'registrant');
  }

  push @d, build_contact($cs);
 }

 $mes->command_body(\@d);
}

sub renew
{
 Net::DRI::Exception->die(0, 'RRI', 4, 'No domain renew available in RRI');
}

sub transfer_request
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my %ns = map { $_ => $mes->ns->{$_}->[0] } qw(domain dnsentry xsi);
 my @d = build_command($mes, 'chprov', $domain, undef, \%ns);

 ## Contacts, all OPTIONAL
 if (verify_rd($rd, 'contact') && UNIVERSAL::isa($rd->{contact},
	'Net::DRI::Data::ContactSet'))
 {
  my $cs = $rd->{contact};
  push(@d, build_contact($cs));
 }

 ## Nameservers, OPTIONAL
 push @d, build_ns($epp, $rd->{ns}, $domain)
	if (verify_rd($rd, 'ns') && UNIVERSAL::isa($rd->{ns},
		'Net::DRI::Data::Hosts') && !$rd->{ns}->is_empty());

 $mes->command_body(\@d);
}

sub transfer_answer
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = build_command($mes, (verify_rd($rd,'approve') && $rd->{approve}) ?
	'chprovAck' : 'chprovNack', $domain);
 $mes->command_body(\@d);
}

sub transfer_cancel
{
 Net::DRI::Exception->die(0, 'RRI', 4, 'No domain transfer cancel available in RRI');
}

# FIXME: Implement this!
sub update
{
 my ($epp, $domain, $todo)=@_;
 my $mes = $epp->message();

 Net::DRI::Exception->die(0, 'RRI', 4, 'Domain update not implemented yet in RRI');

 Net::DRI::Exception::usererr_invalid_parameters($todo." must be a Net::DRI::Data::Changes object") unless ($todo && UNIVERSAL::isa($todo,'Net::DRI::Data::Changes'));

 if ((grep { ! /^(?:add|del)$/ } $todo->types('ns')) ||
     (grep { ! /^(?:add|del)$/ } $todo->types('status')) ||
     (grep { ! /^(?:add|del)$/ } $todo->types('contact')) ||
     (grep { ! /^set$/ } $todo->types('registrant')) ||
     (grep { ! /^set$/ } $todo->types('auth'))
    )
 {
  Net::DRI::Exception->die(0,'protocol/EPP',11,'Only ns/status/contact add/del or registrant/authinfo set available for domain');
 }

 my @d=build_command($mes,'update',$domain);

 my $nsadd=$todo->add('ns');
 my $nsdel=$todo->del('ns');
 my $sadd=$todo->add('status');
 my $sdel=$todo->del('status');
 my $cadd=$todo->add('contact');
 my $cdel=$todo->del('contact');
 my (@add,@del);

 push @add,build_ns($epp,$nsadd,$domain)            if $nsadd && !$nsadd->is_empty();
 push @add,build_contact_noregistrant($cadd)        if $cadd;
 push @add,$sadd->build_xml('domain:status','core') if $sadd;
 push @del,build_ns($epp,$nsdel,$domain)            if $nsdel && !$nsdel->is_empty();
 push @del,build_contact_noregistrant($cdel)        if $cdel;
 push @del,$sdel->build_xml('domain:status','core') if $sdel;

 push @d,['domain:add',@add] if @add;
 push @d,['domain:rem',@del] if @del;

 my $chg=$todo->set('registrant');
 my @chg;
 push @chg,['domain:registrant',$chg->srid()] if ($chg && ref($chg) && UNIVERSAL::can($chg,'srid'));
 push @d,['domain:chg',@chg] if @chg;
 $mes->command_body(\@d);
}

####################################################################################################
## RFC4931 §3.3  Offline Review of Requested Actions
## FIXME: How does this apply to RRI?

sub pandata_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $pandata=$mes->get_content('panData',$mes->ns('domain'));
 return unless $pandata;

 my $c=$pandata->firstChild();
 while ($c)
 {
  next unless ($c->nodeType() == 1); ## only for element nodes
  my $name=$c->localname() || $c->nodeName();
  next unless $name;

  if ($name eq 'name')
  {
   $oname=lc($c->getFirstChild()->getData());
   $rinfo->{domain}->{$oname}->{action}='create_review';
   $rinfo->{domain}->{$oname}->{result}=Net::DRI::Util::xml_parse_boolean($c->getAttribute('paResult'));
   $rinfo->{domain}->{$oname}->{exist}=$rinfo->{domain}->{$oname}->{result};
  } elsif ($name eq 'paTRID')
  {
   my @tmp=$c->getElementsByTagNameNS($mes->ns('_main'),'clTRID');
   $rinfo->{domain}->{$oname}->{trid}=$tmp[0]->getFirstChild()->getData() if (@tmp && $tmp[0]);
   $rinfo->{domain}->{$oname}->{svtrid}=($c->getElementsByTagNameNS($mes->ns('_main'),'svTRID'))[0]->getFirstChild()->getData();
  } elsif ($name eq 'paDate')
  {
   $rinfo->{domain}->{$oname}->{date}=DateTime::Format::ISO8601->new()->parse_datetime($c->firstChild->getData());
  }
 } continue { $c=$c->getNextSibling(); }
}

####################################################################################################
1;
