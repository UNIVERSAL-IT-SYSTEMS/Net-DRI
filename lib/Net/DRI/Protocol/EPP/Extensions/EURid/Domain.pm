## Domain Registry Interface, EURid Domain EPP extension commands
## (based on EURid registration_guidelines_v1_0E-epp.pdf)
##
## Copyright (c) 2005,2006,2007,2008 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::EURid::Domain;

use strict;

use Net::DRI::Util;
use Net::DRI::Exception;
use Net::DRI::Protocol::EPP::Core::Domain;
use Net::DRI::Data::Hosts;
use Net::DRI::Data::ContactSet;

use DateTime::Format::ISO8601;

our $VERSION=do { my @r=(q$Revision: 1.10 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::EURid::Domain - EURid EPP Domain extension commands for Net::DRI

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

Copyright (c) 2005,2006,2007,2008 Patrick Mevzek <netdri@dotandco.com>.
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
          create            => [ \&create, undef ],
          update            => [ \&update, undef ],
          info              => [ \&info, \&info_parse ],
	  check             => [ \&check, \&check_parse ],
          delete            => [ \&delete, undef ],
          transfer_request  => [ \&transfer_request, undef ],
          transfer_cancel   => [ \&transfer_cancel, undef ],
          transfer_query    => [ \&transfer_query, undef ],
          transfer_answer   => [ \&transfer_answer, undef ],
          undelete          => [ \&undelete, undef ],
          transferq_request => [ \&transferq_request, undef ],
          transferq_cancel  => [ \&transferq_cancel, undef ],
          transferq_answer  => [ \&transferq_answer, undef ],
          transferq_accept  => [ \&transferq_accept, undef ],
          transferq_refuse  => [ \&transferq_refuse, undef ],
          transferq_query   => [ \&transferq_query, undef ],
          trade_request     => [ \&trade_request, undef ],
          trade_cancel      => [ \&trade_cancel, undef ],
          trade_answer      => [ \&trade_answer, undef ],
          trade_accept      => [ \&trade_accept, undef ],
          trade_refuse      => [ \&trade_refuse, undef ],
          trade_query       => [ \&trade_query, undef ],
          reactivate        => [ \&reactivate, undef ],
         );

 return { 'domain' => \%tmp };
}

sub capabilities_add
{
 return { 'domain_update' => { 'nsgroup' => [ 'add','del']} };
}

####################################################################################################

sub build_command_extension
{
 my ($mes,$epp,$tag)=@_;
 
 my @ns=@{$mes->ns->{eurid}};
 return $mes->command_extension_register($tag,sprintf('xmlns:eurid="%s" xsi:schemaLocation="%s %s"',$ns[0],$ns[0],$ns[1]));
}

sub verify_rd
{
 my ($rd, $key) = @_;
 return 0 unless (defined($key) && $key);
 return 0 unless (defined($rd) && (ref($rd) eq 'HASH') &&
	exists($rd->{$key}) && defined($rd->{$key}));
 return 1;
}

sub create
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();

 return unless verify_rd($rd, 'nsgroup');
 my @n=add_nsgroup($rd->{nsgroup});

 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 $mes->command_extension($eid,['eurid:create',['eurid:domain',@n]]);
}

sub update
{
 my ($epp,$domain,$todo)=@_;
 my $mes=$epp->message();

 if (grep { ! /^(?:add|del)$/ } $todo->types('nsgroup'))
 {
  Net::DRI::Exception->die(0,'protocol/EPP',11,'Only nsgroup add/del available for domain');
 }

 my $nsgadd=$todo->add('nsgroup');
 my $nsgdel=$todo->del('nsgroup');
 return unless ($nsgadd || $nsgdel);

 my @n;
 push @n,['eurid:add',add_nsgroup($nsgadd)] if $nsgadd;
 push @n,['eurid:rem',add_nsgroup($nsgdel)] if $nsgdel;

 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 $mes->command_extension($eid,['eurid:update',['eurid:domain',@n]]);
}

sub info
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 $mes->command_extension($eid,['eurid:info',['eurid:domain',{version=>'2.0'}]]);
}

