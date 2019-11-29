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


module Page.Device exposing (Model, Msg(..), init, subscriptions, update, view)

import AstarteApi
import Bootstrap.Badge as Badge
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Table as Table
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Color exposing (Color)
import Dict exposing (Dict)
import Html exposing (Html, h5)
import Html.Attributes exposing (class)
import Icons
import Json.Decode as Decode exposing (Decoder)
import Ports
import Spinner
import Time
import Types.AstarteValue as AstarteValue
import Types.Device as Device exposing (Device)
import Types.DeviceEvent as DeviceEvent exposing (DeviceEvent)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)
import Ui.PieChart as PieChart


type alias Model =
    { deviceId : String
    , device : Maybe Device
    , receivedEvents : List JSEvent
    , spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> String -> ( Model, Cmd Msg )
init session deviceId =
    ( { deviceId = deviceId
      , device = Nothing
      , receivedEvents = []
      , spinner = Spinner.init
      , showSpinner = True
      }
    , AstarteApi.deviceInfos session.apiConfig deviceId <| DeviceInfosDone
    )


type Msg
    = Refresh
    | Forward ExternalMsg
      -- spinner
    | SpinnerMsg Spinner.Msg
      -- API
    | DeviceInfosDone (Result AstarteApi.Error Device)
      -- Ports
    | OnDeviceEventReceived (Result Decode.Error JSEvent)


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        Refresh ->
            ( { model | showSpinner = True }
            , AstarteApi.deviceInfos session.apiConfig model.deviceId <| DeviceInfosDone
            , ExternalMsg.Noop
            )

        DeviceInfosDone (Ok device) ->
            let
                interfaces =
                    device.introspection
                        |> List.map
                            (\i ->
                                case i of
                                    Device.InterfaceInfo name major _ _ _ ->
                                        { name = name
                                        , major = major
                                        }
                            )

                phoenixSocketParams =
                    { secureConnection = session.apiConfig.secureConnection
                    , appengineUrl = session.apiConfig.appengineUrl
                    , realm = session.apiConfig.realm
                    , token = session.apiConfig.token
                    , deviceId = model.deviceId
                    , interfaces = interfaces
                    }
            in
            ( { model
                | device = Just device
                , showSpinner = False
              }
            , Ports.listenToDeviceEvents phoenixSocketParams
            , ExternalMsg.Noop
            )

        DeviceInfosDone (Err error) ->
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

        OnDeviceEventReceived (Ok event) ->
            let
                newEventList =
                    List.append model.receivedEvents [ event ]
            in
            ( { model | receivedEvents = newEventList }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OnDeviceEventReceived (Err error) ->
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Unrecognized Device Event recerived" [ Decode.errorToString error ]
            )


type CardWidth
    = FullWidth
    | HalfWidth


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.containerFluid []
        (case model.device of
            Just device ->
                [ Grid.row
                    [ Row.attrs [ Spacing.mt2 ] ]
                    [ Grid.col
                        [ Col.sm12 ]
                        [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
                    ]
                , Grid.row []
                    [ deviceInfoCard device HalfWidth
                    , deviceEventsCard device HalfWidth
                    , deviceAliasesCard device HalfWidth
                    , deviceGroupsCard device HalfWidth
                    , deviceIntrospectionCard device HalfWidth
                    , devicePreviousInterfacesCard device HalfWidth
                    , deviceStatsCard device FullWidth
                    , deviceChannelCard model.receivedEvents FullWidth
                    ]
                ]

            Nothing ->
                [ Html.text "" ]
        )


renderCard : String -> CardWidth -> List (Html Msg) -> Grid.Column Msg
renderCard cardName width innerItems =
    let
        classWidth =
            case width of
                FullWidth ->
                    [ Col.xs12 ]

                HalfWidth ->
                    [ Col.xs12
                    , Col.md6
                    ]
    in
    Grid.col (classWidth ++ [ Col.attrs [ Spacing.p2 ] ])
        [ Grid.containerFluid
            [ class "bg-white", Border.rounded, Spacing.p3, Size.h100 ]
            ([ Grid.row
                [ Row.attrs [ Spacing.mt2 ] ]
                [ Grid.col [ Col.sm12 ]
                    [ h5
                        [ Display.inline
                        , class "text-secondary"
                        , class "font-weight-normal"
                        , class "align-middle"
                        ]
                        [ Html.text cardName ]
                    ]
                ]
             ]
                ++ innerItems
            )
        ]


deviceInfoCard : Device -> CardWidth -> Grid.Column Msg
deviceInfoCard device width =
    renderCard "Device Info"
        width
        [ renderTextRow ( "Device ID", device.id )
        , renderTextRow ( "Device name", Dict.get "name" device.aliases |> Maybe.withDefault "No name alias set" )
        , renderHtmlRow ( "Status", renderConnectionStatus device )
        , renderBoolRow ( "Credentials inhibited", device.credentialsinhibited )
        ]


type alias ComputedInterfaceStats =
    { name : String
    , bytes : Int
    , msgs : Int
    , percentBytes : Float
    , percentMsgs : Float
    }


deviceStatsCard : Device -> CardWidth -> Grid.Column Msg
deviceStatsCard device width =
    let
        fullInterfaceList =
            device.introspection ++ device.previousInterfaces

        introspectionStats =
            List.map (computeStats device.totalReceivedBytes device.totalReceivedMsgs) fullInterfaceList

        ( totalIntrospectionBytes, totalIntrospectionMsgs ) =
            computeTotalStats fullInterfaceList

        otherBytes =
            device.totalReceivedBytes - totalIntrospectionBytes

        otherMsgs =
            device.totalReceivedMsgs - totalIntrospectionMsgs

        others =
            { name = "Other"
            , bytes = otherBytes
            , msgs = otherMsgs
            , percentBytes = floatDivision otherBytes device.totalReceivedBytes |> Maybe.withDefault 0
            , percentMsgs = floatDivision otherMsgs device.totalReceivedMsgs |> Maybe.withDefault 0
            }

        total =
            { name = "Total"
            , bytes = device.totalReceivedBytes
            , msgs = device.totalReceivedMsgs
            , percentBytes = 1.0
            , percentMsgs = 1.0
            }

        piecharList =
            (introspectionStats ++ [ others ])
                |> List.map (\info -> ( info.name, toFloat info.bytes ))
                |> List.filter (\t -> Tuple.second t > 0)

        listLength =
            List.length piecharList

        preferedColors =
            List.range 0 (listLength - 1)
                |> List.map (\val -> Color.hsl (toFloat val / toFloat listLength) 0.7 0.7)

        chartParams =
            { width = 800
            , height = 800
            , colors = preferedColors
            , data = piecharList
            }
    in
    renderCard "Device stats" width <|
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm6 ]
                [ Table.simpleTable
                    ( Table.simpleThead
                        [ Table.th [] [ Html.text "Interface" ]
                        , Table.th [ Table.cellAttr <| class "text-right" ] [ Html.text "Bytes" ]
                        , Table.th [ Table.cellAttr <| class "text-right" ] [ Html.text "Bytes (%)" ]
                        , Table.th [ Table.cellAttr <| class "text-right" ] [ Html.text "Messages" ]
                        , Table.th [ Table.cellAttr <| class "text-right" ] [ Html.text "Messages (%)" ]
                        ]
                    , Table.tbody []
                        (List.map renderInterfaceStats <| introspectionStats ++ [ others, total ])
                    )
                ]
            , Grid.col
                [ Col.sm6, Col.attrs [ class "piechart-container" ] ]
                [ PieChart.view chartParams
                , Html.ul
                    [ class "list-unstyled"
                    , Display.inlineBlock
                    , Spacing.ml2
                    , Html.Attributes.style "vertical-align" "top"
                    ]
                    (List.map2 labelHelper piecharList preferedColors)
                ]
            ]
        ]


