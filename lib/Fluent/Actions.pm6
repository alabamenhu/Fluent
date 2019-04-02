unit class FTLActions;
use Fluent::Classes;

method TOP ($/) {
  my @entries = $<entry>.map(*.made);
  my @result = ();
  my $comment;

  while @entries {
    given @entries.head {
      when Comment {
        # Comments need to be merged if they are of the same type
        # and immediately follow each other
        if $comment {
          if $comment.type == @entries.head.type {
            merge $comment: @entries.shift;
          } else {
            # Not the same, so place the previously tracked comment into the
            # results, and place the new one on the stack;
            push @result: $comment;
            $comment = @entries.shift;
          }
        } else {
          # no previously stored one
          $comment = @entries.shift;
        }
      }
      default {
        if $comment {
          # If we tracked a comment, add it here iff type 1.  Otherwise it's
          # technically a stand alone and we can either ignore or add it to
          # the result pile (we do the latter for now). Eventually we may want
          # to all the comment objects, if we ever decide to add in line numbers,
          # etc for editing / debugging.
          $comment.type == 1
            ?? (@entries.head.comment = $comment.text)
            !!  push @result: $comment;
          $comment = Nil;
        }
        push @result: @entries.shift;
      }
    }
  }
  make @result;
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
  my @pre-patterns = $<pattern>.made;
  my @patterns =  @pre-patterns.shift;

  # this merge still isn't quite correct -- identations need to be correctly
  # taken into account and they aren't, but that logic is fairly complicated
  # and I'm not sure if it's best handled here or in Messages's creation method
  # Single pass processing is NOT possible.
  while my $foo =  @pre-patterns.shift {
    if $foo ~~ BlockText && @patterns.tail ~~ BlockText|InlineText {
      @patterns.tail.merge($foo)
    }else{
      push @patterns, $foo;
    }
  }
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

# This should formally be $<text-char>.map(*.Str).join) but since it's
# just raw text, we can pass the matched text as such
method pattern-element:sym<inline-text> ($/) {
  my $text = $/.Str;
  make InlineText.new(:$text);
}

method pattern-element:sym<block-text> ($/) {
  my $text   = $<indented-char>.Str; # guaranteed
     $text  ~= $<text-char>.Str if $<text-char>;
  my $indent = <blank-inline>.chars;
  make BlockText.new(:$text, :$indent);
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
  my $attribute = $<attribute-accessor> ?? $<attribute-accessor>.made !! "";
  make MessageReference.new(:$identifier, :$attribute);
}
method reference-expression:sym<term-reference> ($/){
  my $identifier = $<identifier>.Str;
  my $attribute = $<attribute-accessor> ?? $<attribute-accessor>.made !! "";
  my @arguments = $<call-arguments> ?? $<call-arguments>.made !! ();
  make TermReference.new(:$identifier, :$attribute, :@arguments);
}
# Experimental, for use as an example with the issue at
# https://github.com/projectfluent/fluent/issues/80
method reference-expression:sym<variable-term-reference> ($/){
  my $identifier = $<identifier>.Str;
  my $attribute = $<attribute-accessor> ?? $<attribute-accessor>.made !! "";
  my @arguments = $<call-arguments> ?? $<call-arguments>.made !! ();
  # possible bug, doing $<call-arguments>.made results in [(Any)], so passes the
  # definedor operator check, and thus  $<call-arguments>.made // () doesn't
  # work as expected
  make VariableTermReference.new(:$identifier, :$attribute, :@arguments);
}

method reference-expression:sym<variable-reference> ($/) {
  my $identifier = $<identifier>.Str;
  make VariableReference.new(:$identifier);
}

method attribute-accessor ($/){
  make $<identifier>.Str;
}
method call-arguments ($/) { make     $<argument-list>.made; }
method argument-list  ($/) { make   $<argument>.map: *.made; }
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
