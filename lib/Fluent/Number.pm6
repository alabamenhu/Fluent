unit module Number;
# This module is not very pretty.  There are lots of other ways to make it work.
# Feel free (no, seriously, that's a legitimate invitation) to make it cleaner
# and more sustainable.
#
# That said, don't make any assumptions on how to call things in here, because I
# I may decide to change it.
use Intl::BCP47;

my \zero  =  'zero';
my \one   =   'one';
my \two   =   'two';
my \few   =   'few';
my \many  =  'many';
my \other = 'other';


class NumExt {
  has $.original;
  has $.n; # absolute value
  has $.i; # integer digits of $.n
  has $.v; # count of visible fraction digits, with trailing zeros
  has $.w; # count of visible fraction digits, without trailing zeros
  has $.f; # visible fraction digits
  has $.t; # visible fractional digits without trailing zeros
  proto method new(|c) { * }
  multi method new(Numeric $original) {
    samewith $original.Str;
  }
  multi method new(Str $original) {
    $original ~~ /^
      ('-'?)         # negative marker [0]
      ('0'*)         # leading zeros [1]
      (<[0..9]>+)    # one or more integer values [2]
      [
        '.'          #   decimal pointer
        (<[0..9]>*?) #   any number of decimals [3]
        ('0'*)       #   with trailing zeros [4]
      ]?             # decimal is optional
    $/;
    return False unless $/; # equivalent of death
    my $n = $original.abs;
    my $i = $2.Str;
    my ($f, $t, $v, $w);
    if $3 { # the decimal matche
      $f = $3.Str ~ $4.Str;
      say $f;
      $t = $4.Str;
      $v = $f.chars;
      $w = $t.chars;
    } else { # no integer value
      ($f, $t, $v, $w) = 0 xx 4;
    }
    self.bless(:$original, :$n, :$i, :$f, :$t, :$v, :$w);
  }

}

sub i($x) {$x.abs.floor.Int.Str.chars}
sub n($x) {$x.abs}
sub v() { … } # visible decimal units (0.1 = 1; 0.120 = 3; 0.40000 = 5)
sub w() { … } # non-zero units (0.1 = 1, 0.120 = 2; 0.00400 = 3)
sub f() { … }
sub t() { … }

role Typifier {
  method languages { … };
  method cardinal (NumExt $number --> Str) { … }

#  method ordinal  (NumExt $number --> Str) { … }
#  method range    (NumExt $start, NumExt $end --> Str) { … }
}

class AllOther does Typifier {
  # This is the catch all class, basically defines every number as 'other'
  method languages {<bm  bo  dz  id  ig  ii   in  ja  jbo jv  jw  kde kea km  ko
                     lkt lo  ms  my  nqo root sah ses sg  th  to  vi  wo  yo
                     yue zh  >}
  method cardinal (NumExt $x            --> Str) { 'other' }
}

class OneOtherA does Typifier {
  method languages { <am as bn fa gu hi kn mr zu> }
  method cardinal (NumExt $x --> Str) {
    return 'one' if $x.i == 0 || $x.n == 1;
    'other'
  }
}

class OneOtherB does Typifier {
  method languages { <ff fr hy kab> };
  method cardinal (NumExt $x --> Str) {
    return one if $x.i == 0|1;
    other
  }
}

class OneOtherC does Typifier {
  method languages { <pt> };
  method cardinal (NumExt $x --> Str) {
    return one if $x.i == 0|1;
    other
  }
}

class OneOtherD does Typifier {
  method languages { <ast ca de en et fi fy gl ia io it ji nl pt_PT sc scn sv sw ur yi> };
  method cardinal (NumExt $x --> Str) {
    say "Called cardinal for ", $x.original, "  i=", $x.i;
    return one if $x.i == 1 && $x.v == 0;
    other
  }
}

class OneOtherE does Typifier {
  method languages { <si> };
  method cardinal (NumExt $x --> Str) {
    return one if $x.n == 1|0 || ($x.i == 0 && $x.f == 1);
    other
  }
}

class OneOtherF does Typifier {
  method languages { <ak bh guw ln mg nso pa ti wa> };
  method cardinal (NumExt $x --> Str) {
    return one if $x.n == 1|0;
    other
  }
}

