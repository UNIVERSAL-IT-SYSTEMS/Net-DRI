## Domain Registry Interface, RRI Message
##
## Copyright (c) 2007 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>. All rights reserved.
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

package Net::DRI::Protocol::RRI::Message;

use strict;

use DateTime::Format::ISO8601 ();
use XML::LibXML ();
use Encode ();

use Net::DRI::Protocol::ResultStatus;
use Net::DRI::Exception;
use Net::DRI::Util;

use Carp qw(confess);

use base qw(Class::Accessor::Chained::Fast Net::DRI::Protocol::Message);
__PACKAGE__->mk_accessors(qw(version command command_body cltrid svtrid result
	msg_id errmsg node_resdata node_msg result_extra_info));

our $VERSION=do { my @r=(q$Revision: 1.18 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::RRI::Message - RRI Message for Net::DRI

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
 my $proto = shift;
 my $class = ref($proto) || $proto;
 my $trid = shift;

 my $self = {
           result => 'uninitialized',
          };

 bless($self,$class);

 $self->cltrid($trid) if (defined($trid) && $trid);
 return $self;
}

sub ns
{
 my ($self,$what)=@_;
 return $self->{ns} unless defined($what);

 if (ref($what) eq 'HASH')
 {
  $self->{ns}=$what;
  return $what;
 }
 return unless exists($self->{ns}->{$what});
 return $self->{ns}->{$what}->[0];
}

sub is_success { return (shift->result() =~ m/^success/)? 1 : 0; }

sub result_status
{
 my $self=shift;
 my $rs = Net::DRI::Protocol::ResultStatus->new('rri',
	($self->is_success() ? 1000 : 2000), undef, $self->is_success(),
	$self->errmsg(), 'en', $self->result_extra_info());
 $rs->_set_trid([ $self->cltrid(), $self->svtrid() ]);
 return $rs;
}

sub as_string
{
 my ($self,$to)=@_;
 my $rns=$self->ns();
 my $topns=$rns->{_main};
 my $ens=sprintf('xmlns="%s"', $topns->[0]);
 my @d;
 push @d,'<?xml version="1.0" encoding="UTF-8" standalone="no"?>';
 my ($type, $cmd, $ns, $attr) = @{$self->command()};

 $attr = '' unless (defined($attr));
 $attr = ' ' . join(' ', map { $_ . '="' . $attr->{$_} . '"' }
	keys (%{$attr})) if (ref($attr) eq 'HASH');

 if (defined($ns))
 {
  if (ref($ns) eq 'HASH')
  {
   $ens .= ' ' . join(' ', map { 'xmlns:' . $_ . '="' . $ns->{$_} . '"' }
	keys(%{$ns}));
   $cmd = $type . ':' . $cmd;
  }
  else
  {
   $ens .= ' xmlns:' . $type . '="' . $ns . '"';
   $cmd = $type . ':' . $cmd;
  }
 }
 else
 {
  $cmd = $type;
  $type = undef;
 }
 push @d,'<registry-request '.$ens.'>';

 my $body=$self->command_body();
 if (defined($body) && $body)
 {
  push @d,'<'.$cmd.$attr.'>';
  push @d,_toxml($body);
  push @d,'</'.$cmd.'>';
 } else
 {
  push @d,'<'.$cmd.$attr.'/>';
 }
 
 ## OPTIONAL clTRID
 my $cltrid=$self->cltrid();
 push @d,'<ctid>'.$cltrid.'</ctid>'
	if (defined($cltrid) && $cltrid &&
		Net::DRI::Util::xml_is_token($cltrid,3,64));
 push @d,'</registry-request>';

 my $m=Encode::encode('utf8',join('',@d));
 my $l=pack('N',4+length($m)); ## RFC 4934 §4
 return (defined($to) && ($to eq 'tcp') && ($self->version() gt '0.4'))?
	$l.$m : $m;
}

sub _toxml
{
 my $rd=shift;
 my @t;
 foreach my $d ((ref($rd->[0]))? @$rd : ($rd)) ## $d is a node=ref array
 {
  my @c; ## list of children nodes
  my %attr;
  foreach my $e (grep { defined } @$d)
  {
   if (ref($e) eq 'HASH')
   {
    while(my ($k,$v)=each(%$e)) { $attr{$k}=$v; }
   } else
   {
    push @c,$e;
   }
  }
  my $tag=shift(@c);
  my $attr=keys(%attr)? ' '.join(' ',map { $_.'="'.$attr{$_}.'"' } sort(keys(%attr))) : '';
  if (!@c || (@c==1 && !ref($c[0]) && ($c[0] eq '')))
  {
   push @t,"<${tag}${attr}/>";
  } else
  {
   push @t,"<${tag}${attr}>";
   push @t,(@c==1 && !ref($c[0]))? xml_escape($c[0]) : _toxml(\@c);
   push @t,"</${tag}>";
  }
 }
 return @t;
}

sub xml_escape
{
 my $in=shift;
 $in=~s/&/&amp;/g;
 $in=~s/</&lt;/g;
 $in=~s/>/&gt;/g;
 return $in;
}

sub topns { return shift->ns->{_main}->[0]; }

sub get_content
{
 my ($self,$nodename,$ns,$ext)=@_;
 return unless (defined($nodename) && $nodename);

 my @tmp;
 my $n1=$self->node_resdata();

 $ns||=$self->topns();

 @tmp=$n1->getElementsByTagNameNS($ns,$nodename) if (defined($n1));

 return unless @tmp;
 return wantarray()? @tmp : $tmp[0];
}

sub parse
{
 my ($self,$dc,$rinfo)=@_;

 my $NS=$self->topns();
 my $trNS = $self->ns('tr');
 my $parser=XML::LibXML->new();
 my $xstr = $dc->as_string();
 $xstr =~ s/^\s*//;
 my $doc=$parser->parse_string($xstr);
 my $root=$doc->getDocumentElement();
 Net::DRI::Exception->die(0, 'protocol/RRI', 1,
	'Unsuccessfull parse, root element is not registry-response')
		unless ($root->getName() eq 'registry-response');

 my @trtags = $root->getElementsByTagNameNS($trNS, 'transaction');
 Net::DRI::Exception->die(0, 'protocol/EPP', 1,
	'Unsuccessfull parse, no transaction block') unless (@trtags);
 my $res = $trtags[0];

 ## result block(s)
 my @results = $res->getElementsByTagNameNS($trNS,'result'); ## success indicator
 foreach (@results)
 {
  $self->result($_->firstChild()->getData());
 }

 if ($res->getElementsByTagNameNS($NS,'message')) ## OPTIONAL
 {
  my @msgs = $res->getElementsByTagNameNS($NS,'message');
  my $msg = $msgs[0];
  my $id = $msg->getAttribute('code'); ## id of *next* available message
  $rinfo->{message}->{info}={ queue => $msg->getAttribute('level'), id => $id };
  if ($msg->hasChildNodes()) ## We will have childs only as a result of a poll request
  {
   my %d=( id => $id );
   $self->msg_id($id);
   $d{qdate}=DateTime::Format::ISO8601->new()->parse_datetime(($msg->getElementsByTagNameNS($NS,'qDate'))[0]->firstChild()->getData());
   my $msgc=($msg->getElementsByTagNameNS($NS,'msg'))[0];
   $msgc=($res->getElementsByTagName('msg'))[0] if (!$msgc);
   $d{lang}=$msgc->getAttribute('lang') || 'en';

   if (grep { $_->nodeType() == 1 } $msgc->childNodes())
   {
    $self->node_msg($msgc);
   } else
   {
    $d{content}=$msgc->firstChild()->getData();
   }
   $rinfo->{message}->{$id}=\%d;
  }
 }

 if ($res->getElementsByTagNameNS($trNS,'data')) ## OPTIONAL
 {
  $self->node_resdata(($res->getElementsByTagNameNS($trNS,'data'))[0]);
 }

 ## trID
 if ($res->getElementsByTagNameNS($trNS, 'stid'))
 {
  my @svtrid = $res->getElementsByTagNameNS($trNS, 'stid');
  $self->svtrid($svtrid[0]->firstChild()->getData());
 }
 if ($res->getElementsByTagNameNS($trNS, 'ctid'))
 {
  my @cltrid = $res->getElementsByTagNameNS($trNS, 'ctid');
  $self->cltrid($cltrid[0]->firstChild()->getData());
 }
}

####################################################################################################

sub get_name_from_message # FIXME: Totally broken!
{
 my ($self)=@_;
 my $cb=$self->command_body();
 return 'session' unless (defined($cb) && ref($cb)); ## TO FIX
 foreach my $e (@$cb)
 {
  return $e->[1] if ($e->[0]=~m/^(?:domain|host|nsgroup):name$/); ## TO FIX (notably in case of check_multi)
  return $e->[1] if ($e->[0]=~m/^(?:contact|defreg):id$/); ## TO FIX
 }
 return 'session'; ## TO FIX
}

####################################################################################################
1;
