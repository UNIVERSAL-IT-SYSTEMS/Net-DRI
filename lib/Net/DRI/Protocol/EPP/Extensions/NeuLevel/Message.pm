## Domain Registry Interface, NeuLevel connection implementation
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

package Net::DRI::Protocol::EPP::Extensions::NeuLevel::Message;

use strict;
use Net::DRI::Exception;
use Errno qw(EAGAIN);
use Fcntl;

use base qw(Net::DRI::Protocol::EPP::Message);
__PACKAGE__->mk_accessors(qw(command_creds));

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NeuLevel::Message - Message to
	NeuLevel

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

sub as_string
{
 my ($self,$to)=@_;
 my $rns=$self->ns();
 my $topns=$rns->{_main};
 my $ens=sprintf('xmlns="%s" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="%s %s"',$topns->[0],$topns->[0],$topns->[1]);
 my @d;
 push @d,'<?xml version="1.0" encoding="UTF-8" standalone="no"?>';
 push @d,'<epp '.$ens.'>';
 my ($cmd,$ocmd,$ons)=@{$self->command()};
 my $nocommand=(!ref($cmd) && (($cmd eq 'hello') || ($cmd eq 'nocommand')));
 push @d,'<command>' unless $nocommand;
 my $attr;
 if (ref($cmd))
 {
  ($cmd,$attr)=($cmd->[0],' '.join(' ',map { $_.'="'.$cmd->[1]->{$_}.'"' } keys(%{$cmd->[1]})));
 } else
 {
  $attr='';
 }

 ## OPTIONAL credentials
 my $ext=$self->{command_creds};
 if (defined($ext) && (ref($ext) eq 'HASH'))
 {
  push @d,'<creds>';
  push(@d,'<clID>' . $ext->{clid} . '</clID>');
  push(@d,'<pw>' . $ext->{pw} . '</pw>');
  push(@d,'<newPW>' . $ext->{newPW} . '</newPW>') if (defined($ext->{newPW}));
  push(@d,'<options>');
  push(@d,'<version>' . $ext->{version} . '</version>');
  push(@d,'<lang>' . $ext->{lang} . '</lang>');
  push(@d,'</options>');
  push @d,'</creds>';
 }

 if ($cmd ne 'nocommand')
 {
  my $body=$self->command_body();
  if (defined($ocmd) && $ocmd)
  {
   push @d,'<'.$cmd.$attr.'>';
   push @d,'<'.$ocmd.' '.$ons.'>';
   push @d,$self->SUPER::_toxml($body);
   push @d,'</'.$ocmd.'>';
   push @d,'</'.$cmd.'>';
  } else
  {
   if (defined($body) && $body)
   {
    push @d,'<'.$cmd.$attr.'>';
    push @d,$self->SUPER::_toxml($body);
    push @d,'</'.$cmd.'>';
   } else
   {
    push @d,'<'.$cmd.$attr.'/>';
   }
  }
 }
 
 ## OPTIONAL extension
 $ext=$self->{extension};
 if (defined($ext) && (ref($ext) eq 'ARRAY') && @$ext)
 {
  push @d,'<extension>';
  foreach my $e (@$ext)
  {
   my ($ecmd,$ens,$rdata)=@$e;
   if ($ecmd && $ens)
   {
    push @d,'<'.$ecmd.' '.$ens.'>';
    push @d,ref($rdata)? $self->SUPER::_toxml($rdata) : xml_escape($rdata);
    push @d,'</'.$ecmd.'>';
   } else
   {
    push @d,xml_escape(@$rdata);
   }
  }
  push @d,'</extension>';
 }

 ## OPTIONAL clTRID
 my $cltrid=$self->cltrid();
 push @d,'<clTRID>'.$cltrid.'</clTRID>' if (defined($cltrid) && $cltrid && Net::DRI::Util::xml_is_token($cltrid,3,64) && !$nocommand);
 push @d,'</command>' unless $nocommand;
 push @d,'</epp>';

 my $m=Encode::encode('utf8',join('',@d));
 my $l=pack('N',4+length($m)); ## RFC 3734 §4
 return (defined($to) && ($to eq 'tcp'))? $l.$m : $m;
}

####################################################################################################

1;
