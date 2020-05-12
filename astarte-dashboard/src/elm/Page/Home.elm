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


module Page.Home exposing (Model, Msg, init, subscriptions, update, view)

import Assets
import AstarteApi exposing (DeviceStats)
import Bootstrap.Button as Button
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Color exposing (Color)
import Html exposing (Html)
import Html.Attributes exposing (class, href, src, target)
import Icons
import Maybe.Extra exposing (values)
import Spinner
import TypedSvg as Svg
import TypedSvg.Attributes as SvgAttr
import TypedSvg.Types as SvgTypes
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)
import Ui.Card as Card


type alias Model =
    { deviceStats : Maybe DeviceStats
    , appengineHealth : Maybe Bool
    , realmManagementHealth : Maybe Bool
    , pairingHealth : Maybe Bool
    , installedInterfaces : Maybe Int
    , installedTriggers : Maybe Int
    , spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { deviceStats = Nothing
      , appengineHealth = Nothing
      , realmManagementHealth = Nothing
      , pairingHealth = Nothing
      , installedInterfaces = Nothing
      , installedTriggers = Nothing
      , spinner = Spinner.init
      , showSpinner = True
      }
    , Cmd.batch
        [ AstarteApi.deviceStats session.apiConfig DeviceStatsDone
        , AstarteApi.appEngineApiHealth session.apiConfig AppEngineHealthCheckDone
        , AstarteApi.realmManagementApiHealth session.apiConfig RealmManagementHealthCheckDone
        , AstarteApi.pairingApiHealth session.apiConfig PairingHealthCheckDone
        , AstarteApi.listInterfaces session.apiConfig ListInterfacesDone AstarteError LoginRequired
        , AstarteApi.listTriggers session.apiConfig ListTriggersDone AstarteError LoginRequired
        ]
    )


