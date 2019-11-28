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


module Page.Triggers exposing (Model, Msg, init, subscriptions, update, view)

import AstarteApi
import Bootstrap.Button as Button
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html, a, h4, h5, text)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Icons
import Route
import Spinner
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)


type alias Model =
    { triggers : List String
    , spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { triggers = []
      , spinner = Spinner.init
      , showSpinner = True
      }
    , AstarteApi.listTriggers session.apiConfig
        GetTriggerListDone
        (ShowError "Could not retrieve trigger list")
        RedirectToLogin
    )


type Msg
    = GetTriggerList
    | GetTriggerListDone (List String)
    | AddNewTrigger
    | ShowError String AstarteApi.Error
    | RedirectToLogin
    | Forward ExternalMsg
      -- spinner
    | SpinnerMsg Spinner.Msg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetTriggerList ->
            ( { model | showSpinner = True }
            , AstarteApi.listTriggers session.apiConfig
                GetTriggerListDone
                (ShowError "Could not retrieve trigger list")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        GetTriggerListDone triggerNames ->
            ( { model
                | triggers = triggerNames
                , showSpinner = False
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        AddNewTrigger ->
            ( model
            , Cmd.none
            , ExternalMsg.RequestRoute (Route.Realm Route.NewTrigger)
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

        RedirectToLogin ->
            ( model
            , Cmd.none
            , ExternalMsg.RequestRoute (Route.Realm Route.Logout)
            )

        Forward externalMsg ->
            ( model
            , Cmd.none
            , externalMsg
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
        , if model.showSpinner then
            Spinner.view Spinner.defaultConfig model.spinner

          else
            text ""
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
                    [ if List.isEmpty model.triggers then
                        text "No trigger installed"

                      else
                        text "Triggers"
                    ]
                , Button.button
                    [ Button.primary
                    , Button.onClick AddNewTrigger
                    , Button.attrs [ class "float-right" ]
                    ]
                    [ text "Install a New trigger ..." ]
                , Button.button
                    [ Button.primary
                    , Button.onClick GetTriggerList
                    , Button.attrs [ class "float-right", Spacing.mr1 ]
                    ]
                    [ Icons.render Icons.Reload [ Spacing.mr2 ]
                    , text "Reload"
                    ]
                ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ ListGroup.ul <| List.map renderSingleTrigger model.triggers ]
            ]
        ]


renderSingleTrigger : String -> ListGroup.Item Msg
renderSingleTrigger triggerName =
    ListGroup.li
        [ ListGroup.attrs [ Spacing.p0, Spacing.mb2 ] ]
        [ h4
            [ class "card-header" ]
            [ a
                [ href <| Route.toString <| Route.Realm (Route.ShowTrigger triggerName) ]
                [ text triggerName ]
            ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.showSpinner then
        Sub.map SpinnerMsg Spinner.subscription

    else
        Sub.none