class OneOtherG does Typifier {
  method languages { <tzm> };
  method cardinal (NumExt $x --> Str) {
    return one if $x.n == 1|0 || $.n ∈ 11..99;
    other
  }
}

class OneOtherH does Typifier {
  method languages { <af asa az bem bez bg brx ce cgg chr ckb dv ee el eo es eu
                      fo fur gsw ha haw hu jgo jmc ka kaj kcg kk kkj kl ks ksb
                      ku ky lb lg mas mgo ml mn nah nb nd ne nn nnh no nr ny nyn
                      om or os pap ps rm rof rwk saq sd sdh seh sn so sq ss ssy
                      st syr ta te teo tig tk tn tr ts ug uz ve vo vun wae xh
                      xog> };
  method cardinal (NumExt $x --> Str) {
    return one if $x.n == 1;
    other
  }
}

class OneOtherI does Typifier {
  method languages { <da> };
  method cardinal (NumExt $x --> Str) {
    return one if $x.n == 1 || ($x.t != 0 && $x.i == 0|1);
    other
  }
}

class OneOtherJ does Typifier {
  method languages { <is> };
  method cardinal (NumExt $x --> Str) {
    return one if ($x.t == 0 && $x.i mod 10 == 1 && $x.i mod 100 != 11) || ($x.t != 0);
    other
  }
}

class OneOtherK does Typifier {
  method languages { <mk> };
  method cardinal (NumExt $x --> Str) {
    return one if ($x.v == 0 && $x.i mod 10 == 1 && $x.i mod 100 != 11)
               || ($x.f mod 10 == 1 && $x.f mod 100 != 11);
    other
  }
}

class OneOtherL does Typifier {
  method languages { <fil tl> };
  method cardinal (NumExt $x --> Str) {
    return one if ($x.v == 0 && $x.i == 1|2|3)
               || ($x.v == 0 && $x.i mod 10 != 4|6|9)
               || ($x.v != 0 && $x.f mod 10 != 4|6|9);
    other
  }
}

class ZeroOneOtherA does Typifier {
  method languages { <lv prg> }
  method cardinal (NumExt $x --> Str) {
    return zero if ($x.n mod 10 == 0)
                || ($x.n mod 100 ∈ 11.19)
                || ($x.v == 2 && $x.f mod 100 ∈ 11..19);
    return one  if ($x.n mod 10 == 1 && $x.n mod 100 != 11)
                || ($x.v == 2 && $x.f mod 10 == 1 && $x.f mod 100 != 11)
                || ($x.v != 2 && $x.f mod 10 == 1);
    other
  }
}

class ZeroOneOtherB does Typifier {
  method languages { <lag> }
  method cardinal (NumExt $x --> Str) {
    return zero if $x.n == 0;
    return one  if $x.i == 0|1 && $x.n != 0;
    other
  }
}

class ZeroOneOtherC does Typifier {
  method languages { <ksh> }
  method cardinal (NumExt $x --> Str) {
    return zero if $x.n == 0;
    return one  if $x.n == 1;
    other
  }
}

class OneTwoOtherA does Typifier {
  method languages { <iu kw naq se sma smi smj smn sms> }
  method cardinal (NumExt $x --> Str) {
    return one if $x.n == 1;
    return two if $x.n == 2;
    other
  }
}


class OneFewOtherA does Typifier {
  method languages { <shi> }
  method cardinal (NumExt $x --> Str) {
    return one if $x.i == 0 || $x.n == 1;
    return few if $x.n ∈ 2..19;
    other
  }
}

class OneFewOtherB does Typifier {
  method languages { <mo ro> }
  method cardinal (NumExt $x --> Str) {
    return one if  $x.i == 0 && $x.v == 0;
    return few if ($x.v != 0)
               || ($x.n == 0)
               || ($x.n != 1 && $x.n mod 100 ∈ 11..19);
    other
  }
}

