unit module Fluent;
# see https://developer.mozilla.org/en-US/docs/Mozilla/Projects/L20n
use Fluent::Grammar;
use Fluent::Actions;
use Fluent::Classes;
use Intl::BCP47;
use Intl::UserLanguage;

my Hash %domains;
my %default-index; # when domains aren't contemplated

my @default-languages = user-languages; # Intl::UserLanguage

localized(
    Str $message,
    :$domain    = Nil,
    :$language  = Nil,
    :@languages = (),
    :$attribute = Nil,
    :%variables = Nil,
    *%slurp-vars --> Str) {

    # The %variables is for when someone has stored values or if they need to
    # use one of the reserved terms 'language', 'languages', 'attribute' or
    # 'variables'.
    %slurp-var{%variables.keys} = %variables.values if %variables;

    # If $language is defined it is folded into @languages as the top pick.
    # Defaults are used only if no languages are provided.
    @languages.prepend:($language,) if $language;
    @languages = @default-languages if @languages == 0;

    # Get the order that we should attempt finding localizations in.
    # TODO: include reduced language tags for long matches
    @language-test-order = filter-language-tags(@languages, @support-languages);


}

sub find-message($id, @languages, $domain, %variables) {
  # For those wanting to use domains, the correct index is grabbed, else
  # the default.
  my %index := $domain ?? %domains{$domain} !! %default-index;
  my $localization = 0;
  for @languages -> $language {
    next unless $localization = %index{$language.Str};
  }
  $localization.format($, %)
}

sub find-identifier($id, @languages, :%variables) {

}


my %data = ();

multi sub load-localization($language-any is copy, $file-any, :$lazy = False) {
  my $language;
  if $language-any ~~ LanguageTag {
    $language = $language-any;
  }else {
    try {
      $language = LanguageTag.new($language-any.Str)
    }
    die "Error loading localization: Could not create LanguageTag from '$language-any' of type ", $language-any.WHAT if $!;
  }

  my $file;
  if !$lazy || ($lazy && $file-any.WHAT.gist eq "(Resources)") {
#    try {
#      if $file-any ~~ Str {
#        $file = $file-any;
#      }elsif $file-any ~~ Resource {
#        $file = $file-any.slurp;
#      }else{
#        $file = $file-any.Str;
#      }
    }
    die "Error loading localization: Could not obtain data from '$file-any' of type ", $file-any.WHAT if $!;
    # do non lazy load style
#  } else {
    # do lazy load style
#  }
}

multi sub load-localization(LanguageTag $language, Str $file-data) { … }

sub messages (Str $text, Bool :$dump) is export {
  FTL.parse($text ~ "\n", :actions(FTLActions)).made;
}

sub files is export {
  %?RESOURCES;
}
