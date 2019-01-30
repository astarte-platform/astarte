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


module Page.RealmSettings exposing (Model, Msg, init, update, view)

import AstarteApi
import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Modal as Modal
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html, h5, i, p, text)
import Html.Attributes exposing (class, for)
import Navigation
import Route
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.RealmConfig exposing (Config)
import Types.Session exposing (Session)


type alias Model =
    { conf : Maybe Config
    , initialKey : String
    , keyChanged : Bool
    , confirmModalVisibility : Modal.Visibility
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { conf = Nothing
      , initialKey = ""
      , keyChanged = False
      , confirmModalVisibility = Modal.hidden
      }
    , AstarteApi.realmConfig session
        GetRealmConfDone
        GetRealmConfError
        RedirectToLogin
    )


type ModalResult
    = ModalCancel
    | ModalOk


type Msg
    = GetRealmConf
    | GetRealmConfDone Config
    | GetRealmConfError String
    | UpdateRealmConfDone String
    | UpdateRealmConfError String
    | UpdatePubKey String
    | RedirectToLogin
    | Forward ExternalMsg
      -- Modal
    | ShowConfirmModal
    | CloseConfirmModal ModalResult


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetRealmConf ->
            ( model
            , AstarteApi.realmConfig session
                GetRealmConfDone
                GetRealmConfError
                RedirectToLogin
            , ExternalMsg.Noop
            )

        GetRealmConfDone config ->
            ( { model
                | conf = Just config
                , initialKey = config.pubKey
                , keyChanged = False
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        GetRealmConfError errorMessage ->
            ( model
            , Cmd.none
            , ("Cannot retrieve the realm configuration. " ++ errorMessage)
                |> ExternalMsg.AddFlashMessage FlashMessage.Error
            )

        UpdateRealmConfDone response ->
            ( model
            , if model.keyChanged then
                Navigation.modifyUrl <| Route.toString (Route.Realm Route.Logout)

              else
                Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Realm configuration has been successfully applied."
            )

        UpdateRealmConfError errorMessage ->
            ( model
            , Cmd.none
            , ("Cannot apply realm configuration. " ++ errorMessage)
                |> ExternalMsg.AddFlashMessage FlashMessage.Error
            )

        UpdatePubKey newPubKey ->
            let
                newConfig =
                    case model.conf of
                        Just config ->
                            { config | pubKey = newPubKey }

                        Nothing ->
                            { pubKey = newPubKey }
            in
            ( { model
                | conf = Just newConfig
                , keyChanged = model.initialKey /= newPubKey
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        RedirectToLogin ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm Route.Logout)
            , ExternalMsg.Noop
            )

        Forward msg ->
            ( model
            , Cmd.none
            , msg
            )

        ShowConfirmModal ->
            ( { model | confirmModalVisibility = Modal.shown }
            , Cmd.none
            , ExternalMsg.Noop
            )

        CloseConfirmModal result ->
            case ( result, model.conf ) of
                ( ModalOk, Just config ) ->
                    ( { model | confirmModalVisibility = Modal.hidden }
                    , AstarteApi.updateRealmConfig config
                        session
                        UpdateRealmConfDone
                        UpdateRealmConfError
                        RedirectToLogin
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( { model | confirmModalVisibility = Modal.hidden }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.containerFluid
        [ class "bg-white"
        , Border.rounded
        , Spacing.pb3
        ]
        [ Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ h5
                    [ Display.inline
                    , class "text-secondary"
                    , class "font-weight-normal"
                    , class "align-middle"
                    ]
                    [ text "Realm settings" ]
                ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ renderConfig model.conf
                , Button.button
                    [ Button.primary
                    , Button.onClick GetRealmConf
                    , Button.attrs [ Spacing.mt2, Spacing.mr1 ]
                    ]
                    [ i [ class "fas", class "fa-sync-alt", Spacing.mr2 ] []
                    , text "Reload"
                    ]
                , Button.button
                    [ Button.primary
                    , Button.onClick ShowConfirmModal
                    , Button.attrs [ Spacing.mt2 ]
                    ]
                    [ text "Save" ]
                ]
            ]
        , renderConfirmModal model.confirmModalVisibility model.keyChanged
        ]


renderConfig : Maybe Config -> Html Msg
renderConfig mConfig =
    case mConfig of
        Just conf ->
            Form.form []
                [ Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ Form.group []
                            [ Form.label [ for "realmPublicKey" ] [ text "Public key" ]
                            , Textarea.textarea
                                [ Textarea.id "realmPublicKey"
                                , Textarea.rows 10
                                , Textarea.value conf.pubKey
                                , Textarea.onInput UpdatePubKey
                                ]
                            ]
                        ]
                    ]
                ]

        Nothing ->
            text ""


renderConfirmModal : Modal.Visibility -> Bool -> Html Msg
renderConfirmModal modalVisibility keyChanged =
    Modal.config (CloseConfirmModal ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ text "Confirmation Required" ]
        |> Modal.body []
            [ Grid.container []
                [ Grid.row []
                    [ Grid.col
                        [ Col.sm12 ]
                        [ p []
                            [ text <|
                                if keyChanged then
                                    "Realm public key will be changed, users will not be able to make further API calls using their current auth token."

                                else
                                    "Realm configuration will be changed."
                            ]
                        , text "Confirm?"
                        ]
                    ]
                ]
            ]
        |> Modal.footer []
            [ Button.button
                [ Button.secondary
                , Button.onClick <| CloseConfirmModal ModalCancel
                ]
                [ text "Cancel" ]
            , Button.button
                [ Button.primary
                , Button.onClick <| CloseConfirmModal ModalOk
                ]
                [ text "Confirm" ]
            ]
        |> Modal.view modalVisibility
