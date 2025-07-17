module Models.Game.GameState exposing (GameState, calculatingScore, correctGuess, decoder, duplicateGuess, failedAction, newGuess, receivedGuess)

import Dict exposing (Dict)
import Json.Decode as JD
import Json.Decode.Pipeline as DecodePipeline
import Models.Game.GameNumber as GameNumber exposing (GameNumber)
import Models.Game.LastActionStatus as LastActionStatus exposing (LastActionStatus)
import Models.Guess as Guess exposing (Guess)
import Models.GuessScore exposing (GuessScore)
import Models.Score as Score exposing (Score)
import Utils.Data.Error exposing (ErrorMessage)


type alias GameState =
    { gameNumber : GameNumber
    , targetWord : Maybe Guess
    , guesses : Dict Guess Score
    , lastActionStatus : LastActionStatus
    }



-- UPDATERS


newGuess : GameState -> GuessScore -> GameState
newGuess state guessScore =
    let
        stateWithNewGuess =
            if guessScore.score == 1 then
                correctGuess state guessScore.guess

            else
                receivedGuess state guessScore
    in
    { stateWithNewGuess
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
