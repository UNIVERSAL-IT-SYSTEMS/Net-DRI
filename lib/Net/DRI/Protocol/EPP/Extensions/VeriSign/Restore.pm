## Domain Registry Interface, EPP Restore Command (RFC 3915)
##
## Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
##                    All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::VeriSign::Restore;

use strict;

use Net::DRI::Util;
use Net::DRI::Exception;

our $VERSION=do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::VeriSign::Restore - EPP IDN Restore command (RFC 3915) for Net::DRI

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

Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
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
           restore_request => [ \&restore_request, undef ],
           restore_report =>  [ \&restore_report, undef ],
         );

 return { 'domain' => \%tmp };
}

####################################################################################################

############ Transform commands

sub restore_request
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @d = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes, 'update',
	$domain);
 push(@d, ['domain:chg']);
 $mes->command_body(\@d);

 my $eid = $mes->command_extension_register('rgp:update','xmlns:rgp="urn:ietf:params:xml:ns:rgp-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:rgp-1.0 rgp-1.0.xsd"');
 $mes->command_extension($eid,['rgp:restore', { op => 'request' }]);
}

sub restore_report
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @b = Net::DRI::Protocol::EPP::Core::Domain::build_command($mes, 'update',
	$domain);
 my @d;
 my @h;
 push(@b, ['domain:chg']);
 $mes->command_body(\@b);

 return unless (defined($rd->{data}) && UNIVERSAL::isa($rd->{data},
	'Net::DRI::Data::Changes') && defined($rd->{deleted}) &&
	UNIVERSAL::isa($rd->{deleted}, 'DateTime') &&
	defined($rd->{restored}) && UNIVERSAL::isa($rd->{restored}, 'DateTime')
	&& defined($rd->{reason}));

 my $eid = $mes->command_extension_register('rgp:update','xmlns:rgp="urn:ietf:params:xml:ns:rgp-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:rgp-1.0 rgp-1.0.xsd"');

 push(@h, Net::DRI::Protocol::EPP::Core::Domain::build_ns($epp,
	$rd->{data}->del('ns'), $domain));
 push(@h, $rd->{data}->del('status')->build_xml('domain:status','core'));
 unless (!defined($rd->{data}->del('contact')) ||
	$rd->{data}->del('contact')->is_empty())
 {
  push(@h, ['domain:registrant', $rd->{data}->del('contact')->get('registrant')->srid()]);
  push(@h, Net::DRI::Protocol::EPP::Core::Domain::build_contact_noregistrant(
	$rd->{data}->del('contact')));
 }

 push(@d, ['rgp:preData', @h]);

 @h = ();
 push(@h, Net::DRI::Protocol::EPP::Core::Domain::build_ns($epp,
	$rd->{data}->add('ns'), $domain));
 push(@h, $rd->{data}->add('status')->build_xml('domain:status','core'));
 unless (!defined($rd->{data}->add('contact')) ||
	$rd->{data}->add('contact')->is_empty())
 {
  push(@h, ['domain:registrant', $rd->{data}->add('contact')->get('registrant')->srid()]);
  push(@h, Net::DRI::Protocol::EPP::Core::Domain::build_contact_noregistrant(
	$rd->{data}->add('contact')));
 }

 push(@d, ['rgp:postData', @h]);
 push(@d, ['rgp:delTime', $rd->{deleted}->ymd . 'T' . $rd->{deleted}->hms .
	'.0Z']);
 push(@d, ['rgp:resTime', $rd->{restored}->ymd . 'T' . $rd->{restored}->hms .
	'.0Z']);
 push(@d, ['rgp:resReason', $rd->{reason}]);
 push(@d, ['rgp:statement', 'This registrar has not restored the Registered Name in order to assume the rights to use or sell the Registered Name for itself or for any third party.']);
 push(@d, ['rgp:statement', 'The information in this report is true to the best of this registrar\'s knowledge, and this registrar acknowledges that intentionally supplying false information in this report shall constitute an incurable material breach of the Registry-Registrar Agreement.']);
 push(@d, ['rgp:other', $rd->{other}]) if (defined($rd->{other}) &&
	length($rd->{other}));

 $mes->command_extension($eid,['rgp:restore', { op => 'report' }, @d]);
}

####################################################################################################
1;
