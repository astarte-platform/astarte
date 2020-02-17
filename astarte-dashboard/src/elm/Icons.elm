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
    )

import Html exposing (Html, i)
import Html.Attributes exposing (class)


type Icon
    = Add
    | Close
    | Delete
    | Device
    | ExclamationMark
    | EmptyCircle
    | FullCircle
    | Group
    | Healthy
    | Home
    | Interface
    | Logout
    | Reload
    | Settings
    | ToggleSidebar
    | Trigger
    | Unhealthy


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

        Close ->
            "fa-times"

        Delete ->
            "fa-times"

        Device ->
            "fa-cube"

        ExclamationMark ->
            "fa-exclamation-circle"

        EmptyCircle ->
            "fa-circle"

        FullCircle ->
            "fa-circle"

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