sub info_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $infdata=$mes->get_content('infData',$mes->ns('eurid'),1);
 return unless $infdata;

 my @c;
 foreach my $el ($infdata->getElementsByTagNameNS($mes->ns('eurid'),'nsgroup'))
 {
  push @c,Net::DRI::Data::Hosts->new()->name($el->getFirstChild()->getData());
 }

 $rinfo->{domain}->{$oname}->{nsgroup}=\@c;

 my $cs=$rinfo->{domain}->{$oname}->{status};
 foreach my $s (qw/onhold quarantined/) ## onhold here has nothing to do with EPP client|serverHold, unfortunately
 {
  my @s=$infdata->getElementsByTagNameNS($mes->ns('eurid'),$s);
  next unless @s;
  $cs->add($s) if Net::DRI::Util::xml_parse_boolean($s[0]->getFirstChild()->getData()); ## should we also remove 'ok' status then ?
 }
 my $pd=DateTime::Format::ISO8601->new();
 foreach my $d (qw/availableDate deletionDate/)
 {
  my @d=$infdata->getElementsByTagNameNS($mes->ns('eurid'),$d);
  next unless @d;
  $rinfo->{domain}->{$oname}->{$d}=$pd->parse_datetime($d[0]->getFirstChild()->getData());
 }

 my $pt=$infdata->getElementsByTagNameNS($mes->ns('eurid'),'pendingTransaction');
 if ($pt->size())
 {
  my %p;
  foreach my $t (qw/trade transfer transferq/)
  {
   my $r=$infdata->getElementsByTagNameNS($mes->ns('eurid'),$t);
   next unless $r->size();
   $p{type}=$t;
   $cs->add(($t eq 'trade')? 'pendingUpdate' : 'pendingTransfer');

   my $c=$r->shift()->getFirstChild();
   while ($c)
   {
    next unless ($c->nodeType() == 1); ## only for element nodes
    my $name=$c->localname() || $c->nodeName();
    next unless $name;
    if ($name eq 'domain')
    {
     my $cs2=Net::DRI::Data::ContactSet->new();
     my $cf=$po->factories()->{contact};
     my $cc=$c->getFirstChild();
     while($cc)
     {
      next unless ($cc->nodeType() == 1); ## only for element nodes
      my $name2=$cc->localname() || $cc->nodeName();
      next unless $name2;
      if ($name2=~m/^(registrant|tech|billing)$/)
      {
       $cs2->set($cf->()->srid($cc->getFirstChild()->getData()),$name2);       
      } elsif ($name2=~m/^(trDate)$/)
      {
       $p{$1}=$pd->parse_datetime($cc->getFirstChild()->getData());
      }
     } continue { $cc=$cc->getNextSibling(); }
     $p{contact}=$cs2;
    } elsif ($name=~m/^(initiationDate|unscreenedFax)$/)
    {
     $p{$1}=$pd->parse_datetime($c->getFirstChild()->getData());
    } elsif ($name=~m/^(status|replySeller|replyBuyer|replyOwner)$/)
    {
     $p{$1}=$c->getFirstChild()->getData();
    }
   } continue { $c=$c->getNextSibling(); }
   last;
  }
  $rinfo->{domain}->{$oname}->{pending_transaction}=\%p;
 }
}

sub check
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 $mes->command_extension($eid,['eurid:check',['eurid:domain',{version=>'2.0'}]]);
}

sub check_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $chkdata=$mes->get_content('chkData',$mes->ns('eurid'),1);
 return unless $chkdata;

 foreach my $cd ($chkdata->getElementsByTagNameNS($mes->ns('eurid'),'cd'))
 {
  my $c=$cd->getFirstChild();
  my $domain;
  while($c)
  {
   next unless ($c->nodeType() == 1); ## only for element nodes
   my $n=$c->localname() || $c->nodeName();
   if ($n eq 'name')
   {
    $domain=lc($c->getFirstChild()->getData());
    $rinfo->{domain}->{$domain}->{action}='check';
    foreach my $ef (qw/accepted expired initial rejected/) ## only for domain applications
    {
     next unless $c->hasAttribute($ef);
     $rinfo->{domain}->{$domain}->{'application_'.$ef}=Net::DRI::Util::xml_parse_boolean($c->getAttribute($ef));
    }
   } elsif ($n eq 'availableDate')
   {
    $rinfo->{domain}->{$domain}->{availableDate}=DateTime::Format::ISO8601->new()->parse_datetime($c->getFirstChild()->getData());
   }
  } continue { $c=$c->getNextSibling(); }
 }
}


sub delete
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();

 return unless (verify_rd($rd, 'deleteDate'));

 Net::DRI::Util::check_isa($rd->{deleteDate},'DateTime');

 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 my @n=('eurid:delete',['eurid:domain',['eurid:deleteDate',$rd->{deleteDate}->set_time_zone('UTC')->strftime("%Y-%m-%dT%T.%NZ")]]);
 $mes->command_extension($eid,\@n);
}

sub transfer_request
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();

 # We must overwrite the command body here in case someone specified
 # an authcode.
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transfer',{op=>'request'}], $domain);
 $mes->command_body(\@d);

 my @n=add_transfer($epp,$mes,$domain,$rd);
 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 $mes->command_extension($eid,['eurid:transfer',@n]);
}

