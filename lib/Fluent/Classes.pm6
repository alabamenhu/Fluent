use Fluent::Number;
use Intl::BCP47;

sub StrHash ($s, %h --> Str)  {
  $s but (
    %h,
    role {
      method AT-KEY(|c) { self.Hash.AT-KEY(|c)}
      method EXISTS(|c) { self.Hash.EXISTS(|c)}
    }
  );
}

# role HasLocal { has %!h handles <AT-KEY EXISTS-KEY keys>; }; my $s = "Hello" but HasLocal;

class Message is export {
  has $.identifier;
  has @.patterns;
  has @.attributes;
  has $.comment is rw = "" ;
  multi method gist (::?CLASS:U:) { "⁽ᴹ⁾" }
  multi method gist (::?CLASS:D:) {
    "⁽ᴹ⁾$.identifier: "
    ~ "[" ~ @.patterns.map(*.gist).join( ' ') ~ "] "
    ~ "\{", @.attributes.map(*.gist).join( ' ' ), "\} #", $.comment.gist;
  }

  method format (:$attribute = Nil) {
    my $primary = @.patterns.map(*.format(:$attribute)).join;
    my %secondary = gather {
      take ($_.identifier => $_.format(:$attribute)) for @.attributes;
    }
    #return $primary;
    return StrHash($primary, %secondary);
  }
}

class Term is export {
  has $.identifier;
  has @.patterns;
  has @.attributes;
  has $.comment is rw = "" ;
  multi method gist (::?CLASS:U:) { "⁽ᵀ⁾" }
  multi method gist (::?CLASS:D:) {
    "⁽ᵀ⁾$.identifier: "
    ~ "[" ~ @.patterns.map(*.gist).join( ' ') ~ "] "
    ~ "\{", @.attributes.map(*.gist).join( ' ' ), "\} #", $.comment.gist;
  }
}

class Attribute is export {
    has $.identifier;
    has @.pattern;
    has $.comment is rw = "" ;
    multi method gist (::?CLASS:D:) {
      "⁽ᴬ⁾$.identifier #", $.comment.gist;
    }
    multi method gist (::?CLASS:U:) {
      "⁽ᴬ⁾"
    }
    method format (:$attribute) {
      @.pattern.map(*.format(:$attribute)).join;
    }
}

role Pattern {
  method format() { ... }
}
role Argument {
  method argument-value() { ... }
}

class InlineText does Pattern does Argument {
  has Str $.text is rw;
  multi method gist (::?CLASS:D:) {
   '⁽ᵗˣᵗ⁾' ~ $.text.substr(0,max($.text.chars,8)) ~ '…'
  }
  multi method gist (::?CLASS:U:) {
   '⁽ᵗˣᵗ⁾'
  }
  method format (:$attribute, :@arguments) {
    $.text;
  }
  method argument-value() {
    $.text;
  }
  method merge ($it) {
    $.text ~= $it.text;
  }
}

class BlockText does Pattern does Argument {
  has Str $.text is rw;
  multi method gist (::?CLASS:U:) { '⁽ᵗˣᵗ⁾' }
  multi method gist (::?CLASS:D:) { '⁽ᵗˣᵗ⁾'
    ~ $.text.substr(0,max($.text.chars,8)) ~ '…'
  }
  method format () {
    $.text;
  }
  method argument-value () {
    $.text;
  }
  method merge ($it) {
    $.text ~= $it.text;
  }
}

  # placeable ---> select expression
  # placeable -+-> reference expression
  #            +-> placeable

class Placeable does Pattern {
  has $.type = 1; # select or inline
  method format() { ... }
}


# not done
class FunctionReference is Placeable does Pattern does Argument {
  has $.identifier;
  has @.arguments;
  multi method gist (::?CLASS:U:) { '⁽ᶠ⁾'                   }
  multi method gist (::?CLASS:D:) { '⁽ᶠ⁾' ~ $.identifier.lc }
  method format() {
    if $.identifier eq "DATE" {
      return '[date]';
    }elsif $.identifier eq "NUMBER" {
      return '[number]';
    }
  }
  method argument-value {
    return 0; # TODO
  }
}

class VariableReference is Placeable does Pattern does Argument {
  has $.identifier;
  multi method gist (::?CLASS:U:) { '⁽ˀ⁾'                }
  multi method gist (::?CLASS:D:) { '⁽ˀ⁾' ~ $.identifier }
  method argument-value {
    try { return $*VARIABLES{$.identifier}}
    '〖' ~ $.identifier ~ '〗'
  }
  method format {
    try { return %*VARIABLES{$.identifier}}
    '〖' ~ $.identifier ~ '〗'
  }
}

