module Models.SessionId exposing (SessionId, decoder, display, empty)

import Json.Decode as JD


type SessionId
    = SessionId String


decoder : JD.Decoder SessionId
decoder =
    JD.map SessionId JD.string


display : SessionId -> String
display (SessionId sessionId) =
    sessionId


empty : SessionId
empty =
    SessionId ""
