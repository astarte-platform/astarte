{-
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-}


module HtmlUtils exposing (handleEnterKeyPress)

import Html exposing (Html)
import Html.Events
import Json.Decode as Decode exposing (Decoder)


handleEnterKeyPress : msg -> Bool -> Html msg -> Html msg
handleEnterKeyPress enterMessage enabled innerHtml =
    Html.div
        [ Html.Events.on "keydown" (eventHelper enterMessage enabled) ]
        [ innerHtml ]


eventHelper : msg -> Bool -> Decoder msg
eventHelper enterMessage enable =
    Decode.at [ "key" ] Decode.string
        |> Decode.andThen
            (\key ->
                if key == "Enter" && enable then
                    Decode.succeed enterMessage

                else
                    Decode.fail "not enter"
            )
