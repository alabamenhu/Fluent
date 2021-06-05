unit module Fluent;
# see https://developer.mozilla.org/en-US/docs/Mozilla/Projects/L20n
#use Fluent::Grammar;
#use Fluent::Actions;
use Fluent::Classes;
use Intl::LanguageTag;
use Intl::UserLanguage;


class Domain {
  ####################
  # INTERNAL CLASSES #
  ####################
  # Container holds onto the messages and terms for a given language
  # BasePath
  class Container {
    has Message %.messages       = ();
    has Term    %.terms          = ();
    has         @.unloaded-files = ();

    proto method add ($) {*}
    multi method add (Message $message) { %.messages{$message.id} = $message }
    multi method add (Term    $term   ) { %.Terms\  {   $term.id} = $term    }

    # Immediately loads the FTL-formatted file into the container
    proto method load($){*}
    multi method load($file) {
      samewith $file.slurp if $file.IO.e;
      warn "Could not locate localization file at ", $file.absolute;
    }
    multi method load(Str $text) is default {
      use Fluent::Grammar;
      use Fluent::Actions;
      my @entries = FTL.parse($text ~ "\n", :actions(FTLActions)).made;
      for @entries -> $entry {
        given $entry {
          when Message { %.messages{$entry.identifier} = $entry }
          when Term { %.terms{$entry.identifier} = $entry }
          when Comment { @.comments.push: $entry }
        }
      }
    }
    method add-path ($path where IO::Path|Distribution::Resource, :$lazy = True) {
      $lazy
        ?? push @.unloaded-files, $path
        !! self.load($path.slurp);
    }
    # Both of these methods (message and term) also handle the lazy loading.
    # If the message/term isn't found, then each as-yet unloaded file is
    # sequentially loaded and processed, and the process is stopped as soon
    # as a message/term is found, leave the remaining ones undone.
    method message ($id) {
      return %.messages{$id} if %.messages{$id}:exists;
      while my $file = @.unloaded-files.shift {
        self.load($file.slurp);
        return %.messages{$id} if %.messages{$id}:exists;
      }
      Nil
    }
    method term($id) {
      return %.terms{$id} if %.terms{$id}:exists;
      while my $file = @.unloaded-files.shift {
        self.load($file.slurp);
        return %.terms{$id} if %.terms{$id}:exists;
      }
      Nil
    }
  }
  class BasePath {
    has Str  $.path     = '';
    has Bool $.resource = False;
    has Bool $.lazy     = True;
    method file (Str() $filename) {
      $!resource
        ??  %?RESOURCES{$!path ~ $filename}
        !! IO::Path.new($!path ~ $filename)
    }
  }

  has Str       $.id; # probably unnecessary
  has Container %.languages;
  has BasePath  @.base-paths;

  method message($id, @languages) {
    my @candidates = lookup-language-tags(%.languages.keys, @languages);
    for @candidates -> $candidate {
      next unless my $message = %.languages{$candidate}.message($id);
      return $message;
    }
    Nil
  }
  method term($id, @languages) {
    my @candidates = lookup-language-tags(%.languages.keys, @languages);
    for @candidates -> $candidate {
      next unless my $message = %.languages{$candidate}.term($id);
      return $message;
    }
    Nil
  }

  method load (Str $text, $language) {
    %.languages{$language} = Container.new unless %.languages{$language}:exists;
    %.languages{$language}.load($text);
  }

  method add-basepath (Str() $path, Bool :$resource = False, :$lazy = True) {
    # TODO check if paths are already loaded and warn
    # Pass the new basepath to all existing languages and store it for
    # languages that added later;
    my $basepath = BasePath.new(:$path, :$resource);
    %.languages{$_}.add-path($basepath.file($_ ~ '.ftl')) for %.languages.keys;
    push @.base-paths, $basepath;
  }
  method add-language (Str() $language-tag) {
    # TODO check if langauge is already made and warn
    # Create a container, and populate it with all existing base paths.
    my $language = Container.new;
    $language.add-path: $_.file($language-tag ~ '.ftl') for @.base-paths;
    %.languages{$language-tag} = $language;
  }

}

class LocalizationManager is export {
  use Intl::UserLanguage;

  has Domain %!domains;
  has Domain $!default-domain = Domain.new;

  has &!fallback-message = ( '[' ~ * ~ '|' ~ *.uc ~ ']' ); #[DOMAIN:message]
  has @.default-languages = user-languages(); # Intl::UserLanguage

