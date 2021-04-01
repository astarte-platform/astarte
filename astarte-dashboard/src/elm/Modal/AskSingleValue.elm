{-
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl

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


module Modal.AskSingleValue exposing
    ( ExternalMsg(..)
    , Model
    , Msg(..)
    , ValueValidation(..)
    , init
    , update
    , view
    )

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid.Col as Col
import Bootstrap.Modal as Modal
import Html exposing (Html)
import Html.Attributes exposing (for, value)
import Html.Events
import HtmlUtils


type alias Model =
    { title : String
    , valueLabel : String
    , value : String
    , valueValidation : ValueValidation
    , confirmLabel : String
    , visibility : Modal.Visibility
    }


init : String -> String -> ValueValidation -> Bool -> String -> Model
init modalTitle valueLabel valueValidation shown confirmLabel =
    { title = modalTitle
    , valueLabel = valueLabel
    , value = ""
    , valueValidation = valueValidation
    , confirmLabel = confirmLabel
    , visibility =
        if shown then
            Modal.shown

        else
            Modal.hidden
    }


type ValueValidation
    = AnyValue
    | Trimmed


type ModalResult
    = ModalCancel
    | ModalOk


type Msg
    = Close ModalResult
    | UpdateValue String
    | PreventSubmit


type ExternalMsg
    = Noop
    | Cancel
    | Confirm String


update : Msg -> Model -> ( Model, ExternalMsg )
update message model =
    case message of
        Close ModalCancel ->
            ( { model | visibility = Modal.hidden }
            , Cancel
            )

        Close ModalOk ->
            ( { model | visibility = Modal.hidden }
            , Confirm (adaptValue model.value model.valueValidation)
            )

        UpdateValue newValue ->
            ( { model | value = newValue }
            , Noop
            )

        PreventSubmit ->
            ( model
            , Noop
            )


adaptValue : String -> ValueValidation -> String
adaptValue value validation =
    case validation of
        AnyValue ->
            value

        Trimmed ->
            String.trim value


invalidForm : String -> ValueValidation -> Bool
invalidForm value valueValidation =
    case valueValidation of
        AnyValue ->
            False

        Trimmed ->
            String.isEmpty <| String.trim value


view : Model -> Html Msg
view model =
    let
        disableSubmit =
            invalidForm model.value model.valueValidation
    in
    Modal.config (Close ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ Html.text model.title ]
        |> Modal.body []
            [ renderBody model.valueLabel model.value ]
        |> Modal.footer []
            [ Button.button
                [ Button.secondary
                , Button.onClick <| Close ModalCancel
                ]
                [ Html.text "Cancel" ]
            , Button.button
                [ Button.primary
                , Button.disabled disableSubmit
                , Button.onClick <| Close ModalOk
                ]
                [ Html.text model.confirmLabel ]
            ]
        |> Modal.view model.visibility
        |> HtmlUtils.handleEnterKeyPress (Close ModalOk) (not disableSubmit)


renderBody : String -> String -> Html Msg
renderBody valueLabel value =
    Form.form [ Html.Events.onSubmit PreventSubmit ]
        [ Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "value" ] [ Html.text valueLabel ]
                    , Input.text
                        [ Input.id "value"
                        , Input.value value
                        , Input.onInput UpdateValue
                        ]
                    ]
                ]
            ]
        ]
