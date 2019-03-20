unit module Fluent;
# see https://developer.mozilla.org/en-US/docs/Mozilla/Projects/L20n
#use Fluent::Grammar;
#use Fluent::Actions;
use Fluent::Classes;
use Intl::BCP47;
use Intl::UserLanguage;


class Domain {
  class Container {
    has Message %.messages       = ();
    has Term    %.terms          = ();
    has         @.unloaded-files = ();

    proto method add ($) {*}
    multi method add (Message $message) { %.messages{$message.id} = $message }
    multi method add (Term    $term   ) { %.Terms\  {   $term.id} = $term    }

    method message ($id) { %.messages{$id} // Nil }
    method term    ($id) {    %.terms{$id} // Nil }

    method load(Str $text) {
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
  }
  has Str     $.id; # probably unnecessary
  has Container %languages;

  method message($id, @languages) {
    for @languages -> $language {
      next unless %languages{$language}:exists;
      next unless my $message = %languages{$language}.message($id);
      return $message;
    }
    Nil
  }

  method load (Str $text, $language) {
    %languages{$language} = Container.new unless %languages{$language}:exists;
    %languages{$language}.load($text);
  }

}

class LocalizationManager is export {
  use Intl::UserLanguage;

  has Domain %!domains;
  has Domain $!default-domain = Domain.new;

  has &!fallback-message = ( '[' ~ * ~ '|' ~ *.uc ~ ']' ); # [DOMAIN:message]
  has @default-languages = user-languages(); # Intl::UserLanguage

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
      @languages.prepend: $language if $language;
      @languages = @default-languages if @languages == 0;
      # Get the order that we should attempt finding localizations in.
      # TODO: include reduced language tags for long matches
      #my @language-test-order = filter-language-tags(@languages, @support-languages);

      # The %variables is for when someone has stored values or if they need to
      # use one of the reserved terms 'language', 'languages', 'attribute' or
      # 'variables', or if they just want to pass a stored list of variables
      %slurp-vars{%variables.keys} = %variables.values if %variables;
      my %*VARIABLES = %slurp-vars;

      # Redirects find-message and find-term to this object
      my $*MANAGER = self;

      # Get the message and return fallback if no message (Nil) found
      if my $message = self.find-message($message-id, $domain, :@languages) {
        return $message.format(:$attribute)
      } else {
        self.fallback($message-id, $domain);
      }
  }

  method find-message($id, $domain-id = Nil, :@languages = Nil) {
    my $domain;
    $domain = $domain-id ?? %!domains{$domain-id} !! $!default-domain;
    $domain.message: $id, @languages;
  }
  method find-term($id, $domain-id = Nil, :@languages = Nil) {
    my $domain;
    $domain = $domain-id ?? %!domains{$domain-id} !! $!default-domain;
    $domain.term: $id, @languages;
  }

  method load(Str $text, $language, $domain-id = Nil) {
    my $domain;
    if $domain-id ~~ Nil { # for some weird reason, ?$domain-id doesn't work
      $domain = $!default-domain;
    } else {
      %!domains{$domain-id} = Domain.new unless %!domains{$domain-id}:exists;
      $domain = %!domains{$domain-id};
    }
    $domain.load($text, $language);
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

#sub files is export {
#  %?RESOURCES;
#}