  method localized(
      Str $message-id,
      :$domain    = Nil,
      :$language,
      :@languages is copy = () ,
      :$attribute = Nil,
      :%variables,
      *%slurp-vars --> Str) {

      # If $language is defined it is folded into @languages as the top pick.
      # Defaults are used only if no languages are provided.
      @languages.prepend: LanguageTag.new($language) if $language;
      @languages = @!default-languages if @languages == 0;

      # The %variables is for when someone has stored values or if they need to
      # use one of the reserved terms 'language', 'languages', 'attribute' or
      # 'variables', or if they just want to pass a stored list of variables
      %slurp-vars{%variables.keys} = %variables.values if %variables;
      my %*VARIABLES = %slurp-vars;
      my @*LANGUAGES = @languages;
      # Redirects find-message and find-term to this object
      my $*MANAGER = self;

      # Get the message and return fallback if no message (Nil) found
      if my $message = self.find-message($message-id, $domain, :@languages) {
        return $message.format(:$attribute, :variables(%slurp-vars))
      } else {
        self.fallback($message-id, $domain);
      }
  }

  method find-message(
    $id,
    $domain-id = Nil, #  ⬇︎ dyanmic variable allows for cleaner nesting
    :@languages = (@*LANGUAGES // @!default-languages)) {
    self.domain($domain-id).message: $id, @languages;
  }
  method find-term(
    $id,
    $domain-id = Nil, #  ⬇︎ dyanmic variable allows for cleaner nesting
    :@languages = (@*LANGUAGES // @!default-languages)) {
    self.domain($domain-id).term: $id, @languages;
  }

  method load(Str $text, $language-tag, $domain = "") {
    self.domain($domain).load($text, $language-tag);
  }
  method add-basepath(Str $path, :$resource = False, :$lazy = True, :$domain = "") {
    self.domain($domain).add-basepath($path, :$resource, :$lazy);
  }
  method add-basepaths(*@path where .map(*.isa: Str), :$resource = False, :$lazy = True, :$domain = "") {
    self.domain($domain).add-basepath($_, :$resource, :$lazy) for @path;
  }
  method add-language($language-tag where Str|LanguageTag, :$domain = "") {
    self.domain($domain).add-language($language-tag);
  }
  multi method add-languages(*@language-tags, :$domain = "") {
    self.add-language($_, :$domain) for @language-tags;
  }
  multi method add-languages(@language-tags, :$domain = "") {
    self.add-language($_, :$domain) for @language-tags;
  }

  method domain ($domain-id) {
    return $!default-domain      unless $domain-id;
    return %!domains{$domain-id} if %!domains{$domain-id}:exists;
    return %!domains{$domain-id} = Domain.new;
  }

  ####################
  # FALLBACK METHODS #
  ####################
  proto method set-fallback(|) {*}
  multi method set-fallback (&msg ) is default {&!fallback-message =  &msg  }
  multi method set-fallback (Str()    $msg ) {&!fallback-message = {$msg} }
  method reset-fallback { &!fallback-message = '[' ~ * ~ '|' ~ *.uc ~ ']' }
  method fallback ($msg-id is copy = Nil, $domain is copy = Nil) {
    # Fallback callables where {.arity > 2} are passed blank strings for the
    # rest of their arguments.  Those are currently reserved for future use.
    $msg-id = $msg-id // '';
    $domain = $domain // '';
    given &!fallback-message.arity {
      &!fallback-message(|($msg-id, $domain, |('' xx $_ -2))[0..^$_]);
    }
  }
}

# All of the subs in this module are effectively convenience methods to access
# a special LocalizationManager which allows for much easier handling of the
# get-message/term methods.  Advanced users can have multiple LM's, but for 99%
# of users, we make them blissfully aware that this class even exists.
my $default = LocalizationManager.new();

sub localized                   (|c) is export  { $default.localized:      |c }
sub load-localization           (|c) is export  { $default.load:           |c }
sub set-localization-fallback   (|c) is export  { $default.set-fallback:   |c }
sub reset-localization-fallback (|c) is export  { $default.reset-fallback: |c }
sub add-localization-basepath   (|c) is export  { $default.add-basepath:   |c }
sub add-localization-language   (|c) is export  { $default.add-language:   |c }
sub add-localization-languages  (|c) is export  { $default.add-languages:  |c }
sub ddd is export { $default }
#sub files is export {
#  %?RESOURCES;
#}

sub with-args(*@positional, *%named) is export {
  CodeArguments.new(:@positional, :%named)
}
