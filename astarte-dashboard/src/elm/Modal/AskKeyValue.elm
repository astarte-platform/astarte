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


module Modal.AskKeyValue exposing
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
import Json.Decode as Decode exposing (Decoder)


type alias Model =
    { title : String
    , keyLabel : String
    , valueLabel : String
    , key : String
    , value : String
    , valueValidation : ValueValidation
    , visibility : Modal.Visibility
    }


init : String -> String -> String -> ValueValidation -> Bool -> Model
init modalTitle keyLabel valueLabel valueValidation shown =
    { title = modalTitle
    , keyLabel = keyLabel
    , valueLabel = valueLabel
    , key = ""
    , value = ""
    , valueValidation = valueValidation
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
    | UpdateKey String
    | UpdateValue String


type ExternalMsg
    = Noop
    | Cancel
    | Confirm String String


update : Msg -> Model -> ( Model, ExternalMsg )
update message model =
    case message of
        Close ModalCancel ->
            ( { model | visibility = Modal.hidden }
            , Cancel
            )

        Close ModalOk ->
            let
                key =
                    String.trim model.key

                value =
                    adaptValue model.value model.valueValidation
            in
            ( { model | visibility = Modal.hidden }
            , Confirm key value
            )

        UpdateKey newKey ->
            ( { model | key = newKey }
            , Noop
            )

        UpdateValue newValue ->
            ( { model | value = newValue }
            , Noop
            )


adaptValue : String -> ValueValidation -> String
adaptValue value validation =
    case validation of
        AnyValue ->
            value

        Trimmed ->
            String.trim value


invalidForm : String -> String -> ValueValidation -> Bool
invalidForm key value valueValidation =
    let
        invalidKey =
            String.trim key
                |> String.isEmpty

        invalidValue =
            case valueValidation of
                AnyValue ->
                    False

                Trimmed ->
                    String.isEmpty <| String.trim value
    in
    invalidKey || invalidValue


view : Model -> Html Msg
view model =
    let
        disableSubmit =
            invalidForm model.key model.value model.valueValidation
    in
    Modal.config (Close ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ Html.text model.title ]
        |> Modal.body []
            [ renderBody model.keyLabel model.valueLabel model.key model.value ]
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
                [ Html.text "Confirm" ]
            ]
        |> Modal.view model.visibility
        |> HtmlUtils.handleEnterKeyPress (Close ModalOk) (not disableSubmit)


renderBody : String -> String -> String -> String -> Html Msg
renderBody keyLabel valueLabel key value =
    Form.form []
        [ Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "key" ] [ Html.text keyLabel ]
                    , Input.text
                        [ Input.id "key"
                        , Input.value key
                        , Input.onInput UpdateKey
                        ]
                    ]
                ]
            ]
        , Form.row []
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
