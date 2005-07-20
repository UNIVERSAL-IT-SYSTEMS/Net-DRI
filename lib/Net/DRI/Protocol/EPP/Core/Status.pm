## Domain Registry Interface, EPP Status
##
## Copyright (c) 2005 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Core::Status;

use base qw!Net::DRI::Data::StatusList!;

use strict;

use Net::DRI::Exception;

our $VERSION=do { my @r=(q$Revision: 1.1 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Core::Status - EPP Status for Net::DRI

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

Copyright (c) 2005 Patrick Mevzek <netdri@dotandco.com>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

#######################################################################################

sub new
{
 my $proto=shift;
 my $class=ref($proto) || $proto;

 my $self=$class->SUPER::new('epp','1.0');
 bless($self,$class);

 my %s=('delete'   => 'clientDeleteProhibited',
        'renew'    => 'clientRenewProhibited',
        'update'   => 'clientUpdateProhibited',
        'transfer' => 'clientTransferProhibited',
        'publish'  => 'clientHold',
       );
 $self->_register_pno(\%s);

 my $msg=shift;
 return $self unless defined($msg);

 if (ref($msg) eq 'ARRAY')
 {
  $self->add(@$msg);
 } else
 {
  Net::DRI::Exception::err_invalid_parameters();
 }

 return $self;
}

sub build_xml
{
 my ($self,$name)=@_;
 my @d;
 my $rd=$self->status_details();
 while(my ($k,$v)=each(%$rd))
 {
  if ($v && ref($v) && keys(%$v))
  {
   my %tmp=(s => $k);
   $tmp{lang}=$v->{lang} if exists($v->{lang});
   push @d,[$name,$v->{msg} || '',\%tmp];
  } else
  {
   push @d,[$name,undef,{s=>$k}];
  }
 }
 return @d;
}

sub is_active    { return shift->has_any('ok'); }
sub is_published { return shift->has_not('clientHold','serverHold','inactive'); }
sub is_pending   { return shift->has_any('pendingCreate','pendingDelete','pendingRenew','pendingTransfer','pendingUpdate'); }
sub is_linked    { return shift->has_any('linked'); }

sub can_delete
{
 my $self=shift;
 my $ispending=$self->is_pending();
 return !$ispending && $self->has_not('clientDeleteProhibited','serverDeleteProhibited');
}

sub can_renew
{
 my $self=shift;
 my $ispending=$self->is_pending();
 return !$ispending && $self->has_not('clientRenewProhibited','serverRenewProhibited');
}

sub can_update
{
 my $self=shift;
 my $ispending=$self->is_pending();
 return !$ispending && $self->has_not('clientUpdateProhibited','serverUpdateProhibited');
}

sub can_transfer { return shift->has_not('clientTransferProhibited','serverTransferProhibited'); }


####################################################################################################################
1;
