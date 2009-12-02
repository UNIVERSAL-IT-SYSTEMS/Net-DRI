#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;
use DateTime::Duration;
use Data::Dumper;

use Test::More tests => 6;

eval { use Test::LongString max => 100; $Test::LongString::Context = 50; };
*{'main::is_string'} = \&main::is if $@;

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
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
$dri->add_registry('VNDS');
eval {
	$dri->target('VNDS')->new_current_profile('p1',
		'Net::DRI::Transport::Dummy',
		[{
			f_send=> \&mysend,
			f_recv=> \&myrecv
		}], 'Net::DRI::Protocol::EPP', ['1.0',['Net::DRI::Protocol::EPP::Extensions::VeriSign::Restore']]);
};
print $@->as_string() if $@;


my $rc;
my $s;
my $d;
my $ro = $dri->remote_object('domain');
my ($dh, @c);

####################################################################################################
## Restore a deleted domain
$R2 = $E1 . '<response>' . r(1001,'Command completed successfully; ' .
	'action pending') . $TRID . '</response>' . $E2;

eval {
	$rc = $ro->restore_request('deleted-by-accident.com');
};
print(STDERR $@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Domain successfully recovered');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><update><domain:update xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>deleted-by-accident.com</domain:name><domain:chg/></domain:update></update><extension><rgp:update xmlns:rgp="urn:ietf:params:xml:ns:rgp-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:rgp-1.0 rgp-1.0.xsd"><rgp:restore op="request"/></rgp:update></extension><clTRID>ABC-12345</clTRID></command></epp>', 'Recover Domain request XML correct');

my $ch = $dri->local_object('changes');
$ch->del('ns', $dri->local_object('hosts')->add('dns1.syhosting.com')->
	add('dns2.syhosting.com')->add('dns23.syhosting.com'));
$ch->del('contact', $dri->local_object('contactset')->
	add($dri->local_object('contact')->srid('TL1-BLAH'), 'registrant')->
	add($dri->local_object('contact')->srid('DA1-BLAH'), 'tech')->
	add($dri->local_object('contact')->srid('SK1-BLAH'), 'billing')->
	add($dri->local_object('contact')->srid('SL1-BLAH'), 'admin'));
$ch->add('ns', $dri->local_object('hosts')->add('dns1.syhosting.com')->
	add('dns2.syhosting.com')->add('dns3.syhosting.com'));
$ch->del('status', $dri->local_object('status')->no('delete')->no('transfer'));
$ch->add('status', $dri->local_object('status')->no('delete')->no('transfer'));
$ch->add('contact', $dri->local_object('contactset')->
	add($dri->local_object('contact')->srid('TL1-BLAH'), 'registrant')->
	add($dri->local_object('contact')->srid('DA1-BLAH'), 'tech')->
	add($dri->local_object('contact')->srid('SK1-BLAH'), 'billing')->
	add($dri->local_object('contact')->srid('SL1-BLAH'), 'admin'));

eval {
	$rc = $ro->restore_report('deleted-by-accident.com', {
		data =>	$ch,
		deleted =>	new DateTime(year => 2008, month => 2,
			day => 7, hour => 14, minute => 23),
		restored =>	new DateTime(year => 2008, month => 2,
			day => 7, hour => 15, minute => 33),
		reason =>	'Registrant error',
		other =>	'He clicked on everything he saw'
	});
};
print(STDERR $@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'RGP report sent successfully');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><update><domain:update xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>deleted-by-accident.com</domain:name><domain:chg/></domain:update></update><extension><rgp:update xmlns:rgp="urn:ietf:params:xml:ns:rgp-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:rgp-1.0 rgp-1.0.xsd"><rgp:restore op="report"><rgp:preData><domain:ns><domain:hostObj>dns1.syhosting.com</domain:hostObj><domain:hostObj>dns2.syhosting.com</domain:hostObj><domain:hostObj>dns23.syhosting.com</domain:hostObj></domain:ns><domain:status s="clientTransferProhibited"/><domain:status s="clientDeleteProhibited"/><domain:registrant>TL1-BLAH</domain:registrant><domain:contact type="admin">SL1-BLAH</domain:contact><domain:contact type="billing">SK1-BLAH</domain:contact><domain:contact type="tech">DA1-BLAH</domain:contact></rgp:preData><rgp:postData><domain:ns><domain:hostObj>dns1.syhosting.com</domain:hostObj><domain:hostObj>dns2.syhosting.com</domain:hostObj><domain:hostObj>dns3.syhosting.com</domain:hostObj></domain:ns><domain:status s="clientTransferProhibited"/><domain:status s="clientDeleteProhibited"/><domain:registrant>TL1-BLAH</domain:registrant><domain:contact type="admin">SL1-BLAH</domain:contact><domain:contact type="billing">SK1-BLAH</domain:contact><domain:contact type="tech">DA1-BLAH</domain:contact></rgp:postData><rgp:delTime>2008-02-07T14:23:00.0Z</rgp:delTime><rgp:resTime>2008-02-07T15:33:00.0Z</rgp:resTime><rgp:resReason>Registrant error</rgp:resReason><rgp:statement>This registrar has not restored the Registered Name in order to assume the rights to use or sell the Registered Name for itself or for any third party.</rgp:statement><rgp:statement>The information in this report is true to the best of this registrar\'s knowledge, and this registrar acknowledges that intentionally supplying false information in this report shall constitute an incurable material breach of the Registry-Registrar Agreement.</rgp:statement><rgp:other>He clicked on everything he saw</rgp:other></rgp:restore></rgp:update></extension><clTRID>ABC-12345</clTRID></command></epp>', 'Recover Domain RGP report XML correct');

####################################################################################################
exit(0);

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}
