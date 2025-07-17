module Models.GuessScore exposing (GuessScore, decoder)

import Json.Decode as JD
import Json.Decode.Pipeline as DecodePipeline
import Models.Guess as Guess exposing (Guess)
import Models.Score as Score exposing (Score)


type alias GuessScore =
    { guess : Guess
    , score : Score
    }


decoder : JD.Decoder GuessScore
decoder =
    JD.succeed GuessScore
        |> DecodePipeline.required "guess" Guess.decoder
        |> DecodePipeline.required "score" Score.decoder
