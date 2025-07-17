module Models.Guess exposing (Guess, decoder, encoder)

import Json.Decode as JD
import Json.Encode as JE


type alias Guess =
    String


decoder : JD.Decoder Guess
decoder =
    JD.string


encoder : Guess -> JE.Value
encoder guess =
    JE.string guess