labelHelper : ( String, Float ) -> Color -> Html Msg
labelHelper ( name, _ ) color =
    Html.li []
        [ Html.span
            [ class "square"
            , Html.Attributes.style "background-color" <| Color.toCssString color
            , Spacing.mr1
            ]
            []
        , Html.text name
        ]


computeStats : Int -> Int -> Device.IntrospectionValue -> ComputedInterfaceStats
computeStats totalBytes totalMsgs introspectionValue =
    case introspectionValue of
        Device.InterfaceInfo interfaceName interfaceMajor interfaceMinor exchangedBytes exchangedMsgs ->
            { name =
                String.join "" [ interfaceName, " v", String.fromInt interfaceMajor, ".", String.fromInt interfaceMinor ]
            , bytes = exchangedBytes
            , msgs = exchangedMsgs
            , percentBytes = floatDivision exchangedBytes totalBytes |> Maybe.withDefault 0
            , percentMsgs = floatDivision exchangedMsgs totalMsgs |> Maybe.withDefault 0
            }


floatDivision : Int -> Int -> Maybe Float
floatDivision a b =
    if b == 0 then
        Nothing

    else
        Just <| toFloat a / toFloat b


computeTotalStats : List Device.IntrospectionValue -> ( Int, Int )
computeTotalStats values =
    List.foldl computeTotalStatsHelper ( 0, 0 ) values


