#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;
use DateTime::Duration;
use Data::Dumper;

use Test::More tests => 27;

eval { use Test::LongString max => 100; $Test::LongString::Context=50; };
*{'main::is_string'}=\&main::is if $@;

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-response xmlns="http://registry.denic.de/global/1.0" xmlns:tr="http://registry.denic.de/transaction/1.0" xmlns:domain="http://registry.denic.de/domain/1.0" xmlns:contact="http://registry.denic.de/contact/1.0">';
our $E2='</registry-response>';
our $TRID='<tr:ctid>ABC-12345</tr:ctid><tr:stid>54322-XYZ</tr:stid>';

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
 return Net::DRI::Data::Raw->new_from_string($R2? $R2 : $E1.'<registry-response>'.r().$TRID.'</registry-response>'.$E2);
}

my $dri=Net::DRI->new(10);
$dri->{trid_factory}=sub { return 'ABC-12345'; };
$dri->add_registry('DENIC');
eval {
$dri->target('DENIC')->new_current_profile('p1','Net::DRI::Transport::Dummy',[{f_send=>\&mysend,f_recv=>\&myrecv}],'Net::DRI::Protocol::RRI',[]);
};
print $@->as_string() if $@;


my $rc;
my $s;
my $d;
my ($dh,@c);

####################################################################################################
## Session Management
$R2 = $E1 . '<tr:transaction><tr:stid>' . $TRID .
	'</tr:stid><tr:result>success</tr:result></tr:transaction>' . $E2;

eval {
	$rc = $dri->process('session', 'login', ['user','password']);
};
print($@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Login successful');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-request xmlns="http://registry.denic.de/global/1.0"><login><user>user</user><password>password</password></login><ctid>ABC-12345</ctid></registry-request>', 'Login XML correct');

####################################################################################################
## Contact Operations
$R2 = $E1 . '<tr:transaction><tr:stid>' . $TRID .
	'</tr:stid><tr:result>success</tr:result><tr:data><contact:checkData><contact:handle>DENIC-12345-BSP</contact:handle><contact:status>free</contact:status></contact:checkData></tr:data></tr:transaction>' . $E2;

