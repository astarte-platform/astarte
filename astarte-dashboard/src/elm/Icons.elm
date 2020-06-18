{-
   This file is part of Astarte.

   Copyright 2019 Ispirata Srl

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


module Icons exposing
    ( Icon(..)
    , render
    , renderWithColor
    )

import Color exposing (Color)
import Html exposing (Html, i)
import Html.Attributes exposing (class, style)


type Icon
    = Add
    | Back
    | Close
    | Delete
    | Device
    | Edit
    | Erase
    | ExclamationMark
    | ExternalLink
    | EmptyCircle
    | FullCircle
    | Flow
    | Group
    | Healthy
    | Home
    | Interface
    | Logout
    | Pipeline
    | Reload
    | Settings
    | ToggleSidebar
    | Trigger
    | Unhealthy


renderWithColor : Color -> Icon -> List (Html.Attribute msg) -> Html msg
renderWithColor color icon attributes =
    render icon <| attributes ++ [ style "color" <| Color.toCssString color ]


render : Icon -> List (Html.Attribute msg) -> Html msg
render icon attributes =
    let
        classes =
            [ class <| classType icon
            , class <| className icon
            ]
    in
    i (classes ++ attributes) []


classType : Icon -> String
classType icon =
    case icon of
        EmptyCircle ->
            "far"

        _ ->
            "fas"


className : Icon -> String
className icon =
    case icon of
        Add ->
            "fa-plus"

        Back ->
            "fa-chevron-left"

        Close ->
            "fa-times"

        Delete ->
            "fa-times"

        Device ->
            "fa-cube"

        Edit ->
            "fa-pencil-alt"

        Erase ->
            "fa-eraser"

        ExclamationMark ->
            "fa-exclamation-circle"

        ExternalLink ->
            "fa-external-link-alt"

        EmptyCircle ->
            "fa-circle"

        FullCircle ->
            "fa-circle"

        Flow ->
            "fa-wind"

        Group ->
            "fa-object-group"

        Healthy ->
            "fa-heart"

        Home ->
            "fa-home"

        Interface ->
            "fa-stream"

        Logout ->
            "fa-sign-out-alt"

        Pipeline ->
            "fa-code-branch"

        Reload ->
            "fa-sync-alt"

        Settings ->
            "fa-cog"

        ToggleSidebar ->
            "fa-arrows-alt-h"

        Trigger ->
            "fa-bolt"

        Unhealthy ->
            "fa-heart-broken"
