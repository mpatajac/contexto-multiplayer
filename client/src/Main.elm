module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Game
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Html.Keyed
import Html.Lazy
import Json.Decode as JD
import Json.Encode as JE
import Models.Game.GameState as GameState exposing (GameState)
import Models.Game.LastActionStatus as LastActionStatus exposing (LastActionStatus)
import Models.Guess exposing (Guess)
import Models.GuessScore exposing (GuessScore)
import Models.Score exposing (Score)
import Models.SessionId as SessionId exposing (SessionId)
import Models.Sse.Message exposing (Message)
import Sse
import Utils.Api.Response as Response
import Utils.Data.Fetched as Fetched exposing (Fetched(..))
import Utils.Data.Flags as Flags exposing (Flags)
import Utils.Utils


main : Program JE.Value Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { sessionId : SessionId
    , sessionLink : String
    , gameState : Fetched GameState
    , guessInput : String
    }


{-| Dummy Model only to be used after invalid flags init.
-}
emptyModel : Model
emptyModel =
    { sessionId = SessionId.empty
    , sessionLink = ""
    , gameState = Fetched.Fetching
    , guessInput = ""
    }



-- INIT


init : JE.Value -> ( Model, Cmd Msg )
init rawFlags =
    let
        flagsParseResult =
            JD.decodeValue Flags.decoder rawFlags
    in
    case flagsParseResult of
        Err _ ->
            -- something is wrong with passed flags
            ( emptyModel, Cmd.none )

        Ok flags ->
            ( initData flags, Game.init flags.sessionId GameInit )


initData : Flags -> Model
initData { sessionId, sessionLink } =
    { emptyModel
        | sessionId = sessionId
        , sessionLink = sessionLink
    }



-- UPDATE


type Msg
    = NoOp
    | GameInit Game.GameStateInitResult
    | SseMessage Message
    | UpdateGuessInput Guess
    | SubmitGuess
    | HandleGuessSubmissionResponse (Response.ResponseResult GuessScore)
    | RevealTargetWord


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GameInit (Ok gameState) ->
            ( { model | gameState = Fetched.Loaded gameState }, Cmd.none )

        GameInit (Err gameStateInitError) ->
            let
                errorStateUpdater error =
                    { model | gameState = Fetched.Failed error }
            in
            Response.handleResponseError gameStateInitError errorStateUpdater

        UpdateGuessInput guessInput ->
            ( { model | guessInput = guessInput }, Cmd.none )

        SseMessage message ->
            let
                updateGameState gameState =
                    Game.handleMessage gameState message

                updatedGameState =
                    Fetched.map updateGameState model.gameState
            in
            ( { model | gameState = updatedGameState }, Cmd.none )

        SubmitGuess ->
            case model.gameState of
                Loaded gameState ->
                    let
                        isDuplicateGuess =
                            Dict.member model.guessInput gameState.guesses

                        updatedGameState =
                            if not isDuplicateGuess then
                                GameState.calculatingScore gameState

                            else
                                model.guessInput
                                    |> GameState.duplicateGuess gameState

                        transitionCmd =
                            if not isDuplicateGuess then
                                Game.submitGuess model.sessionId model.guessInput HandleGuessSubmissionResponse

                            else
                                Cmd.none
                    in
                    ( { model
                        | gameState = Fetched.Loaded updatedGameState
                        , guessInput =
                            if isDuplicateGuess then
                                ""

                            else
                                model.guessInput
                      }
                    , transitionCmd
                    )

                _ ->
                    ( model, Cmd.none )

        HandleGuessSubmissionResponse guessSubmissionResponse ->
            case model.gameState of
                Loaded gameState ->
                    let
                        updatedGuessInput =
                            case guessSubmissionResponse of
                                -- reset input on successful guess
                                Ok _ ->
                                    ""

                                Err _ ->
                                    model.guessInput

                        updateRoomState guessSubmissionResult =
                            Game.handleGuessSubmissionResult gameState guessSubmissionResult

                        updatedModel =
                            { model
                                | gameState = Fetched.Loaded (updateRoomState guessSubmissionResponse)
                                , guessInput = updatedGuessInput
                            }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        RevealTargetWord ->
            case model.gameState of
                Loaded gameState ->
                    case gameState.targetWord of
                        Just targetWord ->
                            let
                                updatedGameState =
                                    GameState.receivedGuess gameState (GuessScore targetWord 1)
                            in
                            ( { model | gameState = Fetched.Loaded updatedGameState }, Cmd.none )

                        Nothing ->
                            -- invalid case, ignore
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sse.subscribe
        { successMsg = SseMessage
        , failMsg = NoOp
        }



-- VIEW


