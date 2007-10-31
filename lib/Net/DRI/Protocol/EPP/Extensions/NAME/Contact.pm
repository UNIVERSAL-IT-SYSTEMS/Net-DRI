## Domain Registry Interface, .NAME EPP Contact commands
##
## Copyright (c) 2005,2006,2007 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::NAME::Contact;

use strict;

use Net::DRI::Util;
use Net::DRI::Exception;
use Net::DRI::Protocol::EPP;

use DateTime::Format::ISO8601;

our $VERSION=do { my @r=(q$Revision: 1.11 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

use base qw(Net::DRI::Protocol::EPP::Core::Contact);

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NAME::Contact - EPP .NAME Contact commands for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt>

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


##########################################################

#sub register_commands
#{
# my ($class,$version)=@_;
# my %tmp=( 
#           check  => [ \&check, \&check_parse ],
#           info   => [ \&info, \&info_parse ],
#           transfer_query  => [ \&transfer_query, \&transfer_parse ],
#           create => [ \&create, \&create_parse ],
#           delete => [ \&delete ],
#           transfer_request => [ \&transfer_request, \&transfer_parse ],
#           transfer_cancel  => [ \&transfer_cancel,\&transfer_parse ],
#           transfer_answer  => [ \&transfer_answer,\&transfer_parse ],
#	   update => [ \&update ],
#           review_complete => [ undef, \&pandata_parse ],
#         );
#
# $tmp{check_multi}=$tmp{check};
# return { 'contact' => \%tmp };
#}
sub register_commands
{
 my ($class,$version)=@_;
 my %tmp=( 
           create => [ \&create ],
	   update => [ \&update ]
         );

 return { 'contact' => \%tmp };
}

sub build_command
{
 shift if (UNIVERSAL::isa($_[0], __PACKAGE__));
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
  my $az=$contact[0]->auth();
  if ($az && ref($az) && exists($az->{pw}))
  {
   push @d,['contact:authInfo',['contact:pw',$az->{pw}]];
  }
 }
 
 return @d;
}

##################################################################################################

############ Transform commands

sub build_cdata
{
 my $contact=shift;
 my @d;

 my (@postl,@posti,@addrl,@addri);
 _do_locint(\@postl,\@posti,$contact,'name');
 _do_locint(\@postl,\@posti,$contact,'org');
 _do_locint(\@addrl,\@addri,$contact,'street');
 _do_locint(\@addrl,\@addri,$contact,'city');
 _do_locint(\@addrl,\@addri,$contact,'sp');
 _do_locint(\@addrl,\@addri,$contact,'pc');
 _do_locint(\@addrl,\@addri,$contact,'cc');
 push @posti,['contact:addr',@addri] if @addri;
 push @d,['contact:postalInfo',@posti,{type=>'int'}] if @posti;


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

 sub build_authinfo
 {
  shift if (UNIVERSAL::isa($_[0], __PACKAGE__));
  my $contact = shift;
  my $az=(ref($contact) eq 'HASH' ? $contact : $contact->auth());
  return () unless ($az && ref($az) && exists($az->{pw}));
  return ['contact:authInfo',['contact:pw',$az->{pw}]];
 }

 sub build_tel
 {
  shift if (UNIVERSAL::isa($_[0], __PACKAGE__));
  my ($name,$tel)=@_;
  if ($tel=~m/^(\S+)x(\S+)$/)
  {
   return [$name,$1,{x=>$2}];
  }
  else
  {
   return [$name,$tel];
  }
 }

 sub build_disclose
 {
  shift if (UNIVERSAL::isa($_[0], __PACKAGE__));
  my $contact=shift;
  my $d=$contact->disclose();
  return () unless ($d && ref($d));
  my %v = map { $_ => 1 } values(%$d);
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
}

sub create
{
 my ($epp,$contact)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,'create',$contact);
 
 Net::DRI::Exception->die(1,'protocol/EPP',10,'Invalid contact '.$contact)
	unless (UNIVERSAL::isa($contact,'Net::DRI::Data::Contact'));
 $contact->validate(); ## will trigger an Exception if needed
 push @d,build_cdata($contact);
 $mes->command_body(\@d);
}

sub update
{
 my ($epp,$contact,$todo)=@_;
 my $mes=$epp->message();

 Net::DRI::Exception::usererr_invalid_parameters($todo." must be a Net::DRI::Data::Changes object") unless ($todo && ref($todo) && $todo->isa('Net::DRI::Data::Changes'));
 if ((grep { ! /^(?:add|del)$/ } $todo->types('status')) ||
     (grep { ! /^(?:set)$/ } $todo->types('info'))
    )
 {
  Net::DRI::Exception->die(0,'protocol/EPP',11,'Only status add/del or info set available for contact');
 }

 my @d=build_command($mes,'update',$contact);

 my $sadd=$todo->add('status');
 my $sdel=$todo->del('status');
 push @d,['contact:add',$sadd->build_xml('contact:status')] if ($sadd);
 push @d,['contact:rem',$sdel->build_xml('contact:status')] if ($sdel);

 my $newc=$todo->set('info');
 if ($newc)
 {
  Net::DRI::Exception->die(1,'protocol/EPP',10,'Invalid contact '.$newc)
	unless (UNIVERSAL::isa($newc,'Net::DRI::Data::Contact'));
  $newc->validate(1); ## will trigger an Exception if needed
  my @c=build_cdata($newc);
  push @d,['contact:chg',@c] if @c;
 }
 $mes->command_body(\@d);
}

####################################################################################################
1;
