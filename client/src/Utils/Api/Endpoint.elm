module Utils.Api.Endpoint exposing
    ( Endpoint
    , delete
    , gameState
    , get
    , guess
    , post
    , put
    )

import Http
import Models.SessionId as SessionId exposing (SessionId)
import Url.Builder


type Endpoint
    = Endpoint String



-- UTILS


type alias QueryParams =
    List Url.Builder.QueryParameter


request :
    { method : String
    , headers : List Http.Header
    , endpoint : Endpoint
    , body : Http.Body
    , expect : Http.Expect msg
    }
    -> Cmd msg
request config =
    Http.request
        { method = config.method
        , headers = config.headers
        , url = unwrap config.endpoint
        , body = config.body
        , expect = config.expect
        , timeout = Nothing
        , tracker = Nothing
        }


unwrap : Endpoint -> String
unwrap (Endpoint value) =
    value


url : List String -> Endpoint
url paths =
    urlWithParams paths []


urlWithParams : List String -> QueryParams -> Endpoint
urlWithParams paths queryParams =
    let
        -- NOTE: prefix all endpoint routes with `api`
        apiPath =
            "api" :: paths
    in
    Url.Builder.absolute apiPath queryParams |> Endpoint



-- METHDOS


get : Endpoint -> Http.Expect msg -> Cmd msg
get endpoint expect =
    request
        { method = "GET"
        , headers = []
        , endpoint = endpoint
        , body = Http.emptyBody
        , expect = expect
        }


post : Endpoint -> Http.Body -> Http.Expect msg -> Cmd msg
post endpoint body expect =
    request
        { method = "POST"
        , headers = []
        , endpoint = endpoint
        , body = body
        , expect = expect
        }


put : Endpoint -> Http.Body -> Http.Expect msg -> Cmd msg
put endpoint body expect =
    request
        { method = "PUT"
        , headers = []
        , endpoint = endpoint
        , body = body
        , expect = expect
        }


delete : Endpoint -> Http.Expect msg -> Cmd msg
delete endpoint expect =
    request
        { method = "DELETE"
        , headers = []
        , endpoint = endpoint
        , body = Http.emptyBody
        , expect = expect
        }



-- ENDPOINTS


guess : SessionId -> Endpoint
guess sessionId =
    url [ SessionId.display sessionId, "guess" ]


gameState : SessionId -> Endpoint
gameState sessionId =
    url [ SessionId.display sessionId ]
