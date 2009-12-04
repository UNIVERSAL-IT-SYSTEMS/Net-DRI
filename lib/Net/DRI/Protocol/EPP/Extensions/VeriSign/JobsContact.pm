## Domain Registry Interface, .JOBS contact extension
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

package Net::DRI::Protocol::EPP::Extensions::VeriSign::JobsContact;

use strict;

our $VERSION=do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::VeriSign::JobsContact - .JOBS EPP contact extensions

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

Tonnerre Lombard E<lt>tonnerre.lombard@sygroup.chE<gt>

=head1 COPYRIGHT

Copyright (c) 2007,2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
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
 my %contacttmp=(
	   create =>		[ \&create, undef ],
	   update =>		[ \&update, undef ],
	   info =>		[ undef, \&info_parse ]
	 );

 return { 'contact' => \%contacttmp };
}

####################################################################################################

############ Transform commands

sub add_job
{
	my ($cmd, $epp, $contact, $rd) = @_;
	my $mes = $epp->message();
	my $info;
	my @jobdata;

	return unless (UNIVERSAL::isa($contact, 'Net::DRI::Data::Contact::JOBS'));
	return unless (UNIVERSAL::can($contact, 'jobinfo') &&
		UNIVERSAL::isa($contact->jobinfo(), 'HASH'));

	$info = $contact->jobinfo();
	push(@jobdata, ['jobsContact:title', $info->{title}])
		if (defined($info->{title}) && length($info->{title}));
	push(@jobdata, ['jobsContact:website', $info->{website}])
		if (defined($info->{website}) && length($info->{website}));
	push(@jobdata, ['jobsContact:industryType', $info->{industry}])
		if (defined($info->{industry}) && length($info->{industry}));
	push(@jobdata, ['jobsContact:isAdminContact',
		(defined($info->{admin}) && $info->{admin} ? 'Yes' : 'No')])
		if (defined($info->{admin}) && length($info->{admin}));
	push(@jobdata, ['jobsContact:isAssociationMember',
		(defined($info->{member}) && $info->{member} ? 'Yes' : 'No')])
		if (defined($info->{member}) && length($info->{member}));

	return unless (@jobdata);

	my $eid = $mes->command_extension_register('jobsContact:' . $cmd,
		'xmlns:jobsContact="http://www.verisign.com/epp/jobsContact-1.0" ' .
		'xsi:schemaLocation="http://www.verisign.com/epp/jobsContact-1.0 jobsContact-1.0.xsd"');
	$mes->command_extension($eid, \@jobdata);
}

sub create
{
	return add_job('create', @_);
}

sub update
{
	return add_job('update', @_);
}

sub info_parse
{
	my ($po,$otype,$oaction,$oname,$rinfo)=@_;
	my $mes = $po->message();
	my $jobNS = 'http://www.verisign.com/epp/dotJobs-1.0';
	my $infdata = $mes->get_content('infData', $jobNS, 1);
	my $contact = $rinfo->{$otype}->{$oname}->{self};
	my $jobinfo = +{
	};
	my $c;

	warn('No infdata') unless (defined($infdata));
	return unless (defined($infdata));

	$c = $infdata->getElementsByTagNameNS($jobNS, 'title');
	$jobinfo->{title} = $c->shift()->getFirstChild()->getData() if ($c);

	$c = $infdata->getElementsByTagNameNS($jobNS, 'website');
	$jobinfo->{website} = $c->shift()->getFirstChild()->getData() if ($c);

	$c = $infdata->getElementsByTagNameNS($jobNS, 'industryType');
	$jobinfo->{industry} = $c->shift()->getFirstChild()->getData() if ($c);

	$c = $infdata->getElementsByTagNameNS($jobNS, 'isAdminContact');
	$jobinfo->{admin} = (lc($c->shift()->getFirstChild()->getData()) eq
		'yes') if ($c);

	$c = $infdata->getElementsByTagNameNS($jobNS, 'isAssociationMember');
	$jobinfo->{member} = (lc($c->shift()->getFirstChild()->getData()) eq
		'yes') if ($c);

	$contact->jobinfo($jobinfo);
}

####################################################################################################
1;
