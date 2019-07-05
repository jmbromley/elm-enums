# `elm-enums` automatic code generator

**Summary**: `elm-enums` is a command-line tool to autogenerate *Elm* type declarations and JSON encoders/decoders
for simple *enum-like* custom types.  It will also generate stringifiers and lists of all values for you.
If you're just interested in how to use it then you can jump straight to the
[How It Works](#how-it-works) section below.

## The Problem (a.k.a. `elm-enums`' Raison d'être)

Often you have a finite list of possible *values* that something can take.  While it's perfectly possible
to represent such values simply as a `String`, often we prefer to make a very simple *custom type* to
deal with this, e.g.

```elm
type Animal
    = Cat
    | Dog
    | Bird
    | Rat
```

The advantage of this approach is that the compiler will stop any errors creeping into our code if/when we make a typo
in later referring to one of the *values*: something that otherwise can be quite annoying to track down.  It also forces
us to consider all possibilities when making a decision based on the *value* (unless we cheat and use `_ ->` in `case`
statements!).

This advantage becomes more important the more we have to pass such types around.  Consider the case of an
interactive story.  The player moves from chapter to chapter in the story depending on their actions; some chapters may be
revisited or even change their appearance depending on what accomplishments the player has already made and what items
they have acquired.  If we were to try and code this in *Elm* we would need to keep track of which chapters a player
had already visited, which chapter they were on now, what objects they were carrying and what objectives they had completed.
The rules for transitioning from chapter to chapter would depend on all these things.  At this point referring to
chapters simply by a name encoded as a `String` becomes very error-prone.  Typos can cause references to non-existent
chapters, and it's very easy to forget to consider all possibilities when writing logic to determine what happens to a
player based on all the things they could already have done.

Having custom types to refer to the chapters, items and accomplishments becomes very appealing:

```elm
type ChapterName
    = Introduction
    | Meeting1
    | Meeting2
    | AChoiceOfPaths
    | FollowingTheRedPath
    | FollowingTheGreenPath
    | ...

type Accomplishment
    = FixedTheCar
    | FoundTheMap
    | ...

...
```

we can then encode the logic of how to render the current section of story to the user in a function that takes these
types, e.g.

```elm
viewStory : ChapterName -> List ChapterName -> List Accomplishments -> List Item -> Html Msg
viewStory currentChapter exploredChapters accomplishments items =
   ...
```

and the compiler will ensure that we can't refer to non-existent chapters *and* that we don't forget to consider *any*
possibility when determining what options the chapter should offer to the player based on what they have with them and
what they have already accomplished.

This all works wonderfully until things get so large that we want *persistence*: to somehow save the player's state so
they can return to the game at another time.  As soon as this happens we find we need to encode our nice custom types
in a way that javascript or a server can handle and store for us.  So now we need to write JSON encoders and decoders
for all our types. Not only does this take a bit of time to initially set up, but more importantly while it might still
help with keeping our encoder up to date, the compiler no longer has our back when it comes to keeping the decoder up
to date.  Suddenly adding a new chapter and a bunch of new accompanying accomplishments requires us not only to add them
to our custom types, but also to our encoders and decoders; and if we forget to add one of them to the decoder (or if we
make a typo when doing so in either the decoder or the encoder) then suddenly our game can encounter saved state being
handed back to it that it can't understand.

## The Solution

`elm-enums` is a very basic command-line tool (written in *Elm*!) to take the pain out of handling simple
custom types (of the form that other languages would refer to as *enums*) that need passing in and out of JSON
and are prone to frequent change in their set of values.  It can't handle more complex custom types at all (i.e. anything
that is more than just a union of simple argumentless constructors), but it aims to make those it can handle as
maintenance-free as possible.

### How it works

To use `elm-enums` you create a single input file called `enums.defs` in your source tree.  In it you place all the
*enum-like* type definitions you want `elm-enums` to handle for you.  Each definition must start with the `enum` keyword
and follow the following pattern:

```elm
{- Chapter names

By convention we prefix all chapters that cause a game end with "Final".
-}
enum ChapterName =
    [ Introduction -- the game always starts here
    , Meeting1
    , Meeting2
    , AChoiceOfPaths
    , FollowingTheRedPath
    , FollowingTheGreenPath
    , FinalAStickyEnd
    , FinalSmallVictory
    ]
```

note that Elm-like comments are supported.  Whitespace is totally ignore so you are free to format/indent the definitions
however you like.

The name assigned to a `enum` and all its declared values can only contain alphanumeric ASCII characters and the underscore
`_` chararacter (note this is more restrictive than *Elm* itself, additional characters may be allowed in later versions).
Additionally names and values must be unique, begin with an uppercase letter, and cannot match the names of any of the *Elm*
[default imports](https://package.elm-lang.org/packages/elm/core/latest/).

If you run `elm-enums` without any arguments from the same directory as your `enums.defs` it will then parse this file
and automatically generate a file `Enums.elm` in the same directory, which will contain *custom types* and
JSON encoders/decoders for all your enum definitions.  To use these from any or your *Elm* modules, simply import what you
need using the following pattern:

```elm
import Enums exposing (ChapterName(..), encodeChapterName, decodeChapterName, Item(..), encodeItem, decodeItem)
```

All *custom types* will have the name given in your `enum` declaration and encoders/decoders will have the same name
but prefixed with *encoder/decoder* appropriately.  The type signature of the encoders/decoders is always:

```elm
decodeMyEnum : Json.Decode.Decoder MyEnum

encodeMyEnum : MyEnum -> Json.Encode.Value
```

`elm-enums` also generates stringifiers and a list of all valid values for you, should you need them (and, thanks to
dead code elimination in Elm 0.19, at no cost in speed or file size if you don't!).  They have the following type signatures
and naming scheme and can be imported in a similar fashion:

```elm
stringifyMyEnum : MyEnum -> String

listAllMyEnum : List MyEnum
```

If you need to update an `enum` simply modify `enums.defs` and then rerun `elm-enums`.   The produced `Enums.elm` is
preformatted to the standards of *elm-format*, both so that it is easy to read and so that no change will occur to the file
if you have any git hooks to run *elm-format* on everything before comitting.

#### Current Limitations

As discussed above, `elm-enums` currently needs to be run from the same directory that your `enums.defs` is in and
currently only ASCII alphanumeric characters (plus the underscore) are accepted in names and values.