class OneFewOtherC does Typifier {
  method languages { <bs hr sh sr> }
  method cardinal (NumExt $x --> Str) {
    return one if ($x.v == 0 && $x.i mod 10 == 1 && $x.i mod 100 != 11)
               || ($x.f mod 10 == 1 && $x.f mod 100 != 11);
    return few if ($x.v == 0 && $x.i mod 10 == 2|3|4 && $x.i mod 100 != 12|13|14)
               || ($x.f mod 10 == 2|3|4 && $x.f mod 100 != 12|13|14);
    other
  }
}

class OneTwoFewOtherA does Typifier {
  method languages { <gd> }
  method cardinal (NumExt $x --> Str) {
    return one if $x.n == 1|11;
    return two if $x.n == 2|12;
    return few if $x.n ∈ 3..10 || $x.n ∈ 13..19;
    other
  }
}

class OneTwoFewOtherB does Typifier {
  method languages { <sl> }
  method cardinal (NumExt $x --> Str) {
    return one if  $x.v == 0 && $x.i mod 100 ==   1;
    return two if  $x.v == 0 && $x.i mod 100 ==   2;
    return few if ($x.v == 0 && $x.i mod 100 == 3|4)
               || ($x.v != 0);
    other
  }
}

class OneTwoFewOtherC does Typifier {
  method languages { <dsb hsb> }
  method cardinal (NumExt $x --> Str) {
    return one if ($x.v == 0 && $x.i mod 100 ==   1)
               || ($x.f mod 100 == 1);
    return two if ($x.v == 0 && $x.i mod 100 ==   2)
               || ($x.f mod 100 == 2);
    return few if ($x.v == 0 && $x.i mod 100 == 3|4)
               || ($x.f mod 100 == 3|4);
    other
  }
}

class OneTwoManyOtherA does Typifier {
  method languages { <he iw> }
  method cardinal (NumExt $x --> Str) {
    return one  if $x.i == 1 && $x.v == 0;
    return two  if $x.i == 2 && $x.v == 0;
    return many if $x.v == 0 && $x.n !∈ 0..10 && $x.n mod 10 == 0;
    other
  }
}

class OneFewManyOtherA does Typifier {
  method languages { <cs sk> }
  method cardinal (NumExt $x --> Str) {
    return one  if $x.i == 1     && $x.v == 0;
    return few  if $x.i == 2|3|4 && $x.v == 0;
    return many if $x.v != 0;
    other
  }
}

class OneFewManyOtherB does Typifier {
  method languages { <pl> }
  method cardinal (NumExt $x --> Str) {
    return one  if  $x.i == 1     && $x.v == 0;
    return few  if  $x.v == 0 && $x.i mod 10 == 2|3|4 && $x.i mod 100 != 12|13|14;
    return many if ($x.v == 0 && $x.i != 1 && $x.i mod 10 == 0|1)
                || ($x.v == 0 && $x.i mod 10 == 5|6|7|8|9)
                || ($x.v = 0 && $x.i mod 100 == 12|13|14);
    other
  }
}

class OneFewManyOtherC does Typifier {
  method languages { <be> }
  method cardinal (NumExt $x --> Str) {
    return one  if  $x.n mod 10  == 1 && $x.n mod 100 != 11;
    return few  if  $x.n mod 10  == 2|3|4 && $x.n mod 100 != 12|13|14;
    return many if ($x.n mod 10  == 0|5|6|7|8|9)
                || ($x.n mod 100 == 11|12|13|14);
    other
  }
}


class OneFewManyOtherD does Typifier {
  method languages { <lt> }
  method cardinal (NumExt $x --> Str) {
    return one  if $x.n mod 10  == 1    && $x.n mod 100 !∈ 11..19;
    return few  if $x.n mod 10  ∈  2..9 && $x.n mod 100 !∈ 11..19;
    return many if $x.f != 0;
    other
  }
}

class OneFewManyOtherE does Typifier {
  method languages { <mt> }
  method cardinal (NumExt $x --> Str) {
    return one  if $x.n == 1;
    return few  if $x.n == 0 || $x.n mod 100 ∈ 2..10;
    return many if $x.n mod 100 ∈ 11..19;
    other
  }
}

