use lib '../lib';
use Fluent;
use Intl::BCP47;

my $i-wanna-test-out = "variable-term-references";

given $i-wanna-test-out {

  when "variable-term-references" {
    add-localization-language("en"); # when doing direct loads, language
    add-localization-basepath("");   # in the root directory here

    say localized("handsome",   :animal<dog>);
    say localized("handsome",   :animal<cat>);
    say localized("cute",       :animal<dog>);
    say localized("cute",       :animal<cat>);
    say localized("stupidcute", :animal<dog>);
    say localized("stupidcute", :animal<cat>);

    #say localized("cute", :animal<mouse>);  # Currently terms must exist,
                                             # as a result this one bombs
                                             # with an error
    #say localized("cute");      # and this one (without the variable
                                 # either) bombs twice.
    # Error handling is next on my list of things to do
  }

}
