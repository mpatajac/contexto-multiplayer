module Utils.Api.Response exposing (EmptyResponseResult, ResponseError(..), ResponseResult, expectJson, handleResponseError, withoutBody)

import Http
import Json.Decode as JD
import Utils.Data.Error exposing (ErrorMessage)
import Utils.Text as Text


{-|

    NOTE: generalize with `cErr` and `sErr` when (if) necessary

    NOTE: keep client/server error separate (to maybe display with a different color?)

-}
type ResponseError
    = ClientError ErrorMessage
    | ServerError ErrorMessage
    | GeneralError Http.Error


type alias ResponseResult value =
    Result ResponseError value


{-| Alias for a `ResponseResult` with an empty "body" (`Ok` variant).
-}
type alias EmptyResponseResult =
    ResponseResult ()


type alias BodyHandler value =
    String -> ResponseResult value


type alias ResponseHandler value msg =
    ResponseResult value -> msg


{-|

    Variation of `Response.expectJson` used when there is no
    (success) response body to parse (or it is not relevant).

-}
withoutBody : ResponseHandler () msg -> Http.Expect msg
withoutBody responseHandler =
    let
        bodyHandler _ =
            Ok ()
    in
    expectBase responseHandler bodyHandler


{-|

    Like `Http.expectJson`, but returns message from body on `4xx` response.

-}
expectJson : ResponseHandler value msg -> JD.Decoder value -> Http.Expect msg
expectJson responseHandler decoder =
    let
        badBodyErrorHandler =
            JD.errorToString >> Http.BadBody >> GeneralError

        bodyHandler =
            JD.decodeString decoder >> Result.mapError badBodyErrorHandler
    in
    expectBase responseHandler bodyHandler


{-|

    Base response handling logic

-}
expectBase : ResponseHandler value msg -> BodyHandler value -> Http.Expect msg
expectBase responseHandler bodyHandler =
    let
        asGeneralError =
            GeneralError >> Err
    in
    -- https://package.elm-lang.org/packages/elm/http/latest/Http#expectStringResponse
    Http.expectStringResponse responseHandler <|
        \response ->
            case response of
                Http.BadUrl_ url ->
                    asGeneralError (Http.BadUrl url)

                Http.Timeout_ ->
                    asGeneralError Http.Timeout

                Http.NetworkError_ ->
                    asGeneralError Http.NetworkError

                Http.BadStatus_ metadata body ->
                    Err (handleBadStatus metadata body)

                Http.GoodStatus_ _ body ->
                    bodyHandler body


handleBadStatus : Http.Metadata -> String -> ResponseError
handleBadStatus metadata body =
    let
        statusCode =
            metadata.statusCode
    in
    if statusCode >= 500 then
        ServerError body

    else if statusCode >= 400 then
        ClientError body

    else
        GeneralError (Http.BadStatus statusCode)



-- UTILS


type alias UpdateResponse model msg =
    ( model, Cmd msg )


type alias ErrorStateUpdater model =
    Utils.Data.Error.Error -> model


{-| Utility function for handling `ResponseError` with an apropriate action
-}
handleResponseError : ResponseError -> ErrorStateUpdater model -> UpdateResponse model msg
handleResponseError error errorStateUpdater =
    case error of
        ClientError errorMessage ->
            ( errorStateUpdater { source = Utils.Data.Error.Client, message = errorMessage }, Cmd.none )

        ServerError errorMessage ->
            ( errorStateUpdater { source = Utils.Data.Error.Server, message = errorMessage }, Cmd.none )

        GeneralError _ ->
            ( errorStateUpdater { source = Utils.Data.Error.Other, message = Text.genericErrorMessage }, Cmd.none )