view : Model -> Html Msg
view model =
    case model.gameState of
        Fetched.Fetching ->
            Html.div [] [ Html.text "Loading game..." ]

        Fetched.Failed error ->
            Html.div [] [ Html.text error.message ]

        Fetched.Loaded gameState ->
            viewGameState model gameState


viewGameState : Model -> GameState -> Html Msg
viewGameState model gameState =
    let
        guessCountText state =
            "Guesses: " ++ (state |> GameState.guessCount |> String.fromInt)

        sessionLinkText =
            "Session " ++ SessionId.display model.sessionId
    in
    Html.main_
        [ Html.Attributes.class "section container is-max-tablet" ]
    <|
        [ Html.h1
            [ Html.Attributes.class "title" ]
            [ Html.text "Contexto" ]
        , Html.h2
            [ Html.Attributes.class "subtitle" ]
            [ Html.text "multiplayer" ]
        , Html.div [ Html.Attributes.class "mb-1 is-flex is-justify-content-space-between" ]
            [ Html.span [] [ Html.text <| guessCountText gameState ]
            , Html.a [ Html.Attributes.href model.sessionLink ] [ Html.text sessionLinkText ]
            ]
        , Html.Lazy.lazy2 viewInput model.guessInput gameState
        , Html.Lazy.lazy viewTargetWordAlert gameState.targetWord
        , Html.Lazy.lazy viewLastActionStatus gameState.lastActionStatus
        , Html.Lazy.lazy viewGuesses gameState.guesses
        ]


viewInput : Guess -> GameState -> Html Msg
viewInput guessInput gameState =
    Html.input
        [ Html.Attributes.placeholder "type a word"
        , Html.Attributes.class "input block has-text-weight-semibold"
        , Html.Attributes.maxlength 50
        , Html.Attributes.value guessInput
        , Html.Attributes.autofocus True
        , Html.Attributes.disabled (GameState.targetWordRevealed gameState)
        , Html.Events.onInput UpdateGuessInput
        , Utils.Utils.onEnter SubmitGuess
        ]
        []


viewTargetWordAlert : Maybe Guess -> Html Msg
viewTargetWordAlert maybeGuess =
    case maybeGuess of
        Nothing ->
            Html.p [] []

        Just _ ->
            let
                classList =
                    [ "notification", "is-primary", "py-3", "is-clickable", "has-text-weight-bold", "has-text-centered" ]
            in
            Html.p
                [ Html.Events.onClick RevealTargetWord
                , Html.Attributes.title "Click to reveal word"
                , Utils.Utils.classes classList
                ]
                [ Html.text "Word guessed!" ]


viewLastActionStatus : LastActionStatus -> Html Msg
viewLastActionStatus lastActionStatus =
    let
        classList =
            [ "last-guess"
            , "is-flex"
            , "is-justify-content-space-between"
            , "box"
            , "p-3"
            , "my-5"
            , "has-text-weight-semibold"
            ]
    in
    case lastActionStatus of
        LastActionStatus.Initial ->
            Html.div [] []

        LastActionStatus.Processing ->
            Html.div [ Utils.Utils.classes classList ] [ Html.text "Calculating..." ]

        LastActionStatus.Message message ->
            Html.div [ Utils.Utils.classes classList ] [ Html.text message ]

        LastActionStatus.Guess guessScore ->
            viewGuess ( guessScore.guess, guessScore.score ) (Just classList)


viewGuesses : Dict Guess Score -> Html Msg
viewGuesses guesses =
    let
        guessesDisplay =
            guesses
                |> Dict.toList
                |> List.sortBy Tuple.second
                |> List.map viewKeyedGuess
    in
    Html.Keyed.node "div" [ Html.Attributes.class "guess-score-list" ] guessesDisplay


viewKeyedGuess : ( Guess, Score ) -> ( String, Html Msg )
viewKeyedGuess (( guess, _ ) as guessScore) =
    -- https://guide.elm-lang.org/optimization/keyed
    ( guess, Html.Lazy.lazy2 viewGuess guessScore Nothing )


viewGuess : ( Guess, Score ) -> Maybe (List String) -> Html Msg
viewGuess ( guess, score ) maybeClassList =
    let
        defaultClassList =
            [ "guess-score"
            , "is-flex"
            , "is-justify-content-space-between"
            , "box"
            , "p-3"
            , "my-3"
            , "has-text-weight-semibold"
            ]

        classList =
            Maybe.withDefault defaultClassList maybeClassList
    in
    Html.div
        [ Utils.Utils.classes classList ]
        [ Html.span [] [ Html.text guess ]
        , Html.span [] [ Html.text (String.fromInt score) ]
        ]
