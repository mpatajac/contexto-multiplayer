module Models.Sse.Message exposing (Message(..), decoder)

import Json.Decode as JD
import Models.Guess as Guess exposing (Guess)
import Models.GuessScore as GuessScore exposing (GuessScore)


type Message
    = NewGuess GuessScore
    | CorrectGuess Guess


decoder : JD.Decoder Message
decoder =
    JD.oneOf
        [ GuessScore.decoder |> JD.map NewGuess
        , Guess.decoder |> JD.map CorrectGuess
        ]
