module Models.Score exposing (Score, decoder)

import Json.Decode as JD


type alias Score =
    Int


decoder : JD.Decoder Score
decoder =
    JD.int
