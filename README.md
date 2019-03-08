# WARNING

This module is in its very early stages and not yet very useful.  It does
not fail gracefully when variables aren't passed, and the two core functions,
NUMBER() and DATE() have not been implementing, pending an implementation of the
relevant parts CLDR/ICU into a separate Intl module.

# Example

A Perl 6 module that implements Mozilla's Project Fluent.

This is an implementation based on the design documents, but it is not actually
a port.  The idea is to provide both an interface and code that is
maintainable, usable, and Perl-y.

An example of the usability is the value returned when formatting a Message.

While it is technically a Str (and thus can be used anywhere a Str can be), the
Fluent format allows for secondary messages to be attached called attributes.
This owes to its origins as a framework for web translation where the attributes
could autopopulate various child elements and attributes.  In Perl 6, you can
access those attributes as if the result were a hash such that

    my $translation = localized: 'greeting';
    say $translation; # ↪︎ "Hello!"
    say $translation<foo>; # ↪︎ "some related text"
    say $translation<bar>; # ↪︎ "some other related text"

Variables are passed using named arguments:

    my $translationA = localized: 'greeting2', :who('Jane');
    say $translationA; # ↪︎ "Hello, Jane!"
    my $translationB = $localization.format('greeting2', :who('Jack'));
    say $translationB; # ↪︎ "Hello, Jack!"

# Formatting and organization

The file format is described on the [Project Fluent page](https://projectfluent.org).   
To use localization files, just provide the root path of the files which can
be in your resources folder or locally stored on a disk.  If you're writing a
module, structure it like this:

    lib/
    resources/
        localization/
            ast.ftl       
            en.ftl
            es-ES.ftl     ⬅︎ These two are bad design,
            es-MX.ftl     ⬅︎   see usage notes.
            zh-Hant.ftl    
            zh-Hans.ftl
    t/
    LICENSE
    META6.json
    README.md

To let fluent know where the files are, give it the base file path on top of
which it will add language codes (which may end in a `/` or not, but I find it
easiest to keep them all in a folder, but you may want them prefixed elsewise).

    Fluent.add-base-path: 'localization/', :resources;

The `:resources` adverb lets the module know to look in the `%*RESOURCES`
variable for the file.  If the file is on the hard drive, don't use it,
and just reference the file path as you would any other.  For example, in another
project where we've named files 'ui_en.ftl', 'ui_es-ES.ftl', etc, we might say:

    Fluent.add-base-path: 'data/l10n/ui_';

In later versions of this module, you will also have an additional option to
group the terms.  This may be useful if your script is handling several different
sites/services/etc at once, and each one may have different texts for the same
message id.  So, imagining I had an HTTP server and a website called Fruitopia
all about fruits, and another called Vegitania all about vegetables, with vastly
different sets of text, we could load (and access them) by using the `:domain`
argument:

    Fluent.add-base-path: $root ~ 'fruitopia/text/email/', :domain('fruit');
    Fluent.add-base-path: $root ~ 'fruitopia/text/ui/',    :domain('fruit');
    Fluent.add-base-path: $root ~ 'fruitopia/text/store/', :domain('veggie');
    Fluent.add-base-path: $root ~ 'fruitopia/text/ui/',    :domain('veggie');

With this set up, using `localized('sitename', 'fruit')` contained in the `ui/`
directory would return something like **Fruitopia** but by changing the domain
`veggie` we might get **Vegitania**.  But because Fruitopia doesn't have any
text for a store loaded, if we called `localized('buynow', 'fruit')`, the
text returned would be that defined by the fallback option.

To define the fallback text, you can use either a string or some combination of
strings and WhateverCode (`*`).  If you use WhateverCode, consider using two
Whatevers to better debug.  Using the previous example, here's the text that
would be returned based on different fall back text:

    Fluent.set-fallback: '[No Localization Present]';
    localized: 'buynow', 'fruit';
    # ↪︎ [No Localization Present]

    Fluent.set-fallback: '[MessageID:' ~ * ~ ']';
    localized: 'buynow', 'fruit';
    # ↪︎ [MessageID:buynow]

    Fluent.set-fallback: '[﹖ ' ~ * ~ ' ← ' ~ *.uc ']';
    localized: 'buynow', 'fruit';
    # ↪︎ [﹖ buynow ← FRUIT]

If you only use a single Whatever (or positional, if you pass a block using, e.g.
`$^a`), then be aware that the order will always be first the Message ID, second
the domain.  If the arity is greater than 2 then all other parameters will be
passed a blank string, although the third one *may* in the future also receive
a hash of variables being passed.

= Language Usage Notes

If the first thing you do with Fluent is pass a base file, Fluent won't do
much of anything with it.  Fluent also needs to know which languages you intend
to support.  Because the `resources` directory in modules is not able to be
queried for files available, I made the decision to have the programmer tell
Fluent which languages are available.  To enable a language, simply pass it or
various to the `add-language` (single) or `add-languages` (convenience, calls
`add-language` for each passed language) functions which takes *either* a
LanguageTag *or* a Str representing a valid BCP47 language tag.  For the
hypothetical module listed previously, we'd say:

    Fluent.add-languages: 'ast', 'en', 'es-ES', 'es-MX', 'zh-Hant', 'zh-Hans';

Once both languages and file paths have been loaded, only once there is a need
for a language's localization files to be read will the `.ftl` be loaded and
parsed.  However, if you want the files to be read into memory immediately,
you can use the `:!lazy` adverb:

    Fluent.add-language: 'en', :!lazy; # any base paths now or in the future
                                       # for English will be loaded immediately.

This option is best suited when precompilation is beneficial so that the FTL
files will be loaded at compilation.

To determine the best fit language, Fluent uses the match algorithm in the
`Intl::BCP47` module on a *per message/term* basis.  This means you can set a  
base English translation in the `en.ftl` file, and override specific terms or
messages in an `en-GB` or `en-NZ` file.  If the user prioritizes `en-NZ`, then
Fluent will first look there.  If the message is not there, then it will look
in `en`, failing that, it will look (if enabled) the project default language
and finally, failing all other options, provide the fall back text described
above.

Note that this means it is a *bad idea* to only include regional language tags
without a base one.  In the module example, there is a tag for `es-ES` and
`es-MX`.  For a user requesting `es-GT`, Fluent will not fine any Guatemalan
Spanish files, and so then will try `es`.  But it *also* won't find that!  At
that point, its only two options are to either choose randomly between
Peninsular or Mexican Spanish, or go to the next best choice (or the default
or, worst case, the fallback).
