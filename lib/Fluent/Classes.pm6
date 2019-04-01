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
  multi method gist (::?CLASS:U:) { "[Ƒ›Message]"        }
  multi method gist (::?CLASS:D:) { "[Ƒ›Msg:$.identifier]" }

  method format (:$attribute = Nil, :%variables) {
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
  multi method gist (::?CLASS:U:) { "[Ƒ›Term]"          }
  multi method gist (::?CLASS:D:) { "[Ƒ›Term:$.identifier" }
  method format (:$attribute = Nil, :%variables = ()) {
    my $primary = @.patterns.map(*.format(:$attribute, :%variables)).join;
    my %secondary = gather {
      take ($_.identifier => $_.format(:$attribute, :%variables)) for @.attributes;
    }
    #return $primary;
    return StrHash($primary, %secondary);
  }
}

class Attribute is export {
    has $.identifier;
    has @.pattern;
    has $.comment is rw = "" ;
    multi method gist (::?CLASS:U:) { "[Ƒ›Attribute]"         }
    multi method gist (::?CLASS:D:) { "[Ƒ›Attr:$.identifier]" }
    method format (:$attribute) {
      @.pattern.map(*.format(:$attribute)).join;
    }
}

role Pattern {
  method format() { ... }
}
role Argument { ;
#  method argument-value() { ... }
}


class BlockText does Pattern does Argument {
  has Str $.text is rw;
  multi method gist (::?CLASS:U:) { '[Ƒ›BlockText]'                        }
  multi method gist (::?CLASS:D:) { '[Ƒ›BTxt:' ~ $.text.substr(0,7) ~ '…]' }
  method format (:$attribute = "", :%variables = ()) {
    $.text;
  }
  method merge ($it) {
    $.text ~= "\n" ~ $it.text;
  }
}
class InlineText does Pattern does Argument {
  has Str $.text is rw;
  multi method gist (::?CLASS:U:) { '[Ƒ›InlineText]'                       }
  multi method gist (::?CLASS:D:) { '[Ƒ›ITxt:' ~ $.text.substr(0,7) ~ '…]' }
  method format (:$attribute, :@arguments) {
    $.text;
  }
  multi method merge (InlineText $it) { $.text ~=        $it.text; }
  multi method merge (BlockText  $it) { $.text ~= "\n" ~ $it.text; }
}

  # placeable ---> select expression
  # placeable -+-> reference expression
  #            +-> placeable
# probably not needed any tbh
class Placeable does Pattern {
  has $.type = 1; # select or inline
  method format() { ... }
}


# not done
class FunctionReference is Placeable does Pattern does Argument {
  has $.identifier;
  has @.arguments;
  multi method gist (::?CLASS:U:) { '[Ƒ›FunctionReference]'              }
  multi method gist (::?CLASS:D:) { '[Ƒ›FuncRef:' ~ $.identifier.lc ~ ']'}
  method format() {
    if $.identifier eq "DATE" {
      return '[date]';
    }elsif $.identifier eq "NUMBER" {
      return '[number]';
    }
  }
}

class VariableReference is Placeable does Pattern does Argument {
  has $.identifier;
  multi method gist (::?CLASS:U:) { "[Ƒ›VariableReference]"   }
  multi method gist (::?CLASS:D:) { "[Ƒ›VarRef:$.identifier]" }
  method format (:$attribute = "", :%variables) {
    try { return %variables{$.identifier}}
    '$' ~ $.identifier
  }
}

# deprecated because Messages shouldn't be referenced from other messages anymore
class MessageReference is Placeable does Pattern does Argument {
  has $.identifier;
  has $.attribute;
  multi method gist (::?CLASS:D:) { "[Ƒ›MessageReference"     }
  multi method gist (::?CLASS:D:) { "[Ƒ›MsgRef:$.identifier]" }
  method format {
    $*MANAGER.find-message($.identifier).format(:$.attribute)
    # $*MESSAGES{:$.attribute}.format
  }
}

class TermReference is Placeable does Pattern does Argument {
  has $.identifier;
  has $.attribute;
  has @.arguments;
  multi method gist (::?CLASS:U:) { "[Ƒ›TermReference]"        }
  multi method gist (::?CLASS:D:) { "[Ƒ›TermRef:$.identifier]" }
  method format (:$attribute, :%variables) {
    my %new-vars;
    for @.arguments {
      %new-vars{$_.identifier} = $_.value.format(:$attribute, :%variables);
    }
    $*MANAGER.find-term($.identifier).format(:$.attribute, :variables(%new-vars))
  }
}

