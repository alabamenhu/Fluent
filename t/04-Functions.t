use Test;
use lib 'lib';
use Fluent;

add-localization-basepath("t/04-data/");
add-localization-languages("en");

is localized("a", :4number,  :language<en>), '4';
is localized("b", :10number, :language<en>), '10.000';
is localized("c", :language<en>, :number( (1/3) but with-args(:5minimumIntegerDigits))), '00,000.33333';
is localized("a", :123number, :language<fa>), '۱۲۳';
say localized("c", :language<en>, :number( (2/7) but with-args(:4maximumIntegerDigits)));
say localized("c", :language<ar>, :number( (2/7) but with-args(:4maximumIntegerDigits)));
say localized("c", :language<es>, :number( (2/7) but with-args(:4maximumIntegerDigits)));
#is localized("c", :language<as>, :number( (2/7) but with-args(:4maximumIntegerDigits))), '০.২৮৫৭১';

use Intl::CLDR;

say get-number-pattern('as');



done-testing();
