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


module Page.DeviceList exposing (Model, Msg(..), init, subscriptions, update, view)

import AstarteApi
import Bootstrap.Button as Button
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Table as Table
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing
import Dict exposing (Dict)
import Html exposing (Html, h5)
import Html.Attributes exposing (class, for, href)
import Icons exposing (Icon)
import Route
import Spinner
import Types.Device exposing (Device)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)


type alias Model =
    { deviceList : List Device
    , spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { deviceList = []
      , spinner = Spinner.init
      , showSpinner = True
      }
    , AstarteApi.detailedDeviceList session.apiConfig <| DeviceListDone
    )


type Msg
    = RefreshTable
    | Forward ExternalMsg
      -- spinner
    | SpinnerMsg Spinner.Msg
      -- API
    | DeviceListDone (Result AstarteApi.Error (List Device))


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        RefreshTable ->
            ( { model | showSpinner = True }
            , AstarteApi.detailedDeviceList session.apiConfig <| DeviceListDone
            , ExternalMsg.Noop
            )

        DeviceListDone result ->
            case result of
                Ok deviceList ->
                    ( { model
                        | deviceList = deviceList
                        , showSpinner = False
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                -- TODO handle error
                Err error ->
                    let
                        ( message, details ) =
                            AstarteApi.errorToHumanReadable error
                    in
                    ( { model | showSpinner = False }
                    , Cmd.none
                    , ExternalMsg.AddFlashMessage FlashMessage.Error message details
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
                    [ Html.text "Device list" ]
                , Button.button
                    [ Button.primary
                    , Button.onClick RefreshTable
                    , Button.attrs [ class "float-right" ]
                    ]
                    [ Icons.render Icons.Reload [ Spacing.mr2 ]
                    , Html.text "Reload"
                    ]
                ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ deviceTable model.deviceList
                ]
            ]
        ]


deviceTable : List Device -> Html Msg
deviceTable deviceList =
    Table.table
        { options =
            [ Table.striped ]
        , thead =
            Table.simpleThead
                [ Table.th [] [ Html.text "Status" ]
                , Table.th [] [ Html.text "Device ID / name" ]
                , Table.th [] [ Html.text "Last connection event" ]
                ]
        , tbody =
            Table.tbody [] (List.map deviceRow deviceList)
        }


deviceRow : Device -> Table.Row Msg
deviceRow device =
    let
        displayNameCell =
            case Dict.get "name" device.aliases of
                Just displayName ->
                    Table.td []
                        [ Html.a
                            [ href <| Route.toString <| Route.Realm (Route.ShowDevice device.id) ]
                            [ Html.text displayName ]
                        ]

                Nothing ->
                    Table.td
                        [ Table.cellAttr <| class "text-monospace" ]
                        [ Html.a
                            [ href <| Route.toString <| Route.Realm (Route.ShowDevice device.id) ]
                            [ Html.text device.id ]
                        ]

        ( statusCell, lastEventCell ) =
            if device.connected then
                ( Table.td [] [ Icons.render Icons.FullCircle [ class "icon-connected" ] ]
                , Table.td [] [ Html.text <| "Connected at " ++ device.lastConnection ]
                )

            else
                ( Table.td [] [ Icons.render Icons.FullCircle [ class "icon-disconnected" ] ]
                , Table.td [] [ Html.text <| "Disconnected at " ++ device.lastDisconnection ]
                )
    in
    Table.tr []
        [ statusCell
        , displayNameCell
        , lastEventCell
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.showSpinner then
        Sub.map SpinnerMsg Spinner.subscription

    else
        Sub.none