# This is a test class to go with a proposed feature on github
# at https://github.com/projectfluent/fluent/issues/80
class VariableTermReference is Placeable does Pattern does Argument {
  has $.identifier;
  has $.attribute;
  has @.arguments;
  multi method gist (::?CLASS:U:) { "[Ƒ›VariableTermReference]"   }
  multi method gist (::?CLASS:D:) { "[Ƒ›VarTermRef:$.identifier]" }
  method format (:$attribute, :%variables) {
    my %new-vars = ();
    %new-vars{$_.identifier} = $_.value.format(:$attribute, :%variables) for @.arguments;
    $*MANAGER
      .find-term(%*VARIABLES{$.identifier})
      .format(:$.attribute, :variables(%new-vars))
  }
}
class Comment is export {
  has $.type;
  has $.text is rw;

  multi method gist (::?CLASS:U:) { '[Ƒ›Comment]' }
  multi method gist (::?CLASS:D:) {
    '[Ƒ›'
    ~ do given $.type {
      when 1 { "¹" }
      when 2 { "²" }
      when 3 { "³" }
    } ~ ':' ~ $.text.substr(0,7) ~ '…]'
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
  multi method gist (::?CLASS:D:) { "[Ƒ›ID:$.text]" }
  multi method gist (::?CLASS:U:) { '[Ƒ›Identifier]' }
  method Str { $.text }
  method format { $.text }
}


class StringLiteral does Literal does Pattern {
  has Str $.text;
  multi method gist (::?CLASS:D:) { '[Ƒ›StrLit:' ~ $.text ~ '”' }
  multi method gist (::?CLASS:U:) { '[Ƒ›StringLiteral]' }
  method format { return $.text }
}


class NumberLiteral does Literal does Pattern {
  has Cool $.plusminus = 1;
  has Str $.integer;
  has Str $.decimal;
  has Str $.text; # what it was derived from;
  has Num $.value;

  multi method gist (::?CLASS:U:) { '[Ƒ›NumberLiteral' }
  multi method gist (::?CLASS:D:) { return '[Ƒ›NumLit:' ~ ($.plusminus == 1 ?? '+' !! '-') ~ $.integer ~ '.' ~ $.decimal ~ ']' }

  # Probably 90% of this is garbage and needs to be cleaned up.
  # The number literal is effectively matched as a string
  method new (:$sign, :$integer, :$decimal) {
    my $plusminus = $sign eq "-" ?? -1 !! 1;
    my $value = Num.new(($integer // '0') ~ ('.' ~ $decimal if $decimal ne '')) * $plusminus;
    my $text = $sign ~ $integer ~ ("." ~ $decimal if ?$decimal);
    self.bless(:$plusminus, :$integer, :$decimal, :$text, :$value);
  }
  method format { return $.value.Str }
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
    return $.value.format;
  }
  method gist (::?CLASS:D:) {
     '[[' ~ $.identifier ~ ":" ~ $.value.gist ~ ']]'
  }
}

class Variant {
  has Bool $.default;
  has $.identifier;
  has @.patterns;
  multi method gist (::?CLASS:U:) { '[Ƒ›Variant]'           }
  multi method gist (::?CLASS:D:) { '[Ƒ›Vrnt:$.identifier]' }
  method format (:$attribute) {
    @.patterns.map(*.format(:$attribute)).join;
  }
}

class Select is Placeable does Pattern  {
  has $.selector;
  has $.default;
  has @.others;

  multi method gist (::?CLASS:U:) {  '[Ƒ›Select]'                           }
  multi method gist (::?CLASS:D:) {  '[Ƒ›Sel:' ~ (@.others.elems + 1) ~ ']' }
  method format (:$attribute = "", :%variables = ()) { ## todo check string vs number
    my $selector = $.selector.format(:$attribute, :%variables);
    # [Attempt 1] Check the exact string from the selector
    for @.others -> $variant {
      return $variant.format if $variant.identifier.format eq $selector;
    }
    # [Attempt 2] Check for the number category if it's possible.
    # The language needs to be modified slightly, so that it can know which
    # language the term/message was loaded in. TODO
    if $selector = cldr-number-type($selector, @*LANGUAGES.head) {
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
