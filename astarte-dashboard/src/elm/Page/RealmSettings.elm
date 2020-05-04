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


module Page.RealmSettings exposing (Model, Msg, init, subscriptions, update, view)

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
import Html exposing (Html, h5, p, text)
import Html.Attributes exposing (class, for)
import Icons
import Route
import Spinner
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.RealmConfig exposing (RealmConfig)
import Types.Session exposing (Session)


type alias Model =
    { conf : Maybe RealmConfig
    , initialKey : String
    , keyChanged : Bool
    , confirmModalVisibility : Modal.Visibility
    , spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { conf = Nothing
      , initialKey = ""
      , keyChanged = False
      , confirmModalVisibility = Modal.hidden
      , spinner = Spinner.init
      , showSpinner = True
      }
    , AstarteApi.realmConfig session.apiConfig
        GetRealmConfDone
        (ShowError "Could not retrieve the realm configuration")
        RedirectToLogin
    )


type ModalResult
    = ModalCancel
    | ModalOk


type Msg
    = GetRealmConf
    | GetRealmConfDone RealmConfig
    | UpdateRealmConfDone
    | UpdatePubKey String
    | RedirectToLogin
    | ShowError String AstarteApi.Error
    | Forward ExternalMsg
      -- Modal
    | ShowConfirmModal
    | CloseConfirmModal ModalResult
      -- spinner
    | SpinnerMsg Spinner.Msg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetRealmConf ->
            ( model
            , AstarteApi.realmConfig session.apiConfig
                GetRealmConfDone
                (ShowError "Could not retrieve the realm configuration")
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

        UpdateRealmConfDone ->
            let
                addFlashMessageCmd =
                    ExternalMsg.AddFlashMessage FlashMessage.Notice "Realm configuration has been successfully applied." []
            in
            ( model
            , Cmd.none
            , if model.keyChanged then
                ExternalMsg.Batch
                    [ addFlashMessageCmd
                    , ExternalMsg.RequestRoute <| Route.Realm Route.Logout
                    ]

              else
                addFlashMessageCmd
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
            , Cmd.none
            , ExternalMsg.RequestRoute <| Route.Realm Route.Logout
            )

        ShowError actionError apiError ->
            let
                ( apiErrorTitle, apiErrorDetails ) =
                    AstarteApi.errorToHumanReadable apiError

                flashmessageTitle =
                    String.concat [ actionError, ": ", apiErrorTitle ]
            in
            ( { model | showSpinner = False }
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error flashmessageTitle apiErrorDetails
            )

        Forward externalMsg ->
            ( model
            , Cmd.none
            , externalMsg
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
                    , AstarteApi.updateRealmConfig session.apiConfig
                        config
                        UpdateRealmConfDone
                        (ShowError "Could not apply realm configuration")
                        RedirectToLogin
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( { model | confirmModalVisibility = Modal.hidden }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        SpinnerMsg spinnerMsg ->
            ( { model | spinner = Spinner.update spinnerMsg model.spinner }
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
                [ Html.h3 []
                    [ text "Realm Settings" ]
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
                    [ Icons.render Icons.Reload [ Spacing.mr2 ]
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


renderConfig : Maybe RealmConfig -> Html Msg
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
                                , Textarea.attrs [ class "text-monospace" ]
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.showSpinner then
        Sub.map SpinnerMsg Spinner.subscription

    else
        Sub.none
