## Domain Registry Interface, Gandi Web Services Connection handling
##
## Copyright (c) 2008 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::Gandi::WS::Connection;

use strict;
use XMLRPC::Lite; ## needed to have XMLRPC::Data

our $VERSION=do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::Gandi::WS::Connection - Gandi Web Services Connection handling for Net::DRI

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

Copyright (c) 2008 Patrick Mevzek <netdri@dotandco.com>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub login
{
 shift if ($_[0] eq __PACKAGE__);
 my ($cm,$id,$pass,$cltrid)=@_;
 my $mes=$cm->();
 $mes->method('login');
 $mes->params([$id,$pass,XMLRPC::Data->type('boolean')->value(0)]);
 return $mes;
}

sub parse_login
{
 shift if ($_[0] eq __PACKAGE__);
 my $mes=shift;
 $mes->errmsg($mes->is_success()? 'Login OK' : 'Login failed') unless $mes->errmsg();
 return $mes->result_status();
}

sub extract_session
{
 shift if ($_[0] eq __PACKAGE__);
 my $mes=shift;
 return { id => $mes->value() };
}

####################################################################################################
1;