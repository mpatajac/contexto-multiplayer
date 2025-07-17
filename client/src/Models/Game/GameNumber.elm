module Models.Game.GameNumber exposing (GameNumber, decoder)

import Json.Decode as JD


type alias GameNumber =
    Int


decoder : JD.Decoder GameNumber
decoder =
    JD.int
