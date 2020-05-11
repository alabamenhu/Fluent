# Introduction

A Perl 6 module that implements Mozilla's Project Fluent.  This is an
implementation based on the design documents, but it is not actually a port.
The idea is to provide both an interface and code that is maintainable, usable,
and Perl-y.

## Basic Usage

```perl6
    use Fluent;
    add-localization-basepath('localization');
    add-localization-languages('en', 'es');
    say localized('helloworld');   #   ↪︎ "Hello World!" (if system set to English)
    say localized 'helloworld';    #   ↪︎ "¡Hola mundo!" (if system set to Spanish)
```

If you store the result of a `localized` call, you’ll get a Hashy `Str`.  That
means you can use it like a `Str` (because it is one), but if the message
has attributes, you can access it via the normal associative ways:

```perl6
    my  $translation = localized 'greeting';
    say $translation;          #   ↪︎ "Hello!"
    say $translation<foo>;     #   ↪︎ "some related text"
    say $translation{'bar'};   #   ↪︎ "some other related text"
```

## Subroutines

When load the module, Fluent will export a handful of useful subroutines.  You
don't *have* to use them, but they implement an entire localization framework
that only under rare circumstances would you want or need to handle manually.   

  * **localized**(Str *$message-id*, Str *:$domain?*, *:$language?*, *:@languages?*, :*%variables?*, *%slurp-vars*) returns **Str**  
