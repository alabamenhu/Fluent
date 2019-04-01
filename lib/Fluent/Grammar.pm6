unit grammar FTL;

  token TOP { 
    [
      || <entry>
      || <blank-block>
      || <junk>
    ]+
  }

  # Entries are the main building blocks of Fluent.  They define translations
  # and contextual and semantic information about the translations. During the
  # AST construction, adjacent comment lines of the same comment type (defined
  # by the number #) are joined together.  Single-# comments directly preceding
  # Messages and Terms are attached to the Message or Term and are not
  # standalone Entries.
  token entry {
    || <message> <line-end>
    || <term> <line-end>
    || <comment-line>
  }
  token message {
    <identifier>
    <blank>?
    '='
    <blank>?
    [
      | <pattern> <attribute>*
      | <attribute>+
    ]
  }
  token term { # has full .t
    '-' <identifier> <blank>? '=' <blank>? <pattern> <attribute>*
  }

  # Adjacent comment lines of the same comment type are joined together during
  # the AST construction.  (Alternation used to match EBNF definition)
  token comment-line {
    ( '###' || '##' || '#' ) [ ' ' (<-[\n]>*) ]? <line-end>
  }

  # Junk represents unparsed content.
  # Junk is parsed line-by-line until a line is found which looks like it might
  # be a beginning of a new message, term, or comment.  Any whitespace following
  # a broken Entry is also considered part of junk.
  token junk {
    <junk-line>
    #[
      #<!before <[a..zA..Z\#\-]>>
      #<junk-line>
      <-[a..zA..Z\#\-\n]>*?
    #]+?
  }
  token junk-line {
    <-[\n]>*? \n
  }

  #Attributes of Messages and Terms
  token attribute {
    <line-end> <blank>? '.' <identifier> <blank-inline>?
    '=' <blank-inline>? <pattern>
  }

  # Patterns are values of Messages, Terms, Attributes, and Variants
  token pattern {
    <pattern-element>+
  }

  # TextElement and Placeable can occur inline or as block.
  # Text needs to be indented and start with a non special character.
  # Placeables can start at the beginning of a line or be indented.
  # Adjacent TextElements are joined in the AST creation.
  proto token pattern-element { * }
        token pattern-element:sym<inline-text> { <text-char>+ }
        token pattern-element:sym<block-text> {
          # the formal definition of block-text places <PE:inline-text> after
          # indented character but this allows us to avoid some object creation
          # since it's so basic
          <blank-block> <blank-inline> <indented-char> <text-char>*?
        }
        token pattern-element:sym<inline-placeable> {
          '{' <blank>?
          [ <select-expression> | <inline-expression> ]
          <blank>? '}'
        }
        token pattern-element:sym<block-placeable> {
          <blank-block>
          <blank-inline>?
          '{' <blank>?
            [ <select-expression> | <inline-expression> ]
          <blank>? '}'
        }

  # Rules for validating expressions in Placeables and as selectors of
  # SelectExpressions are documented in spec/valid.md and enforced in
  # syntax/abstract.mjs
  token inline-expression {
    | <string-literal>
    | <number-literal>
    | <reference-expression>
    | <pattern-element:sym<inline-placeable>> # ugly ………
  }

  # Literals
  token string-literal { '"' <quoted-char>* '"' }
  token number-literal { ('-'?) (<[0..9]>+) [ '.' (<[0..9]>+)]? }

  # Inline expressions
  proto token reference-expression {*}
        token reference-expression:sym<function-reference> {
          <identifier> <call-arguments>
        }
        token reference-expression:sym<message-reference> { # works
          <identifier> <attribute-accessor>?
        }
        token reference-expression:sym<term-reference> {
          '-' <identifier> <attribute-accessor>? <call-arguments>?
        }
        token reference-expression:sym<variable-reference> {
          '$' <identifier>
        }
        # Experimental - for use as an example with the issue at
        # https://github.com/projectfluent/fluent/issues/80
        token reference-expression:sym<variable-term-reference> {
          '-$' <identifier> <attribute-accessor>? <call-arguments>?
        }
  token attribute-accessor { '.' <identifier> }
  token call-arguments { <blank>? '(' <blank>? <argument-list> <blank>? ')' }
  token argument-list { <argument>*  % [ <blank>? ',' <blank>? ] }
  token argument { <inline-expression> | <named-argument> }
  token named-argument { # workrs
    <identifier> <blank>? ':' <blank>? [ (<string-literal>) | (<number-literal>) ]
  }

  # Block expressions
  token select-expression { # works
    <inline-expression>
    <blank>?
    '->'
    <blank-inline>?
    <variant-list>
  }
  token variant-list { # works, full .t
    <variant>* <default-variant> <variant>* <line-end>
  }
  token variant { # works, full .t
    <line-end> <blank>? <variant-key> <blank-inline>? <pattern>
  }
  token default-variant { # works, full .t
    <line-end> <blank>? '*' <variant-key> <blank-inline>? <pattern>
  }
  token variant-key { # works, full .t
    '[' <blank>? ( <number-literal> | <identifier> ) <blank>? ']'
  }

  # Identifier
  token identifier { <[a..zA..Z]> <[a..zA..Z0..9_\-]>* } # works, full .t

  # Content character
  #
  # Translation content can be written using any Unicode characters.  However,
  # some characters are considered special depending on the type of content
  # they're in.  See <text-char> and <quoted-char> for more information.
  #
  # Some Unicode characters, even if allowed, should be avoided in Fluent
  # resources.  See spec/recommendations.md
  token any-char {
    . # defined explicitly in EBNF as \x0 .. \x10fff
  }

  # Text elements
  #
  # The primary storage for content are text elements.  Text elements are not
  # delimited with quotes and may span multiple lines as long as all line are
  # idented. The opening brace ({) marks a start of aplaceable in the pattern
  # and may not be used in text elements verbatim.  Due to the indentation
  # requirement some text characters may not appear as the first character on
  # a new line.
  token special-text-char {
    || '{'
    || '}'
  }
  token text-char {
    <-[ \{ \} \n]> # anything that is not a new-line or the special-text-char
    # the special-text-char works in the EBNF syntax but not as well in perl6 grammar
  }
  token indented-char {
    <-[ \{ \} \n \[ * .]>
    # again, we use this syntax to match P6's regex, the EBNF defines it as
    # a text-char that is not [ * or .
  }

  # String literals
  #
  # For special-purpose content, quoted string literals can be used where text
  # elements are not a good fit. String literals are delimited with double
  # quotes and may not contain line breaks. String literals use the backslash
  # as the escape character.  The literal double quoted can be inserted via
  # the \" escape sequence. The literal backslash can be inserted with \\. The
  # literal opening brace ({) is allowed in string literals because they may not
  # comprise placeables.

  token special-quoted-char {
    | '"'
    | '\\'
  }
  proto token quoted-char {*}
        token quoted-char:sym<text> {
          (<-[\" \\ \n]>)                #" Comment to kill bad syntax highlight
        }
        token quoted-char:sym<special-escape> {
          "\\" <special-quoted-char>
        }
        token quoted-char:sym<unicode-escape> {
          | '\\u' (<[0..9a..fA..F]> ** 4)
          | '\\U' (
              [
                | '10'
                | '0' <[0..9a..fA..F]>
              ]
              <[0..9a..fA..F]> ** 4
            )
        }
  method quoted-char-error {
    my $message = "Error parsing quoted string in Fluent file: ";
    my $candie = True;
    given self.orig.substr(self.from) {
      when /^\\u/ {
        $message ~= "The unicode escape \\u must be followed by exactly four hexadecimal digits."
      }
      when /^\\U/ {
        $message ~= "The unicode escape \\U must be followed by exactly six hexadecimal digits."
      }
      when /^\n/ {
        $message ~= "New lines are not allowed here."
      }
      when "\\" {
        $message ~= "Encountered EOF after escape sequence";
      }
      default {
        $message ~= "Invalid escape sequence “\\" ~ $_.substr(1,1) ~ "”.";
        $candie = False;
      }
    }
    $message ~= "\n" ~ self.error-location-string(self.orig,self.from);
    die $message if $candie;
  }

  method error-location-string ($base, $location) {
    my $start = $location - 20 > 0 ?? $location - 20 !! 0;
    my $end = $location + 20 > $base.chars ?? $base.chars !! $location + 20;
    return "  "
      ~ $base.substr($start, $end - $start)
      ~ "\n  "
      ~ " " x ($location - $start)
      ~ "↑ (offset $location)";
  }

  # Whitespace
  token blank-inline {
    " "+
  }
  token line-end {
    # The standard allows for \r\n as well.  P6 considers \r, \n, and \r\n as
    # equivalent for the purpose of line matching in regexes using \n.  I s'pose
    # theoretically \r by itself isn't supposed to count, but 🤷🏼‍♂️
    \n
  }
  token blank-block {
    (<blank-inline>? <line-end>)+?
  }
  token blank {
    (<blank-inline> || <line-end>)+
  }
