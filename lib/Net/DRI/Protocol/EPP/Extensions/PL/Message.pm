## Domain Registry Interface, .PL Message EPP extension commands
##
## Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
## Copyright (c) 2008 Thorsten Glaser for Sygroup GmbH
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
#########################################################################################

package Net::DRI::Protocol::EPP::Extensions::PL::Message;

use strict;

our $VERSION=do { my @r=(q$Revision: 1.1 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::PL::Message - .PL EPP Message extension commands for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>development@sygroup.chE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://oss.bsdprojects.net/project/netdri/E<gt>

=head1 AUTHOR

Tonnerre Lombard, E<lt>tonnerre.lombard@sygroup.chE<gt>
Thorsten Glaser

=head1 COPYRIGHT

Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
Copyright (c) 2008 Thorsten Glaser for Sygroup GmbH
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
          plretrieve => [ \&poll, \&parse_poll ]
         );

 return { 'message' => \%tmp };
}

####################################################################################################

sub poll
{
 my ($epp,$msgid)=@_;
 Net::DRI::Exception::usererr_invalid_parameters('In EPP, you can not specify the message id you want to retrieve') if defined($msgid);
 my $mes=$epp->message();
 $mes->command([['poll',{op=>'req'}]]);
}

sub parse_poll
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my ($epp,$rep,$ext,$ctag,@conds,@tags);
 my $mes=$po->message();
 my $msgid=$mes->msg_id();
 my $domname;
 my $domauth;

 return unless $mes->is_success();
 return if ($mes->result_code() == 1300);	# no messages in queue
 return unless (defined($msgid) && $msgid);

 my $mesdata = $mes->node_resdata();
 return unless ($mesdata);

 $rinfo->{message}->{session}->{last_id}=$msgid;

 foreach my $cnode ($mesdata->childNodes) {
  my $name = $cnode->localName || $cnode->nodeName;
  if ($name eq 'pollAuthInfo') {
   my $ra = $rinfo->{message}->{$msgid}->{extra_info};
   push @{$ra}, $cnode;
   $rinfo->{message}->{$msgid}->{action} = 'pollAuthInfo';
   foreach my $cnode ($cnode->childNodes) {
    my $name = $cnode->localName || $cnode->nodeName;
    if ($name eq 'domain') {
     $rinfo->{message}->{$msgid}->{object_type} = 'domain';
     foreach my $cnode ($cnode->childNodes) {
      my $name = $cnode->localName || $cnode->nodeName;
      if ($name eq 'name') {
       $domname = $cnode->getFirstChild()->getData();
      } elsif ($name eq 'authInfo') {
       $domauth = $cnode->getFirstChild();
      }
     }
    }
   }
  }
 }
 if (defined ($domname)) {
  $rinfo->{domain}->{$domname}->{name} = $domname;
  $rinfo->{domain}->{$domname}->{exist} = 1;
  $rinfo->{message}->{$msgid}->{object_id} = $domname;
  if (defined ($domauth)) {
   my $name = $domauth->localName || $domauth->nodeName;
   $rinfo->{domain}->{$domname}->{auth} = {
    $name => $domauth->getFirstChild()->getData()
   };
  }
 }

 $rinfo->{$otype}->{$oname}->{message}=$mesdata;
}

####################################################################################################
1;