The function that you will use most often.  In common use, you will only need to
specify the `$message-id`, and maybe the `$domain` if your project uses them.
If you need to pass variables, you can use the
`%variables` named parameter, or alternative, specify the variables as
additional named parameters (using `%variables` is only required if the
name of the variable is one of the extant named parameters.  If you do not pass
any languages (which should be either `Str` or `LanguageTag`), the default
languages will be used.
  * **add-localization-basepath**(Str *$path*, Str *:$domain?*, Bool *:$resource* = False, Bool, *:$lazy* = True)
Adds the given path (directories need to end in `/`!) to the list of locations
where `.ftl` files can be found.  If used in a module, then pass the `:resource`
adverb to have it search in the module’s resource folder.  Lazy loading is
enabled by default.  Turning it off is mainly useful if you want to preparse
everything during a precompilation phase.
  * **add-localization-basepaths**(Str *@paths*, Str *:$domain?*, Bool *:$resource* = False, Bool, *:$lazy* = True)  
Same as previous, but acts on a list of basepaths.
  * **add-localization-language**(*$language-tag*, Str *:$domain?*)  
Adds the given language to the list of languages supported (this cannot be
automated because `%*RESOURCES` does not allow introspection of files).  If
any eager (non-lazy) basepaths were previously added, their associated `.ftl`
files will be loaded immediately.  The `$language-tag` may be either a `Str`
in valid BCP47 format or a `LanguageTag` (available in the `Intl::BCP47`
package)
  * **add-localization-language**(*@language-tags*, Str *:$domain?*)  
Same as previous, but acts on a list of language tags.  
  * **set-localization-fallback**(Callable *&fallback*)  
If a localization cannot be found, the callable is called with two positional
parameters: (1) the message ID and (2) the domain if applicable.  Fluent will
pass the correct number of parameters, so if you don't use domains, feel free
to just use a single `Whatever` to make your life easy.  You can also pass a
`Str` if you want a static message.  
  * **reset-localization-fallback**()  
Resets the fall back to the default.
  * **load-localization**(Str *$fluent-document*, *$language-tag*, Str *$domain?*)  
Loads the specified Fluent data (note: *not* a filename) for the given language
tag (as a BCP47 `Str` or a `LanguageTag`), optionally in the given domain.  Most
useful for testing, not as useful in actual production.
* **with-args**(*|c*)  
This function is mixes in the arguments into anything.  Its primary use is for
the `NUMBER` and `DATETIME` functions to pass complex formatting information
in an easy to read manner.

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

```perl6
    add-localization-basepath('localization/', :resource);
```

The `:resource` adverb lets the module know to look in the `%*RESOURCES`
variable for the file.  If the file is on the hard drive, don't use it,
and just reference the file path as you would any other.  For example, in another
project where we've named files 'ui_en.ftl', 'ui_es-ES.ftl', etc, we might say:

```perl6
    add-localization-basepath('data/l10n/ui_');
```

You also have an additional option to group the terms into various *domains*.
This may be useful if you plan to handle several different
sites/services/etc at once, and each one may have different texts for the same
message id.  So, imagining I had an HTTP server and a website called Fruitopia
all about fruits, and another called Vegitania all about vegetables, with vastly
different sets of text, we could load (and access them) by using the `:domain`
argument:

```perl6
    add-localization-basepath($root ~ 'fruitopia/text/email/', :domain('fruit') );
    add-localization-basepath($root ~ 'fruitopia/text/ui/',    :domain('fruit') );
    add-localization-basepath($root ~ 'fruitopia/text/store/', :domain('veggie'));
    add-localization-basepath($root ~ 'fruitopia/text/ui/',    :domain('veggie'));
```

With this set up, using `localized('sitename', :domain('fruit'))` contained in the `ui/`
directory would return something like **Fruitopia** but by changing the domain
`veggie` we might get **Vegitania**.  But because Fruitopia doesn't have any
text for a store loaded, if we called `localized('buynow', :domain('fruit'))`,
the text returned would be that defined by the fallback option.

To define the fallback text, you can use either a string, some combination of
strings and WhateverCode (`*`), or some other callable.  If you use a `Callable`
you might consider using two Whatevers or positional parameters to capture
the domain as well.  Using the previous example, here's the text that
would be returned based on different fall back text:

```perl6
    set-localization-fallback('[No Localization Present]');
    localized('buynow', :domain('fruit'));
    # ↪︎ [No Localization Present]

    set-localization-fallback('[MessageID:' ~ * ~ ']');
    localized('buynow', :domain('fruit'));
    # ↪︎ [MessageID:buynow]

    set-localization-fallback('[﹖ ' ~ * ~ ' ← ' ~ *.uc ']');
    localized('buynow', :domain('fruit'));
    # ↪︎ [﹖ buynow ← FRUIT]

    set-localization-fallback( { '[$^b:$^a??]' };
    localized('buynow', :domain('fruit'));
    # ↪︎ [fruit:buynow??]
```

Be aware that the order of positional arguments is first the Message ID,
second the domain (which is '' if no domain is specified).  If the arity is
greater than 2 then all other parameters will be passed a blank string, although
the third one *may* in the future also receive a hash of variables being passed.

# Language Usage Notes

If the first thing you do with Fluent is pass a base file, Fluent won't do
much of anything with it.  Fluent also needs to know which languages you intend
to support.  Because the `resources` directory in modules is not able to be
queried for files available, I made the decision to have the programmer tell
Fluent which languages are available.  To enable a language, simply pass it or
various to the `add-localization-language` (single) or `add-localization-languages`
(convenience, calls `add-localization-language` for each passed language)
functions which take *either* a LanguageTag *or* a Str representing a valid BCP47 language tag.  For the hypothetical module listed previously, we'd say:

```perl6
    add-localization-languages('ast', 'en', 'es-ES', 'es-MX', 'zh-Hant', 'zh-Hans');
```

Once both languages and file paths have been loaded, only once there is a need
for a language's localization files to be read will the `.ftl` be loaded and
parsed.  However, if you want the files to be read into memory immediately,
you can use the `:!lazy` adverb:

```perl6
    add-localization-basepath('foo/') :!lazy; # FTL files for all enabled languages
                                              # will be loaded immediately, and will
                                              # load immediately for any languages
                                              # added in the future
```

This option is best suited when precompilation is beneficial so that the FTL
files will be loaded once.

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

# Perl 6 implementation details

This module makes use of mixins to match features of other implementations in a
clean and intuitive manner.  There are two main areas where they are used:

## The Hashy Str

The `localized` routine always returns a `Str`, but if the message also has
attributes, they are mixed in in a `Hash`-like manner and can be accessed as if
the result were a `Hash`;

```perl6
    my  $translation = localized('greeting');
    say $translation;          #   ↪︎ "Hello!"
    say $translation<foo>;     #   ↪︎ "some related text"
    say $translation{'bar'};   #   ↪︎ "some other related text"
```

## Who doesn't like `but`s?

To take advantage of the partial arguments, you can use the function `with-args`
after a `but`.  Functions that take arguments can then access them in addition
to the localizer’s arguments.  For example:

```perl6
my $weight = 5 but with-args(:3minimum-fraction-digits);
localized 'kilograms', :$weight; #   ↪︎ "It weighs 5.000 kg"
```

It can be done in one fell swoop, and actually ends up a bit cleaner (IMO) than
the Javascript version (with only two parentheses at the end, rather than two
parentheses and two brackets):

```javascript
FluentBundle.format('proportion', {amount: FluentNumber(5, {minimumFractionDigits: 3, style: 'percent'})})
```
```perl6
localized 'proportion', :amount( 5 but with-args(:3minimum-fraction-digits, :style<percent>) );
```

(You may even want to do a quick `&format = &with-args` so you can make your
code even prettier, *with-args* was chosen to be as generic as possible.)

## camelCase vs. kebab-case

Fluent's built in functions `NUMBER` and `DATETIME` take arguments in camelCase.
Because those aren't as natural to Perl 6 programmers (and aren’t what Intl::CLDR
uses), you can *also* use kebab-case arguments.   This *only* applies to
arguments supplied code-side.  Any arguments from the `.ftl` *must* use
camelCase to ensure compatibility with other implementations.

# Version history
  - 0.8 “Alcovy”
    - Added support for the `NUMBER` function (currency formatting will be available when Intl::CLDR supports it)
    - Improved handling for functions in general, including the ability for programs to add their own functions.
    - Updated test files.
  - 0.7 “Cheaha”
    - Updated documents substantially
    - Fixed a bug in inline block text
    - Fixed major bugs in variable references and term references
    - Corrected term attribute usage, particularly evident in selectors
    - Moved the CLDR Plural logic into a separate module (Intl::CLDR) where it is better suited.
    - Added an experimental feature Variable Term References which is not currently part of the standard to demonstrate proof of concept
  - 0.6 “Blackjack”
    - First reasonably usable version (missing NUMBER/DATE functions)
    - Localization file structure added
    - Messages/Terms are now tested based on `Intl::BCP47`'s lookup.
    - API should be mostly frozen at this point.
  - 0.5
    - First semi working version

# Licensing and rights information
This module is released under the Artistic License 2.0.
The social media image (resources/logo.png) is released under CC-by 4.0, and incorporates
the pieces (https://commons.wikimedia.org/wiki/File:Adonis_Blue_Butterfly.jpg, licensed under CC0 1.0)
and