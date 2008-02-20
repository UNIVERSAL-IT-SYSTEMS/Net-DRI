## Domain Registry Interface, CN Contact extension
##
## Copyright (c) 2006,2007 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::CN::Contact;

use strict;

use Net::DRI::Util;
#use Net::DRI::Exception;
#use Net::DRI::Protocol::EPP;

our $VERSION=do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };


=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::AT::Contact - NIC.AT Contact Extensions for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt>

=head1 AUTHOR

Patrick Mevzek, E<lt>netdri@dotandco.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2006,2007 Patrick Mevzek <netdri@dotandco.com>.
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
		check			=> [ undef, \&check_parse ],
		create			=> [ \&create ],
		update			=> [ \&update ],
		info			=> [ undef, \&info_parse ],
		transfer_request	=> [ \&transfer_request, undef ]
         );

 return { 'contact' => \%tmp };
}

##################################################################################################
########### Query commands

sub check_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $chkdata=$mes->get_content('chkData',$mes->ns('contact'));
 return unless $chkdata;
 foreach my $cd ($chkdata->getElementsByTagNameNS($mes->ns('contact'),'cd'))
 {
    my $contact;
    $contact = $cd->getFirstChild()->getData();
    $rinfo->{contact}->{$contact}->{action}='check';
    if ($cd->getAttribute('x') eq '+') {
       $rinfo->{contact}->{$contact}->{exist}=1;
       $rinfo->{contact}->{lc($contact)}->{exist}=1;
       $rinfo->{contact}->{uc($contact)}->{exist}=1;
    } else {
       $rinfo->{contact}->{$contact}->{exist}=0;
       $rinfo->{contact}->{lc($contact)}->{exist}=0;
       $rinfo->{contact}->{uc($contact)}->{exist}=0;
    }
 }
}


sub info_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $infdata=$mes->get_content('infData',$mes->ns('contact'));
 return unless $infdata;

 my %cd=map { $_ => [] } qw/name org street city sp pc cc/;
 my $contact=$po->factories()->{contact}->();
 my @s;
 my $c=$infdata->getFirstChild();
 while ($c)
 {
  my $name=$c->localname() || $c->nodeName();
  next unless $name;
  if ($name eq 'id')
  {
   $oname=$c->getFirstChild()->getData();
   $rinfo->{contact}->{$oname}->{action}='info';
   $rinfo->{contact}->{$oname}->{exist}=1;
   $contact->srid($oname);
  } elsif ($name eq 'roid')
  {
   $contact->roid($c->getFirstChild()->getData());
   $rinfo->{contact}->{$oname}->{roid}=$contact->roid();
  } elsif ($name eq 'status')
  {
   push @s,Net::DRI::Protocol::EPP::parse_status($c);
  } elsif ($name=~m/^(clID|crID|upID)$/)
  {
   $rinfo->{contact}->{$oname}->{$1}=$c->getFirstChild()->getData();
  } elsif ($name=~m/^(crDate|upDate|trDate)$/)
  {
   $rinfo->{contact}->{$oname}->{$1}=DateTime::Format::ISO8601->new()->parse_datetime($c->getFirstChild()->getData());
  } elsif ($name eq 'email')
  {
   $contact->email($c->getFirstChild()->getData());
  } elsif ($name eq 'voice')
  {
   $contact->voice(parse_tel($c));
  } elsif ($name eq 'fax')
  {
   $contact->fax(parse_tel($c));
  } elsif ($name eq 'ascii')
  {
   parse_postalinfo($c,\%cd);
  } elsif ($name eq 'authInfo')
  {
   my $pw=$c->getFirstChild()->getData();
   $contact->auth({pw => $pw});
  } elsif ($name eq 'disclose')
  {
   $contact->disclose(parse_disclose($c));
  }
  $c=$c->getNextSibling();
 }

 $contact->name(@{$cd{name}});
 $contact->org(@{$cd{org}});
 $contact->street(@{$cd{street}});
 $contact->city(@{$cd{city}});
 $contact->sp(@{$cd{sp}});
 $contact->pc(@{$cd{pc}});
 $contact->cc(@{$cd{cc}});

 $rinfo->{contact}->{$oname}->{status}=$po->create_local_object('status')->add(@s);
 $rinfo->{contact}->{$oname}->{self}=$contact;
 $rinfo->{contact}->{lc($oname)} = $rinfo->{contact}->{uc($oname)} =
	$rinfo->{contact}->{$oname};
}

