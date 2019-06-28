module Enum exposing (Enum, compileToElm, fromList)

import Set exposing (Set)


type Enum
    = Valid (ValidEnum PossiblyUnique)
    | Invalid { name : String, reason : String }


type ValidEnum a
    = ValidEnum
        { name : String
        , values : Set String
        }


type Unique
    = Unique


type PossiblyUnique
    = PossiblyUnique


fromList : String -> List String -> Enum
fromList n v =
    let
        firstDuplicate list =
            case list of
                [] ->
                    Nothing

                next :: rest ->
                    case List.head <| List.filter (\a -> a == next) rest of
                        Nothing ->
                            firstDuplicate rest

                        Just duplicate ->
                            Just duplicate
    in
    case firstDuplicate v of
        Nothing ->
            Valid (ValidEnum { name = n, values = Set.fromList v })

        Just duplicate ->
            Invalid
                { name = n
                , reason =
                    "Multiple identical values of " ++ duplicate ++ " in the definition of this enum."
                }


compileToElm : List Enum -> Result String String
compileToElm list =
    checkValid list
        |> Result.andThen checkUnique
        |> Result.andThen compile


checkValid : List Enum -> Result String (List (ValidEnum PossiblyUnique))
checkValid unvalidated =
    let
        validate remaining done =
            case remaining of
                [] ->
                    Ok done

                next :: rest ->
                    case next of
                        Invalid { name, reason } ->
                            Err (name ++ ": " ++ reason)

                        Valid valid ->
                            validate rest (valid :: done)
    in
    validate unvalidated []


checkUnique : List (ValidEnum PossiblyUnique) -> Result String (List (ValidEnum Unique))
checkUnique enums =
    let
        markUnique : ValidEnum PossiblyUnique -> ValidEnum Unique
        markUnique (ValidEnum value) =
            ValidEnum value

        member check set =
            Set.intersect check set
                |> Set.toList
                |> List.head

        checkIdentifiers remaining gathered =
            case remaining of
                [] ->
                    Ok (List.map markUnique enums)

                (ValidEnum { name, values }) :: rest ->
                    case member (Set.insert name values) gathered of
                        Just duplicate ->
                            Err ("Identifier " ++ duplicate ++ " appears in more than one definition in enums.defs.")

                        Nothing ->
                            checkIdentifiers rest (Set.union gathered <| Set.insert name values)
    in
    checkIdentifiers enums Set.empty


compile : List (ValidEnum Unique) -> Result String String
compile enums =
    let
        construct names declarations encoders decoders remaining =
            case remaining of
                [] ->
                    assemble names declarations encoders decoders

                (ValidEnum { name, values }) :: rest ->
                    construct
                        (name :: names)
                        (makeDeclaration name values :: declarations)
                        (makeEncoder name values :: encoders)
                        (makeDecoder name values :: decoders)
                        rest
    in
    Ok <| construct [] [] [] [] enums


assemble : List String -> List String -> List String -> List String -> String
assemble names declarations encoders decoders =
    let
        flatten =
            List.intersperse "\n\n" >> List.foldl (++) ""

        header =
            "module Enums exposing\n    ( "
                ++ (List.map (\a -> [ a ++ "(..)", "decode" ++ a, "encode" ++ a ]) names
                        |> List.foldl (++) []
                        |> List.sort
                        |> List.reverse
                        |> List.intersperse "\n    , "
                        |> List.foldl (++) ""
                   )
                ++ "\n    )\n"
                ++ headerWarning
                ++ "\nimport Json.Decode\nimport Json.Encode\n\n\n"
    in
    header ++ flatten declarations ++ "\n\n" ++ flatten encoders ++ "\n\n" ++ flatten decoders


makeDeclaration : String -> Set String -> String
makeDeclaration name values =
    let
        union =
            Set.toList values
                |> List.intersperse "\n    | "
                |> List.foldl (++) ""
    in
    "type " ++ name ++ "\n    = " ++ union ++ "\n"


makeEncoder : String -> Set String -> String
makeEncoder name values =
    let
        encoderName =
            "encode" ++ name

        makeEntry x =
            "        " ++ x ++ " ->\n            Json.Encode.string \"" ++ x ++ "\"\n"

        entries =
            Set.toList values
                |> List.map makeEntry
                |> List.intersperse "\n"
                |> List.foldl (++) ""

        body =
            "    case value of\n" ++ entries

        declaration =
            encoderName ++ " : " ++ name ++ " -> Json.Encode.Value\n" ++ encoderName ++ " value =\n"
    in
    declaration ++ body


makeDecoder : String -> Set String -> String
makeDecoder name values =
    let
        decoderName =
            "decode" ++ name

        entries =
            Set.toList values
                |> List.map (\a -> "                \"" ++ a ++ "\" ->\n                    Json.Decode.succeed " ++ a ++ "\n")
                |> List.intersperse "\n"
                |> List.foldl (++) ""

        body =
            "    let\n        findMatch str =\n"
                ++ "            case str of\n"
                ++ entries
                ++ "\n                _ ->\n                    Json.Decode.fail \"Unknown value for "
                ++ name
                ++ "\"\n"
                ++ "    in\n    Json.Decode.string |> Json.Decode.andThen findMatch\n"

        declaration =
            decoderName ++ " : Json.Decode.Decoder " ++ name ++ "\n" ++ decoderName ++ " =\n"
    in
    declaration ++ body


headerWarning : String
headerWarning =
    """
{- WARNING: This code is autogenerated by elm-enums.

   Any modifications you make to this file will be wiped out if elm-enums is run again.

   You probably want to make modifications to the enums.defs source file rather than here.
-}
"""
