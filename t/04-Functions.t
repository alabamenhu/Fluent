use Test;
use Fluent;

add-localization-basepath("t/04-data/");
add-localization-languages("en");

is localized("a", :4number,  :language<en>), '4';
is localized("b", :10number, :language<en>), '10.000';
is localized("c", :language<en>, :number( (1/3) but with-args(:5minimumIntegerDigits))), '00,000.33333';
is localized("a", :123number, :language<fa>), '۱۲۳';
is localized("c", :language<as>, :number( (2/7) but with-args(:4maximumIntegerDigits))), '০.২৮৫৭১';

done-testing();
