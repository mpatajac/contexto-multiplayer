module Utils.Utils exposing (onEnter)

import Html
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
