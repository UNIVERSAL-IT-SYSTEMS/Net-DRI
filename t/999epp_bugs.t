#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;
use Net::DRI::DRD::ICANN;

use Test::More tests => 57;

eval { use Test::LongString max => 100; $Test::LongString::Context=50; };
*{'main::is_string'} = \&main::is if $@;

our $E1 = '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2 = '</epp>';
our $TRID = '<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

our $R1;
sub mysend
{
	my ($transport, $count, $msg) = @_;
	$R1 = $msg->as_string();
	return 1;
}

our $R2;
sub myrecv
{
 return Net::DRI::Data::Raw->new_from_string($R2 ? $R2 : $E1 . '<response>' .
	r() . $TRID . '</response>' . $E2);
}

my $dri = Net::DRI->new(10);
$dri->{trid_factory} = sub { return 'ABC-12345'; };
eval {
	$dri->add_registry('AT');
	$dri->target('AT')->new_current_profile('p1',
		'Net::DRI::Transport::Dummy',
		[{f_send => \&mysend, f_recv => \&myrecv}],
			'Net::DRI::Protocol::EPP::Extensions::AT', []);
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}

my $rc;
my $s;
my $d;
my ($dh, @c);

####################################################################################################
## Registry Messages


$R2 = $E1 . '<response><result code="1301"><msg>Command completed successfully; ack to dequeue</msg></result><msgQ count="2265" id="374185914"><qDate>2008-02-04T09:23:04.63Z</qDate><msg>EPP response to a transaction executed on your behalf: objecttype [domain] command [transfer-execute] objectname [mydomain.at]</msg></msgQ><resData><message xmlns="http://www.nic.at/xsd/at-ext-message-1.0" type="response-copy" xsi:schemaLocation="http://www.nic.at/xsd/at-ext-message-1.0 at-ext-message-1.0.xsd"><desc>EPP response to a transaction executed on your behalf: objecttype [domain] command [transfer-execute] objectname [mydomain.at]</desc><data><entry name="objecttype">domain</entry><entry name="command">transfer-execute</entry><entry name="objectname">mydomain.at</entry><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="2304"><msg>Object status prohibits operation</msg></result><msgQ count="734" id="374047143"/><extension><conditions xmlns="http://www.nic.at/xsd/at-ext-result-1.0" xsi:schemaLocation="http://www.nic.at/xsd/at-ext-result-1.0 at-ext-result-1.0.xsd"><condition code="NC20077" severity="error"><msg>Registry::NICAT::Exception::Policy::Domain::Locked</msg><details>Domain mydomain.at: domain is locked.</details></condition></conditions></extension><trID><clTRID>NICAT-1234-4341234246535343</clTRID><svTRID>2008020412454356454273-9-nicat</svTRID></trID></response></epp></data></message></resData>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->is_success(), 1, 'message polled successfully');

unless ($rc->is_success())
{
	die('Error ' . $rc->code() . ': ' . $rc->message());
}

is($dri->get_info('last_id'), 374185914, 'message get_info last_id 1');
is($dri->get_info('last_id', 'message', 'session'), 374185914,
	'message get_info last_id 2');
is($dri->get_info('id', 'message', 374185914), 374185914,
	'message get_info id');
is('' . $dri->get_info('qdate', 'message', 374185914), '2008-02-04T09:23:04',
	'message get_info qdate');
is($dri->get_info('lang', 'message', 374185914), 'en', 'message get_info lang');
is($dri->get_info('roid', 'message', 374185914), undef,
	'message get_info roid');
is($dri->get_info('content', 'message', 374185914), 'EPP response to a ' .
	'transaction executed on your behalf: objecttype [domain] ' .
	'command [transfer-execute] objectname [mydomain.at]',
	'message get_info content');
is($dri->get_info('action', 'message', 374185914), 'transfer-execute',
	'message get_info action');
is($dri->get_info('object_type', 'message', 374185914), 'domain',
	'message get_info object_type');
is($dri->get_info('object_id', 'message', 374185914), 'mydomain.at',
	'message get_info object_id');

my $conds = $dri->get_info('conditions', 'message', 374185914);
is($conds->[0]->{msg}, 'Registry::NICAT::Exception::Policy::Domain::Locked',
	'message condition message');
is($conds->[0]->{code}, 'NC20077', 'message condition code');
is($conds->[0]->{severity}, 'error', 'message condition severity');
is($conds->[0]->{details}, 'Domain mydomain.at: domain is locked.',
	'message condition details');

$R2 = $E1 . '<response><result code="1301"><msg>Command completed successfully; ack to dequeue</msg></result><msgQ count="1" id="375338309"><qDate>2008-02-06T10:18:19.70Z</qDate><msg>Reg losing: blafasel.at</msg></msgQ><resData><message xmlns="http://www.nic.at/xsd/at-ext-message-1.0" type="domain-transferred-away" xsi:schemaLocation="http://www.nic.at/xsd/at-ext-message-1.0 at-ext-message-1.0.xsd"><desc>Reg losing: blafasel.at</desc><data><entry name="domain">blafasel.at</entry></data></message></resData>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->is_success(), 1, 'message polled successfully');

