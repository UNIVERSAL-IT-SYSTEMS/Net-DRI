## Domain Registry Interface, AFNIC Email Domain commands
##
## Copyright (c) 2006 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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
#########################################################################################

package Net::DRI::Protocol::AFNIC::Email::Domain;

use strict;
use Net::DRI::Util;

our $VERSION=do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::AFNIC::Email::Domain - AFNIC Email Domain commands for Net::DRI

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

Copyright (c) 2006 Patrick Mevzek <netdri@dotandco.com>.
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
          create => [ \&create, undef ], ## TODO : parsing of return messages
          delete => [ \&delete, undef ],
          update => [ \&update, undef ],
          transfer_request => [ \&transfer_request, undef],
          trade => [ \&trade, undef],
         );

 return { 'domain' => \%tmp };
}

sub verify_rd
{
 my ($rd,$key)=@_;
 return 0 unless (defined($key) && $key);
 return 0 unless (defined($rd) && (ref($rd) eq 'HASH') && exists($rd->{$key}) && defined($rd->{$key}));
 return 1;
}

sub format_tel
{
 my $in=shift;
 $in=~s/x.*$//;
 $in=~s/\./ /;
 return $in;
}

sub add_starting_block
{
 my ($action,$domain,$mes,$rd)=@_;
 my $ca=$mes->client_auth();

 $mes->line('1a',$action);
 $mes->line('1b',$ca->{id}); ## code fournisseur
 $mes->line('1c',$ca->{pw}); ## mot de passe
 $mes->line('1e',$mes->trid()); ## reference client (=trid) ## allow more/other ?
 $mes->line('1f','2.0.0');
 $mes->line('1g',$rd->{auth_code}) if ($action=~m/^[CD]$/ && verify_rd($rd,'auth_code') && $rd->{auth_code}); ## authorization code for reserved domain names

 $mes->line('2a',$domain);
}

sub create
{
 my ($a,$domain,$rd)=@_;
 my $mes=$a->message();

 add_starting_block('C',$domain,$mes,$rd);
 
 Net::DRI::Exception::usererr_insufficient_parameters("contacts are mandatory") unless (verify_rd($rd,'contact') && UNIVERSAL::isa($rd->{contact},'Net::DRI::Data::ContactSet'));
 my $cs=$rd->{contact};
 my $co=$cs->get('registrant');
 Net::DRI::Exception::usererr_insufficient_parameters("registrant contact is mandatory") unless ($co && UNIVERSAL::isa($co,'Net::DRI::Data::Contact::AFNIC'));
 $co->validate();
 $co->validate_is_french() unless ($co->roid()); ## registrant must be in France

 $mes->line('3w',$co->org()? 'PM' : 'PP');

 if ($co->org()) ## PM
 {
  add_company_info($mes,$co);
 } else ## PP
 {
  Net::DRI::Exception::usererr_insufficient_parameters("name or key needed for PP") unless ($co->name() || $co->key());
  if ($co->key())
  {
   $mes->line('3q',$co->key());
  } else
  {
   $mes->line('3a',$co->name());
   my $b=$co->birth();
   Net::DRI::Exception::usererr_insufficient_parameters("birth data mandatory, if no registrant key provided") unless ($b && (ref($b) eq 'HASH') && exists($b->{date}) && exists($b->{place}));
   $mes->line('3r',(ref($b->{date}))? $b->{date}->strftime('%d/%m/%Y') : $b->{date});
   $mes->line('3s',$b->{place});
  }
 }

 add_owner_info($mes,$co);
 add_maintainer_disclose($mes,$co,$rd->{maintainer}) unless $mes->line('3x');
 add_admin_contact($mes,$cs); ## optional
 add_tech_contacts($mes,$cs); ## mandatory

 Net::DRI::Exception::usererr_insufficient_parameters("at least 2 nameservers are mandatory") unless verify_rd($rd,'ns');
 add_all_ns($domain,$mes,$rd->{ns});

 add_installation($mes,$rd->{installation_type},$rd->{form_type});
}

sub add_company_info
{
 my ($mes,$co)=@_;
 $mes->line('3a',$co->org());
 Net::DRI::Exception::usererr_insufficient_parameters("one legal form must be provided") unless ($co->legal_form() || $co->legal_form_other());
 $mes->line('3h',$co->legal_form())       if $co->legal_form();
 $mes->line('3i',$co->legal_form_other()) if $co->legal_form_other();
 Net::DRI::Exception::usererr_insufficient_parameters("legal id must be provided if no trademark") if (($co->legal_form() eq 'S') && !$co->trademark() && !$co->legal_id());
 $mes->line('3j',$co->legal_id())         if $co->legal_id();
 my $jo=$co->jo();
 Net::DRI::Exception::usererr_insufficient_parameters("jo data is needed for non profit organization without legal id or trademark") if (($co->legal_form() eq 'A') && !$co->legal_id() && !$co->trademark() && (!$jo || (ref($jo) ne 'HASH') || !exists($jo->{date_publication}) || !exists($jo->{page})));
 if ($jo && (ref($jo) eq 'HASH'))
 {
  $mes->line('3k',$jo->{date_declaration}) if (exists($jo->{date_declaration}) && $jo->{date_declaration});
  $mes->line('3l',$jo->{date_publication}) if (exists($jo->{date_publication}) && $jo->{date_publication});
  $mes->line('3m',$jo->{number})           if (exists($jo->{number})           && $jo->{number});
  $mes->line('3n',$jo->{page})             if (exists($jo->{page})             && $jo->{page});
 }
 $mes->line('3p',$co->trademark()) if $co->trademark();
}


