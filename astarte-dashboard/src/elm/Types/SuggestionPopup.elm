module Types.SuggestionPopup exposing (SuggestionPopup, Msg, new, update, view, subs)

import Html exposing (Html, div, i, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, onMouseLeave)
import Time exposing (Time)


-- bootstrap components

import Bootstrap.Utilities.Display as Display


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
