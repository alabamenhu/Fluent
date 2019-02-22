# Example

A Perl 6 modulee that implements Mozilla's Project Fluent.

This is an implementation based on the design documents, but it is not actually
a port.  The idea is to provide both an interface and code that is
maintainable, usable, and Perl-y.

An example of the usability is the value returned when formatting a Message.

While it is technically a Str (and thus can be used anywhere a Str can be), the
Fluent format allows for secondary messages to be attached called attributes.
This owes to its origins as a framework for web translation where the attributes
could autopopulate various child elements and attributes.  In Perl 6, you can
access those attributes as if the result were a hash such that

    my $translation = $localization.format('greeting');
    say $translation; # --> "Hello!"
    say $translation<foo>; # --> "some related text"
    say $translation<bar>; # --> "some other related text"

Variables are passed using named arguments:

    my $translationA = $localization.format('greeting2', :who('Jane'));
    say $translationA; # --> "Hello, Jane!"
    my $translationB = $localization.format('greeting2', :who('Jack'));
    say $translationB; # --> "Hello, Jack!"
