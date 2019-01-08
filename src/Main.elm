port module Main exposing (..)

import EnumParser


-- PROGRAM


main : Program () Model Msg
main =
    Platform.worker
        { init = always ( Init, Cmd.none )
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type Model
    = Init
    | Finished



-- UPDATE


type Msg
    = Input String


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case model of
        Init ->
            case msg of
                Input data ->
                    let
                        answer =
                            case EnumParser.parse data of
                                Err problem ->
                                    { error = Just problem, result = Nothing }

                                Ok processed ->
                                    { error = Nothing, result = Just processed }
                    in
                        ( Finished, output answer )

        Finished ->
            ( model, Cmd.none )



-- PORTS


port input : (String -> msg) -> Sub msg


port output : { error : Maybe String, result : Maybe String } -> Cmd msg



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Init ->
            input Input

        _ ->
            Sub.none
