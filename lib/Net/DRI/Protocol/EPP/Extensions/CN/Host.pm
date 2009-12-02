## Domain Registry Interface, CN domain transactions extension
##
## Copyright (c) 2006,2007 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::CN::Host;

use strict;

use Net::DRI::Util;

our $VERSION = do { my @r = ( q$Revision: 1.2 $ =~ /\d+/g ); sprintf( "%d" . ".%02d" x $#r, @r ); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::CN::Host - .CN EPP Host extension

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

Copyright (c) 2006,2007 Patrick Mevzek <netdri@dotandco.com>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub register_commands {
       my ( $class, $version ) = @_;
       my %tmp=(
           check  => [ undef, \&check_parse ],
               );

       $tmp{check_multi}=$tmp{check};

       return { 'host' => \%tmp };
}

##################################################################################################

sub build_command
{
 my ($msg,$command,$hostname)=@_;
 my @n=map { UNIVERSAL::isa($_,'Net::DRI::Data::Hosts')? $_->get_names() : $_ } ((ref($hostname) eq 'ARRAY')? @$hostname : ($hostname));

 Net::DRI::Exception->die(1,'protocol/EPP',2,"Host name needed") unless @n;
 foreach my $n (@n)
 {
  Net::DRI::Exception->die(1,'protocol/EPP',2,'Host name needed') unless defined($n) && $n;
  Net::DRI::Exception->die(1,'protocol/EPP',10,'Invalid host name: '.$n) unless Net::DRI::Util::is_hostname($n);
 }

 my @ns=@{$msg->ns->{host}};
 $msg->command([$command,'host:'.$command,sprintf('xmlns:host="%s" xsi:schemaLocation="%s %s"',$ns[0],$ns[0],$ns[1])]);

 my @d=map { ['host:name',$_] } @n;
 return @d;
}



##################################################################################################
########### Query commands

sub check_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $chkdata=$mes->get_content('chkData',$mes->ns('host'));
 return unless $chkdata;
 foreach my $cd ($chkdata->getElementsByTagNameNS($mes->ns('host'),'cd'))
 {
  my $host;
    $host=lc($cd->getFirstChild()->getData());
    $rinfo->{host}->{$host}->{action}='check';
    if ($cd->getAttribute('x') eq '+') {
       $rinfo->{host}->{$host}->{exist}=1;
    } else {
       $rinfo->{host}->{$host}->{exist}=0;
    }
 }
}


####################################################################################################
1;
