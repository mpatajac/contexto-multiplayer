module Models.Game.GameState exposing
    ( GameState
    , calculatingScore
    , correctGuess
    , decoder
    , duplicateGuess
    , failedAction
    , guessCount
    , newGuess
    , receivedGuess
    , targetWordRevealed
    )

import Dict exposing (Dict)
import Json.Decode as JD
import Json.Decode.Pipeline as DecodePipeline
import Models.Game.GameNumber as GameNumber exposing (GameNumber)
import Models.Game.LastActionStatus as LastActionStatus exposing (LastActionStatus)
import Models.Guess as Guess exposing (Guess)
import Models.GuessScore exposing (GuessScore)
import Models.Score as Score exposing (Score)
import Utils.Data.Error exposing (ErrorMessage)
import Utils.Utils


type alias GameState =
    { gameNumber : GameNumber
    , targetWord : Maybe Guess
    , guesses : Dict Guess Score
    , lastActionStatus : LastActionStatus
    }



-- STATS


guessCount : GameState -> Int
guessCount state =
    let
        incorrectGuessCount =
            state.guesses |> Dict.keys |> List.length

        correctGuessCount =
            state.targetWord |> Utils.Utils.m2i
    in
    incorrectGuessCount + correctGuessCount


targetWordRevealed : GameState -> Bool
targetWordRevealed state =
    case state.targetWord of
        Nothing ->
            False

        Just word ->
            Dict.member word state.guesses



-- UPDATERS


newGuess : GameState -> GuessScore -> GameState
newGuess state guessScore =
    let
        stateWithNewGuess =
            receivedGuess state guessScore

        stateWithHandledCorrectGuess =
            if guessScore.score == 1 then
                correctGuess stateWithNewGuess guessScore.guess

            else
                stateWithNewGuess
    in
    { stateWithHandledCorrectGuess
        | lastActionStatus = LastActionStatus.Guess guessScore
    }


failedAction : GameState -> ErrorMessage -> GameState
failedAction state errorMessage =
    { state | lastActionStatus = LastActionStatus.Message errorMessage }


duplicateGuess : GameState -> Guess -> GameState
duplicateGuess state guess =
    { state | lastActionStatus = LastActionStatus.Message ("The word '" ++ guess ++ "' was already guessed.") }


calculatingScore : GameState -> GameState
calculatingScore state =
    { state | lastActionStatus = LastActionStatus.Processing }



-- EXTERNAL UPDATERS (SSE)


receivedGuess : GameState -> GuessScore -> GameState
receivedGuess state guessScore =
    { state
        | guesses = Dict.insert guessScore.guess guessScore.score state.guesses
    }


correctGuess : GameState -> Guess -> GameState
correctGuess state guess =
    { state | targetWord = Just guess }



-- DECODER


decoder : JD.Decoder GameState
decoder =
    JD.succeed GameState
        |> DecodePipeline.required "game_number" GameNumber.decoder
        |> DecodePipeline.optional "target_word" (JD.maybe Guess.decoder) Nothing
        |> DecodePipeline.required "guesses" (JD.dict Score.decoder)
        |> DecodePipeline.hardcoded LastActionStatus.Initial
