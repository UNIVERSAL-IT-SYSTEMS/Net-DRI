## Domain Registry Interface, NeuLevel contact implementation
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

package Net::DRI::Protocol::EPP::Extensions::NeuLevel::Contact;

use strict;
use Net::DRI::Exception;

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NeuLevel::Contact - Contact at
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

sub register_commands
{
	my ($class, $version) = @_;
	my %tmp = (
		create =>	[ \&create, \&create_parse ]
	);
	return { 'contact' => \%tmp };
}

sub build_authinfo
{
	shift if (UNIVERSAL::isa($_[0], __PACKAGE__));
	my $contact = shift;
	my $az = (ref($contact) eq 'HASH' ? $contact : $contact->auth());

	return () unless ($az && ref($az) && exists($az->{pw}));
	return ['contact:authInfo',{'type' => 'pw'},$az->{pw}];
}

sub build_cdata
{
	my $contact = shift;
	my @d;

	my (@asciil, @asciii, @addrl, @addri);
	_do_locint(\@asciil, \@asciii, $contact, 'name');
	_do_locint(\@asciil, \@asciii, $contact, 'org');
	_do_locint(\@addrl,\@addri,$contact,'street');
	_do_locint(\@addrl,\@addri,$contact,'city');
	_do_locint(\@addrl,\@addri,$contact,'sp');
	_do_locint(\@addrl,\@addri,$contact,'pc');
	_do_locint(\@addrl,\@addri,$contact,'cc');
	push(@asciil,['contact:addr',@addrl]) if (@addrl);
	push(@asciii,['contact:addr',@addri]) if (@addri);

	push(@d, ['contact:ascii', @asciil]) if (@asciil);
	push(@d, ['contact:ascii', @asciii]) if (@asciii);
	push(@d, Net::DRI::Protocol::EPP::Core::Contact::build_tel('contact:voice',$contact->voice()))
		if (defined($contact->voice()));
	push(@d, Net::DRI::Protocol::EPP::Core::Contact::build_tel('contact:fax',$contact->fax()))
		if (defined($contact->fax()));
	push(@d, ['contact:email',$contact->email()])
		if (defined($contact->email()));
	push(@d, build_authinfo($contact));

	return @d;

	sub _do_locint
	{
		my ($rl,$ri,$contact,$what)=@_;
		my @tmp = $contact->$what();
		return unless @tmp;
		if ($what eq 'street')
		{
			if (defined($tmp[0]))
			{
				foreach (@{$tmp[0]})
				{
					push @$rl,['contact:street',$_];
				}
			}
			if (defined($tmp[1]))
			{
				foreach (@{$tmp[1]})
				{
					push @$rl,['contact:street',$_];
				}
			}
		}
		else
		{
			if (defined($tmp[0]))
			{
				push @$rl,['contact:'.$what,$tmp[0]];
			}
			if (defined($tmp[1]))
			{
				push @$rl,['contact:'.$what,$tmp[1]];
			}
		}
	}
}

sub create
{
	my ($epp, $contact) = @_;
	my $mes = $epp->message();
	my @d = Net::DRI::Protocol::EPP::Core::Contact::build_command($mes,
		'create',$contact);

	Net::DRI::Exception->die(1,'protocol/EPP',10,'Invalid contact '.$contact) unless (UNIVERSAL::isa($contact,'Net::DRI::Data::Contact'));
	$contact->validate(); ## will trigger an Exception if needed
	push @d,build_cdata($contact);
	$mes->command_body(\@d);
}

sub create_parse
{
	return Net::DRI::Protocol::EPP::Core::Contact::create_parse(@_);
}

####################################################################################################

1;
