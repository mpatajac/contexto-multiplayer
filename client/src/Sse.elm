port module Sse exposing (subscribe)

import Json.Decode as JD
import Models.Sse.Message as Message exposing (Message)


subscribe :
    { successMsg : Message -> msg
    , failMsg : msg
    }
    -> Sub msg
subscribe { successMsg, failMsg } =
    let
        sseMessageDecoder value =
            JD.decodeValue Message.decoder value

        decodeSseMessage value =
            case sseMessageDecoder value of
                Ok message ->
                    successMsg message

                Err _ ->
                    -- TODO: "log" error (somehow)
                    failMsg
    in
    sse decodeSseMessage


port sse : (JD.Value -> msg) -> Sub msg
