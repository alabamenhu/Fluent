unit class FTLActions;
use Fluent::Classes;

method TOP ($/) {
  my @entries = (); $<entry>.map(*.made);
  my $comment;
  my @block-collector = ();
  my $index = 0;
  while $index < $<entry>.elems {
    my $entry = $<entry>[$index].made;

    given $entry {
      ## comment special logic
      when Comment {
        my $comments while
          $<entry>[$index+ ++$comments].made      ~~ Comment
          && $<entry>[$index+$comments].made.type == $entry.type;

        $entry.merge($<entry>[$index+$_].made) for 1..^$comments;
        $index += $comments;

        if ($entry.type == 1
            && $<entry>[$index].?made
            && $<entry>[$index].made !~~ Comment
        ) { # attach to the next and add
          my $commented-entry = $<entry>[$index].made;
          $commented-entry.comment = $entry;
          push @entries, $commented-entry;
          $index++;
        } else { push @entries, $entry }
        next;
      }
      when BlockText {
          ;
      }

      default {
        if $comment {
          $entry.comment = $comment.text;
          $comment = Nil;
        }
        push @entries, $entry;
      }
    }

    $index++;
  }

  my $localization = Localization.new(@entries);
  make $localization;
}

method comment-line ($/) {
  my $type = $0.chars;
  my $text = $1 ?? $1.Str !! '';
  make Comment.new(:$type, :$text);
}
method junk ($/) { make Junk.new( :text($/.Str )) }
method identifier ($/) { make Identifier.new(:text($/.Str)) }


method quoted-char:sym<text>           ($/) { make $0.Str }
method quoted-char:sym<unicode-escape> ($/) { make :16($0.Str).chr }
method quoted-char:sym<special-escape> ($/) { make $<special-quoted-char>.Str }


method entry ($/) {
  my $entry = $<message>.made // $<term>.made // $<comment-line>.made;
  make $entry;
}
method message ($/) {
  my $identifier = $<identifier>.Str;
  my @patterns = $<pattern>.made;
  my @attributes = $<attribute>.map(*.made);
  make Message.new(:$identifier, :@patterns, :@attributes);
}
method term ($/) {
  my $identifier = $<identifier>.Str;
  my @patterns = $<pattern>.made;
  my @attributes = $<attribute>.map(*.made);
  make Term.new(:$identifier, :@patterns, :@attributes);
 }

method junk-line ($/ ) { make Junk.new()}
method attribute ($/) {
  my $identifier = $<identifier>.Str;
  my @pattern = $<pattern>.made;
  make Attribute.new(:$identifier, :@pattern);
}


method pattern ($/) {
  make $<pattern-element>.map(*.made);
}
method pattern-element:sym<inline-text> ($/) {
  make InlineText.new(:text($<text-char>.map(*.Str).join));
}
method pattern-element:sym<block-text> ($/) {
  my $text   = $<indented-char>.Str; # guaranteed
     $text  ~= $<inline-text>.made.txt if $<inline-text>; # optional
  my $indent = <blank-inline>.chars;
  make BlockText.new(:$text, :$indent);
}

method inline-text ($/) {
  #say 'inline-text'
  ;
}
method block-text ($/) {
  #say "Given the following block text: ";
  ;
}
method pattern-element:sym<inline-placeable> ($/) {
   make ($<select-expression> || $<inline-expression>).made;
 }
method pattern-element:sym<block-placeable>  ($/) {
  make ($<select-expression> || $<inline-expression>).made;
}
method inline-expression ($/) {
  make $<string-literal>.made
    // $<number-literal>.made
    // $<reference-expression>.made
    // $<pattern-element:sym<inline-placeable>>;
}

method string-literal ($/) {
  make StringLiteral.new(:text($<quoted-char>.map(*.made).join('')));
}
method number-literal ($/){
  my $sign = $0 ?? $0.Str !! "+";
  my $integer = $1.Str;
  my $decimal = $2 ?? $2.Str !! "";
  my $original = $/;
  make NumberLiteral.new(:$sign, :$integer, :$decimal, :$original);
}

# THERE ARE FOUR REFERENCE EXPRESSION TYPES
# 1: function, generally built in: abc()
# 2: message, only optional attributes: abc[.foo]
# 3: term, optional attributes or args: -abc[.foo][(bar)]
# 4: variable, very basic: $foo
method reference-expression:sym<function-reference> ($/){
  my $identifier = $<identifier>.Str;
  my @arguments = $<call-arguments>.made<>;
  make FunctionReference.new(:$identifier, :@arguments);
}
method reference-expression:sym<message-reference> ($/){
  my $identifier = $<identifier>;
  my $attribute = $<attribute-accessor>.made // Nil;
  make MessageReference.new(:$identifier, :$attribute);
}
method reference-expression:sym<term-reference> ($/){
  my $identifier = $<identifier>.Str;
  my $attribute = $<attribute-accessor>.made // Nil;
  my @arguments = $<call-arguments>.made // Nil;
  make TermReference.new(:$identifier, :$attribute, :@arguments);
}
method reference-expression:sym<variable-reference> ($/) {
  my $identifier = $<identifier>.Str;
  make VariableReference.new(:$identifier);
}

method attribute-accessor ($/){
  make $<identifier>.Str;
}
method call-arguments ($/) { make     $<argument-list>.made }
method argument-list  ($/) { make   $<argument>.map: *.made }
method argument       ($/) {
  if (?$<inline-expression>) {
    make PositionalArgument.new(:argument($<inline-expression>.made));
  } else {
    make $<named-argument>.made
  }
}
method named-argument ($/) {
  my $identifier = $<identifier>.Str;
  my $value = ($0<string-literal> // $0<number-literal>).made;
  make NamedArgument.new(:$identifier, :$value)
}
method select-expression ($/){
  my $selector = $<inline-expression>.made;
  my %variants = $<variant-list>.made;
  my @others = %variants<others><>;
  my $default = %variants<default>;
  make Select.new(:$selector, :$default, :@others);
}
method variant-list ($/){
  my @variants = $<variant>.map(*.made);
  my $default = $<default-variant>.made;
  make {others => @variants, default => $default};
}
method variant ($/) {
  my $identifier = $<variant-key>.made;
  my @patterns = $<pattern>.made;
  make Variant.new(:!default, :$identifier, :@patterns);
}
method default-variant ($/) {
  my $identifier = $<variant-key>.made;
  my @patterns = $<pattern>.made;
  make Variant.new(:default, :$identifier, :@patterns);
}
method variant-key ($/) {
  my $identifier;
  if $0<number-literal> {
    $identifier = $0<number-literal>.made;
  } else {
    $identifier = $0<identifier>.made;
  }
  make $identifier;
}
