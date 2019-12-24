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


module Modal.NewAlias exposing (ExternalMsg(..), Model, Msg(..), init, update, view)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid.Col as Col
import Bootstrap.Modal as Modal
import Html exposing (Html)
import Html.Attributes exposing (for, value)


type alias Model =
    { aliasTag : String
    , aliasValue : String
    , visibility : Modal.Visibility
    }


init : Bool -> Model
init shown =
    { aliasTag = ""
    , aliasValue = ""
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
    | UpdateAliasTag String
    | UpdateAliasValue String


type ExternalMsg
    = Noop
    | AddAlias String String


update : Msg -> Model -> ( Model, ExternalMsg )
update message model =
    case message of
        Close ModalCancel ->
            ( { model | visibility = Modal.hidden }
            , Noop
            )

        Close ModalOk ->
            ( { model | visibility = Modal.hidden }
            , AddAlias model.aliasTag model.aliasValue
            )

        UpdateAliasTag newTag ->
            ( { model | aliasTag = newTag }
            , Noop
            )

        UpdateAliasValue newValue ->
            ( { model | aliasValue = newValue }
            , Noop
            )


view : Model -> Html Msg
view model =
    Modal.config (Close ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ Html.text "Add New Alias" ]
        |> Modal.body []
            [ renderBody model.aliasTag model.aliasValue ]
        |> Modal.footer []
            [ Button.button
                [ Button.secondary
                , Button.onClick <| Close ModalCancel
                ]
                [ Html.text "Cancel" ]
            , Button.button
                [ Button.primary
                , Button.disabled <| String.isEmpty model.aliasTag || String.isEmpty model.aliasValue
                , Button.onClick <| Close ModalOk
                ]
                [ Html.text "Confirm" ]
            ]
        |> Modal.view model.visibility


renderBody : String -> String -> Html Msg
renderBody aliasTag aliasValue =
    Form.form []
        [ Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "aliasTag" ] [ Html.text "Tag" ]
                    , Input.text
                        [ Input.id "aliasTag"
                        , Input.value aliasTag
                        , Input.onInput UpdateAliasTag
                        ]
                    ]
                ]
            ]
        , Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "aliasValue" ] [ Html.text "Alias" ]
                    , Input.text
                        [ Input.id "aliasValue"
                        , Input.value aliasValue
                        , Input.onInput UpdateAliasValue
                        ]
                    ]
                ]
            ]
        ]
