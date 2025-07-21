module Utils.Data.Flags exposing (Flags, decoder)

import Json.Decode as JD
import Json.Decode.Pipeline as DecodePipeline
import Models.SessionId as SessionId exposing (SessionId)


type alias Flags =
    { sessionId : SessionId
    }


decoder : JD.Decoder Flags
decoder =
    JD.succeed Flags
        |> DecodePipeline.required "session_id" SessionId.decoder
