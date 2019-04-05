use Test;
use Fluent;
add-localization-basepath("t/03-data/");
add-localization-languages("en");

is localized('foo', :0number), "nothing";
is localized('foo', :1number), "one";
is localized('foo', :2number), "more";
done-testing();
