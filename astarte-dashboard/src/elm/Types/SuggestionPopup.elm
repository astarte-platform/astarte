{-
   This file is part of Astarte.

   Copyright 2018 Ispirata Srl

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


module Types.SuggestionPopup exposing (Msg, SuggestionPopup, new, subs, update, view)

import Bootstrap.Utilities.Display as Display
import Html exposing (Html, div, i, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, onMouseLeave)
import Time exposing (Time)


type SuggestionPopup
    = SuggestionPopup Status


type alias Status =
    { message : String
    , visible : Bool
    , timeoutCounter : Int
    }


type Msg
    = ToggleVisibility
    | AutoHide
    | CountDown Time


new : String -> SuggestionPopup
new message =
    SuggestionPopup
        { message = message
        , visible = False
        , timeoutCounter = 0
        }


update : SuggestionPopup -> Msg -> SuggestionPopup
update (SuggestionPopup status) msg =
    case msg of
        ToggleVisibility ->
            if status.visible then
                SuggestionPopup
                    { status
                        | timeoutCounter = 0
                        , visible = False
                    }

            else
                SuggestionPopup
                    { status
                        | timeoutCounter = 5
                        , visible = True
                    }

        AutoHide ->
            SuggestionPopup { status | timeoutCounter = 2 }

        CountDown now ->
            if status.timeoutCounter > 1 then
                SuggestionPopup { status | timeoutCounter = status.timeoutCounter - 1 }

            else
                SuggestionPopup
                    { status
                        | timeoutCounter = status.timeoutCounter - 1
                        , visible = False
                    }


view : SuggestionPopup -> List (Html Msg)
view (SuggestionPopup status) =
    [ div
        [ class "suggestion"
        , onClick ToggleVisibility
        ]
        [ i
            [ class "suggestion-icon"
            , class "fas"
            , class "fa-exclamation-circle"
            ]
            []
        ]
    , div
        [ class "suggestion-bubble"
        , onMouseLeave AutoHide
        , if status.visible then
            Display.block

          else
            Display.none
        ]
        [ text status.message ]
    ]


subs : SuggestionPopup -> Sub Msg
subs (SuggestionPopup status) =
    if status.timeoutCounter > 0 then
        Time.every Time.second CountDown

    else
        Sub.none
