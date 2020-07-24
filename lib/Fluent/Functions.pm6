unit module Functions;

my %functions;

sub function($name) is export {
  return %functions{$name} if %functions{$name}:exists;
}
sub add-function($name,&code) {
  %functions{$name} = &code;
}

#############################
# FLUENT BUILT IN FUNCTIONS #
#############################

my &number = sub ($number, *%options) {
  use Intl::CLDR::Numbers;
  use Intl::CLDR::Plurals;
  my $language = @*LANGUAGES.head;

  # TODO : handle currency (not currently available in Intl:CLDR)
  my $style = %options<style> // 'decimal';

  my %pattern = get-number-pattern(
        $language,
        :system( get-default-number-system $language )
        :count( plural-count $number, $language ),
        :format($style)
  ).format;

  my %dev-args = $number.^can('CodeArguments') ?? $number.CodeArguments.named !! ();

  # Fluent's NUMBER() function uses camelCase to match the Javascript functions.
  # While that's fine for compatibility, it also makes for ugly P6 code if
  # anyone wants to override, so we check both.
  # I am currently doing things more correctly than JS, by respecting the CLDR
  # values.
  for <positive negative> -> $sign {
    %pattern{$sign}<minimum-fraction-digits>    = $_ with                                       %dev-args<minimum-fraction-digits>;
    %pattern{$sign}<minimum-fraction-digits>    = $_ with %options<minimumFractionDigits>    // %dev-args<minimumFractionDigits>;
    %pattern{$sign}<maximum-fraction-digits>    = $_ with                                       %dev-args<maximum-fraction-digits>;
    %pattern{$sign}<maximum-fraction-digits>    = $_ with %options<maximumFractionDigits>    // %dev-args<maximumFractionDigits>;
    %pattern{$sign}<minimum-integer-digits>     = $_ with                                       %dev-args<minimum-integer-digits>;
    %pattern{$sign}<minimum-integer-digits>     = $_ with %options<minimumIntegerDigits>     // %dev-args<minimumIntegerDigits>;
    %pattern{$sign}<minimum-significant-digits> = $_ with                                       %dev-args<minimum-significant-digits>;
    %pattern{$sign}<minimum-significant-digits> = $_ with %options<minimumSignificantDigits> // %dev-args<minimumSignificantDigits>;
    %pattern{$sign}<maximum-significant-digits> = $_ with                                       %dev-args<maximum-significant-digits>;
    %pattern{$sign}<maximum-significant-digits> = $_ with %options<maximumSignificantDigits> // %dev-args<maximumSignificantDigits>;
  }

  return format-number($number, :$language, :symbols(get-numeric-symbols($language).symbols), :%pattern)
}

my &datetime = sub ($datetime, *%options) {
  return $datetime.Str;
}

add-function "NUMBER", &number;
add-function "DATETIME", &datetime;
