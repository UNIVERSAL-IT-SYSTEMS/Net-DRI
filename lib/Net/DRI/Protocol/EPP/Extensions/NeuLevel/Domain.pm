## Domain Registry Interface, NeuLevel domain implementation
##
## Copyright (c) 2007 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
## All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::NeuLevel::Domain;

use strict;
use Net::DRI::Exception;
use Net::DRI::Protocol::EPP::Core::Domain;
use Errno qw(EAGAIN);
use Fcntl;

#use base qw(Net::DRI::Protocol::EPP::Core::Domain);
#__PACKAGE__->mk_accessors(qw(command_creds));

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NeuLevel::Domain - Domain at NeuLevel

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt> or
E<lt>http://oss.bsdprojects.net/projects/netdri/E<gt>

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
 my ($class, $version) = @_;
 my %tmp = (
	info	=> [ \&info, \&info_parse ]
 );
 return { 'domain' => \%tmp };
}

sub info
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,'info',$domain);
 push @d,Net::DRI::Protocol::EPP::Core::Domain::build_authinfo($rd->{auth}) if (Net::DRI::Protocol::EPP::Core::Domain::verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 $mes->command_body(\@d);
}

sub info_parse
{
 return Net::DRI::Protocol::EPP::Core::Domain::info_parse(@_);
}

####################################################################################################

1;