sub transfer_cancel
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @n;

 # We must overwrite the command body here in case someone specified
 # an authcode.
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transfer', {op => 'cancel'}], $domain);
 $mes->command_body(\@d);

 @n = ['eurid:reason', $rd->{reason}] if (verify_rd($rd, 'reason'));
 my $eid = build_command_extension($mes, $epp, 'eurid:ext');
 $mes->command_extension($eid, ['eurid:cancel', @n]);
}

sub transfer_query
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @n;

 # We must overwrite the command body here in case someone specified
 # an authcode.
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transfer', {op => 'query'}], $domain);
 $mes->command_body(\@d);

 my $eid = build_command_extension($mes, $epp, 'eurid:ext');
 push(@n, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 $mes->command_extension($eid, ['eurid:transfer', @n]);
}

sub transfer_answer
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @n;

 # We must overwrite the command body here in case someone specified
 # an authcode.
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transfer', {op => (verify_rd($rd, 'approve') && $rd->{approve} ?
		'approve' : 'reject')}], $domain);
 $mes->command_body(\@d);

 my $eid = build_command_extension($mes, $epp, 'eurid:ext');
 push(@n, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 $mes->command_extension($eid, ['eurid:transfer', @n]);
}

sub add_transfer
{
 my ($epp,$mes,$domain,$rd)=@_;
 Net::DRI::Exception::usererr_insufficient_parameters('rd should be a hash')
	unless (defined($rd) && (ref($rd) eq 'HASH'));
 my $cs=$rd->{contact};
 my @n;
 my @d;

 Net::DRI::Exception::usererr_insufficient_parameters('registrant and billing are mandatory') unless (UNIVERSAL::isa($cs,'Net::DRI::Data::ContactSet') && $cs->has_type('registrant') && $cs->has_type('billing'));

 my $creg=$cs->get('registrant');
 Net::DRI::Exception::usererr_invalid_parameters('registrant must be a contact object or #AUTO#') unless (UNIVERSAL::isa($creg,'Net::DRI::Data::Contact') || (!ref($creg) && ($creg eq '#AUTO#')));
 push @n,['eurid:registrant',ref($creg)? $creg->srid() : '#AUTO#' ];

 if (verify_rd($rd, 'trDate'))
 {
  Net::DRI::Util::check_isa($rd->{trDate},'DateTime');
  push @n,['eurid:trDate',$rd->{trDate}->set_time_zone('UTC')->strftime("%Y-%m-%dT%T.%NZ")];
 }

 my $cbill=$cs->get('billing');
 Net::DRI::Exception::usererr_invalid_parameters('billing must be a contact object') unless UNIVERSAL::isa($cbill,'Net::DRI::Data::Contact');
 push @n,['eurid:billing',$cbill->srid()];

 push @n,add_contact('tech',$cs,9) if $cs->has_type('tech');
 push @n,add_contact('onsite',$cs,5) if $cs->has_type('onsite');

 if (verify_rd($rd, 'ns') && (UNIVERSAL::isa($rd->{ns},'Net::DRI::Data::Hosts')) && !$rd->{ns}->is_empty())
 {
  my $n=Net::DRI::Protocol::EPP::Core::Domain::build_ns($epp,$rd->{ns},$domain,'eurid');
  my @ns=@{$mes->ns->{domain}};
  push @$n,{'xmlns:domain'=>$ns[0],'xsi:schemaLocation'=>sprintf('%s %s',@ns)};
  push @n,$n;
 }

 push @n,add_nsgroup($rd->{nsgroup}) if (verify_rd($rd, 'nsgroup'));
 push(@d, ['eurid:domain', @n]);
 push(@d, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 return @d;
}

sub add_nsgroup
{
 my ($nsg)=@_;
 return unless (defined($nsg) && $nsg);
 my @a=grep { defined($_) && Net::DRI::Util::xml_is_normalizedstring($_,1,100) } map { UNIVERSAL::isa($_,'Net::DRI::Data::Hosts')? $_->name() : $_ } (ref($nsg) eq 'ARRAY')? @$nsg : ($nsg);
 return map { ['eurid:nsgroup',$_] } grep {defined} @a[0..8];
}

sub add_contact
{
 my ($type,$cs,$max)=@_;
 $max--;
 my @r=grep { UNIVERSAL::isa($_,'Net::DRI::Data::Contact') } ($cs->get($type));
 return map { ['eurid:'.$type,$_->srid()] } grep {defined} @r[0..$max];
}

sub undelete
{
 my ($epp,$domain)=@_;
 my $mes=$epp->message();
 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,'undelete',$domain);
 $mes->command_body(\@d);
}