unless ($rc->is_success())
{
	die('Error ' . $rc->code() . ': ' . $rc->message());
}

is($dri->get_info('last_id'), 375338309, 'message get_info last_id 1');
is($dri->get_info('object_type', 'message', 375338309), 'domain',
	'message get_info object_type');
is($dri->get_info('object_id', 'message', 375338309), 'blafasel.at',
	'message get_info object_id');
is($dri->get_info('action', 'message', 375338309), 'domain-transferred-away',
	'message get_info action');

$R2 = $E1 . '<response><result code="1301"><msg>Command completed successfully; ack to dequeue</msg></result><msgQ count="3" id="375424692"><qDate>2008-02-06T13:37:59.63Z</qDate><msg>ATTENTION: domain weingeist.at is marked to be locked SKW - lock customer request.</msg></msgQ><resData><message xmlns="http://www.nic.at/xsd/at-ext-message-1.0" type="domain-info-lock-customer" xsi:schemaLocation="http://www.nic.at/xsd/at-ext-message-1.0 at-ext-message-1.0.xsd"><desc>ATTENTION: domain weingeist.at is marked to be locked SKW - lock customer request.</desc><data><entry name="domain">weingeist.at</entry></data></message></resData>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->is_success(), 1, 'message polled successfully');

unless ($rc->is_success())
{
	die('Error ' . $rc->code() . ': ' . $rc->message());
}

is($dri->get_info('last_id'), 375424692, 'message get_info last_id 1');
is($dri->get_info('object_type', 'message', 375424692), 'domain',
	'message get_info object_type');
is($dri->get_info('object_id', 'message', 375424692), 'weingeist.at',
	'message get_info object_id');
is($dri->get_info('action', 'message', 375424692), 'domain-info-lock-customer',
	'message get_info action');

$R2 = $E1 . '<response><result code="1301"><msg>Command completed successfully; ack to dequeue</msg></result><msgQ count="18" id="390336246"><qDate>2008-03-14T11:42:23.64Z</qDate><msg>Transfer process cancelled for domain: (transfer-request with client-id [NICAT-1234-1242342543566334] and server-id [20080307124235423353F9-4-nicat])</msg></msgQ><resData><message xmlns="http://www.nic.at/xsd/at-ext-message-1.0" type="domain-transfer-aborted" xsi:schemaLocation="http://www.nic.at/xsd/at-ext-message-1.0 at-ext-message-1.0.xsd"><desc>Transfer process cancelled for domain: (transfer-request with client-id [NICAT-1234-1242342543566334] and server-id [20080307124235423353F9-4-nicat])</desc><reftrID><clTRID>NICAT-1234-1242342543566334</clTRID><svTRID>20080307124235423353F9-4-nicat</svTRID></reftrID><data><entry name="domain"/></data></message></resData>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->is_success(), 1, 'message polled successfully');

unless ($rc->is_success())
{
	die('Error ' . $rc->code() . ': ' . $rc->message());
}

is($dri->get_info('last_id'), 390336246, 'message get_info last_id 1');
is($dri->get_info('object_type', 'message', 390336246), 'domain',
	'message get_info object_type');
is($dri->get_info('object_id', 'message', 390336246), undef,
	'message get_info object_id');
is($dri->get_info('action', 'message', 390336246), 'domain-transfer-aborted',
	'message get_info action');

eval {
	$dri->add_registry('LU');
	$dri->target('LU')->new_current_profile('p2',
		'Net::DRI::Transport::Dummy',
		[{f_send => \&mysend, f_recv => \&myrecv}],
			'Net::DRI::Protocol::EPP::Extensions::LU', []);
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}

$R2 = $E1 . '<response><result code="1301"><msg>[1301] Command completed successfully; ack to dequeue</msg></result><msgQ count="1" id="104574"><qDate>2008-01-24T12:41:03.000Z</qDate><msg><dnslu:pollmsg type="13" xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:roid>D41231-DNSLU</dnslu:roid><dnslu:object>blafasel.lu</dnslu:object><dnslu:clTRID>DNSLU-4123-1342324575404832</dnslu:clTRID><dnslu:svTRID>CAFEBABE:002A-DNSLU</dnslu:svTRID><dnslu:exDate>2009-01-24T12:41:03.000Z</dnslu:exDate><dnslu:ns name="any">Nameserver test succeeded</dnslu:ns></dnslu:pollmsg></msg></msgQ>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
is($rc->is_success(), 1, 'message polled successfully');

unless ($rc->is_success())
{
	die('Error ' . $rc->code() . ': ' . $rc->message());
}

is($dri->get_info('last_id'), 104574, 'message get_info last_id');
is($dri->get_info('type', 'message', 104574), 13, 'message get_info type');
is($dri->get_info('roid', 'message', 104574), 'D41231-DNSLU',
	'message get_info roid');

