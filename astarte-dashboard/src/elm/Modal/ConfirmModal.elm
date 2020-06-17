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


module Modal.ConfirmModal exposing (ExternalMsg(..), ModalType(..), Model, Msg(..), init, update, view)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid.Col as Col
import Bootstrap.Modal as Modal
import Html exposing (Html)
import Html.Attributes exposing (for, value)
import HtmlUtils


type alias Model =
    { title : String
    , body : String
    , action : String
    , modalType : ModalType
    , visibility : Modal.Visibility
    }


type ModalType
    = Normal
    | Danger


init : String -> String -> Maybe String -> Maybe ModalType -> Bool -> Model
init modalTitle body action modalType shown =
    { title = modalTitle
    , body = body
    , action = action |> Maybe.withDefault "Confirm"
    , modalType = modalType |> Maybe.withDefault Normal
    , visibility =
        if shown then
            Modal.shown

        else
            Modal.hidden
    }


type ModalResult
    = ModalCancel
    | ModalOk


type Msg
    = Close ModalResult


type ExternalMsg
    = Noop
    | Cancel
    | Confirm


update : Msg -> Model -> ( Model, ExternalMsg )
update message model =
    case message of
        Close ModalCancel ->
            ( { model | visibility = Modal.hidden }
            , Cancel
            )

        Close ModalOk ->
            ( { model | visibility = Modal.hidden }
            , Confirm
            )


view : Model -> Html Msg
view model =
    Modal.config (Close ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ Html.text model.title ]
        |> Modal.body []
            [ Html.p [] [ Html.text model.body ]
            ]
        |> Modal.footer []
            [ Button.button
                [ Button.secondary
                , Button.onClick <| Close ModalCancel
                ]
                [ Html.text "Cancel" ]
            , Button.button
                [ buttonStyle model.modalType
                , Button.onClick <| Close ModalOk
                ]
                [ Html.text model.action ]
            ]
        |> Modal.view model.visibility
        |> HtmlUtils.handleEnterKeyPress (Close ModalOk) True


buttonStyle : ModalType -> Button.Option Msg
buttonStyle modalType =
    case modalType of
        Normal ->
            Button.primary

        Danger ->
            Button.danger
