## Domain Registry Interface, HTTPS Form Transport
##
## Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>. All rights reserved.
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

package Net::DRI::Transport::HTTPS;

use strict;

use base qw/Net::DRI::Transport/;

use LWP::UserAgent;

use Net::DRI::Exception;

our $VERSION=do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Transport::HTTPS - HTTPS Form Transport for Net::DRI

=head1 DESCRIPTION

The following options are available at creation:

=over

=item *

C<timeout> : time to wait (in seconds) for server reply

=item *

C<protocol_connection> : Net::DRI class handling protocol connection details.

=item *

C<credentials> : hashref with handle and pass keys (for Gandi scraping, will depend on web site used)

=back

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>tonnerre.lombard@sygroup.chE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

http://oss.bsdprojects.net/project/netdri/

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

####################################################################################################################

sub new
{
 my $proto = shift;
 my $class = ref($proto) || $proto;

 my $drd = shift;
 my $po = shift;
 my %opts = (@_ == 1 && ref($_[0])) ? %{$_[0]} : @_;
 my $self = $class->SUPER::new(\%opts); ## We are now officially a Net::DRI::Transport instance
 $self->has_state(1);
 $self->is_sync(1);
 $self->name('https');
 $self->version($VERSION);

 my %t;
 $t{ua} = LWP::UserAgent->new( cookie_jar => {},
                             agent      => exists($opts{agent}) ? $opts{agent}
				: "Net::DRI::Transport::HTTPS (${VERSION})",
			     timeout    => exists($opts{timeout}) ?
				int($opts{timeout}) : 180
                           );

 Net::DRI::Exception::usererr_insufficient_parameters("protocol_connection")
	unless (exists($opts{protocol_connection}) && $opts{protocol_connection});
 $t{trid_factory} = (exists($opts{trid}) && (ref($opts{trid}) eq 'CODE')) ?
	$opts{trid} : \&Net::DRI::Util::create_trid_1;
 $t{message_factory} = $po->factories()->{message};
 $t{pc} = $opts{protocol_connection};

 foreach my $var (qw(url client_login client_password client_newpassword
	protocol_version protocol_data))
 {
  $t{$var} = $opts{$var} if (defined($opts{$var}));
 }

 $ENV{HTTPS_CERT_FILE} = $opts{ssl_cert_file} if (defined($opts{ssl_cert_file}));
 $ENV{HTTPS_KEY_FILE} = $opts{ssl_key_file} if (defined($opts{ssl_key_file}));
 $ENV{HTTPS_DEBUG} = $opts{debug} if (defined($opts{debug}));

 my @needed = ('login','logout');
 eval 'require ' . $t{pc}; ## no critic (ProhibitStringyEval)
 Net::DRI::Exception::usererr_invalid_parameters("protocol_connection class must have: " . join(" ", @needed)) if (grep { ! $t{pc}->can($_) } @needed);

 $self->{transport} = \%t;
 bless($self, $class); ## rebless in my class

 if ($self->defer()) ## we will open, but later
 {
  $self->current_state(0);
 } else ## we will open NOW
 {
  $self->open_connection();
  $self->current_state(1);
 }

 return $self;
}

sub ua    { return shift->{transport}->{ua}; }
sub pc    { return shift->{transport}->{pc}; }
sub creds { return shift->{transport}->{creds}; }
sub ctx   { return shift->{transport}->{ctx}; }
sub url   { return shift->{transport}->{url}; }
sub response	{ return shift->{transport}->{response}; }

sub open_connection
{
 my ($self) = @_;
 my $pc = $self->pc();
 my $t = $self->{transport};

 if ($pc->can('login') && $pc->can('parse_login'))
 {
  my $cltrid = $t->{trid_factory}->($self->name());
  my $dr;

  if ($pc->can('parse_greeting'))
  {
   my $grtrid = $t->{trid_factory}->($self->name());
   my $msg = $pc->keepalive($t->{message_factory}, $grtrid);
   $self->_webprint(length($msg), Net::DRI::Data::Raw->new_from_string($msg));
   $dr = Net::DRI::Data::Raw->new_from_string($self->response());
   $self->logging($cltrid, 1, 1, 1, $dr);
  }

  $t->{ctx} = $pc->login($t->{message_factory}, $t->{client_login},
	$t->{client_password}, $cltrid, $dr, $t->{client_newpassword},
	$t->{protocol_data});
  $self->_webprint(length($t->{ctx}),
	Net::DRI::Data::Raw->new_from_string($t->{ctx}));
  $dr = Net::DRI::Data::Raw->new_from_string($self->response());
  $self->logging($cltrid, 1, 1, 1, $dr);
  my $rc2 = $pc->parse_login($dr); ## gives back a Net::DRI::Protocol::ResultStatus
  die($rc2) unless $rc2->is_success();
 }
 $self->current_state(1);
 $self->time_open(time());
 $self->{transport}->{exchanges_done} = 0;
}

sub close_connection
{
 my ($self) = @_;
 my $pc = $self->pc();
 my $t = $self->{transport};

 if ($pc->can('logout') && $pc->can('parse_logout'))
 {
  my $cltrid = $t->{trid_factory}->($self->name());
  my $logout = $pc->logout($t->{message_factory}, $cltrid);
  my $dr;

  $self->logging($cltrid, 3, 0, 1, $logout);
  $self->_webprint(length($logout),
	Net::DRI::Data::Raw->new_from_string($logout));
  $dr = Net::DRI::Data::Raw->new_from_string($self->response());
  $self->logging($cltrid, 3, 1, 1, $dr);
  my $rc1 = $pc->parse_logout($dr);
  die($rc1) unless $rc1->is_success();
 }

 $self->ua()->cookie_jar({}); ## we reset the cookie jar
 $self->{transport}->{ctx} = undef;
 $self->current_state(0);
}

sub end
{
 my $self = shift;
 if ($self->current_state())
 {
  $self->close_connection();
 }
}

########################################################################################################################

sub send
{
 my ($self, $trid, $tosend) = @_;
 $tosend = Net::DRI::Data::Raw->new_from_string($tosend) unless (ref($tosend));
 $self->SUPER::send($trid, $tosend, \&_webprint, sub {});
}

sub _webprint ## here we are sure open_connection() was called before
{
 my ($self, $count, $tosend) = @_;
 my $ua = $self->ua();
 my $req = $tosend->as_string('https');
 my $res;

 if ($req !~ /^\<\?xm/)
 {
  $req = substr($req, 4);
 }

 warn('Sending: ' . $req);
 $res = $ua->post($self->url(), 'Content-Length' => $count, Content => $req);

 $self->{transport}->{response} = $res->content if ($res->is_success());
 Net::DRI::Exception->die(0,'transport/https', 4,
	'Unable to send message: ' . $res->status_line)
	unless ($res->is_success());
 warn('Received: ' . $res->content);

 return 1; ## very important
}

sub receive
{
 my ($self, $trid) = @_;
 return $self->SUPER::receive($trid, \&_web_receive);
}

sub _web_receive
{
 my ($self, $count) = @_;
 my $m = $self->response();

 return Net::DRI::Data::Raw->new_from_string($m);
}

####################################################################################################################
1;
