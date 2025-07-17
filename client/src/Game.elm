module Game exposing
    ( GameStateInitResult
    , handleGuessSubmissionResult
    , handleMessage
    , init
    , submitGuess
    )

import Http
import Models.Game.GameState as GameState exposing (GameState)
import Models.Guess as Guess exposing (Guess)
import Models.GuessScore as GuessScore exposing (GuessScore)
import Models.SessionId exposing (SessionId)
import Models.Sse.Message as Sse
import Utils.Api.Endpoint exposing (gameState)
import Utils.Api.Request as Request
import Utils.Api.Response as Response
import Utils.Data.Error exposing (ErrorMessage)
import Utils.Text


type alias GameStateInitResult =
    Response.ResponseResult GameState


init : SessionId -> (GameStateInitResult -> msg) -> Cmd msg
init sessionId toMsg =
    let
        responseHandler =
            Response.expectJson
                toMsg
                GameState.decoder
    in
    Request.fetchGameState sessionId responseHandler


submitGuess : SessionId -> Guess -> (Response.ResponseResult GuessScore -> msg) -> Cmd msg
submitGuess sessionId guess toMsg =
    let
        body =
            guess
                |> Guess.encoder
                |> Http.jsonBody

        responseHandler =
            Response.expectJson toMsg GuessScore.decoder
    in
    Request.submitGuess sessionId body responseHandler


handleGuessSubmissionResult : GameState -> Response.ResponseResult GuessScore -> GameState
handleGuessSubmissionResult gameState result =
    case result of
        Ok guessScore ->
            GameState.newGuess gameState guessScore

        Err error ->
            GameState.failedAction gameState (messageFromError error)


handleMessage : GameState -> Sse.Message -> GameState
handleMessage gameState message =
    case message of
        Sse.NewGuess guessScore ->
            GameState.receivedGuess gameState guessScore

        Sse.CorrectGuess guess ->
            GameState.correctGuess gameState guess



-- HELPERS


messageFromError : Response.ResponseError -> ErrorMessage
messageFromError responseError =
    case responseError of
        Response.ClientError errorMessage ->
            errorMessage

        Response.ServerError errorMessage ->
            errorMessage

        Response.GeneralError _ ->
            Utils.Text.genericErrorMessage