sub parse_tel
{
 my $node=shift;
 my $ext=$node->getAttribute('x') || '';
 my $num=get_data($node);
 $num.="x${ext}" if $ext;
 return $num;
}

sub get_data
{
 my $n=shift;
 return ($n->getFirstChild())? $n->getFirstChild()->getData() : '';
}

sub parse_postalinfo
{
 my ($c,$rcd)=@_;
 my $type='int'; # we don't have a type with epp 0.4
 my $ti={loc=>0,int=>1}->{$type};

 my $n=$c->getFirstChild();
 while($n)
 {
  my $name=$n->localname() || $n->nodeName();
  next unless $name;
  if ($name eq 'name')
  {
   $rcd->{name}->[$ti]=get_data($n);
  } elsif ($name eq 'org')
  {
   $rcd->{org}->[$ti]=get_data($n);
  } elsif ($name eq 'addr')
  {
   my $nn=$n->getFirstChild();
   my @street;
   while($nn)
   {
    my $name2=$nn->localname() || $nn->nodeName();
    next unless $name2;
    if ($name2 eq 'street')
    {
     push @street,get_data($nn);
    } elsif ($name2 eq 'city')
    {
     $rcd->{city}->[$ti]=get_data($nn);
    } elsif ($name2 eq 'sp')
    {
     $rcd->{sp}->[$ti]=get_data($nn);
    } elsif ($name2 eq 'pc')
    {
     $rcd->{pc}->[$ti]=get_data($nn);
    } elsif ($name2 eq 'cc')
    {
     $rcd->{cc}->[$ti]=get_data($nn);
    }
    $nn=$nn->getNextSibling();
   }
   $rcd->{street}->[$ti]=\@street;
  }
  $n=$n->getNextSibling();
 }
}

sub parse_disclose ## RFC 3733 §2.9
{
 my $c=shift;
 my $flag=Net::DRI::Util::xml_parse_boolean($c->getAttribute('flag'));
 my %tmp;
 my $n=$c->getFirstChild();
 while($n)
 {
  my $name=$n->localname() || $n->nodeName();
  next unless $name;
  if ($name=~m/^(name|org|addr)$/)
  {
   my $t=$n->getAttribute('type');
   $tmp{$1.'_'.$t}=$flag;
  } elsif ($name=~m/^(voice|fax|email)$/)
  {
   $tmp{$1}=$flag;
  }
  $n=$n->getNextSibling();
 }
 return \%tmp;
}

sub transfer_request
{
 my ($epp, $c) = @_;
 my $mes = $epp->message();
 my @d = build_command($mes, ['transfer', {'op'=>'request'}], $c);
 $mes->command_body(\@d);
}

####################################################################################################

sub build_command
{
 my ($msg,$command,$contact)=@_;
 my @contact=(ref($contact) eq 'ARRAY')? @$contact : ($contact);
 my @c=map { UNIVERSAL::isa($_,'Net::DRI::Data::Contact')? $_->srid() : $_ } @contact;

 Net::DRI::Exception->die(1,'protocol/EPP',2,"Contact id needed") unless @c;
 foreach my $n (@c)
 {
  Net::DRI::Exception->die(1,'protocol/EPP',2,'Contact id needed') unless defined($n) && $n;
  Net::DRI::Exception->die(1,'protocol/EPP',10,'Invalid contact id: '.$n) unless Net::DRI::Util::xml_is_token($n,3,16);
 }

 my $tcommand=(ref($command))? $command->[0] : $command;
 my @ns=@{$msg->ns->{contact}};
 $msg->command([$command,'contact:'.$tcommand,sprintf('xmlns:contact="%s" xsi:schemaLocation="%s %s"',$ns[0],$ns[0],$ns[1])]);

 my @d=map { ['contact:id',$_] } @c;

 if (($tcommand=~m/^(?:info|transfer)$/) && ref($contact[0]) && UNIVERSAL::isa($contact[0],'Net::DRI::Data::Contact'))
 {
  push(@d, build_authinfo($contact[0]));
 }

 return @d;
}

####################################################################################################

############ Transform commands

