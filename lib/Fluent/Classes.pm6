#use Fluent::Number;
use Intl::LanguageTag;
#use Intl::CLDR::Plurals;

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
    my $primary = @.patterns.map(*.format(:$attribute, :%variables)).join;
    my %secondary = gather {
      take ($_.identifier => $_.format(:$attribute,  :%variables)) for @.attributes;
    }
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
    if $attribute {
      # Need to get a specific attribute
      # These should probably be stored into a hash for quicker access in
      # the future, as their order doesn't matter
      for @!attributes {
        return .format(:attribute(Nil), :%variables)
            if .identifier eq $attribute;
      }
      return "-$!identifier" ~ ".$attribute"; # could not find it; the better
                                              # default might be the message?
    } else {
      # Return the main attribute.  Terms attributes are considered hidden from
      # code so we only need to return the primary pattern, and not any
      # attributes in a StrHash like is done with Messages.  If the standard
      # changes, then modify this section to match Messages' format
      return @.patterns.map(*.format(:$attribute, :%variables)).join;
    }
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
    $!text;
  }
  method merge ($it) {
    $!text ~= "\n" ~ $it.text;
  }
}
class InlineText does Pattern does Argument {
  has Str $.text is rw;
  multi method gist (::?CLASS:U:) { '[Ƒ›InlineText]'                       }
  multi method gist (::?CLASS:D:) { '[Ƒ›ITxt:' ~ $.text.substr(0,7) ~ '…]' }
  method format (:$attribute, :@arguments) {
    $!text;
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

class PositionalArgument does Argument {
  has Pattern $.argument;
  method argument-value(|c) {
    return $.argument.format(|c);
  }
  method gist (::?CLASS:D:) {
    '[Ƒ›PosArg:' ~ $.argument.gist ~ ']'
  }
}

class NamedArgument does Argument {
  has Str $.identifier;
  has $.value; # Literal Role?
  method argument-value {
    return $.value.format;
  }
  method gist (::?CLASS:D:) {
     '[Ƒ›NamedArg:' ~ $.identifier ~ ":" ~ $.value.gist ~ ']'
  }
}


# not done
class FunctionReference is Placeable does Pattern does Argument {
  has $.identifier;
  has @.arguments;
  multi method gist (::?CLASS:U:) { '[Ƒ›FunctionReference]'              }
  multi method gist (::?CLASS:D:) { '[Ƒ›FuncRef:' ~ $.identifier.lc ~ ']'}
  method format(|c) {
    use Fluent::Functions;

    my @positionals = @.arguments.grep(* ~~ PositionalArgument).map(*.argument-value(|c));
    my %named;
    @.arguments.grep(* ~~ NamedArgument).map({ %named{.identifier} = .argument-value(|c)});

    if $.identifier eq "DATE" {
      return '[date]';
    }elsif $.identifier eq "NUMBER" {
      return function('NUMBER').(|@positionals, |%named);
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
    $*MANAGER.find-term($.identifier).format(:$.attribute, :variables(%new-vars));
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
    note "\e[31mƑluent: Variable Term References are \e[1m\e[91mexperimental\e[0m\e[31m and not compatible with other systems.\e[39m" unless $++;
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
  has Numeric $.value;

  multi method gist (::?CLASS:U:) { '[Ƒ›NumberLiteral' }
  multi method gist (::?CLASS:D:) { return '[Ƒ›NumLit:' ~ ($.plusminus == 1 ?? '+' !! '-') ~ $.integer ~ '.' ~ $.decimal ~ ']' }

  # Probably 90% of this is garbage and needs to be cleaned up.
  # The number literal is effectively matched as a string
  method new (:$sign, :$integer, :$decimal) {
    my $plusminus = $sign eq "-" ?? -1 !! 1;
    my $value = ((($integer // '0') ~ ('.' ~ $decimal if $decimal ne '')) * $plusminus).Numeric;
    my $text = $sign ~ $integer ~ ("." ~ $decimal if ?$decimal);
    self.bless(:$plusminus, :$integer, :$decimal, :$text, :$value);
  }
  method format { return $.text }
}

class Variant {
  has Bool $.default;
  has $.identifier;
  has @.patterns;
  multi method gist (::?CLASS:U:) { '[Ƒ›Variant]'           }
  multi method gist (::?CLASS:D:) {
    '[Ƒ›' ~ ('Def' if $.default) ~ 'Vrnt:'
    ~ ($.identifier ~~ NumberLiteral ?? $.identifier.text !! $.identifier) ~ "]"
  }
  method format (:$attribute) {
    @.patterns.map(*.format(:$attribute)).join;
  }
}

class Select is Placeable does Pattern  {
  has $.selector;
  has $.default;
  has @.others; # this should be redone in a hash, binding the default to the hash TODO
  has %.variants;

  multi method gist (::?CLASS:U:) {  '[Ƒ›Select]'                           }
  multi method gist (::?CLASS:D:) {  '[Ƒ›Sel:' ~ (@.others.elems + 1) ~ ']' }
  method format (:$attribute = "", :%variables = ()) { ## todo check string vs number
    use Intl::CLDR::Plurals;
    my $selector = $.selector.format(:$attribute, :%variables);

    # Check first for exact match
    .format(:$attribute, :%variables).return with %.variants{$selector};

    if is-numeric $selector -> $number {
      # [1] Check if the number form exists
      #     (for example, input of +5.0 can match [5] in this block)
      # [2] Check for plural forms
      .format(:$attribute, :%variables).return with %.variants{$number};
      my $plural = plural-count($selector, @*LANGUAGES.head, :type<cardinal>);
      .format(:$attribute, :%variables).return with %.variants{$plural};
    }

    # When all else fails, default
    $.default.format(:$attribute, :%variables);
  }

  sub is-numeric ($x) {
    try {
      CATCH { return False }
      return $x.Numeric but True;
    }
  }
}

class CodeArguments {
  has @.positional;
  has %.named;
}


class Junk is export {
  has Str $.text;
}
