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

package Net::DRI::Protocol::EPP::Extensions::NeuLevel::Connection;

use strict;
use Net::DRI::Exception;
use Errno qw(EAGAIN);
use Fcntl;

use base qw(Net::DRI::Protocol::EPP::Connection);

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NeuLevel::Connection - Connection to
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

sub login
{
 shift if ($_[0] eq __PACKAGE__ || UNIVERSAL::isa($_[0], __PACKAGE__));
 my ($cm,$id,$pass,$cltrid,$dr,$newpass)=@_;

 my $got=$cm->();
 $got->parse($dr);
 my $rg=$got->result_greeting();

 my $mes=$cm->();
 $mes->command(['login']);
 my $cred = {
	clid =>	$id,
	pw =>	$pass,
	version =>	$rg->{version}->[0],
	lang =>	'en'
 };
 $cred->{'newPW'} = $newpass if (defined($newpass) && $newpass);
 $mes->command_creds($cred);

 my @d;
 my @s;
 push @s,map { ['objURI',$_] } @{$rg->{svcs}};
 foreach my $type (qw(contact domain host))
 {
  push(@s,[$type . ':svc', {
	'xmlns:' . $type => 'urn:iana:xml:ns:' . $type . '-1.0',
	'xsi:schemaLocation' => 'urn:iana:xml:ns:' . $type . '-1.0 ' . $type .
	'-1.0.xsd'}]);
 }
 push @s,['svcExtension',map {['extURI',$_]} @{$rg->{svcext}}] if (exists($rg->{svcext}) && defined($rg->{svcext}) && (ref($rg->{svcext}) eq 'ARRAY'));
 push @d,['svcs',@s];

 $mes->command_body(\@d);
 $mes->cltrid($cltrid) if $cltrid;
 return $mes->as_string();
}

sub logout
{
 shift if ($_[0] eq __PACKAGE__ || UNIVERSAL::isa($_[0], __PACKAGE__));
 my ($cm,$cltrid)=@_;
 my $mes=$cm->();
 $mes->command(['logout']);
 $mes->cltrid($cltrid) if $cltrid;
 return $mes->as_string();
}

sub keepalive
{
 shift if ($_[0] eq __PACKAGE__ || UNIVERSAL::isa($_[0], __PACKAGE__));
 my ($cm,$cltrid)=@_;
 my $mes=$cm->();
 $mes->command(['hello']); ## Explicitely allowed since draft-hollenbeck-epp-rfc3730bis-02.txt
 return $mes->as_string();
}

sub get_data
{
 shift if ($_[0] eq __PACKAGE__ || UNIVERSAL::isa($_[0], __PACKAGE__));
 my ($to,$sock)=@_;
 my $flags = 0;
 my $err = EAGAIN;
 my $s;
 my $m;

 $sock->read($s, 1);
 die(Net::DRI::Protocol::ResultStatus->new_error('COMMAND_SYNTAX_ERROR','Unable to read EPP message: ' . $! . ' (connection closed by registry?)','en')) unless $s;

 fcntl($sock, F_GETFL, $flags) or
   die(Net::DRI::Protocol::ResultStatus->new_error('COMMAND_SYNTAX_ERROR','Unable to retrieve currently set flags from socket: ' . $!,'en'));

 fcntl($sock, F_SETFL, $flags | O_NONBLOCK) or
   die(Net::DRI::Protocol::ResultStatus->new_error('COMMAND_SYNTAX_ERROR','Unable to set non-blocking option on socket: ' . $!,'en'));

 $sock->read($m,65536);
 die(Net::DRI::Protocol::ResultStatus->new_error('COMMAND_SYNTAX_ERROR','Unable to read EPP message: ' . $! . ' (connection closed by registry?)','en')) unless $m;
 fcntl($sock, F_SETFL, $flags) or
   die(Net::DRI::Protocol::ResultStatus->new_error('COMMAND_SYNTAX_ERROR','Unable to restore old flags on socket: ' . $!,'en'));
 die(Net::DRI::Protocol::ResultStatus->new_error('COMMAND_SYNTAX_ERROR',$m? $m : '<empty message from server>','en')) unless ($m=~m!</epp>$!);

 return Net::DRI::Data::Raw->new_from_string($s . $m);
}

####################################################################################################

1;
