unit module Fluent;
# see https://developer.mozilla.org/en-US/docs/Mozilla/Projects/L20n
use Fluent::Grammar;
use Fluent::Actions;
use Fluent::Classes;
use Intl::BCP47;

sub localized (Str $text, Bool :$dump) is export {
  say FTL.parse($text ~ "\n") if $dump;
  return FTL.parse($text ~ "\n", :actions(FTLActions)).made;
}