sub add_installation
{
 my ($mes,$installation,$form)=@_;

 ## Default = A = waiting for client, otherwise I = direct installation
 $mes->line('8a',$installation) if (defined($installation) && $installation=~m/^[IA]$/);
 ## S = standard = fax need to be sent, Default = E = Express = no fax
 $mes->line('9a',$form)         if (defined($form) && $form=~m/^[SE]$/);
}

sub add_owner_info
{
 my ($mes,$co)=@_;
 
 if ($co->org() || !$co->roid())
 {
  my $s=$co->street();
  Net::DRI::Exception::usererr_insufficient_parameters("1 line of address at least needed if no nichandle") unless ($s && (ref($s) eq 'ARRAY') && @$s && $s->[0]);
  $mes->line('3b',$s->[0]);
  $mes->line('3c',$s->[1]) if $s->[1];
  $mes->line('3d',$s->[2]) if $s->[2];
  Net::DRI::Exception::usererr_insufficient_parameters("city, pc & cc mandatory if no nichandle") unless ($co->city() && $co->pc() && $co->cc());
  $mes->line('3e',$co->city());
  $mes->line('3f',$co->pc());
  $mes->line('3g',uc($co->cc()));
  Net::DRI::Exception::usererr_insufficient_parameters("voice & email mandatory if no nichandle") unless ($co->voice() && $co->email());
  $mes->line('3t',format_tel($co->voice()));
  $mes->line('3u',format_tel($co->fax())) if $co->fax();
  $mes->line('3v',$co->email());
 } else
 {
  $mes->line('3x',$co->roid());
 }
}

sub add_maintainer_disclose
{
 my ($mes,$co,$maintainer)=@_;
 Net::DRI::Exception::usererr_insufficient_parameters("maintainer mandatory if no nichandle") unless (defined($maintainer) && $maintainer=~m/^[A-Z0-9][-A-Z0-9]+[A-Z0-9]$/i);
 $mes->line('3y',$maintainer);
 Net::DRI::Exception::usererr_insufficient_parameters("disclose option is mandatory if no nichandle") unless ($co->disclose());
 $mes->line('3z',$co->disclose());
}

sub add_admin_contact
{
 my ($mes,$cs)=@_;
 my $co=$cs->get('admin');
 $mes->line('4a',$co->roid()) if ($co && UNIVERSAL::isa($co,'Net::DRI::Data::Contact') && $co->roid());
}

sub add_tech_contacts
{
 my ($mes,$cs)=@_;
 my @co=map { $_->roid() } grep { UNIVERSAL::isa($_,'Net::DRI::Data::Contact') } $cs->get('tech');
 Net::DRI::Exception::usererr_insufficient_parameters("at least one technical contact is mandatory") unless @co;
 $mes->line('5a',$co[0]);
 $mes->line('5c',$co[1]) if $co[1];
 $mes->line('5e',$co[2]) if $co[2];
}

sub add_all_ns
{
 my ($domain,$mes,$ns)=@_;
 Net::DRI::Exception::usererr_insufficient_parameters("at least 2 nameservers are mandatory") unless (defined($ns) && ref($ns) && UNIVERSAL::isa($ns,'Net::DRI::Data::Hosts') && !$ns->is_empty() && $ns->count()>=2);

 add_one_ns($mes,$ns,1,$domain,'6a','6b');
 add_one_ns($mes,$ns,2,$domain,'7a','7b');
 my $nsc=$ns->count();
 add_one_ns($mes,$ns,3,$domain,'7c','7d') if ($nsc >= 3);
 add_one_ns($mes,$ns,4,$domain,'7e','7f') if ($nsc >= 4);
 add_one_ns($mes,$ns,5,$domain,'7g','7h') if ($nsc >= 5);
 add_one_ns($mes,$ns,6,$domain,'7i','7j') if ($nsc >= 6);
 add_one_ns($mes,$ns,7,$domain,'7k','7l') if ($nsc >= 7);
 add_one_ns($mes,$ns,8,$domain,'7m','7n') if ($nsc >= 8);
}

