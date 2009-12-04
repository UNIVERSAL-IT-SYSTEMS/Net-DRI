## Domain Registry Interface, .PRO domain extensions
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

package Net::DRI::Protocol::EPP::Extensions::PRO::Domain;

use strict;

use DateTime::Format::ISO8601;

our $VERSION=do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf("%d".".%02d" x $#r, @r); };
my $NS = 'http://registrypro.pro/2003/epp/1/rpro-epp-2.0';

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::PRO::Domain - .PRO EPP domain extensions

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>development@sygroup.chE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt> and
E<lt>http://oss.bdsprojects.net/projects/netdri/E<gt>

=head1 AUTHOR

Tonnerre Lombard E<lt>tonnerre.lombard@sygroup.chE<gt>,
Alexander Biehl, E<lt>info@hexonet.netE<gt>, HEXONET Support GmbH,
E<lt>http://www.hexonet.net/E<gt>.

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
 my ($class,$version)=@_;
 my %tmp=(
           create =>		[ \&add_pro_extinfo ],
           update =>		[ \&add_pro_extinfo ],
	   info =>		[ undef, \&parse ]
         );

 return { 'domain' => \%tmp };
}

############################################################################

############ Transform commands

sub add_pro_extinfo
{
 my ($epp, $domain, $rd) = @_;
 my $mes = $epp->message();
 my @prodata;
 my @tmdata;
 my $ph;
 my $pw;

 $rd = +{ pro => $rd->set('pro') } if (UNIVERSAL::isa($rd, 'Net::DRI::Data::Changes'));

 return unless (defined($rd) && (ref($rd) eq 'HASH') && exists($rd->{pro}) &&
	(ref($rd->{pro}) eq 'HASH'));

 $ph = $rd->{pro};

 push(@prodata, ['rpro:tradeMarkName', $ph->{tmname}])
	if (exists($ph->{tmname}));
 push(@prodata, ['rpro:tradeMarkJurisdiction', $ph->{tmjurisdiction}])
	if (exists($ph->{tmjurisdiction}));
 push(@prodata, ['rpro:tradeMarkDate', $ph->{tmdate}->strftime('%Y-%m-%dT%H:%M:%S.%1NZ')])
	if (exists($ph->{tmdate}) && UNIVERSAL::isa($ph->{tmdate}, 'DateTime'));
 push(@prodata, ['rpro:tradeMarkNumber', int($ph->{tmnumber})])
	if (exists($ph->{tmnumber}) && int($ph->{tmnumber}));

 push(@prodata, ['rpro:registrationType', $ph->{type}])
	if (exists($ph->{type}));
 push(@prodata, ['rpro:redirectTarget', $ph->{redirect}])
	if (exists($ph->{redirect}) &&
		Net::DRI::Util::is_hostname($ph->{redirect}));
 push(@prodata, ['rpro:tradeMark', @tmdata]) if (@tmdata);

 if (exists($ph->{auth}) && ref($ph->{auth}) eq 'HASH' &&
	exists($ph->{auth}->{pw}))
 {
  $pw = $ph->{auth}->{pw};
  delete($ph->{auth}->{pw});
 }

 push(@prodata, ['rpro:authorization', $ph->{auth}, $pw])
	if (exists($ph->{auth}));
 return unless (@prodata);

 my $eid = $mes->command_extension_register('rpro:proDomain',
	'xmlns:rpro="' . $NS . '" xsi:schemaLocation="' . $NS .
	' rpro-epp-2.0.xsd"');
 $mes->command_extension($eid, [@prodata]);
}

sub parse
{
 my ($po, $otype, $oaction, $oname, $rinfo) = @_;
 my $mes = $po->message();
 my $infdata = $mes->get_content('proDomain', $NS, 1);
 my $pro = {};
 my $c;

 return unless ($infdata);
 my $pd = DateTime::Format::ISO8601->new();

 $c = $infdata->getFirstChild();

 while (defined($c) && $c)
 {
	my $name = $c->localname() || $c->nodeName();
	next unless $name;

	if ($name eq 'registrationType')
	{
		$pro->{type} = $c->getFirstChild()->getData();
	}
	elsif ($name eq 'redirectTarget')
	{
		$pro->{redirect} = $c->getFirstChild()->getData();
	}
	elsif ($name eq 'tradeMark')
	{
		my $to = $c->getFirstChild();

		while (defined($to) && $to)
		{
			my $totag = $to->localname() || $to->nodeName();
			next unless ($totag);

			if ($totag eq 'tradeMarkName')
			{
				$pro->{tmname} =
					$to->getFirstChild()->getData();
			}
			elsif ($totag eq 'tradeMarkJurisdiction')
			{
				$pro->{tmjurisdiction} =
					$to->getFirstChild()->getData();
			}
			elsif ($totag eq 'tradeMarkDate')
			{
				$pro->{tmdate} = $pd->parse_datetime(
					$to->getFirstChild()->getData());
			}
			elsif ($totag eq 'tradeMarkNumber')
			{
				$pro->{tmnumber} = int($to->getFirstChild()->
					getData());
			}

			$to = $to->getNextSibling();
		}
	}
	$c = $c->getNextSibling();
 }

 $rinfo->{$otype}->{$oname}->{pro} = $pro;
}

############################################################################

1;