sub build_tel
{
 my ($name,$tel)=@_;
 if ($tel=~m/^(\S+)x(\S+)$/)
 {
  return [$name,$1,{x=>$2}];
 } else
 {
  return [$name,$tel];
 }
}

sub build_authinfo
{
 my $contact=shift;
 my $az=$contact->auth();
 return () unless ($az && ref($az) && exists($az->{pw}));
 return ['contact:authInfo',$az->{pw}, {type => 'pw'}];
}

sub build_disclose
{
 my $contact=shift;
 my $d=$contact->disclose();
 return () unless ($d && ref($d));
 my %v=map { $_ => 1 } values(%$d);
 return () unless (keys(%v)==1); ## 1 or 0 as values, not both at same time
 my @d;
 push @d,['contact:name',{type=>'int'}] if (exists($d->{name_int}) && !exists($d->{name}));
 push @d,['contact:name',{type=>'loc'}] if (exists($d->{name_loc}) && !exists($d->{name}));
 push @d,['contact:name',{type=>'int'}],['contact:name',{type=>'loc'}] if exists($d->{name});
 push @d,['contact:org',{type=>'int'}] if (exists($d->{org_int}) && !exists($d->{org}));
 push @d,['contact:org',{type=>'loc'}] if (exists($d->{org_loc}) && !exists($d->{org}));
 push @d,['contact:org',{type=>'int'}],['contact:org',{type=>'loc'}] if exists($d->{org});
 push @d,['contact:addr',{type=>'int'}] if (exists($d->{addr_int}) && !exists($d->{addr}));
 push @d,['contact:addr',{type=>'loc'}] if (exists($d->{addr_loc}) && !exists($d->{addr}));
 push @d,['contact:addr',{type=>'int'}],['contact:addr',{type=>'loc'}] if exists($d->{addr});
 push @d,['contact:voice'] if exists($d->{voice});
 push @d,['contact:fax']   if exists($d->{fax});
 push @d,['contact:email'] if exists($d->{email});
 return ['contact:disclose',@d,{flag=>(keys(%v))[0]}];
}

sub build_cdata
{
 my ($contact, $v) = @_;
 my $hasloc = $contact->has_loc();
 my $hasint = $contact->has_int();
 my @d;

 if ($hasint && !$hasloc && (($v & 5) == $v))
 {
  $contact->int2loc();
  $hasloc = 1;
 }
 elsif ($hasloc && !$hasint && (($v & 6) == $v))
 {
  $contact->loc2int();
  $hasint = 1;
 }

 my (@post1,@post2,@addr1,@addr2);
 _do_locint(\@post1,\@post2,$contact,'name');
 _do_locint(\@post1,\@post2,$contact,'org');
 _do_locint(\@addr1,\@addr2,$contact,'street');
 _do_locint(\@addr1,\@addr2,$contact,'city');
 _do_locint(\@addr1,\@addr2,$contact,'sp');
 _do_locint(\@addr1,\@addr2,$contact,'pc');
 _do_locint(\@addr1,\@addr2,$contact,'cc');
 push @post1,['contact:addr',@addr1] if @addr1;
 push @post2,['contact:addr',@addr2] if @addr2;
 
 push @d,['contact:ascii',@post1] if (@post1 && ($v & 5) && $hasloc);
 push @d,['contact:i15d',@post2] if (@post2 && ($v & 6) && $hasint);

 push @d,build_tel('contact:voice',$contact->voice()) if defined($contact->voice());
 push @d,build_tel('contact:fax',$contact->fax()) if defined($contact->fax());
 push @d,['contact:email',$contact->email()] if defined($contact->email());
 push @d,build_authinfo($contact);
 push @d,build_disclose($contact);
 return @d;


 sub _do_locint
 {
  my ($rl,$ri,$contact,$what)=@_;
  my @tmp=$contact->$what();
  return unless @tmp;
  if ($what eq 'street')
  {
   if (defined($tmp[0])) { foreach (@{$tmp[0]}) { push @$rl,['contact:street',$_]; } };
   if (defined($tmp[1])) { foreach (@{$tmp[1]}) { push @$ri,['contact:street',$_]; } };
  } else
  {
   if (defined($tmp[0])) { push @$rl,['contact:'.$what,$tmp[0]]; }
   if (defined($tmp[1])) { push @$ri,['contact:'.$what,$tmp[1]]; }
  }
 }
}