class OneFewManyOtherF does Typifier {
  method languages { <ru uk> }
  method cardinal (NumExt $x --> Str) {
    return one  if  $x.v == 0 && $x.i mod 10 == 1     && $x.i mod 100 != 11;
    return few  if  $x.v == 0 && $x.i mod 10 == 2|3|4 && $x.i mod 100 != 12|13|14;
    return many if ($x.v == 0 && $x.i mod 10  == 0|5|6|7|8|9)
                || ($x.v == 0 && $x.i mod 100 == 11|12|13|14);
    other
  }
}

class OneTwoFewManyOtherA does Typifier {
  method languages { <br> }
  method cardinal (NumExt $x --> Str) {
    return one  if $x.n mod 10 == 1     && $x.n mod 100 != 11|71|91;
    return two  if $x.n mod 10 == 2     && $x.n mod 100 != 12|72|92;
    return few  if $x.n mod 10 == 3|4|9 && $x.n mod 100 ∈ ((10..19) ∪ (70..79) ∪ (90..99));
    return many if $x.n        != 0     && $x.n mod 1_000_000 == 0;
    other
  }
}

class OneTwoFewManyOtherB does Typifier {
  method languages { <ga> }
  method cardinal (NumExt $x --> Str) {
    return one  if $x.n == 1;
    return two  if $x.n == 2;
    return few  if $x.n == 3|4|5|6;
    return many if $x.n == 7|8|9|10;
    other
  }
}

class OneTwoFewManyOtherC does Typifier {
  method languages { <gv> }
  method cardinal (NumExt $x --> Str) {
    return one  if $x.v == 0 && $x.i mod  10 == 1;
    return two  if $x.v == 0 && $x.i mod  10 == 2;
    return few  if $x.v == 0 && $x.i mod 100 == 0|20|40|60|80;
    return many if $x.v != 0;
    other
  }
}

class ZeroOneTwoFewManyOtherA does Typifier {
  method languages { <ar ars> }
  method cardinal (NumExt $x --> Str) {
    return zero if $x.n == 0;
    return one  if $x.n == 1;
    return two  if $x.n == 2;
    return few  if $x.n mod 100 ∈ 3..10;
    return many if $x.n mod 100 ∈ 11..99;
    other
  }
}

class ZeroOneTwoFewManyOtherB does Typifier {
  method languages { <cy> }
  method cardinal (NumExt $x --> Str) {
    return zero if $x.n == 0;
    return one  if $x.n == 1;
    return two  if $x.n == 2;
    return few  if $x.n == 3;
    return many if $x.n == 6;
    other
  }
}


my @classes =  AllOther,
               OneOtherA, OneOtherB, OneOtherC, OneOtherD, OneOtherE, OneOtherF,
               OneOtherG, OneOtherH, OneOtherI, OneOtherJ, OneOtherK, OneOtherL,
               ZeroOneOtherA, ZeroOneOtherB, ZeroOneOtherC,
               OneTwoOtherA,
               OneFewOtherA, OneFewOtherB, OneFewOtherC,
               OneTwoFewOtherA, OneTwoFewOtherB, OneTwoFewOtherC,
               OneTwoManyOtherA,
               OneFewManyOtherA, OneFewManyOtherB, OneFewManyOtherC,
               OneFewManyOtherD, OneFewManyOtherE, OneFewManyOtherF,
               OneTwoFewManyOtherA, OneTwoFewManyOtherB, OneTwoFewManyOtherC,
               ZeroOneTwoFewManyOtherA, ZeroOneTwoFewManyOtherB;

our %cardinal-number-typifier is export;
%cardinal-number-typifier = ();
for @classes -> $class {
  %cardinal-number-typifier{$_} = $class for $class.languages;
}

multi sub cldr-number-type($number, Str $lang) is export {samewith $number, LanguageTag.new($lang) }
multi sub cldr-number-type($number, LanguageTag $tag) is export {
  # more robust handling necessary, theoretically, as some languages (*cough
  # Portuguese cough*) have country codes also included.  Hard code it?
  if my $num = NumExt.new($number) {
    return %cardinal-number-typifier{$tag.language.code}.cardinal($num)
        if %cardinal-number-typifier{$tag.language.code}:exists;
    return other;
  }
  return False; # not a number
}
