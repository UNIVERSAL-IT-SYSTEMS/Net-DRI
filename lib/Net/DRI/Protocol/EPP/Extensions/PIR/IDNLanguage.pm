## Domain Registry Interface, EPP IDN Language (EPP-IDN-Lang-Mapping.pdf)
##
## Copyright (c) 2006 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::PIR::IDNLanguage;

use strict;

use Net::DRI::Util;
use Net::DRI::Exception;

our $VERSION=do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::PIR::IDNLanguage - EPP IDN Language commands (EPP-IDN-Lang-Mapping.pdf) for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt> and
E<lt>http://oss.bdsprojects.net/projects/netdri/E<gt>

=head1 AUTHOR

Tonnerre Lombard E<lt>tonnerre.lombard@sygroup.chE<gt>

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
           create =>		[ \&create, undef ],
	   check =>		[ \&add_idn_scriptparams_check, undef ],
	   check_multi =>	[ \&add_idn_scriptparams_check, undef ],
	   info =>		[ undef, \&parse ],
	   update =>		[ \&add_idn_script_update, undef ]
         );

 return { 'domain' => \%tmp };
}

####################################################################################################

############ Transform commands

sub create
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();

 if (defined($rd) && (ref($rd) eq 'HASH') && exists($rd->{language}))
 {
  Net::DRI::Exception::usererr_invalid_parameters('IDN language tag must be of type XML schema language') unless Net::DRI::Util::xml_is_language($rd->{language});

  my $eid=$mes->command_extension_register('idn:create','xmlns:idn="urn:iana:xml:ns:idn" xsi:schemaLocation="urn:iana:xml:ns:idn idn.xsd"');
  $mes->command_extension($eid,['idn:script', $rd->{language}]);
 }
}

sub add_idn_scriptparams_check
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();

 if (defined($rd) && (ref($rd) eq 'HASH') && exists($rd->{language}))
 {
  my $eid=$mes->command_extension_register('idn:check','xmlns:idn="urn:iana:xml:ns:idn" xsi:schemaLocation="urn:iana:xml:ns:idn idn.xsd"');
  $mes->command_extension($eid,['idn:script', $rd->{language}]);
 }
}

sub parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 my $infdata=$mes->get_content('infData', 'urn:iana:xml:ns:idn', 1);
 my $c;

 return unless ($infdata);

 $c = $infdata->getElementsByTagNameNS('urn:iana:xml:ns:idn', 'script');

 $rinfo->{$otype}->{$oname}->{language} = $c->shift()->getFirstChild()->getData();
}

sub add_idn_script_update
{
 my ($epp,$domain,$todo)=@_;
 my $mes = $epp->message();

 if (grep { ! /^(?:set)$/ } $todo->types('language'))
 {
  my $eid = $mes->command_extension_register('idn:update','xmlns:idn="urn:iana:xml:ns:idn" xsi:schemaLocation="urn:iana:xml:ns:idn idn.xsd"');
  $mes->command_extension($eid,['idn:script', $todo->get('language')]);
 }
}

####################################################################################################
1;
