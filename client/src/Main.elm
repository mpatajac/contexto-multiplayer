-- TODO!: handle word being guessed


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
import Utils.Api.Endpoint exposing (guess)
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
    Html.main_ [] <|
        [ Html.h1 [] [ Html.text "Contexto - multiplayer" ]
        , Html.span [] [ Html.text <| guessCountText gameState ]
        , Html.a [ Html.Attributes.href model.sessionLink ] [ Html.text sessionLinkText ]
        , Html.Lazy.lazy viewInput model.guessInput
        , viewSpacer
        , Html.Lazy.lazy viewLastActionStatus gameState.lastActionStatus
        , viewSpacer
        , Html.Lazy.lazy viewGuesses gameState.guesses
        ]


viewInput : Guess -> Html Msg
viewInput guessInput =
    Html.input
        [ Html.Attributes.placeholder "type a word"
        , Html.Attributes.maxlength 50
        , Html.Attributes.value guessInput
        , Html.Attributes.autofocus True
        , Html.Events.onInput UpdateGuessInput
        , Utils.Utils.onEnter SubmitGuess
        ]
        []


viewLastActionStatus : LastActionStatus -> Html Msg
viewLastActionStatus lastActionStatus =
    case lastActionStatus of
        LastActionStatus.Initial ->
            Html.div [] []

        LastActionStatus.Processing ->
            Html.div [ Html.Attributes.class "statusBox" ] [ Html.text "Calculating..." ]

        LastActionStatus.Message message ->
            Html.div [ Html.Attributes.class "statusBox" ] [ Html.text message ]

        LastActionStatus.Guess guessScore ->
            viewGuess ( guessScore.guess, guessScore.score )


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
    ( guess, Html.Lazy.lazy viewGuess guessScore )


viewGuess : ( Guess, Score ) -> Html Msg
viewGuess ( guess, score ) =
    Html.div
        [ Html.Attributes.class "guess-score" ]
        -- TODO: remove space, add spacing with styling
        [ Html.span [] [ Html.text (guess ++ " ") ]
        , Html.span [] [ Html.text (String.fromInt score) ]
        ]


viewSpacer : Html Msg
viewSpacer =
    -- TODO: remove
    Html.div
        [ Html.Attributes.style "margin-top" "1em"
        ]
        []
