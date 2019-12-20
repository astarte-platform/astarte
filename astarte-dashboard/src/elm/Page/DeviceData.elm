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


module Page.DeviceData exposing (Model, Msg(..), init, subscriptions, update, view)

import AstarteApi
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Table as Table
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html, h5)
import Html.Attributes exposing (class)
import ListUtils exposing (addWhen)
import Spinner
import Time
import Types.AstarteValue as AstarteValue exposing (AstarteValue)
import Types.DeviceData as DeviceData exposing (DeviceData)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)


type alias Model =
    { deviceId : String
    , interfaceName : String
    , deviceData : List DeviceData
    , spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> String -> String -> ( Model, Cmd Msg )
init session deviceId interfaceName =
    ( { deviceId = deviceId
      , interfaceName = interfaceName
      , deviceData = []
      , spinner = Spinner.init
      , showSpinner = True
      }
    , AstarteApi.deviceData session.apiConfig deviceId interfaceName <| DeviceDataDone
    )


type Msg
    = UpdateInterfaceData Time.Posix
    | DeviceDataDone (Result AstarteApi.Error (List DeviceData))
    | Forward ExternalMsg
    | SpinnerMsg Spinner.Msg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        UpdateInterfaceData _ ->
            ( { model | showSpinner = True }
            , AstarteApi.deviceData session.apiConfig model.deviceId model.interfaceName <| DeviceDataDone
            , ExternalMsg.Noop
            )

        DeviceDataDone (Ok data) ->
            ( { model
                | deviceData = data
                , showSpinner = False
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        DeviceDataDone (Err error) ->
            let
                -- TODO handle error
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
                    [ Html.text <| "Device data for interface " ++ model.interfaceName ]
                ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ renderDeviceDataTable model.deviceData ]
            ]
        ]


renderDeviceDataTable : List DeviceData -> Html Msg
renderDeviceDataTable datalist =
    Table.simpleTable
        ( Table.simpleThead
            [ Table.th [] [ Html.text "Path" ]
            , Table.th [] [ Html.text "Value" ]
            , Table.th [] [ Html.text "Reception timestamp" ]
            ]
        , Table.tbody []
            (DeviceData.flatten datalist
                |> List.map renderDeviceDataTableHelper
            )
        )


renderDeviceDataTableHelper : ( String, AstarteValue, Time.Posix ) -> Table.Row Msg
renderDeviceDataTableHelper ( path, value, timestamp ) =
    Table.tr []
        [ Table.td []
            [ Html.text path ]
        , Table.td []
            [ Html.text <| AstarteValue.toString value ]
        , Table.td []
            [ Html.text <| timestampToString timestamp ]
        ]


timestampToString : Time.Posix -> String
timestampToString time =
    let
        -- TODO detect this from config/javascript
        timezone =
            Time.utc
    in
    [ String.fromInt <| Time.toYear timezone time
    , "/"
    , monthToStringNumber <| Time.toMonth timezone time
    , "/"
    , String.padLeft 2 '0' <| String.fromInt <| Time.toDay timezone time
    , " "
    , String.padLeft 2 '0' <| String.fromInt <| Time.toHour timezone time
    , ":"
    , String.padLeft 2 '0' <| String.fromInt <| Time.toMinute timezone time
    , ":"
    , String.padLeft 2 '0' <| String.fromInt <| Time.toSecond timezone time
    , "."
    , String.padLeft 3 '0' <| String.fromInt <| Time.toMillis timezone time
    ]
        |> String.join ""


monthToStringNumber : Time.Month -> String
monthToStringNumber month =
    case month of
        Time.Jan ->
            "01"

        Time.Feb ->
            "02"

        Time.Mar ->
            "03"

        Time.Apr ->
            "04"

        Time.May ->
            "05"

        Time.Jun ->
            "06"

        Time.Jul ->
            "07"

        Time.Aug ->
            "08"

        Time.Sep ->
            "09"

        Time.Oct ->
            "10"

        Time.Nov ->
            "11"

        Time.Dec ->
            "12"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    [ Time.every (30 * 1000) UpdateInterfaceData
    ]
        |> addWhen model.showSpinner (Sub.map SpinnerMsg Spinner.subscription)
        |> Sub.batch
