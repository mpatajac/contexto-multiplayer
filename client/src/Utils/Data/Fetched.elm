module Utils.Data.Fetched exposing (Fetched(..), fromResult, map)

import Utils.Data.Error exposing (Error)


type Fetched a
    = Fetching
    | Failed Error
    | Loaded a


fromResult : Result Error a -> Fetched a
fromResult result =
    case result of
        Ok value ->
            Loaded value

        Err error ->
            Failed error


{-| Transform a `Fetched` value with a given function.
-}
map : (a -> b) -> Fetched a -> Fetched b
map f fetched =
    case fetched of
        Loaded data ->
            Loaded (f data)

        Fetching ->
            Fetching

        Failed err ->
            Failed err
