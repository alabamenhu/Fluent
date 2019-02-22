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
  method gist (::?CLASS:D:) {
    "⁽ᴹ⁾$.identifier: "
    ~ "[" ~ @.patterns.map(*.gist).join( ' ') ~ "] "
    ~ "\{", @.attributes.map(*.gist).join( ' ' ), "\} #", $.comment.gist;
  }

  method format (:$attribute = Nil) {
    my $primary = @.patterns.map(*.format(:$attribute)).join;
    my %secondary = gather {
      take ($_.identifier => $_.format(:$attribute)) for @.attributes;
    }
    return $primary;
    return StrHash($primary, %secondary);
  }
}

class Term is export {
  has $.identifier;
  has @.patterns;
  has @.attributes;
  has $.comment is rw = "" ;
  method gist (::?CLASS:D:) {
    "⁽ᵀ⁾$.identifier: "
    ~ "[" ~ @.patterns.map(*.gist).join( ' ') ~ "] "
    ~ "\{", @.attributes.map(*.gist).join( ' ' ), "\} #", $.comment.gist;
  }
}

class Attribute is export {
    has $.identifier;
    has @.pattern;
    has $.comment is rw = "" ;
    method gist (::?CLASS:D:) {
      "⁽ᴬ⁾$.identifier #", $.comment.gist;
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
  method gist (::?CLASS:D:) {
   '⁽ᵗˣᵗ⁾' ~ $.text.substr(0,max($.text.chars,8)) ~ '…'
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
  method gist (::?CLASS:D:) {
   '⁽ᵗˣᵗ⁾' ~ $.text.substr(0,max($.text.chars,8)) ~ '…'
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
  method gist (::?CLASS:D:) {
    '⁽ᶠ⁾' ~ $.identifier.lc;
  }
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
  method gist (::?CLASS:D:) {
    '⁽ˀ⁾' ~ $.identifier;
  }
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
  method gist (::?CLASS:D:) {
    "[mr:$.identifier]"
  }

  method argument-value {
    $*MESSAGES{:$.attribute}.format
  }
  method format {
    $*MESSAGES{:$.attribute}.format
  }
}

class TermReference is Placeable does Pattern does Argument {
  has $.identifier;
  has $.attribute;
  has @.arguments;
  method gist {
    "[tr:$.identifier]"
  }

  method argument-value {
    $*MESAGES{:$.attribute, :@.arguments}
  }
  method format {
    $*MESSAGES{:attribute, :@.arguments}
  }
}

class Comment is export {
  has $.type;
  has $.text is rw;

  method gist (::?CLASS:D:) {
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

class StringLiteral does Literal does Pattern {
  has Str $.text;
  method gist (::?CLASS:D:) { '“' ~ $.text ~ '”' }
  method format { return $.text }
}

class NumberLiteral does Literal does Pattern {
  has Cool $.plusminus = 1;
  has Str $.integer;
  has Str $.decimal;
  has Str $.text; # what it was derived from;
  has Num $.value;
  method new (:$sign, :$integer, :$decimal) {
    my $plusminus = $sign eq "-" ?? -1 !! 1;
    my $value = Num.new(($integer // '0') ~ ('.' ~ $decimal if $decimal ne '')) * $plusminus;
    my $text = $sign ~ $integer ~ ("." ~ $decimal if ?$decimal);
    self.bless(:$plusminus, :$integer, :$decimal, :$text, :$value);
  }
  method format { return $.text }
  method gist (::?CLASS:D:) { return ($.plusminus == 1 ?? '+' !! '-') ~ $.integer ~ '.' ~ $.decimal }
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
    for @.others -> $variant {
      return $variant.format if $variant.identifier.format eq $selector;
    }
    return $.default.format;
  }
}

class Localization is export {
  has Term %.terms;
  has Message %.messages;
  has Comment @comments;
  has $.id;


  method gist {
    say "ᴸ$.id";
  }

  method new(@entries) {
    say "Making new localization";
    my %messages = ();
    my %terms = ();
    for @entries -> $entry {
      given $entry {
        when Message { %messages{$entry.identifier} = $entry }
        when Term { %terms{$entry.identifier} = $entry }
        when Comment { @comments.push: $entry }
      }
    }
    state $id = 0;
    $id++;
    return self.bless(:%messages, :%terms, :$id);
  }

  method format(Str $messageID, :$attribute = Nil, *%variables --> Str) {
    say "Formatting message '$messageID' given variables ", %variables;
    my %*VARIABLES = %variables;
    return %.messages{$messageID}.format(:$attribute);
  }
}


class Junk is export {
  has Str $.text;
}
