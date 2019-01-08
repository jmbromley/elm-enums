module EnumParser exposing (parse)

import Parser exposing (Parser, (|.), (|=))
import Set exposing (Set)


-- LOCAL IMPORTS

import Enum exposing (Enum)
import Util


{-
   Parser that takes input of the form:

       enum Name1 =
           [ Value1_1
           , Value1_2
           , ...
           , Value1_X
           ]


       enum Name2 =
           [ Value2_1
           , Value2_2
           , ...
           , Value2_Y
           ]


       ...


       enum NameN =
           [ ValueM_1
           , ValueM_2
           , ...
           , ValueM_Z
           ]

   and produces valid Elm custom types and accompanying JSON encoders/decoders in
   an Enums module, thus:

       module Enums
           exposing
               ( Name1
               , Name2
               , Name...
               , NameN
               , encodeName1
               , encodeName2
               , encodeName...
               , encodeNameN
               , decodeName1
               , decodeName2
               , decodeName...
               , decodeNameN
               )

       import Json.Decode
       import Json.Encode


       type Name1
           = Value1_1
           | Value1_2
           | ...
           | Value1_X


       encodeName1 : Name1 -> Json.Encode.Value
       encodeName1 =
           ...


       decodeName1 : Json.Decode.Decoder Name1
       decodeName1 =
           ...


       type Name2
           = ...


       ...

   The following constraints are checked to ensure valid Elm results:

       * All Names and Values must be unique.

       * All Names and Values must begin with an uppercase character.

       * Names and Values cannot be the same as the module or type names of any
         default imports.

   In addition:

      * Elm-style comments are tolerated in the input.

      * All indentation, carriage returns and whitespace are ignored in the input;
        but the resulting generated code will conform to the style mandated by
        elm-format.
-}


parse : String -> Result String String
parse input =
    case Parser.run parseFile input of
        Ok listEnums ->
            Enum.compileToElm listEnums

        Err error ->
            Err (Util.deadEndsToString error)


parseFile : Parser (List Enum)
parseFile =
    Parser.succeed identity
        |. spacesOrComment
        |= enumSequence
        |. spacesOrComment
        |. Parser.end


enumSequence : Parser (List Enum)
enumSequence =
    let
        helper entries =
            Parser.oneOf
                [ Parser.succeed (\entry -> Parser.Loop (entry :: entries))
                    |= enum
                    |. spacesOrComment
                , Parser.succeed ()
                    |> Parser.map (\_ -> Parser.Done entries)
                ]
    in
        Parser.loop [] helper


enum : Parser Enum
enum =
    Parser.succeed Enum.fromList
        |. Parser.keyword "enum"
        |. spacesOrComment
        |= nameOrValue
        |. spacesOrComment
        |. Parser.symbol "="
        |. spacesOrComment
        |= Parser.sequence
            { start = "["
            , separator = ","
            , end = "]"
            , spaces = spacesOrComment
            , item = nameOrValue
            , trailing = Parser.Forbidden
            }


spacesOrComment : Parser ()
spacesOrComment =
    -- Taken from example in elm/parser (published under BSD 3-Clause)
    --     Copyright (c) 2017-present, Evan Czaplicki
    --     All rights reserved.
    let
        checkOffset oldOffset newOffset =
            if oldOffset == newOffset then
                Parser.Done ()
            else
                Parser.Loop newOffset

        ifProgress parser offset =
            Parser.succeed identity
                |. parser
                |= Parser.getOffset
                |> Parser.map (checkOffset offset)
    in
        Parser.loop 0 <|
            ifProgress <|
                Parser.oneOf
                    [ Parser.lineComment "--"
                    , Parser.multiComment "{-" "-}" Parser.Nestable
                    , Parser.spaces
                    ]


nameOrValue : Parser String
nameOrValue =
    Parser.variable
        { start = startTest
        , inner = innerTest
        , reserved = defaultImports
        }


startTest : Char -> Bool
startTest =
    -- FIXME: too restrictive
    Char.isUpper


innerTest : Char -> Bool
innerTest =
    -- FIXME: too restrictive
    \c -> Char.isAlphaNum c || c == '_'


defaultImports : Set String
defaultImports =
    Set.fromList
        [ "Basics"
        , "Int"
        , "Float"
        , "Order"
        , "Bool"
        , "Never"
        , "List"
        , "Maybe"
        , "Just"
        , "Nothing"
        , "Result"
        , "Err"
        , "Ok"
        , "String"
        , "Char"
        , "Tuple"
        , "Debug"
        , "Platform"
        , "Program"
        , "Cmd"
        , "Sub"
        ]
