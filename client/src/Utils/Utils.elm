module Utils.Utils exposing (classes, m2i, onEnter)

import Html
import Html.Attributes
import Html.Events
import Json.Decode as JD


onEnter : msg -> Html.Attribute msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                JD.succeed msg

            else
                JD.fail "not ENTER"
    in
    Html.Events.on "keydown" (JD.andThen isEnter Html.Events.keyCode)


m2i : Maybe a -> Int
m2i m =
    case m of
        Just _ ->
            1

        Nothing ->
            0


classes : List String -> Html.Attribute msg
classes classList =
    classList
        |> List.map (\cls -> ( cls, True ))
        |> Html.Attributes.classList
