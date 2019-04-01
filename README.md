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

    my  $translation = localized('greeting');
    say $translation; # ↪︎ "Hello!"
    say $translation<foo>; # ↪︎ "some related text"
    say $translation<bar>; # ↪︎ "some other related text"

Variables are passed using named arguments:

    my $translationA = localized('greeting2', :who('Jane'));
    say $translationA; # ↪︎ "Hello, Jane!"
    my $translationB = localized('greeting2', :who('Jack'));
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

To let Fluent know where the files are, give it the base file path onto
which it will add language codes (which may end in a `/` or not, but I find it
easiest to keep them all in a folder, but you may want them prefixed elsewise).

    add-localization-basepath('localization/', :resources);

The `:resources` adverb lets the module know to look in the `%*RESOURCES`
variable for the file.  If the file is on the hard drive, don't use it,
and just reference the file path as you would any other.  For example, in another
project where we've named files 'ui_en.ftl', 'ui_es-ES.ftl', etc, we might say:

    add-localization-basepath('data/l10n/ui_');

You also have an additional option to group the terms into various *domains*.
This may be useful if you plan to handle several different
sites/services/etc at once, and each one may have different texts for the same
message id.  So, imagining I had an HTTP server and a website called Fruitopia
all about fruits, and another called Vegitania all about vegetables, with vastly
different sets of text, we could load (and access them) by using the `:domain`
argument:

    add-localization-basepath($root ~ 'fruitopia/text/email/', :domain('fruit') );
    add-localization-basepath($root ~ 'fruitopia/text/ui/',    :domain('fruit') );
    add-localization-basepath($root ~ 'fruitopia/text/store/', :domain('veggie'));
    add-localization-basepath($root ~ 'fruitopia/text/ui/',    :domain('veggie'));

With this set up, using `localized('sitename', :domain('fruit'))` contained in the `ui/`
directory would return something like **Fruitopia** but by changing the domain
`veggie` we might get **Vegitania**.  But because Fruitopia doesn't have any
text for a store loaded, if we called `localized('buynow', :domain('fruit'))`,
the text returned would be that defined by the fallback option.

To define the fallback text, you can use either a string or some combination of
strings and WhateverCode (`*`).  If you use WhateverCode, consider using two
Whatevers to better debug.  Using the previous example, here's the text that
would be returned based on different fall back text:

    Fluent.set-fallback: '[No Localization Present]';
    localized('buynow', :domain('fruit'));
    # ↪︎ [No Localization Present]

    Fluent.set-fallback: '[MessageID:' ~ * ~ ']';
    localized('buynow', :domain('fruit'));
    # ↪︎ [MessageID:buynow]

    Fluent.set-fallback: '[﹖ ' ~ * ~ ' ← ' ~ *.uc ']';
    localized('buynow', :domain('fruit'));
    # ↪︎ [﹖ buynow ← FRUIT]

If you only use a single Whatever (or positional, if you pass a block using, e.g.
`$^a`), then be aware that the order is first the Message ID, second the domain
(which is '' if no domain is specified).  If the arity is greater than 2 then
all other parameters will be passed a blank string, although the third one *may*
in the future also receive a hash of variables being passed.

# Other options

If you want to exert more manual control over the loading of data, you can
use the `load-localization` sub.  This method takes a string in FTL format,
a language tag, and an optional domain as arguments:

    load-localization("hello = Hello World!", "en");
    localized('hello');
    # ↪︎ Hello World!

To specify the language that you want to pull the resource from, you can pass
a language tag or tags using the adverbs :language and :languages respectively
which will then override the user's default languages (as determined by the
`Intl::BCP47` module).

# Language Usage Notes

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

    Fluent.add-basepath: 'foo/', :!lazy; # FTL files for all enabled languages
                                         # will be loaded immediately, and will
                                         # load immediately for any languages
                                         # added in the future

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
`es-MX`.  For a user requesting `es-GT`, Fluent will not find any Guatemalan
Spanish files, and so then will try `es`.  But it *also* won't find that!  At
that point, it will just go to the next best choice (or the default or, worst
case, the fallback).  This is a result of the RFC4647 lookup method that BCP47
implements.  

# Version history
  - 0.6.1
    - Fixed a bug in inline block text
    - Fixed major bugs in variable references and term references
    - Added an experimental feature Variable Term References which is not currently part of the standard to demonstrate proof of concept
  - 0.6
    - First reasonably usable version (missing NUMBER/DATE functions)
    - Localization file structure added
    - Messages/Terms are now tested based on `Intl::BCP47`'s lookup.
    - API should be mostly frozen at this point.
  - 0.5
    - First semi working version