sub add_one_ns
{
 my ($mes,$ns,$pos,$domain,$l1,$l2)=@_;
 my @g=$ns->get_details($pos);
 return unless @g;
 $mes->line($l1,$g[0]); ## name
 return unless ($g[0]=~m/\S+\.${domain}/i || (lc($g[0]) eq lc($domain)));
 $mes->line($l2,join(' ',@{$g[1]},@{$g[2]})); ## nameserver in domain, we add IPs
}

sub delete
{
 my ($a,$domain,$rd)=@_;
 my $mes=$a->message();

 add_starting_block('S',$domain,$mes,$rd);
 add_installation($mes,$rd->{installation_type},$rd->{form_type});
}

sub update
{
 my ($a,$domain,$todo,$rd)=@_;
 my $mes=$a->message();

 Net::DRI::Util::check_isa($todo,'Net::DRI::Data::Changes');

 if ((grep { ! /^(?:ns|contact)/ } $todo->types()) || 
     (grep { ! /^(?:set)$/ } $todo->types('ns')) ||
     (grep { ! /^(?:set)$/ } $todo->types('contact'))
    )
 {
  Net::DRI::Exception->die(0,'protocol/AFNIC/Email',11,'Only ns/contact set available for domain');
 }

 my $ns=$todo->set('ns');
 my $cs=$todo->set('contact');

 my $wc=defined($cs) && ref($cs) && UNIVERSAL::isa($cs,'Net::DRI::Data::ContactSet');
 Net::DRI::Exception::usererr_invalid_parameters("can not change both admin & tech contacts at the same time") if ($wc && $cs->has_type('tech') && ($cs->has_type('admin') || $cs->has_type('registrant')));

 ## Technical change (DNS / Tech contacts)
 if ($wc && $cs->has_type('tech'))
 {
  add_starting_block('T',$domain,$mes); ## no $rd here !
  add_tech_contacts($mes,$cs); ##  tech contacts mandatory even for only nameserver changes !
  add_all_ns($domain,$mes,$ns);
  add_installation($mes,$rd->{installation_type},$rd->{form_type}) if (defined($rd) && (ref($rd) eq 'HASH'));
  return;
 }

 ## Admin change (Admin contact)
 if ($wc && ($cs->has_type('admin') || $cs->has_type('registrant')))
 {
  add_starting_block('A',$domain,$mes);
  my $co=$cs->get('registrant');
  if (defined($co) && UNIVERSAL::isa($co,'Net::DRI::Data::Contact') && $co->org()) ## only for PM
  {
   $co->validate();
   add_owner_info($mes,$co);
  } else
  {
   my $ca=$cs->get('admin');
   Net::DRI::Exception::usererr_insufficient_parameters("contact admin is mandatory for PP admin change") unless ($ca && UNIVERSAL::isa($ca,'Net::DRI::Data::Contact') && $ca->roid());
  }
  add_admin_contact($mes,$cs);

  add_installation($mes,$rd->{installation_type},$rd->{form_type}) if (defined($rd) && (ref($rd) eq 'HASH'));
  return;
 } 

 Net::DRI::Exception::err_assert('We do not know how to handle this kind of update, please report.');
}

sub trade
{
 my ($a,$domain,$rd)=@_;
 my $mes=$a->message();

 create($a,$domain,$rd);
 $mes->line('1a','P');
 $mes->line('1h',$rd->{trade_type}) if (verify_rd($rd,'trade_type') && $rd->{trade_type}=~m/^[VF]$/);
}

sub transfer_request
{
 my ($a,$domain,$rd)=@_;
 my $mes=$a->message();

 add_starting_block('D',$domain,$mes,$rd);
 Net::DRI::Exception::usererr_invalid_parameters() unless (defined($rd) && (ref($rd) eq 'HASH') && keys(%$rd));
 Net::DRI::Exception::usererr_insufficient_parameters("contacts are mandatory") unless (verify_rd($rd,'contact') && UNIVERSAL::isa($rd->{contact},'Net::DRI::Data::ContactSet'));
 my $cs=$rd->{contact};
 my $co=$cs->get('registrant');
 Net::DRI::Exception::usererr_insufficient_parameters("registrant contact is mandatory") unless ($co && UNIVERSAL::isa($co,'Net::DRI::Data::Contact::AFNIC'));
 $co->validate();
 $co->validate_is_french() unless ($co->roid()); ## registrant must be in France

 if ($co->org()) ## PM
 {
  add_company_info($mes,$co);
 } else ## PP
 {
  Net::DRI::Exception::usererr_insufficient_parameters("key mandatory for PP") unless ($co->key());
  $mes->line('3q',$co->key());
 }

 add_tech_contacts($mes,$cs); ##  tech contacts mandatory
 add_all_ns($domain,$mes,$rd->{ns}); ## ns mandatory
 add_installation($mes,$rd->{installation_type},$rd->{form_type});
}

####################################################################################################
1;