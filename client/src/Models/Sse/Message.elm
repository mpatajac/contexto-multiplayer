module Models.Sse.Message exposing (Message(..), decoder)

import Json.Decode as JD
import Json.Decode.Pipeline as DecodePipeline
import Models.Guess as Guess exposing (Guess)
import Models.GuessScore as GuessScore exposing (GuessScore)


type Message
    = NewGuess GuessScore
    | CorrectGuess Guess


decoder : JD.Decoder Message
decoder =
    JD.oneOf
        [ newGuessDecoder
        , correctGuessDecoder
        ]


newGuessDecoder : JD.Decoder Message
newGuessDecoder =
    GuessScore.decoder |> JD.map NewGuess


correctGuessDecoder : JD.Decoder Message
correctGuessDecoder =
    JD.succeed CorrectGuess
        |> DecodePipeline.required "word" Guess.decoder