computeTotalStatsHelper : Device.IntrospectionValue -> ( Int, Int ) -> ( Int, Int )
computeTotalStatsHelper introspectionValue ( totalBytes, totalMsgs ) =
    case introspectionValue of
        Device.InterfaceInfo _ _ _ bytes msgs ->
            ( totalBytes + bytes, totalMsgs + msgs )


renderInterfaceStats : ComputedInterfaceStats -> Table.Row Msg
renderInterfaceStats introspectionStats =
    renderStats
        introspectionStats.name
        introspectionStats.bytes
        introspectionStats.percentBytes
        introspectionStats.msgs
        introspectionStats.percentMsgs


renderStats : String -> Int -> Float -> Int -> Float -> Table.Row Msg
renderStats name bytes totalBytes msgs totalMsgs =
    Table.tr []
        [ Table.td []
            [ Html.text name ]
        , Table.td [ Table.cellAttr <| class "text-right" ]
            [ Html.text <| String.fromInt bytes ]
        , Table.td [ Table.cellAttr <| class "text-right" ]
            [ totalBytes
                |> formatPercentFloat
                |> Html.text
            ]
        , Table.td [ Table.cellAttr <| class "text-right" ]
            [ Html.text <| String.fromInt msgs ]
        , Table.td [ Table.cellAttr <| class "text-right" ]
            [ totalMsgs
                |> formatPercentFloat
                |> Html.text
            ]
        ]


formatPercentFloat : Float -> String
formatPercentFloat num =
    let
        stringPercent =
            floatDivision (round <| num * 10000) 100
                |> Maybe.withDefault 0
                |> String.fromFloat
    in
    stringPercent ++ "%"


deviceAliasesCard : Device -> CardWidth -> Grid.Column Msg
deviceAliasesCard device width =
    renderCard "Aliases"
        width
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ renderAliases device.aliases
                ]
            ]
        ]


deviceGroupsCard : Device -> CardWidth -> Grid.Column Msg
deviceGroupsCard device width =
    renderCard "Groups"
        width
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ renderGroups device.groups
                ]
            ]
        ]


deviceIntrospectionCard : Device -> CardWidth -> Grid.Column Msg
deviceIntrospectionCard device width =
    renderCard "Interfaces"
        width
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ renderIntrospectionInfo device.introspection ]
            ]
        ]


devicePreviousInterfacesCard : Device -> CardWidth -> Grid.Column Msg
devicePreviousInterfacesCard device width =
    renderCard "Previous Interfaces"
        width
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ renderPreviousInterfacesInfo device.previousInterfaces ]
            ]
        ]


deviceEventsCard : Device -> CardWidth -> Grid.Column Msg
deviceEventsCard device width =
    [ ( "Last seen IP", device.lastSeenIp )
    , ( "Last credentials request IP", device.lastCredentialsRequestIp )
    , ( "First registration", device.firstRegistration )
    , ( "First credentials request", device.firstCredentialsRequest )
    , ( "Last connection", device.lastConnection )
    , ( "Last disconnection", device.lastDisconnection )
    ]
        |> List.filterMap nonEmptyValue
        |> List.map renderTextRow
        |> renderCard "Device Status Events" width


deviceChannelCard : List JSEvent -> CardWidth -> Grid.Column Msg
deviceChannelCard events width =
    renderCard "Device Live Events"
        width
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ Html.div [ class "device-event-container", Spacing.p3 ]
                    [ Html.ul
                        [ class "list-unstyled" ]
                        (List.map renderEvent events)
                    ]
                ]
            ]
        ]


type LabelType
    = ChannelLabel
    | DeviceConnectedLabel
    | DeviceDisconnectedLabel
    | IncommingDataLabel