sub create
{
 my ($epp,$contact)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,'create',$contact);

 Net::DRI::Exception->die(1,'protocol/EPP',10,'Invalid contact '.$contact) unless (UNIVERSAL::isa($contact,'Net::DRI::Data::Contact'));
 $contact->validate(); ## will trigger an Exception if needed
 push @d,build_cdata($contact, $epp->{contacti18n});
 $mes->command_body(\@d);
}

sub create_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $credata=$mes->get_content('creData',$mes->ns('contact'));
 return unless $credata;

 my $c=$credata->getFirstChild();
 while ($c)
 {
  my $name=$c->localname() || $c->nodeName();
  if ($name eq 'id')
  {
   my $new=$c->getFirstChild()->getData();
   $rinfo->{contact}->{$oname}->{id}=$new if (defined($oname) && ($oname ne $new)); ## registry may give another id than the one we requested or not take ours into account at all !
   $oname=$new;
   $rinfo->{contact}->{$oname}->{id}=$oname;
   $rinfo->{contact}->{$oname}->{action}='create';
   $rinfo->{contact}->{$oname}->{exist}=1;
  } elsif ($name=~m/^(crDate)$/)
  {
   $rinfo->{contact}->{$oname}->{$1}=DateTime::Format::ISO8601->new()->parse_datetime($c->getFirstChild()->getData());
  }
  $c=$c->getNextSibling();
 }
}

sub update
{
 my ($epp, $contact, $todo) = @_;
 my $mes = $epp->message();

 Net::DRI::Exception::usererr_invalid_parameters($todo.' must be a Net::DRI::Data::Changes object') unless ($todo && ref($todo) && $todo->isa('Net::DRI::Data::Changes'));
 if ((grep { ! /^(?:add|del)$/ } $todo->types('status')) ||
     (grep { ! /^(?:set)$/ } $todo->types('info')))
 {
  Net::DRI::Exception->die(0,'protocol/EPP',11,'Only status add/del or info set available for contact');
 }

 my @d = build_command($mes,'update',$contact);

 my $sadd = $todo->add('status');
 my $sdel = $todo->del('status');
 push @d,['contact:add',$sadd->build_xml('contact:status')] if ($sadd);
 push @d,['contact:rem',$sdel->build_xml('contact:status')] if ($sdel);

 my $newc = $todo->set('info');
 if ($newc)
 {
  Net::DRI::Exception->die(1, 'protocol/EPP', 10, 'Invalid contact ' . $newc)
	unless (UNIVERSAL::isa($newc,'Net::DRI::Data::Contact'));
  $newc->validate(1); ## will trigger an Exception if needed
  my @c = build_cdata($newc, $epp->{contacti18n});
  push(@d, ['contact:chg', @c]) if (@c);
 }

 $mes->command_body(\@d);
}

####################################################################################################
## RFC3733 §3.2.6  Offline Review of Requested Actions

sub pandata_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $pandata=$mes->get_content('panData',$mes->ns('contact'));
 return unless $pandata;

 my $c=$pandata->firstChild();
 while ($c)
 {
  my $name=$c->localname() || $c->nodeName();
  next unless $name;

  if ($name eq 'id')
  {
   $oname=$c->getFirstChild()->getData();
   $rinfo->{contact}->{$oname}->{action}='create_review';
   $rinfo->{contact}->{$oname}->{result}=Net::DRI::Util::xml_parse_boolean($c->getAttribute('paResult'));
   $rinfo->{contact}->{$oname}->{exist}=$rinfo->{contact}->{$oname}->{result};
  } elsif ($name eq 'paTRID')
  {
   my @tmp=$c->getElementsByTagNameNS($mes->ns('_main'),'clTRID');
   $rinfo->{contact}->{$oname}->{trid}=$tmp[0]->getFirstChild()->getData() if (@tmp && $tmp[0]);
   $rinfo->{contact}->{$oname}->{svtrid}=($c->getElementsByTagNameNS($mes->ns('_main'),'svTRID'))[0]->getFirstChild()->getData();
  } elsif ($name eq 'paDate')
  {
   $rinfo->{contact}->{$oname}->{date}=DateTime::Format::ISO8601->new()->parse_datetime($c->firstChild->getData());
  }
  $c=$c->getNextSibling();
 }
}

####################################################################################################

1;
