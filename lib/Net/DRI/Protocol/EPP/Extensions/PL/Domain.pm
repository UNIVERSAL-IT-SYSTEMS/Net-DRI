## Domain Registry Interface, .PL Domain EPP extension commands
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

package Net::DRI::Protocol::EPP::Extensions::PL::Domain;

use strict;

our $VERSION=do { my @r=(q$Revision: 1.1 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::PL::Domain - .PL EPP Domain extension commands for Net::DRI

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
          create =>	[ \&create ],
          update =>	[ \&update ],
	  info =>	[ undef, \&info_parse ]
         );

 return { 'domain' => \%tmp };
}

####################################################################################################

sub build_command_extension
{
 my ($mes,$epp,$tag)=@_;

 my @ns=@{$mes->ns->{pl_domain}};
 return $mes->command_extension_register($tag,sprintf('xmlns:extdom="%s" xsi:schemaLocation="%s %s"',$ns[0],$ns[0],$ns[1]));
}

sub build_ns
{
 my ($epp,$ns,$domain,$xmlns)=@_;
 $xmlns='domain' unless defined($xmlns);

 my @d;
 @d=map { [$xmlns . ':ns',$_] } $ns->get_names();
}

sub create
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,'create',$domain);
 my $def = $epp->default_parameters();

 if ($def && (ref($def) eq 'HASH') && exists($def->{domain_create}) && (ref($def->{domain_create}) eq 'HASH'))
 {
  $rd={} unless ($rd && (ref($rd) eq 'HASH') && keys(%$rd));
  while(my ($k,$v)=each(%{$def->{domain_create}}))
  {
   next if exists($rd->{$k});
   $rd->{$k}=$v
  }
 }

 ## Period, OPTIONAL
 if (Net::DRI::Protocol::EPP::Core::Domain::verify_rd($rd,'duration'))
 {
  my $period=$rd->{duration};
  Net::DRI::Util::check_isa($period,'DateTime::Duration');
  push @d,Net::DRI::Protocol::EPP::Core::Domain::build_period($period);
 }

 ## Nameservers, OPTIONAL
 push @d,build_ns($epp,$rd->{ns},$domain) if (Net::DRI::Protocol::EPP::Core::Domain::verify_rd($rd,'ns') && UNIVERSAL::isa($rd->{ns},'Net::DRI::Data::Hosts') && !$rd->{ns}->is_empty());

 ## Contacts, all OPTIONAL
 if (Net::DRI::Protocol::EPP::Core::Domain::verify_rd($rd,'contact') && UNIVERSAL::isa($rd->{contact},'Net::DRI::Data::ContactSet'))
 {
  my $cs=$rd->{contact};
  my @o=$cs->get('registrant');
  push @d,['domain:registrant',$o[0]->srid()] if (@o);
  push @d,Net::DRI::Protocol::EPP::Core::Domain::build_contact_noregistrant($epp,$cs);
 }

 ## AuthInfo
 Net::DRI::Exception::usererr_insufficient_parameters("authInfo is mandatory") unless (Net::DRI::Protocol::EPP::Core::Domain::verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 push @d,Net::DRI::Protocol::EPP::Core::Domain::build_authinfo($rd->{auth});
 $mes->command_body(\@d);

 return unless exists($rd->{reason}) || exists($rd->{book});

 my $eid=build_command_extension($mes,$epp,'extdom:create');

 my @e;
 push @e,['extdom:reason',$rd->{reason}] if (exists($rd->{reason}) && $rd->{reason});
 push @e,['extdom:book']                 if (exists($rd->{book}) && $rd->{book});

 $mes->command_extension($eid,\@e);
}

sub update
{
 my ($epp,$domain,$todo)=@_;
 my $mes=$epp->message();

 Net::DRI::Exception::usererr_invalid_parameters($todo.' must be a Net::DRI::Data::Changes object') unless ($todo && UNIVERSAL::isa($todo,'Net::DRI::Data::Changes'));

 if ((grep { ! /^(?:add|del)$/ } $todo->types('ns')) ||
     (grep { ! /^(?:add|del)$/ } $todo->types('status')) ||
     (grep { ! /^(?:add|del)$/ } $todo->types('contact')) ||
     (grep { ! /^set$/ } $todo->types('registrant')) ||
     (grep { ! /^set$/ } $todo->types('auth'))
    )
 {
  Net::DRI::Exception->die(0,'protocol/EPP',11,'Only ns/status/contact add/del or registrant/authinfo set available for domain');
 }

 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,'update',$domain);

 my $nsadd=$todo->add('ns');
 my $nsdel=$todo->del('ns');
 my $sadd=$todo->add('status');
 my $sdel=$todo->del('status');
 my $cadd=$todo->add('contact');
 my $cdel=$todo->del('contact');
 my (@add,@del);

 push @add,build_ns($epp,$nsadd,$domain)		if $nsadd && !$nsadd->is_empty();
 push @add,Net::DRI::Protocol::EPP::Core::Domain::build_contact_noregistrant($epp,$cadd) if $cadd;
 push @add,$sadd->build_xml('domain:status','core')	if $sadd;
 push @del,build_ns($epp,$nsdel,$domain)		if $nsdel && !$nsdel->is_empty();
 push @del,Net::DRI::Protocol::EPP::Core::Domain::build_contact_noregistrant($epp,$cdel) if $cdel;
 push @del,$sdel->build_xml('domain:status','core')	if $sdel;

 push @d,['domain:add',@add] if @add;
 push @d,['domain:rem',@del] if @del;

 my $chg=$todo->set('registrant');
 my @chg;
 push @chg,['domain:registrant',$chg->srid()] if ($chg && ref($chg) && UNIVERSAL::can($chg,'srid'));
 $chg=$todo->set('auth');
 push @chg,Net::DRI::Protocol::EPP::Core::Domain::build_authinfo($chg) if ($chg && ref($chg));
 push @d,['domain:chg',@chg] if @chg;
 $mes->command_body(\@d);
}

sub info_parse
{
 my ($po, $otype, $oaction, $oname, $rinfo) = @_;
 my $mes = $po->message();
 return unless $mes->is_success();
 my $infdata = $mes->get_content('infData', $mes->ns('domain'));
 return unless $infdata;
 my $ns = Net::DRI::Data::Hosts->new();
 my $c = $infdata->getFirstChild();

 while ($c)
 {
  next unless ($c->nodeType() == 1); ## only for element nodes
  my $name = $c->localname() || $c->nodeName();
  next unless $name;

  if ($name eq 'name')
  {
   $oname = lc($c->getFirstChild()->getData());
  }
  elsif ($name eq 'ns')
  {
   $ns->add($c->getFirstChild()->getData());
  }
 } continue { $c = $c->getNextSibling(); }

 $rinfo->{domain}->{$oname}->{ns} = $ns;
}

####################################################################################################
1;
