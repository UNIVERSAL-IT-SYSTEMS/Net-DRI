#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;
use DateTime::Duration;

use Test::More tests => 12;

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2='</epp>';
our $TRID='<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

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

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}

my $dri=Net::DRI->new(10);
$dri->{trid_factory}=sub { return 'ABC-12345'; };
$dri->add_registry('PL');
$dri->target('PL')->new_current_profile('p1','Net::DRI::Transport::Dummy',[{f_send=>\&mysend,f_recv=>\&myrecv}],'Net::DRI::Protocol::EPP::Extensions::PL',[]);
my ($rc,$d,$co,$dh,@c);

####################################################################################################
## Examples taken from draft-zygmuntowicz-epp-pltld-02.txt �4

## Example 1, CORRECTED (domain:hostObj)
## + Example 2 CORRECTED (invalid date in exDate)

$R2=$E1.'<response>'.r().'<resData><domain:creData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>przyklad44.pl</domain:name><domain:crDate>1999-04-03T22:00:00.0Z</domain:crDate><domain:exDate>2000-04-03T22:00:00.0Z</domain:exDate></domain:creData></resData>'.$TRID.'</response>'.$E2;
$dh=$dri->local_object('hosts');
$dh->add('ns.przyklad2.pl');
$dh->add('ns5.przyklad.pl');
$rc=$dri->domain_create_only('przyklad44.pl',{ns=>$dh,auth=>{pw=>'authinfo_of_d97'},book=>1,reason=>'nice name'});
is($R1,'<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>przyklad44.pl</domain:name><domain:ns><domain:hostObj>ns.przyklad2.pl</domain:hostObj><domain:hostObj>ns5.przyklad.pl</domain:hostObj></domain:ns><domain:authInfo><domain:pw>authinfo_of_d97</domain:pw></domain:authInfo></domain:create></create><extension><extdom:create xmlns:extdom="http://www.dns.pl/NASK-EPP/extdom-1.0" xsi:schemaLocation="http://www.dns.pl/NASK-EPP/extdom-1.0 extdom-1.0.xsd"><extdom:reason>nice name</extdom:reason><extdom:book/></extdom:create></extension><clTRID>ABC-12345</clTRID></command></epp>','domain_create build with book');

is($rc->is_success(),1,'domain_create is_success');
$d=$dri->get_info('crDate');
is(''.$d,'1999-04-03T22:00:00','domain_create get_info(crDate)');
$d=$dri->get_info('exDate');
is(''.$d,'2000-04-03T22:00:00','domain_create get_info(exDate)');

## Examples 3,4,5,6,7,8 are standard EPP, thus not tested here

## Example 9 + Example 10, CORRECTED (type=loc instead of type=int)

$R2=$E1.'<response>'.r().'<resData><contact:creData xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>sh8013</contact:id><contact:crDate>1999-04-03T22:00:00.0Z</contact:crDate></contact:creData></resData>'.$TRID.'</response>'.$E2;
$co=$dri->local_object('contact')->srid('sh8013');
$co->name('11John Doe');
$co->org('Example Inc.');
$co->street(['123 Example Dr.','Suite 100']);
$co->city('Dulles');
$co->sp('VA');
$co->pc('20166-6503');
$co->cc('US');
$co->voice('+1.7035555555x1234');
$co->fax('+1.7035555556');
$co->email('jdoe@example.tld');
$co->auth({pw=>'2fooBAR'});
$co->individual(1);
$co->consent_for_publishing(1);
$rc=$dri->contact_create($co);
is($R1,'<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>sh8013</contact:id><contact:postalInfo type="loc"><contact:name>11John Doe</contact:name><contact:org>Example Inc.</contact:org><contact:addr><contact:street>123 Example Dr.</contact:street><contact:street>Suite 100</contact:street><contact:city>Dulles</contact:city><contact:sp>VA</contact:sp><contact:pc>20166-6503</contact:pc><contact:cc>US</contact:cc></contact:addr></contact:postalInfo><contact:voice x="1234">+1.7035555555</contact:voice><contact:fax>+1.7035555556</contact:fax><contact:email>jdoe@example.tld</contact:email><contact:authInfo><contact:pw>2fooBAR</contact:pw></contact:authInfo></contact:create></create><extension><extcon:create xmlns:extcon="http://www.dns.pl/NASK-EPP/extcon-1.0" xsi:schemaLocation="http://www.dns.pl/NASK-EPP/extcon-1.0 extcon-1.0.xsd"><extcon:individual>1</extcon:individual><extcon:consentForPublishing>1</extcon:consentForPublishing></extcon:create></extension><clTRID>ABC-12345</clTRID></command></epp>','contact_create build');
is($rc->is_success(),1,'contact_create is_success');
$d=$dri->get_info('id');
is($d,'sh8013','contact_create get_info(id)');
$d=$dri->get_info('crDate');
is(''.$d,'1999-04-03T22:00:00','contact_create get_info(crDate)');

## Example 11

$rc=$dri->contact_info($dri->local_object('contact')->srid('666666'),{auth=>{pw=>'2fooBAR'}});
is($R1,'<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><info><contact:info xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>666666</contact:id></contact:info></info><extension><extcon:info xmlns:extcon="http://www.dns.pl/NASK-EPP/extcon-1.0" xsi:schemaLocation="http://www.dns.pl/NASK-EPP/extcon-1.0 extcon-1.0.xsd"><extcon:authInfo><extcon:pw>2fooBAR</extcon:pw></extcon:authInfo></extcon:info></extension><clTRID>ABC-12345</clTRID></command></epp>','contact_info build');
is($rc->is_success(),1,'contact_info is_success');

## Example 12 is standard EPP, thus not tested here

## Example 13, CORRECTED (type=loc instead of type=int)
$co=$dri->local_object('contact')->srid('sh8013');
$toc=$dri->local_object('changes');
my $co2=$dri->local_object('contact');
$co2->org('');
$co2->street(['124 Example Dr.','Suite 200']);
$co2->city('Dulles');
$co2->sp('VA');
$co2->pc('20166-6503');
$co2->cc('US');
$co2->voice('+1.7034444444');
$co2->fax('');
$co2->consent_for_publishing(1);
$toc->set('info',$co2);
$toc->add('status',$dri->local_object('status')->no('delete'));
$rc=$dri->contact_update($co,$toc);
is($R1,'<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><update><contact:update xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>sh8013</contact:id><contact:add><contact:status s="clientDeleteProhibited"/></contact:add><contact:chg><contact:postalInfo type="loc"><contact:org/><contact:addr><contact:street>124 Example Dr.</contact:street><contact:street>Suite 200</contact:street><contact:city>Dulles</contact:city><contact:sp>VA</contact:sp><contact:pc>20166-6503</contact:pc><contact:cc>US</contact:cc></contact:addr></contact:postalInfo><contact:voice>+1.7034444444</contact:voice><contact:fax/></contact:chg></contact:update></update><extension><extcon:update xmlns:extcon="http://www.dns.pl/NASK-EPP/extcon-1.0" xsi:schemaLocation="http://www.dns.pl/NASK-EPP/extcon-1.0 extcon-1.0.xsd"><extcon:consentForPublishing>1</extcon:consentForPublishing></extcon:update></extension><clTRID>ABC-12345</clTRID></command></epp>','contact_update build');
is($rc->is_success(),1,'contact_update is_success');

## Example 14 is standard EPP, thus not tested here

exit 0;
