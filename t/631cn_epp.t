#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;
use DateTime::Duration;
use Data::Dumper;

use Test::More tests => 9;

eval { use Test::LongString max => 100; $Test::LongString::Context = 50; };
*{'main::is_string'} = \&main::is if $@;

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:iana:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:iana:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2='</epp>';
our $TRID='<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

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
	return Net::DRI::Data::Raw->new_from_string($R2 ? $R2 : $E1 .
		'<response>' . r() . $TRID . '</response>' . $E2);
}

my $dri;
eval {
	$dri = Net::DRI->new(10);
};
print $@->as_string() if $@;
$dri->{trid_factory} = sub { return 'ABC-12345'; };
$dri->add_registry('CN');
eval {
	$dri->target('CN')->new_current_profile('p1',
		'Net::DRI::Transport::Dummy',
		[{
			f_send=> \&mysend,
			f_recv=> \&myrecv,
			protocol_version => 0.4
		}], 'Net::DRI::Protocol::EPP::Extensions::CN', ['0.4',['Net::DRI::Protocol::EPP::Extensions::NeuLevel::Restore']]);
};
print $@->as_string() if $@;


my $rc;
my $s;
my $d;
my ($dh,@c);

####################################################################################################
## Contact operations
$R2 = $E1 . '<response>' . r(1001,'Command completed successfully; ' .
	'action pending') . $TRID . '</response>' . $E2;

my $c = $dri->local_object('contact');
$c->srid('C5213');
$c->name('John R. Doe');
$c->org('DauCorp Inc.');
$c->street(['16777216 Mountain Road', 'Montana Suite']);
$c->city('Missoula');
$c->sp('MT');
$c->pc('59801');
$c->cc('US');
$c->voice('+1.4065521023x1403');
$c->fax('+1.4065521023x1404');
$c->email('jrdoe@daucorp.mt.us');
$c->auth({pw => 'dausrockmissoula'});
$c->loc2int();

eval {
	$rc = $dri->contact_create($c);
};
print(STDERR $@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Contact created successfully');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:iana:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:iana:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="urn:iana:xml:ns:contact-1.0" xsi:schemaLocation="urn:iana:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>C5213</contact:id><contact:ascii><contact:name>John R. Doe</contact:name><contact:org>DauCorp Inc.</contact:org><contact:addr><contact:street>16777216 Mountain Road</contact:street><contact:street>Montana Suite</contact:street><contact:city>Missoula</contact:city><contact:sp>MT</contact:sp><contact:pc>59801</contact:pc><contact:cc>US</contact:cc></contact:addr></contact:ascii><contact:i15d><contact:name>John R. Doe</contact:name><contact:org>DauCorp Inc.</contact:org><contact:addr><contact:street>16777216 Mountain Road</contact:street><contact:street>Montana Suite</contact:street><contact:city>Missoula</contact:city><contact:sp>MT</contact:sp><contact:pc>59801</contact:pc><contact:cc>US</contact:cc></contact:addr></contact:i15d><contact:voice x="1403">+1.4065521023</contact:voice><contact:fax x="1404">+1.4065521023</contact:fax><contact:email>jrdoe@daucorp.mt.us</contact:email><contact:authInfo type="pw">dausrockmissoula</contact:authInfo></contact:create></create><clTRID>ABC-12345</clTRID></command></epp>', 'Create Contact XML correct');

my $todo = $dri->local_object('changes');

$c = $dri->local_object('contact');
$c->street(['16777216 Mountain Road', 'Mountain View Suite']);
$c->org('Daucorp Inc.');
$c->loc2int();
$todo->set('info', $c);

eval {
	$rc = $dri->contact_update($dri->local_object('contact')->srid('C5213'),
		$todo);
};
print(STDERR $@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Contact updated successfully');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:iana:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:iana:xml:ns:epp-1.0 epp-1.0.xsd"><command><update><contact:update xmlns:contact="urn:iana:xml:ns:contact-1.0" xsi:schemaLocation="urn:iana:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>C5213</contact:id><contact:chg><contact:ascii><contact:org>Daucorp Inc.</contact:org><contact:addr><contact:street>16777216 Mountain Road</contact:street><contact:street>Mountain View Suite</contact:street></contact:addr></contact:ascii><contact:i15d><contact:org>Daucorp Inc.</contact:org><contact:addr><contact:street>16777216 Mountain Road</contact:street><contact:street>Mountain View Suite</contact:street></contact:addr></contact:i15d></contact:chg></contact:update></update><clTRID>ABC-12345</clTRID></command></epp>', 'Update Contact XML correct');


####################################################################################################
## Message polling
$R2 = $E1 . '<response><result code="1301"><msg id="52433" lang="en-US">Transfer Request</msg><value>SRS Major Code: 2000</value><value>SRS Minor Code: 20024</value><value>--QUEUE_SUCCESSFULLY_POLLED</value></result><msgQ count="4"><qDate>2008-01-29T22:11:30.0Z</qDate></msgQ><resData><domain:trnData xmlns="urn:iana:xml:ns:domain-1.0" xmlns:domain="urn:iana:xml:ns:domain-1.0" xsi:schemaLocation="urn:iana:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>BLAFASEL23.TW</domain:name><domain:trStatus>pending</domain:trStatus><domain:reID>1-AS4DF</domain:reID><domain:reDate>2008-02-29T02:19:22.0Z</domain:reDate><domain:acID>1000000231</domain:acID><domain:acDate>2008-03-01T21:53:23.0Z</domain:acDate><domain:exDate>2009-01-11T23:59:59.0Z</domain:exDate></domain:trnData></resData>' . $TRID . '</response>' . $E2;

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

is($dri->get_info('last_id'), 52433, 'message get_info last_id 1');
is($dri->get_info('object_id', 'message', 52433), 'blafasel23.tw',
	'message get_info object_id');

####################################################################################################
exit(0);

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}
