## Domain Registry Interface, EPP Renew Redemption Period Extension
## (NeuLevel guide p. 39)
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

package Net::DRI::Protocol::EPP::Extensions::NeuLevel::Restore;

use strict;

use Net::DRI::Util;
use Net::DRI::Exception;

our $VERSION=do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NeuLevel::Restore - EPP renew redemption
	period support (NeuLevel registrar manual p. 38) for Net::DRI

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
 my ($class, $version) = @_;
 my %tmp = (
           renew => [ \&renew, undef ],
         );

 return { 'domain' => \%tmp };
}

####################################################################################################

############ Transform commands

sub renew
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @vals = qw(RestoreReasonCode RestoreComment TrueData ValidUse);
 my %info = (
	TrueData =>	'Y',
	ValidUse =>	'Y'
 );
 my $comment;

 return unless (defined($rd->{rgp}) && ref($rd->{rgp}) eq 'HASH');

 $info{RestoreReasonCode} = $rd->{rgp}->{code};
 $comment = $rd->{rgp}->{comment};
 $comment = join('', map { ucfirst($_) } split(/\s+/, $comment));
 $info{RestoreComment} = $comment;

 $mes->unspec([join(' ', map { $_ . '=' . $info{$_} } @vals)]);
}

####################################################################################################
1;