eval {
	$dri->add_registry('CN');
	$dri->target('CN')->new_current_profile('p3',
		'Net::DRI::Transport::Dummy',
		[{f_send => \&mysend, f_recv => \&myrecv,protocol_version => 0.4}],
			'Net::DRI::Protocol::EPP::Extensions::CN', ['0.4']);
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}

$R2 = $E1 . '<response><result code="1301"><msg id="52309" lang="en-US">Transfer Request</msg><value>SRS Major Code: 2000</value><value>SRS Minor Code: 20024</value></result><msgQ count="60"><qDate>2007-11-20T14:19:48.0Z</qDate></msgQ><resData><domain:trnData xmlns="urn:iana:xml:ns:domain-1.0" xmlns:domain="urn:iana:xml:ns:domain-1.0" xsi:schemaLocation="urn:iana:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>TRUCKSTORE.TW</domain:name><domain:trStatus>pending</domain:trStatus><domain:reID>1-5F3ZW</domain:reID><domain:reDate>2007-11-20T14:19:48.0Z</domain:reDate><domain:acID>2000000198</domain:acID><domain:acDate>2007-11-25T14:19:48.0Z</domain:acDate><domain:exDate>2008-12-18T23:59:59.0Z</domain:exDate></domain:trnData></resData>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->is_success(), 1, 'message polled successfully');

unless ($rc->is_success())
{
	die('Error ' . $rc->code() . ': ' . $rc->message());
}

is($dri->get_info('last_id'), 52309, 'message get_info last_id 1');
is($dri->get_info('last_id', 'message', 'session'), 52309,
	'message get_info last_id 2');
is('' . $dri->get_info('qdate', 'message', 52309), '2007-11-20T14:19:48',
	'message get_info qdate');
is($dri->get_info('id', 'message', 52309), 52309, 'message get_info id');
is($dri->get_info('lang', 'message', 52309), 'en-US', 'message get_info lang');
is($dri->get_info('roid', 'message', 52309), undef,
	'message get_info roid');
is($dri->get_info('content', 'message', 52309), 'Transfer Request',
	'message get_info content');
is($dri->get_info('action', 'message', 52309), 'transfer',
	'message get_info action');
is($dri->get_info('object_type', 'message', 52309), 'domain',
	'message get_info object_type');
is($dri->get_info('object_id', 'message', 52309), 'truckstore.tw',
	'message get_info object_id');

is(Net::DRI::DRD::ICANN::is_reserved_name('test.com.cn', 'info'), 0,
	'.com.cn registrability');
is(Net::DRI::DRD::ICANN::is_reserved_name('xn--vcsq68l.com.cn', 'info'), 0,
	'.com.cn IDN registrability');
is(Net::DRI::DRD::ICANN::is_reserved_name('test.com.tw', 'info'), 0,
	'.com.tw registrability');
is(Net::DRI::DRD::ICANN::is_reserved_name('test.com.hn', 'info'), 0,
	'.com.hn registrability');
is(Net::DRI::DRD::ICANN::is_reserved_name('test.com.ag', 'info'), 0,
	'.com.ag registrability');
is(Net::DRI::DRD::ICANN::is_reserved_name('test.org.ag', 'info'), 0,
	'.org.ag registrability');

$R2 = $E1 . '<response><result code="2400"><msgs></msgs></result>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->remote_object('session')->noop();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->code(), 2400, 'broken hello request parsed successfully');

eval {
	$dri->add_registry('NAME');
	$dri->target('NAME')->new_current_profile('p4',
		'Net::DRI::Transport::Dummy',
		[{f_send => \&mysend, f_recv => \&myrecv}],
			'Net::DRI::Protocol::EPP::Extensions::NAME', ['1.0']);
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}

is($dri->verify_name_domain('tonnerre.lombard.name', 'info'), 0,
	'firstname.lastname.name registrability');

eval {
	$dri->add_registry('NU');
	$dri->target('NU')->new_current_profile('p6',
		'Net::DRI::Transport::Dummy',
		[{f_send => \&mysend, f_recv => \&myrecv}],
			'Net::DRI::Protocol::EPP', ['1.0']);
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}

$R2 = $E1 . '<response><result code="1301"><msg lang="en">Command completed successfully; ack to dequeue</msg></result><msgQ count="2" id="26966"><qDate>2007-11-19 14:46:28</qDate><msg>Transfer approved by .NU Domain Ltd</msg></msgQ><resData><domain:trnData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>blafasel.nu</domain:name><domain:trStatus/><domain:reID>Blafasel Inc</domain:reID><domain:reDate>2007-11-19T19:50:31.0Z</domain:reDate><domain:acID>.NU Domain Ltd</domain:acID><domain:acDate>2007-11-19T07:46:28.0Z</domain:acDate><domain:exDate>2009-03-08T18:44:50.0Z</domain:exDate></domain:trnData></resData>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->is_success(), 1, 'message polled successfully');

exit 0;

sub r
{
 my ($c, $m) = @_;
 return '<result code="' . ($c || 1000) . '"><msg>' .
	($m || 'Command completed successfully') . '</msg></result>';
}