eval {
	$rc = $dri->contact_check($dri->local_object('contact')->srid('DENIC-12345-BSP'));
};
print($@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is(defined($rc) && $rc->is_success(), 1, 'Contact successfully checked');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-request xmlns="http://registry.denic.de/global/1.0" xmlns:contact="http://registry.denic.de/contact/1.0"><contact:check><contact:handle>DENIC-12345-BSP</contact:handle></contact:check><ctid>ABC-12345</ctid></registry-request>', 'Check Contact XML correct');
is($dri->get_info('exist', 'contact', 'DENIC-12345-BSP'), 0, 'Contact does not exist');

$R2 = $E1 . '<tr:transaction><tr:stid>' . $TRID .
	'</tr:stid><tr:result>success</tr:result></tr:transaction>' . $E2;

my $c = $dri->local_object('contact');
$c->srid('DENIC-99990-BSP');
$c->type('PERSON');
$c->name('Theobald Tester');
$c->org('Test-Org');
$c->street(['Kleiner Dienstweg 17']);
$c->pc('09538');
$c->city('Gipsnich');
$c->cc('DE');
$c->voice('+49.123456');
$c->fax('+49.123457');
$c->email('email@denic.de');
$c->sip('sip:benutzer@denic.de');

eval {
	$rc = $dri->contact_create($c);
};
print($@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Contact successfully created');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-request xmlns="http://registry.denic.de/global/1.0" xmlns:contact="http://registry.denic.de/contact/1.0"><contact:create><contact:handle>DENIC-99990-BSP</contact:handle><contact:type>PERSON</contact:type><contact:name>Theobald Tester</contact:name><contact:organisation>Test-Org</contact:organisation><contact:postal><contact:address>Kleiner Dienstweg 17</contact:address><contact:postalCode>09538</contact:postalCode><contact:city>Gipsnich</contact:city><contact:countryCode>DE</contact:countryCode></contact:postal><contact:phone>+49.123456</contact:phone><contact:fax>+49.123457</contact:fax><contact:email>email@denic.de</contact:email><contact:sip>sip:benutzer@denic.de</contact:sip></contact:create><ctid>ABC-12345</ctid></registry-request>', 'Create Contact XML correct');

my $todo = $dri->local_object('changes');
$todo->set('info', $c);

eval {
	$rc = $dri->contact_update($c, $todo);
};
print($@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Contact successfully updated');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-request xmlns="http://registry.denic.de/global/1.0" xmlns:contact="http://registry.denic.de/contact/1.0"><contact:update><contact:handle>DENIC-99990-BSP</contact:handle><contact:type>PERSON</contact:type><contact:name>Theobald Tester</contact:name><contact:organisation>Test-Org</contact:organisation><contact:postal><contact:address>Kleiner Dienstweg 17</contact:address><contact:postalCode>09538</contact:postalCode><contact:city>Gipsnich</contact:city><contact:countryCode>DE</contact:countryCode></contact:postal><contact:phone>+49.123456</contact:phone><contact:fax>+49.123457</contact:fax><contact:email>email@denic.de</contact:email><contact:sip>sip:benutzer@denic.de</contact:sip></contact:update><ctid>ABC-12345</ctid></registry-request>', 'Update Contact XML correct');

$R2 = $E1 . '<tr:transaction><tr:stid>' . $TRID .
	'</tr:stid><tr:result>success</tr:result><tr:data><contact:checkData><contact:handle>DENIC-99990-BSP</contact:handle><contact:status>failed</contact:status></contact:checkData></tr:data></tr:transaction>' . $E2;

eval {
	$rc = $dri->contact_check($c);
};
print($@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is(defined($rc) && $rc->is_success(), 1, 'Contact successfully checked');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-request xmlns="http://registry.denic.de/global/1.0" xmlns:contact="http://registry.denic.de/contact/1.0"><contact:check><contact:handle>DENIC-99990-BSP</contact:handle></contact:check><ctid>ABC-12345</ctid></registry-request>', 'Check Contact XML correct');
is($dri->get_info('exist', 'contact', 'DENIC-99990-BSP'), 1, 'Contact exists');

$R2 = $E1 . '<tr:transaction><tr:stid>' . $TRID .
	'</tr:stid><tr:result>success</tr:result></tr:transaction>' . $E2;

eval {
	$rc = $dri->contact_delete($c);
};
print($@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Contact successfully deleted');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-request xmlns="http://registry.denic.de/global/1.0" xmlns:contact="http://registry.denic.de/contact/1.0"><contact:delete><contact:handle>DENIC-99990-BSP</contact:handle></contact:delete><ctid>ABC-12345</ctid></registry-request>', 'Delete Contact XML correct');

$R2 = $E1 . '<tr:transaction><tr:stid>' . $TRID .
	'</tr:stid><tr:result>success</tr:result><tr:data><contact:infoData>' .
	'<contact:handle>DENIC-99989-BSP</contact:handle>' .
	'<contact:type>ROLE</contact:type>' .
	'<contact:name>SyGroup GmbH</contact:name>' .
	'<contact:organisation>SyGroup GmbH</contact:organisation>' .
	'<contact:postal>' .
	'<contact:address>Gueterstrasse 86</contact:address>' .
	'<contact:city>Basel</contact:city>' .
	'<contact:postalCode>4053</contact:postalCode>' .
	'<contact:countryCode>CH</contact:countryCode>' .
	'</contact:postal>' .
	'<contact:phone>+41.613338033</contact:phone>' .
	'<contact:fax>+41.613831467</contact:fax>' .
	'<contact:email>info@sygroup.ch</contact:email>' .
	'<contact:sip>sip:secretary@sygroup.ch</contact:sip>' .
	'<contact:remarks>Live penguins in the office</contact:remarks>' .
	'<contact:changed>2007-05-23T22:55:33+02:00</contact:changed>' .
	'</contact:infoData></tr:data></tr:transaction>' . $E2;

eval {
	$rc = $dri->contact_info($dri->local_object('contact')->srid('DENIC-99989-BSP'));
};
print($@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Contact successfully queried');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><registry-request xmlns="http://registry.denic.de/global/1.0" xmlns:contact="http://registry.denic.de/contact/1.0"><contact:info><contact:handle>DENIC-99989-BSP</contact:handle></contact:info><ctid>ABC-12345</ctid></registry-request>', 'Query Contact XML correct');

$c = $dri->get_info('self', 'contact', 'DENIC-99989-BSP');
isa_ok($c, 'Net::DRI::Data::Contact::DENIC');
is($c->name() . '|' . $c->org() . '|' . $c->sip() . '|' . $c->type(),
	'SyGroup GmbH|SyGroup GmbH|sip:secretary@sygroup.ch|ROLE',
	'Selected info from contact');

my $mod = $dri->get_info('upDate', 'contact', 'DENIC-99989-BSP');
isa_ok($mod, 'DateTime');
is($mod->ymd . 'T' . $mod->hms, '2007-05-23T22:55:33', 'Update Date');

####################################################################################################
exit(0);

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}