renderLabel : LabelType -> Html Msg
renderLabel labelType =
    case labelType of
        ChannelLabel ->
            Badge.badgeSecondary [ Spacing.mr2 ] [ Html.text "channel" ]

        DeviceConnectedLabel ->
            Badge.badgeSuccess [ Spacing.mr2 ] [ Html.text "device connected" ]

        DeviceDisconnectedLabel ->
            Badge.badgeDanger [ Spacing.mr2 ] [ Html.text "device disconnected" ]

        IncommingDataLabel ->
            Badge.badgeInfo [ Spacing.mr2 ] [ Html.text "incoming data" ]


renderEvent : JSEvent -> Html Msg
renderEvent event =
    case event of
        AstarteDeviceEvent deviceEvent ->
            renderDeviceEvent deviceEvent

        SystemMessage systemMessage ->
            let
                textColor =
                    case systemMessage.level of
                        Error ->
                            Color.red

                        _ ->
                            Color.hsl 0 0 0.4
            in
            renderEventItem systemMessage.timestamp (Just textColor) ChannelLabel <| Html.text systemMessage.message


renderDeviceEvent : DeviceEvent -> Html Msg
renderDeviceEvent event =
    let
        ( label, message ) =
            case event.data of
                DeviceEvent.DeviceConnected data ->
                    ( DeviceConnectedLabel
                    , Html.span [] [ Html.text <| "IP : " ++ data.ip ]
                    )

                DeviceEvent.DeviceDisconnected ->
                    ( DeviceDisconnectedLabel
                    , Html.span [] [ Html.text "Device disconnected" ]
                    )

                DeviceEvent.IncomingData data ->
                    ( IncommingDataLabel
                    , Html.span []
                        [ Html.span [ Spacing.mr2 ] [ Html.text <| data.interface ++ data.path ]
                        , Html.span [ class "text-monospace" ] [ Html.text <| AstarteValue.toString data.value ]
                        ]
                    )

                DeviceEvent.Other eventType ->
                    ( ChannelLabel
                    , Html.span [] [ Html.text <| "Unknown event type " ++ eventType ]
                    )

                _ ->
                    -- No trigger installed for those events
                    ( ChannelLabel
                    , Html.span [] [ Html.text "Error, unexpected event received" ]
                    )
    in
    renderEventItem event.timestamp Nothing label message


renderEventItem : Time.Posix -> Maybe Color -> LabelType -> Html Msg -> Html Msg
renderEventItem timestamp mColor label content =
    let
        classes =
            case mColor of
                Just textColor ->
                    [ Spacing.px2
                    , textColor
                        |> Color.toCssString
                        |> Html.Attributes.style "color"
                    ]

                Nothing ->
                    [ Spacing.px2 ]
    in
    Html.li classes
        [ Html.node "small"
            [ class "text-monospace"
            , Spacing.mr2
            , Color.hsl 0 0 0.4
                |> Color.toCssString
                |> Html.Attributes.style "color"
            ]
            [ Html.text <| "[" ++ timeToString timestamp ++ "]" ]
        , renderLabel label
        , content
        ]


renderConnectionStatus : Device -> Html Msg
renderConnectionStatus device =
    case ( device.lastConnection, device.connected ) of
        ( Nothing, _ ) ->
            Html.span []
                [ Icons.render Icons.FullCircle [ Spacing.mr1 ]
                , Html.text "Never connected"
                ]

        ( Just _, True ) ->
            Html.span []
                [ Icons.render Icons.FullCircle [ class "icon-connected", Spacing.mr1 ]
                , Html.text "Connected"
                ]

        ( Just _, False ) ->
            Html.span []
                [ Icons.render Icons.FullCircle [ class "icon-disconnected", Spacing.mr1 ]
                , Html.text "Disconnected"
                ]


renderGroups : List String -> Html Msg
renderGroups groups =
    if List.isEmpty groups then
        Html.text "Device does not belong to any group"

    else
        Html.ul [] (List.map renderGroupValue groups)


renderGroupValue : String -> Html Msg
renderGroupValue group =
    Html.li [] [ Html.text group ]


renderAliases : Dict String String -> Html Msg
renderAliases aliases =
    if Dict.isEmpty aliases then
        Html.text "Device has no aliases"

    else
        Table.simpleTable
            ( Table.simpleThead
                [ Table.th [] [ Html.text "Alias tag" ]
                , Table.th [] [ Html.text "Alias" ]
                ]
            , Table.tbody []
                (aliases
                    |> Dict.toList
                    |> List.map renderAlias
                )
            )