sub transferq_request
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,['transferq',{'op'=>'request'}],$domain);

 if (Net::DRI::Protocol::EPP::Core::Domain::verify_rd($rd,'period'))
 {
  Net::DRI::Util::check_isa($rd->{period},'DateTime::Duration');
  push @d,Net::DRI::Protocol::EPP::Core::Domain::build_period($rd->{period});
 }

 $mes->command_body(\@d);

 my @n=add_transfer($epp,$mes,$domain,$rd);
 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 $mes->command_extension($eid,['eurid:transferq',@n]);
}

sub transferq_cancel
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transferq', {'op' => 'cancel'}], $domain);
 my @n;

 $mes->command_body(\@d);

 my $eid = build_command_extension($mes,$epp,'eurid:ext');
 @n = ['eurid:reason', $rd->{reason}] if (verify_rd($rd, 'reason'));
 $mes->command_extension($eid,['eurid:cancel',@n]);
}

sub transferq_query
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transferq', {'op' => 'query'}], $domain);
 my @n;

 $mes->command_body(\@d);

 my $eid = build_command_extension($mes, $epp, 'eurid:ext');
 push(@n, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 $mes->command_extension($eid, ['eurid:transfer', @n]);
}

sub transferq_query
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @n;

 # We must overwrite the command body here in case someone specified
 # an authcode.
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transferq', {'op' => 'query'}], $domain);
 $mes->command_body(\@d);

 my $eid = build_command_extension($mes,$epp,'eurid:ext');
 push(@n, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 $mes->command_extension($eid,['eurid:transfer',@n]);
}

sub transferq_answer
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @n;

 # We must overwrite the command body here in case someone specified
 # an authcode.
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,
	['transferq', {'op' => (verify_rd($rd, 'approve') && $rd->{approve} ?
		'approve' : 'reject')}], $domain);
 $mes->command_body(\@d);

 my $eid = build_command_extension($mes,$epp,'eurid:ext');
 push(@n, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 $mes->command_extension($eid,['eurid:transfer',@n]);
}

sub transferq_accept
{
 my ($epp, $domain, $rd) = @_;
 $rd->{approve} = 1;
 return transferq_answer($epp, $domain, $rd);
}

sub transferq_refuse
{
 my ($epp, $domain, $rd) = @_;
 $rd->{approve} = 0;
 return transferq_answer($epp, $domain, $rd);
}

sub trade_request
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,['trade',{op=>'request'}],$domain);
 $mes->command_body(\@d);

 my @n=add_transfer($epp,$mes,$domain,$rd);
 my $eid=build_command_extension($mes,$epp,'eurid:ext');
 $mes->command_extension($eid,['eurid:trade',@n]);
}

sub trade_cancel
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes, ['trade',
	{op => 'cancel'}], $domain);
 my @n;

 $mes->command_body(\@d);

 my $eid=build_command_extension($mes, $epp, 'eurid:ext');
 @n = ['eurid:reason', $rd->{reason}] if (verify_rd($rd, 'reason'));
 $mes->command_extension($eid, ['eurid:cancel', @n]);
}

sub trade_answer
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes, ['trade',
	{op => (verify_rd($rd, 'approve') && $rd->{approve} ?
		'approve' : 'reject')}], $domain);
 my @n;

 $mes->command_body(\@d);

 my $eid=build_command_extension($mes, $epp, 'eurid:ext');
 push(@n, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 $mes->command_extension($eid, ['eurid:transfer', @n]);
}

sub trade_accept
{
 my ($epp, $domain, $rd) = @_;
 $rd->{approve} = 1;
 return trade_answer($epp, $domain, $rd);
}

sub trade_refuse
{
 my ($epp, $domain, $rd) = @_;
 $rd->{approve} = 0;
 return trade_answer($epp, $domain, $rd);
}

sub trade_query
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes, ['trade',
	{op => 'query'}], $domain);
 my @n;

 $mes->command_body(\@d);

 my $eid=build_command_extension($mes, $epp, 'eurid:ext');
 push(@n, ['eurid:ownerAuthCode', $rd->{auth}->{pw}])
	if (verify_rd($rd, 'auth') && verify_rd($rd->{auth}, 'pw'));
 $mes->command_extension($eid, ['eurid:transfer', @n]);
}

sub reactivate
{
 my ($epp,$domain)=@_;
 my $mes=$epp->message();
 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,'reactivate',$domain);
 $mes->command_body(\@d);
}

####################################################################################################
1;
