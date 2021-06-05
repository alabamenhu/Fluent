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
  use Intl::Format::Number;
  use Intl::Number::Plural;
  my $language = @*LANGUAGES.head;

  # TODO : handle currency (not currently available in Intl:CLDR)
  my $style = %options<style> // 'decimal';

  #`<<< Old method specified digits after grabbing formatter
  my $pattern = get-number-formatter(
        $language,
        :system( get-default-number-system $language )
        :count( plural-count $number ),
        :format($style)
  ).format;
  >>>

  my %dev-args = $number.^can('CodeArguments') ?? $number.CodeArguments.named !! ();

  # Fluent's NUMBER() function uses camelCase to match the Javascript functions.
  # While that's fine for compatibility, it also makes for ugly P6 code if
  # anyone wants to override, so we check both.
  # I am currently doing things more correctly than JS, by respecting the CLDR
  # values.
  #`<<<
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
  }>>>

  # Significant digits aren't currently supported by the new Intl::Format::Number, but these are passed along
  # so support is automatically enabled when available.  Support both camelCase (Fluent default) and kebab case.
  my $minimum-fraction-digits = %dev-args<minimum-fraction-digits> // %options<minimumFractionDigits> // %dev-args<minimumFractionDigits>;
  my $maximum-fraction-digits = %dev-args<maximum-fraction-digits> // %options<maximumFractionDigits> // %dev-args<maximumFractionDigits>;
  my $minimum-integer-digits  = %dev-args<minimum-integer-digits>  // %options<minimumIntegerDigits>  // %dev-args<minimumIntegerDigits>;
  my $minimum-significant-digits = %dev-args<minimum-significant-digits> // %options<minimumSignificantDigits> // %dev-args<minimumSignificantDigits>;
  my $maximum-significant-digits = %dev-args<maximum-significant-digits> // %options<maximumSignificantDigits> // %dev-args<maximumSignificantDigits>;
  #my %options;
  %options<minimum-fraction-digits>    = $minimum-fraction-digits    if $minimum-fraction-digits;
  %options<maximum-fraction-digits>    = $maximum-fraction-digits    if $maximum-fraction-digits;
  %options<minimum-integer-digits>     = $minimum-integer-digits     if $minimum-integer-digits;
  %options<minimum-significant-digits> = $minimum-significant-digits if $minimum-significant-digits;
  %options<maximum-significant-digits> = $maximum-significant-digits if $maximum-significant-digits;

  return get-number-formatter($language).($number);
  #return format-number($number, :$language, :symbols(get-numeric-symbols($language).symbols), :%pattern)
}

my &datetime = sub ($datetime, *%options) {
  return $datetime.Str;
}

add-function "NUMBER", &number;
add-function "DATETIME", &datetime;