class MessageReference is Placeable does Pattern does Argument {
  has $.identifier;
  has $.attribute;
  multi method gist (::?CLASS:D:) { "[F|mr]"              }
  multi method gist (::?CLASS:D:) { "[F|mr:$.identifier]" }
  method argument-value {
    $*MESSAGES{:$.attribute}.format
  }
  method format {
    $*MANAGER.find-message($.identifier).format(:$.attribute)
    # $*MESSAGES{:$.attribute}.format
  }
}

class TermReference is Placeable does Pattern does Argument {
  has $.identifier;
  has $.attribute;
  has @.arguments;
  multi method gist (::?CLASS:U:) { "[F|tr]"              }
  multi method gist (::?CLASS:D:) { "[F|tr:$.identifier]" }
  method argument-value {
    $*MESAGES{:$.attribute, :@.arguments} # todo redo
  }
  method format {
    $*MANAGER.find-term($.identifier).format(:$.attribute)
  }
}

class Comment is export {
  has $.type;
  has $.text is rw;

  multi method gist (::?CLASS:U:) { '⁽ᶜ⁾' }
  multi method gist (::?CLASS:D:) {
    '⁽ᶜ'
    ~ do given $.type {
      when 1 { "¹" }
      when 2 { "²" }
      when 3 { "³" }
    } ~ '⁾' ~ $.text.substr(0,8) ~ '…'
  }

  method kind {
    return do given $.type {
      when 1 { "Simple"}
      when 2 { "Group"}
      when 3 { "File"}
    }
  }

  method merge (Comment $c) {
    die unless $c.type == $.type;
    $.text ~= $c.text;
  }
}


role Literal {
  method format { ... } # there is a guarantee that no recursion is possible
}

class Identifier does Literal does Pattern {
  has Str $.text;
  multi method gist (::?CLASS:D:) { '$id:' ~ $.text ~ ':' }
  multi method gist (::?CLASS:U:) { '$id;' }
  method Str { $.text }
  method format { $.text }
}


class StringLiteral does Literal does Pattern {
  has Str $.text;
  multi method gist (::?CLASS:D:) { '“' ~ $.text ~ '”' }
  multi method gist (::?CLASS:U:) { '“StrLit”' }
  method format { return $.text }
}


class NumberLiteral does Literal does Pattern {
  has Cool $.plusminus = 1;
  has Str $.integer;
  has Str $.decimal;
  has Str $.text; # what it was derived from;
  has Num $.value;
  # Probably 90% of this is garbage and needs to be cleaned up.
  # The number literal is effectively matched as a string
  #
  method new (:$sign, :$integer, :$decimal) {
    my $plusminus = $sign eq "-" ?? -1 !! 1;
    my $value = Num.new(($integer // '0') ~ ('.' ~ $decimal if $decimal ne '')) * $plusminus;
    my $text = $sign ~ $integer ~ ("." ~ $decimal if ?$decimal);
    self.bless(:$plusminus, :$integer, :$decimal, :$text, :$value);
  }
  method format { return $.value.Str }
  multi method gist (::?CLASS:D:) { return ($.plusminus == 1 ?? '+' !! '-') ~ $.integer ~ '.' ~ $.decimal }
  multi method gist (::?CLASS:U:) { 'NumLit' }
}


class PositionalArgument does Argument {
  has Pattern $.argument;
  method argument-value {
    return $.argument.format;
  }
  method gist (::?CLASS:D:) {
    '[[' ~ $.argument.gist ~ ']]'
  }
}

class NamedArgument does Argument {
  has Str $.identifier;
  has Literal $.value;
  method argument-value {

  }
  method gist (::?CLASS:D:) {
     '[[' ~ $.identifier ~ ":" ~ $.value.gist ~ ']]'
  }
}

class Variant {
  has Bool $.default;
  has $.identifier;
  has @.patterns;
  method gist {
    '⁽ᵛ⁾' ~ $.identifier.gist
  }
  method format (:$attribute) {
    @.patterns.map(*.format(:$attribute)).join;
  }
}

class Select is Placeable does Pattern  {
  has $.selector;
  has $.default;
  has @.others;

  method gist (::?CLASS:D:) {
    '⁽ ⃗⁾[' ~ (@.others.elems + 1) ~ ']'
  }
  method format { ## todo check string vs number
    my $selector = $.selector.format;
    # [Attempt 1] Check the exact string from the selector
    for @.others -> $variant {
      return $variant.format if $variant.identifier.format eq $selector;
    }
    # [Attempt 2] Check for the number category if it's possible.
    if $selector = cldr-number-type($.selector.format, $*LANGUAGE) {
      for @.others -> $variant {
        return $variant.format if $variant.identifier eq $selector;
      }
    }
    # And finally, if everything fails, the default
    return $.default.format;
  }
}




class Junk is export {
  has Str $.text;
}
