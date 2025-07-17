module Utils.Api.Request exposing
    ( fetchGameState
    , submitGuess
    )

import Http
import Models.SessionId exposing (SessionId)
import Utils.Api.Endpoint as Endpoint


fetchGameState : SessionId -> Http.Expect msg -> Cmd msg
fetchGameState sessionId responseHandler =
    Endpoint.get (Endpoint.gameState sessionId) responseHandler


submitGuess : SessionId -> Http.Body -> Http.Expect msg -> Cmd msg
submitGuess sessionId body responseHandler =
    Endpoint.post (Endpoint.guess sessionId) body responseHandler