renderAlias : ( String, String ) -> Table.Row Msg
renderAlias ( key, value ) =
    Table.tr []
        [ Table.td []
            [ Html.text key ]
        , Table.td []
            [ Html.text value ]
        ]


renderHtmlRow : ( String, Html Msg ) -> Html Msg
renderHtmlRow ( label, value ) =
    Grid.row
        [ Row.attrs [ Spacing.mt3 ] ]
        [ Grid.col [ Col.sm12 ]
            [ Html.h6 [] [ Html.text label ]
            , value
            ]
        ]


renderTextRow : ( String, String ) -> Html Msg
renderTextRow ( label, value ) =
    renderHtmlRow ( label, Html.text value )


renderBoolRow : ( String, Bool ) -> Html Msg
renderBoolRow ( label, value ) =
    if value then
        renderTextRow ( label, "True" )

    else
        renderTextRow ( label, "False" )


renderIntrospectionInfo : List Device.IntrospectionValue -> Html Msg
renderIntrospectionInfo introspectionValues =
    if List.isEmpty introspectionValues then
        Html.text "No introspection info"

    else
        Html.ul [] (List.map renderIntrospectionValue introspectionValues)


renderPreviousInterfacesInfo : List Device.IntrospectionValue -> Html Msg
renderPreviousInterfacesInfo previousInterfaces =
    if List.isEmpty previousInterfaces then
        Html.text "No previous interfaces info"

    else
        Html.ul [] (List.map renderIntrospectionValue previousInterfaces)


renderIntrospectionValue : Device.IntrospectionValue -> Html Msg
renderIntrospectionValue value =
    case value of
        Device.InterfaceInfo name major minor _ _ ->
            Html.li []
                [ [ name, " v", String.fromInt major, ".", String.fromInt minor ]
                    |> String.join ""
                    |> Html.text
                ]


nonEmptyValue : ( String, Maybe String ) -> Maybe ( String, String )
nonEmptyValue ( label, maybeVal ) =
    case maybeVal of
        Just value ->
            Just ( label, value )

        Nothing ->
            Nothing


timeToString : Time.Posix -> String
timeToString time =
    let
        -- TODO detect this from config/javascript
        timezone =
            Time.utc
    in
    [ String.padLeft 2 '0' <| String.fromInt <| Time.toHour timezone time
    , ":"
    , String.padLeft 2 '0' <| String.fromInt <| Time.toMinute timezone time
    , ":"
    , String.padLeft 2 '0' <| String.fromInt <| Time.toSecond timezone time
    , "."
    , String.padLeft 3 '0' <| String.fromInt <| Time.toMillis timezone time
    ]
        |> String.join ""



-- JS messages decoding


type JSEvent
    = SystemMessage SystemEvent
    | AstarteDeviceEvent DeviceEvent


type alias SystemEvent =
    { level : MessageLevel
    , message : String
    , timestamp : Time.Posix
    }


type MessageLevel
    = Error
    | Warning
    | Info
    | Debug


systemEventDecoder : Decoder SystemEvent
systemEventDecoder =
    Decode.map3 SystemEvent
        (Decode.field "level" Decode.string |> Decode.andThen messageLevelDecoder)
        (Decode.field "message" Decode.string)
        (Decode.field "timestamp" Decode.int |> Decode.andThen timeDecoder)


timeDecoder : Int -> Decoder Time.Posix
timeDecoder t =
    Decode.succeed <| Time.millisToPosix t


messageLevelDecoder : String -> Decoder MessageLevel
messageLevelDecoder s =
    case s of
        "error" ->
            Decode.succeed Error

        "warning" ->
            Decode.succeed Warning

        "info" ->
            Decode.succeed Info

        "debug" ->
            Decode.succeed Debug

        _ ->
            Decode.fail "unknown message level"


jsReplyDecoder : Decoder JSEvent
jsReplyDecoder =
    Decode.oneOf
        [ Decode.map AstarteDeviceEvent DeviceEvent.decoder
        , Decode.map SystemMessage systemEventDecoder
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.showSpinner then
        Sub.batch
            [ Sub.map SpinnerMsg Spinner.subscription
            , Sub.map OnDeviceEventReceived deviceEventReceived
            ]

    else
        Sub.map OnDeviceEventReceived deviceEventReceived


deviceEventReceived : Sub (Result Decode.Error JSEvent)
deviceEventReceived =
    Ports.onDeviceEventReceived (Decode.decodeValue jsReplyDecoder)
