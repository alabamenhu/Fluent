use Test;
use lib 'lib';
use Fluent;

add-localization-basepath("t/03-data/");
add-localization-languages("en");

is localized('foo', :0number), "nothing";
is localized('foo', :1number), "one";
is localized('foo', :2number), "more";
is localized('foo', :1000number), "thousand";      # passed as a number
is localized('foo', :number<1000.00>), "thousand"; # passed as a string

done-testing();
