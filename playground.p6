use lib 'lib';
use Fluent;


my $l = localized('hello = hola
  .morning = buenos días
  .night = buenas noches

goodbye = foo { DATE("blah",3.45,foo:12.34, bar : -49.375) }

hi = { $number ->
 [0] hello to {$who}
*[1] hola a {$who}
 [2] bomdia a {$who}
}
');
#', :dump);

say "---------------";
say "Messages: \n  ", $l.messages.values.map(*.gist).join("\n  ");
say "Terms: \n  ", $l.terms.values.map(*.gist).join("\n  ");
say "---------------";

# note, number selection should be for choosing, well,
# numbers.  Language selection will be handled in a different part.
# but this just makes it easy to see that the variable is parsed correctly.
say $l.format("hi", :0number, :who('you'));
say $l.format("hi", :1number, :who('ti'));
say $l.format("hi", :2number, :who('ti'));

#about = About \{ -brand-name \}.
#")
#            [locative] Firefoxa
#*[nominative] Firefox
#about = Informacje o { -brand-name(case: "locative") }.
say " ---------- ";
