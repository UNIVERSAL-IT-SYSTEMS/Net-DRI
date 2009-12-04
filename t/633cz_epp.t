#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;

use Test::More tests => 19;
eval { no warnings; require Test::LongString; Test::LongString->import(max => 100); $Test::LongString::Context=50; };
*{'main::is_string'}=\&main::is if $@;

our $E1 = '<?xml version="1.0" encoding="UTF-8"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2 = '</epp>';
our $TRID = '<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

our $R1;
sub mysend
{
 my ($transport,$count,$msg)=@_;
 $R1=$msg->as_string();
 return 1;
}

our $R2;
sub myrecv
{
 return Net::DRI::Data::Raw->new_from_string($R2? $R2 : $E1.'<response>'.r().$TRID.'</response>'.$E2);
}

my $dri=Net::DRI->new(10);
$dri->{trid_factory}=sub { return 'ABC-12345'; };
$dri->add_registry('CZ');
$dri->target('CZ')->new_current_profile('p1', 'Net::DRI::Transport::Dummy', [{f_send => \&mysend, f_recv => \&myrecv}], 'Net::DRI::Protocol::EPP::Extensions::CZ', []);

my $rc;
my $s;
my $d;
my ($dh, @c);

####################################################################################################
## Contact operations

## Contact create
$R2 = $E1 . '<response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.4 contact-1.4.xsd"><contact:id>TL1-CZ</contact:id><contact:crDate>2008-04-25T18:20:51+02:00</contact:crDate></contact:creData></resData>' . $TRID . '</response>' . $E2;

my $c = $dri->local_object('contact');
$c->srid('TL1-CZ');
$c->name('Tonnerre Lombard');
$c->org('SyGroup GmbH');
$c->street(['Gueterstrasse 86']);
$c->city('Basel');
$c->sp('BS');
$c->pc('4053');
$c->cc('CH');
$c->voice('+41.61338033');
$c->fax('+41.613831467');
$c->email('tonnerre.lombard@sygroup.ch');
$c->auth({pw => 'blablabla'});
eval {
	$rc = $dri->contact_create($c);
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
is($rc->is_success(), 1, 'contact create success');

die('Error ' . $rc->code() . ': ' . $rc->message()) unless ($rc->is_success());
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.4 contact-1.4.xsd"><contact:id>TL1-CZ</contact:id><contact:postalInfo><contact:name>Tonnerre Lombard</contact:name><contact:org>SyGroup GmbH</contact:org><contact:addr><contact:street>Gueterstrasse 86</contact:street><contact:city>Basel</contact:city><contact:sp>BS</contact:sp><contact:pc>4053</contact:pc><contact:cc>CH</contact:cc></contact:addr></contact:postalInfo><contact:voice>+41.61338033</contact:voice><contact:fax>+41.613831467</contact:fax><contact:email>tonnerre.lombard@sygroup.ch</contact:email><contact:authInfo>blablabla</contact:authInfo></contact:create></create><clTRID>ABC-12345</clTRID></command>' . $E2, 'contact create xml correct');
is($dri->get_info('crDate', 'contact', 'TL1-CZ'), '2008-04-25T18:20:51',
	'contact create crdate');

$c = $dri->local_object('contact');
$c->srid('TL2-CZ');

## Contact info
$R2 = $E1 . '<response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:infData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.4 contact-1.4.xsd"><contact:id>TL2-CZ</contact:id><contact:roid>C0000146169-CZ</contact:roid><contact:status s="ok">Objekt is without restrictions</contact:status><contact:postalInfo><contact:name>Tonnerre Lombard</contact:name><contact:org>SyGroup GmbH</contact:org><contact:addr><contact:street>Gueterstrasse 86</contact:street><contact:city>Basel</contact:city><contact:sp>Basel-Stadt</contact:sp><contact:pc>4053</contact:pc><contact:cc>CH</contact:cc></contact:addr></contact:postalInfo><contact:voice>+41.61338033</contact:voice><contact:fax>+41.613831467</contact:fax><contact:email>tonnerre.lombard@sygroup.ch</contact:email><contact:clID>REG-FRED_A</contact:clID><contact:crID>REG-FRED_A</contact:crID><contact:crDate>2008-04-25T18:20:51+02:00</contact:crDate><contact:upID>REG-FRED_A</contact:upID><contact:upDate>2008-04-25T18:29:12+02:00</contact:upDate><contact:authInfo>blablabla</contact:authInfo></contact:infData></resData>' . $TRID . '</response>' . $E2;
eval {
	$rc = $dri->contact_info($c);
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
is($rc->is_success(), 1, 'contact info success');
$c = $dri->get_info('self', 'contact', 'TL2-CZ');
is(ref($c), 'Net::DRI::Data::Contact', 'contact info type');
is($c->srid(), 'TL2-CZ', 'contact info srid');
is($c->roid(), 'C0000146169-CZ', 'contact info roid');
is($c->name(), 'Tonnerre Lombard', 'contact info name');
is($c->org(), 'SyGroup GmbH', 'contact info org');
is_deeply($c->street(), ['Gueterstrasse 86'], 'contact info street');
is($c->city(), 'Basel', 'contact info city');
is($c->sp(), 'Basel-Stadt', 'contact info sp');
is($c->pc(), '4053', 'contact info pc');
is($c->voice(), '+41.61338033', 'contact info voice');
is($c->fax(), '+41.613831467', 'contact info fax');
is($c->email(), 'tonnerre.lombard@sygroup.ch', 'contact info email');
is($c->auth()->{pw}, 'blablabla', 'contact info authcode');

## Contact update
$R2 = $E1 . '<response><result code="1000"><msg>Command completed successfully</msg></result>' . $TRID . '</response>' . $E2;
my $todo = $dri->local_object('changes');
$c = $dri->local_object('contact');
$c->srid('TL2-CZ');
$c->street(['Gueterstrasse 86']);
$c->city('Basel');
$c->sp('BS');
$c->fax(undef);
$c->auth({pw => 'bliblablu'});
$todo->set('info', $c);
eval {
	$rc = $dri->contact_update($c, $todo);
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
is($rc->is_success(), 1, 'contact update success');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><update><contact:update xmlns:contact="http://www.nic.cz/xml/epp/contact-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.4 contact-1.4.xsd"><contact:id>TL2-CZ</contact:id><contact:chg><contact:postalInfo><contact:addr><contact:street>Gueterstrasse 86</contact:street><contact:city>Basel</contact:city><contact:sp>BS</contact:sp></contact:addr></contact:postalInfo><contact:authInfo>bliblablu</contact:authInfo></contact:chg></contact:update></update><clTRID>ABC-12345</clTRID></command></epp>', 'contact update xml correct');

####################################################################################################
## Registry Messages


exit 0;

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}
