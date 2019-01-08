module Util exposing (deadEndsToString)

import Parser exposing (DeadEnd, Problem(..))


{- The below is based on an existing pull request to elm/parser,
   but slightly modified to provide more specific error messages
   for our case.

   elm/parser is itself licensed under a BSD 3-Clause license
   (as is this software).

   The pull request is authored by bburdette on github.com.
-}


deadEndsToString : List DeadEnd -> String
deadEndsToString deadEnds =
    String.concat (List.intersperse "; " (List.map deadEndToString deadEnds))


deadEndToString : DeadEnd -> String
deadEndToString deadend =
    problemToString deadend.problem ++ " at row " ++ String.fromInt deadend.row ++ ", col " ++ String.fromInt deadend.col


problemToString : Problem -> String
problemToString p =
    case p of
        Expecting s ->
            "Expecting '" ++ s ++ "'"

        ExpectingInt ->
            "Expecting int"

        ExpectingHex ->
            "Expecting hex"

        ExpectingOctal ->
            "Expecting octal"

        ExpectingBinary ->
            "Expecting binary"

        ExpectingFloat ->
            "Expecting float"

        ExpectingNumber ->
            "Expecting number"

        ExpectingVariable ->
            "Expecting capitalized identifier"

        ExpectingSymbol s ->
            "Expecting symbol '" ++ s ++ "'"

        ExpectingKeyword s ->
            "Expecting keyword '" ++ s ++ "'"

        ExpectingEnd ->
            "Expecting end or enum keyword"

        UnexpectedChar ->
            "Unexpected char"

        Problem s ->
            "Problem " ++ s

        BadRepeat ->
            "Bad repeat"