type Msg
    = Forward ExternalMsg
    | DeviceStatsDone (Result AstarteApi.Error DeviceStats)
    | AppEngineHealthCheckDone (Result AstarteApi.Error Bool)
    | RealmManagementHealthCheckDone (Result AstarteApi.Error Bool)
    | PairingHealthCheckDone (Result AstarteApi.Error Bool)
    | ListInterfacesDone (List String)
    | ListTriggersDone (List String)
    | AstarteError AstarteApi.Error
    | LoginRequired
      -- spinner
    | SpinnerMsg Spinner.Msg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update _ msg model =
    case msg of
        DeviceStatsDone (Ok stats) ->
            ( { model
                | showSpinner = False
                , deviceStats = Just stats
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        DeviceStatsDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( { model | showSpinner = False }
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        AppEngineHealthCheckDone (Ok healthy) ->
            ( { model | appengineHealth = Just healthy }
            , Cmd.none
            , ExternalMsg.Noop
            )

        AppEngineHealthCheckDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( { model | appengineHealth = Just False }
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        RealmManagementHealthCheckDone (Ok healthy) ->
            ( { model | realmManagementHealth = Just healthy }
            , Cmd.none
            , ExternalMsg.Noop
            )

        RealmManagementHealthCheckDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( { model | realmManagementHealth = Just False }
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        PairingHealthCheckDone (Ok healthy) ->
            ( { model | pairingHealth = Just healthy }
            , Cmd.none
            , ExternalMsg.Noop
            )

        PairingHealthCheckDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( { model | pairingHealth = Just False }
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        ListInterfacesDone interfaceList ->
            ( { model | installedInterfaces = Just <| List.length interfaceList }
            , Cmd.none
            , ExternalMsg.Noop
            )

        ListTriggersDone triggerList ->
            ( { model | installedTriggers = Just <| List.length triggerList }
            , Cmd.none
            , ExternalMsg.Noop
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

        _ ->
            ( model
            , Cmd.none
            , ExternalMsg.Noop
            )


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.containerFluid []
        [ Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
            ]
        , if model.showSpinner then
            Spinner.view Spinner.defaultConfig model.spinner

          else
            Html.text ""
        , Grid.row []
            (values
                [ Just (welcomeCard Card.FullWidth)
                , Just (apiHealthCard Card.HalfWidth model.appengineHealth model.realmManagementHealth model.pairingHealth)
                , Maybe.map (appengineCard Card.HalfWidth) model.deviceStats
                , Maybe.map (interfacesCard Card.HalfWidth) model.installedInterfaces
                , Maybe.map (triggersCard Card.HalfWidth) model.installedTriggers
                ]
            )
        ]


welcomeCard : Card.Width -> Grid.Column Msg
welcomeCard width =
    Card.viewHeadless
        width
        [ Grid.row []
            [ Grid.col
                [ Col.sm12
                , Col.attrs [ Flex.block ]
                ]
                [ Html.div
                    [ Display.inlineBlockMd
                    , Spacing.pl2
                    ]
                    [ Html.h2
                        [ Spacing.pt3 ]
                        [ Html.text "Welcome to Astarte Dashboard!" ]
                    , Html.p
                        [ Spacing.pl2 ]
                        [ Html.text "Here you can easily manage your Astarte realm."
                        , Html.br [] []
                        , Html.text "Read the"
                        , Html.a [ target "_blank", href "https://docs.astarte-platform.org/" ] [ Html.text " documentation " ]
                        , Html.text "for more detailed informations on Astarte."
                        ]
                    ]
                ]
            ]
        ]


interfacesCard : Card.Width -> Int -> Grid.Column Msg
interfacesCard width interfaceCount =
    Card.view "Interfaces"
        width
        [ Html.p []
            (if interfaceCount == 0 then
                [ Html.text "Interfaces defines how data is exchanged between Astarte and its peers."
                , Html.br [] []
                , Html.a
                    [ target "_blank", href "https://docs.astarte-platform.org/snapshot/030-interface.html" ]
                    [ Html.text "Learn more..." ]
                ]

             else
                [ Html.text <| String.fromInt interfaceCount ++ " installed interfaces." ]
            )
        , Html.p []
            [ Html.a
                [ href "/interfaces/new" ]
                [ Icons.render Icons.Add [ Spacing.mr1 ]
                , Html.text "Install new interface..."
                ]
            ]
        ]


triggersCard : Card.Width -> Int -> Grid.Column Msg
triggersCard width triggerCount =
    Card.view "Triggers"
        width
        [ Html.p []
            (if triggerCount == 0 then
                [ Html.text "Triggers in Astarte are the go-to mechanism for generating push events."
                , Html.br [] []
                , Html.text "Triggers allow users to specify conditions upon which a custom payload is delivered to a recipient, using a specific action, which usually maps to a specific transport/protocol, such as HTTP."
                , Html.br [] []
                , Html.a
                    [ target "_blank", href "https://docs.astarte-platform.org/snapshot/060-using_triggers.html" ]
                    [ Html.text "Learn more..." ]
                ]

             else
                [ Html.text <| String.fromInt triggerCount ++ " installed triggers." ]
            )
        , Html.p []
            [ Html.a
                [ href "/triggers/new" ]
                [ Icons.render Icons.Add [ Spacing.mr1 ]
                , Html.text "Install new trigger..."
                ]
            ]
        ]


apiHealthCard : Card.Width -> Maybe Bool -> Maybe Bool -> Maybe Bool -> Grid.Column Msg
apiHealthCard width appengineHelath realmManagementHealth pairingHealth =
    Card.view "API Health"
        width
        [ Card.subTitle "Realm management API"
        , renderHealth appengineHelath
        , Card.subTitle "AppEngine API"
        , renderHealth realmManagementHealth
        , Card.subTitle "Pairing API"
        , renderHealth pairingHealth
        ]


appengineCard : Card.Width -> DeviceStats -> Grid.Column Msg
appengineCard width stats =
    Card.view "Devices"
        width
        [ Card.subTitle "Total registered devices"
        , Card.simpleText <| String.fromInt stats.totalDevices
        , Card.subTitle "Currently connected devices"
        , Card.simpleText <| String.fromInt stats.connectedDevices ++ "/" ++ String.fromInt stats.totalDevices
        ]


renderHealth : Maybe Bool -> Html Msg
renderHealth healthy =
    case healthy of
        Nothing ->
            Card.simpleText "Checking..."

        Just True ->
            Html.p []
                [ Icons.renderWithColor Color.green Icons.Healthy [ Spacing.mr1 ]
                , Html.text "Healthy"
                ]

        Just False ->
            Html.p []
                [ Icons.renderWithColor Color.red Icons.Unhealthy [ Spacing.mr1 ]
                , Html.text "Unhealthy"
                ]


lighter : Float -> Color -> Color
lighter percent baseColor =
    let
        hslaColor =
            Color.toHsla baseColor

        newLightness =
            bind 0 1 <| hslaColor.lightness * (1 + percent)
    in
    { hslaColor | lightness = newLightness }
        |> Color.fromHsla


bind : Float -> Float -> Float -> Float
bind min max val =
    if val < min then
        min

    else if val > max then
        max

    else
        val



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.showSpinner then
        Sub.map SpinnerMsg Spinner.subscription

    else
        Sub.none
