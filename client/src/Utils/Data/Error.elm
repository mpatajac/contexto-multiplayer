module Utils.Data.Error exposing (Error, ErrorMessage, ErrorSource(..))

-- TODO: do we need it to be this detailed?


type ErrorSource
    = Client
    | Server
    | Other


type alias ErrorMessage =
    String


type alias Error =
    { source : ErrorSource
    , message : ErrorMessage
    }
