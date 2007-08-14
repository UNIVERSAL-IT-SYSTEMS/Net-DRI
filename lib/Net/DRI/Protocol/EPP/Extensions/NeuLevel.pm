## Domain Registry Interface, NeuLevel EPP extensions
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

package Net::DRI::Protocol::EPP::Extensions::NeuLevel;

use strict;

use base qw/Net::DRI::Protocol::EPP/;
use Net::DRI::Protocol::EPP::Extensions::NeuLevel::Message;

our $VERSION=do { my @r=(q$Revision: 1.1.1.1 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NeuLevel - NeuLevel EPP extensions for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt> and
E<lt>http://oss.bsdprojects.net/projects/netdri/E<gt>

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

####################################################################################################
sub new
{
 my $h=shift;
 my $c=ref($h) || $h;

 my ($drd,$version,$extrah,$defproduct)=@_;
 my %e=map { $_ => 1 } (defined($extrah)? (ref($extrah)? @$extrah : ($extrah)) : ());

 my $self=$c->SUPER::new($drd,$version,[keys(%e)]); ## we are now officially a Net::DRI::Protocol::EPP object

 $self->{ns}->{_main} = ['urn:iana:xml:ns:epp-1.0', 'epp-1.0.xsd'];
 $self->{ns}->{domain} = ['urn:iana:xml:ns:domain-1.0', 'domain-1.0.xsd'];
 $self->{ns}->{host} = ['urn:iana:xml:ns:host-1.0', 'host-1.0.xsd'];
 $self->{ns}->{contact} = ['urn:iana:xml:ns:contact-1.0', 'contact-1.0.xsd'];

 my $rfact=$self->factories();
 $rfact->{message} = sub {
  my $m = new Net::DRI::Protocol::EPP::Extensions::NeuLevel::Message(@_);
  $m->ns($self->{ns});
  $m->version($version);
  return $m;
 };

 $self->default_parameters()->{subproductid}=$defproduct || '_auto_';
 $self->default_parameters()->{breaks_rfc3915}=1;

 bless($self,$c); ## rebless
 return $self;
}

####################################################################################################
1;
