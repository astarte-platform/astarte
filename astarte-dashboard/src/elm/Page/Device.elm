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
import Bootstrap.Button as Button
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Modal as Modal
import Bootstrap.Table as Table
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Color exposing (Color)
import Dict exposing (Dict)
import Html exposing (Html, h5)
import Html.Attributes exposing (class, href)
import Html.Events
import Icons
import Json.Decode as Decode exposing (Decoder)
import ListUtils exposing (addWhen)
import Modal.AskKeyValue as AskKeyValue
import Modal.AskSingleValue as AskSingleValue
import Modal.ConfirmModal as ConfirmModal
import Modal.SelectGroup as SelectGroup
import Ports
import Route
import Set
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
    , deviceError : Maybe String
    , receivedEvents : List JSEvent
    , portConnected : Bool
    , spinner : Spinner.Model
    , showSpinner : Bool
    , existingGroups : List String
    , selectGroupModal : SelectGroup.Model
    , currentModal : Maybe PageModals
    }


type PageModals
    = NewAlias AskKeyValue.Model (AskKeyValue.Msg -> Msg)
    | NewMetadata AskKeyValue.Model (AskKeyValue.Msg -> Msg)
    | EditAliasValue AskSingleValue.Model (AskSingleValue.Msg -> Msg) String
    | EditMetadataValue AskSingleValue.Model (AskSingleValue.Msg -> Msg) String
    | ConfirmCredentialsWipe ConfirmModal.Model (ConfirmModal.Msg -> Msg)
    | ConfirmAliasDeletion ConfirmModal.Model (ConfirmModal.Msg -> Msg) String
    | ConfirmMetadataDeletion ConfirmModal.Model (ConfirmModal.Msg -> Msg) String


init : Session -> String -> ( Model, Cmd Msg )
init session deviceId =
    ( { deviceId = deviceId
      , device = Nothing
      , deviceError = Nothing
      , portConnected = False
      , receivedEvents = []
      , spinner = Spinner.init
      , showSpinner = True
      , existingGroups = []
      , selectGroupModal = SelectGroup.init False []
      , currentModal = Nothing
      }
    , AstarteApi.deviceInfos session.apiConfig deviceId <| DeviceInfosDone
    )


type Msg
    = Refresh
    | UpdateDeviceInfo Time.Posix
    | Forward ExternalMsg
    | OpenNewAliasPopup
    | OpenNewMetadataPopup
    | OpenGroupsPopup
    | UpdateKeyValueModal AskKeyValue.Msg
    | UpdateSingleValueModal AskSingleValue.Msg
    | UpdateConfirmModal ConfirmModal.Msg
    | UpdateGroupModal SelectGroup.Msg
    | DeviceAliasesUpdated (Dict String String) (Result AstarteApi.Error ())
    | DeviceMetadataUpdated (Dict String String) (Result AstarteApi.Error ())
    | EditAlias String
    | DeleteAlias String
    | EditMetadata String
    | RemoveMetadata String
    | SetCredentialsInhibited Bool
    | ShowConfirmModal
      -- spinner
    | SpinnerMsg Spinner.Msg
      -- API
    | DeviceInfosDone (Result AstarteApi.Error Device)
    | GroupListDone (Result AstarteApi.Error (List String))
    | AddGroupToDeviceDone (Result AstarteApi.Error ())
    | SetCredentialsInhibitedDone Bool (Result AstarteApi.Error ())
    | WipeDeviceCredentialsDone (Result AstarteApi.Error ())
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

        UpdateDeviceInfo _ ->
            ( model
            , AstarteApi.deviceInfos session.apiConfig model.deviceId <| DeviceInfosDone
            , ExternalMsg.Noop
            )

        DeviceInfosDone (Ok device) ->
            let
                ( newModel, command, externalCommand ) =
                    if model.portConnected then
                        ( { model | device = Just device }
                        , Cmd.none
                        , ExternalMsg.Noop
                        )

                    else
                        connectToPort model session device
            in
            ( newModel
            , Cmd.batch [ command, AstarteApi.groupList session.apiConfig <| GroupListDone ]
            , externalCommand
            )

        DeviceInfosDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error

                errorMessage =
                    case error of
                        AstarteApi.InvalidRequest ->
                            "Invalid request."

                        AstarteApi.Forbidden ->
                            "Access denied to " ++ model.deviceId ++ "."

                        AstarteApi.ResourceNotFound ->
                            model.deviceId ++ " does not exists."

                        AstarteApi.InternalServerError ->
                            "Internal Server Error."

                        _ ->
                            message
            in
            ( { model
                | showSpinner = False
                , deviceError = Just errorMessage
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        GroupListDone (Ok groups) ->
            case model.device of
                Just device ->
                    ( { model | existingGroups = subtractList groups device.groups }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Nothing ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        GroupListDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        AddGroupToDeviceDone (Ok _) ->
            ( model
            , AstarteApi.deviceInfos session.apiConfig model.deviceId <| DeviceInfosDone
            , ExternalMsg.Noop
            )

        AddGroupToDeviceDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        OpenNewAliasPopup ->
            let
                modal =
                    NewAlias (AskKeyValue.init "Add New Alias" "Tag" "Alias" AskKeyValue.Trimmed True) UpdateKeyValueModal
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenNewMetadataPopup ->
            let
                modal =
                    NewMetadata (AskKeyValue.init "Add New Item" "Key" "Value" AskKeyValue.AnyValue True) UpdateKeyValueModal
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenGroupsPopup ->
            ( { model | selectGroupModal = SelectGroup.init True model.existingGroups }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateKeyValueModal modalMsg ->
            case model.currentModal of
                Just (NewAlias modalModel msgTag) ->
                    let
                        ( newStatus, extenalCommand ) =
                            AskKeyValue.update modalMsg modalModel
                    in
                    ( { model | currentModal = Just (NewAlias newStatus msgTag) }
                    , handleKeyValueCommand session model extenalCommand
                    , ExternalMsg.Noop
                    )

                Just (NewMetadata modalModel msgTag) ->
                    let
                        ( newStatus, extenalCommand ) =
                            AskKeyValue.update modalMsg modalModel
                    in
                    ( { model | currentModal = Just (NewMetadata newStatus msgTag) }
                    , handleKeyValueCommand session model extenalCommand
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateSingleValueModal modalMsg ->
            case model.currentModal of
                Just (EditAliasValue modalModel msgTag aliasTag) ->
                    let
                        ( newStatus, extenalCommand ) =
                            AskSingleValue.update modalMsg modalModel
                    in
                    ( { model | currentModal = Just (EditAliasValue newStatus msgTag aliasTag) }
                    , handleSingleValueCommand session model extenalCommand
                    , ExternalMsg.Noop
                    )

                Just (EditMetadataValue modalModel msgTag itemKey) ->
                    let
                        ( newStatus, extenalCommand ) =
                            AskSingleValue.update modalMsg modalModel
                    in
                    ( { model | currentModal = Just (EditMetadataValue newStatus msgTag itemKey) }
                    , handleSingleValueCommand session model extenalCommand
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateConfirmModal modalMsg ->
            case model.currentModal of
                Just (ConfirmCredentialsWipe modalModel msgTag) ->
                    let
                        ( newStatus, externalCommand ) =
                            ConfirmModal.update modalMsg modalModel
                    in
                    ( { model | currentModal = Just (ConfirmCredentialsWipe newStatus msgTag) }
                    , handleConfirmModalCommand session model externalCommand
                    , ExternalMsg.Noop
                    )

                Just (ConfirmAliasDeletion modalModel msgTag aliasTag) ->
                    let
                        ( newStatus, externalCommand ) =
                            ConfirmModal.update modalMsg modalModel
                    in
                    ( { model | currentModal = Just (ConfirmAliasDeletion newStatus msgTag aliasTag) }
                    , handleConfirmModalCommand session model externalCommand
                    , ExternalMsg.Noop
                    )

                Just (ConfirmMetadataDeletion modalModel msgTag metadataField) ->
                    let
                        ( newStatus, externalCommand ) =
                            ConfirmModal.update modalMsg modalModel
                    in
                    ( { model | currentModal = Just (ConfirmMetadataDeletion newStatus msgTag metadataField) }
                    , handleConfirmModalCommand session model externalCommand
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateGroupModal modalMsg ->
            let
                ( newStatus, extenalCommand ) =
                    SelectGroup.update modalMsg model.selectGroupModal
            in
            ( { model | selectGroupModal = newStatus }
            , handleGroupModalCommand session model extenalCommand
            , ExternalMsg.Noop
            )

        DeviceAliasesUpdated newAliases (Ok _) ->
            case model.device of
                Nothing ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Just device ->
                    let
                        updatedDevice =
                            { device | aliases = newAliases }
                    in
                    ( { model | device = Just updatedDevice }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        DeviceAliasesUpdated _ (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        DeviceMetadataUpdated newMetadata (Ok _) ->
            case model.device of
                Nothing ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Just device ->
                    let
                        updatedDevice =
                            { device | metadata = newMetadata }
                    in
                    ( { model | device = Just updatedDevice }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        DeviceMetadataUpdated _ (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        DeleteAlias aliasTag ->
            let
                title =
                    "Delete Alias"

                body =
                    "Delete alias \"" ++ aliasTag ++ "\"?"

                action =
                    Just "Delete"

                style =
                    Just ConfirmModal.Danger

                modal =
                    ConfirmAliasDeletion (ConfirmModal.init title body action style True) UpdateConfirmModal aliasTag
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        EditAlias key ->
            let
                title =
                    "Edit \"" ++ key ++ "\""

                modal =
                    EditAliasValue (AskSingleValue.init title "Alias" AskSingleValue.Trimmed True) UpdateSingleValueModal key
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        EditMetadata key ->
            let
                title =
                    "Edit \"" ++ key ++ "\""

                modal =
                    EditMetadataValue (AskSingleValue.init title "Value" AskSingleValue.AnyValue True) UpdateSingleValueModal key
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        RemoveMetadata key ->
            let
                title =
                    "Delete Item"

                body =
                    "Do you want to delete " ++ key ++ " from metadata?"

                action =
                    Just "Delete"

                style =
                    Just ConfirmModal.Danger

                modal =
                    ConfirmMetadataDeletion (ConfirmModal.init title body action style True) UpdateConfirmModal key
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        SetCredentialsInhibited enabled ->
            ( model
            , AstarteApi.setCredentialInhibited session.apiConfig model.deviceId enabled (SetCredentialsInhibitedDone enabled)
            , ExternalMsg.Noop
            )

        SetCredentialsInhibitedDone enabled (Ok _) ->
            let
                newDevice =
                    model.device
                        |> Maybe.map (\r -> { r | credentialsinhibited = enabled })
            in
            ( { model | device = newDevice }
            , Cmd.none
            , ExternalMsg.Noop
            )

        SetCredentialsInhibitedDone _ (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error message details
            )

        ShowConfirmModal ->
            let
                title =
                    "Warning"

                body =
                    "This will remove the current device credential secret from Astarte, forcing the device to register again and store its new credentials secret. Continue?"

                action =
                    Just "Wipe credentials secret"

                style =
                    Just ConfirmModal.Danger

                modal =
                    ConfirmCredentialsWipe (ConfirmModal.init title body action style True) UpdateConfirmModal
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        WipeDeviceCredentialsDone (Ok _) ->
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Credentials wiped" []
            )

        WipeDeviceCredentialsDone (Err error) ->
            let
                ( message, details ) =
                    AstarteApi.errorToHumanReadable error
            in
            ( model
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


handleKeyValueCommand : Session -> Model -> AskKeyValue.ExternalMsg -> Cmd Msg
handleKeyValueCommand session model cmd =
    case ( model.device, model.currentModal, cmd ) of
        ( Just device, Just (NewAlias _ _), AskKeyValue.Confirm key value ) ->
            let
                newAliases =
                    device.aliases
                        |> Dict.insert key value
            in
            DeviceAliasesUpdated newAliases
                |> AstarteApi.updateDeviceAliases session.apiConfig model.deviceId (Dict.fromList [ ( key, value ) ])

        ( Just device, Just (NewMetadata _ _), AskKeyValue.Confirm key value ) ->
            let
                newMetadata =
                    device.metadata
                        |> Dict.insert key value
            in
            DeviceMetadataUpdated newMetadata
                |> AstarteApi.updateDeviceMetadata session.apiConfig model.deviceId (Dict.fromList [ ( key, value ) ])

        ( _, _, AskKeyValue.Cancel ) ->
            Cmd.none

        ( _, _, AskKeyValue.Noop ) ->
            Cmd.none

        ( _, _, _ ) ->
            Cmd.none


handleSingleValueCommand : Session -> Model -> AskSingleValue.ExternalMsg -> Cmd Msg
handleSingleValueCommand session model cmd =
    case ( model.device, model.currentModal, cmd ) of
        ( Just device, Just (EditAliasValue _ _ key), AskSingleValue.Confirm value ) ->
            let
                newAliases =
                    device.aliases
                        |> Dict.insert key value
            in
            DeviceAliasesUpdated newAliases
                |> AstarteApi.updateDeviceAliases session.apiConfig model.deviceId (Dict.fromList [ ( key, value ) ])

        ( Just device, Just (EditMetadataValue _ _ key), AskSingleValue.Confirm value ) ->
            let
                newMetadata =
                    device.metadata
                        |> Dict.insert key value
            in
            DeviceMetadataUpdated newMetadata
                |> AstarteApi.updateDeviceMetadata session.apiConfig model.deviceId (Dict.fromList [ ( key, value ) ])

        ( _, _, AskSingleValue.Cancel ) ->
            Cmd.none

        ( _, _, AskSingleValue.Noop ) ->
            Cmd.none

        ( _, _, _ ) ->
            Cmd.none


handleConfirmModalCommand : Session -> Model -> ConfirmModal.ExternalMsg -> Cmd Msg
handleConfirmModalCommand session model cmd =
    case ( model.device, model.currentModal, cmd ) of
        ( Just device, Just (ConfirmCredentialsWipe _ _), ConfirmModal.Confirm ) ->
            AstarteApi.wipeDeviceCredentials session.apiConfig model.deviceId WipeDeviceCredentialsDone

        ( Just device, Just (ConfirmAliasDeletion _ _ aliasTag), ConfirmModal.Confirm ) ->
            let
                newAliases =
                    device.aliases
                        |> Dict.remove aliasTag
            in
            DeviceAliasesUpdated newAliases
                |> AstarteApi.removeDeviceAlias session.apiConfig model.deviceId aliasTag

        ( Just device, Just (ConfirmMetadataDeletion _ _ metadataField), ConfirmModal.Confirm ) ->
            let
                newMetadatas =
                    device.metadata
                        |> Dict.remove metadataField
            in
            DeviceMetadataUpdated newMetadatas
                |> AstarteApi.removeDeviceMetadataField session.apiConfig model.deviceId metadataField

        ( _, _, ConfirmModal.Cancel ) ->
            Cmd.none

        ( _, _, ConfirmModal.Noop ) ->
            Cmd.none

        ( _, _, _ ) ->
            Cmd.none


handleGroupModalCommand : Session -> Model -> SelectGroup.ExternalMsg -> Cmd Msg
handleGroupModalCommand session model cmd =
    case ( model.device, cmd ) of
        ( Just device, SelectGroup.SelectedGroup groupName ) ->
            AstarteApi.addDeviceToGroup session.apiConfig groupName model.deviceId AddGroupToDeviceDone

        ( Nothing, _ ) ->
            Cmd.none

        ( _, SelectGroup.Noop ) ->
            Cmd.none


subtractList : List comparable -> List comparable -> List comparable
subtractList listA listB =
    let
        -- Only use Sets for the subtrahend to preserve ordering in the minuend
        setB =
            Set.fromList listB
    in
    List.foldl
        (\item acc ->
            if Set.member item setB then
                acc

            else
                item :: acc
        )
        []
        listA


connectToPort : Model -> Session -> Device -> ( Model, Cmd Msg, ExternalMsg )
connectToPort model session device =
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
        , portConnected = True
        , showSpinner = False
      }
    , Ports.listenToDeviceEvents phoenixSocketParams
    , ExternalMsg.Noop
    )


type CardWidth
    = FullWidth
    | HalfWidth


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.containerFluid []
        (case ( model.device, model.deviceError ) of
            ( Just device, _ ) ->
                [ Grid.row
                    [ Row.attrs [ Spacing.mt2 ] ]
                    [ Grid.col
                        [ Col.sm12 ]
                        [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
                    ]
                , Grid.row []
                    [ deviceInfoCard device HalfWidth
                    , deviceAliasesCard device HalfWidth
                    , deviceMetadataCard device HalfWidth
                    , deviceGroupsCard device (not <| List.isEmpty model.existingGroups) HalfWidth
                    , deviceIntrospectionCard device HalfWidth
                    , devicePreviousInterfacesCard device HalfWidth
                    , deviceStatsCard device FullWidth
                    , deviceEventsCard device FullWidth
                    , deviceChannelCard model.receivedEvents FullWidth
                    ]
                , model.currentModal
                    |> Maybe.map renderModals
                    |> Maybe.withDefault (Html.text "")
                , SelectGroup.view model.selectGroupModal
                    |> Html.map UpdateGroupModal
                ]

            ( Nothing, Just error ) ->
                [ deviceErrorCard error ]

            ( Nothing, Nothing ) ->
                [ Html.text "" ]
        )


renderModals : PageModals -> Html Msg
renderModals modal =
    case modal of
        NewAlias model msgHandler ->
            AskKeyValue.view model
                |> Html.map msgHandler

        NewMetadata model msgHanlder ->
            AskKeyValue.view model
                |> Html.map msgHanlder

        EditAliasValue model msgHanlder _ ->
            AskSingleValue.view model
                |> Html.map msgHanlder

        EditMetadataValue model msgHanlder _ ->
            AskSingleValue.view model
                |> Html.map msgHanlder

        ConfirmCredentialsWipe model msgHanlder ->
            ConfirmModal.view model
                |> Html.map msgHanlder

        ConfirmAliasDeletion model msgHanlder _ ->
            ConfirmModal.view model
                |> Html.map msgHanlder

        ConfirmMetadataDeletion model msgHanlder _ ->
            ConfirmModal.view model
                |> Html.map msgHanlder


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
            [ class "bg-white", Border.rounded, Spacing.p3, Size.h100, Flex.block, Flex.col ]
            (Grid.row
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
                :: innerItems
            )
        ]


deviceErrorCard : String -> Html Msg
deviceErrorCard error =
    Grid.row [ Row.attrs [ class "bg-white", Border.rounded, Spacing.p3, Size.h100, Flex.block, Flex.col ] ]
        [ Grid.col []
            [ Html.h3 [] [ Html.text "Error While Loading Device Info" ]
            , Html.p [] [ Html.text error ]
            ]
        ]


deviceInfoCard : Device -> CardWidth -> Grid.Column Msg
deviceInfoCard device width =
    renderCard "Device Info"
        width
        [ renderHtmlRow ( "Device ID", Html.span [ class "text-monospace" ] [ Html.text device.id ] )
        , renderTextRow ( "Device name", Dict.get "name" device.aliases |> Maybe.withDefault "No name alias set" )
        , renderHtmlRow ( "Status", renderConnectionStatus device )
        , renderBoolRow ( "Credentials inhibited", device.credentialsinhibited )
        , Grid.row [ Row.attrs [ class "flex-grow-1" ] ] []
        , buttonsRow device.credentialsinhibited
        ]


tableHeaderRightXl : String -> Table.Cell Msg
tableHeaderRightXl label =
    Table.th
        (List.map Table.cellAttr
            [ Display.tableCellXl
            , Display.none
            , class "text-right"
            ]
        )
        [ Html.text label ]


tableHeaderRight : String -> Table.Cell Msg
tableHeaderRight label =
    Table.th [ Table.cellAttr <| class "text-right" ] [ Html.text label ]


tableCellRightXl : String -> Table.Cell Msg
tableCellRightXl value =
    Table.td
        (List.map Table.cellAttr
            [ Display.tableCellXl
            , Display.none
            , class "text-right"
            ]
        )
        [ Html.text value ]


tableCellRight : String -> Table.Cell Msg
tableCellRight value =
    Table.td [ Table.cellAttr <| class "text-right" ] [ Html.text value ]


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
                |> List.map (\val -> Color.hsl (indexToHue val listLength) 0.7 0.7)

        chartParams =
            { width = 800
            , height = 800
            , colors = preferedColors
            , data = piecharList
            }
    in
    renderCard "Device Stats" width <|
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col []
                [ Table.simpleTable
                    ( Table.simpleThead
                        [ Table.th [] [ Html.text "Interface" ]
                        , tableHeaderRight "Bytes"
                        , tableHeaderRightXl "Bytes (%)"
                        , tableHeaderRight "Messages"
                        , tableHeaderRightXl "Messages (%)"
                        ]
                    , Table.tbody []
                        (List.map renderInterfaceStats <| introspectionStats ++ [ others, total ])
                    )
                ]
            , Grid.col
                [ Col.md12, Col.xl4, Col.attrs [ class "piechart-container" ] ]
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


indexToHue : Int -> Int -> Float
indexToHue i max =
    let
        startingHue =
            0.1

        relative =
            toFloat i / toFloat max

        hue =
            startingHue + relative
    in
    if hue > 1 then
        hue - 1

    else
        hue


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
        , tableCellRight <| String.fromInt bytes
        , tableCellRightXl <| formatPercentFloat <| totalBytes
        , tableCellRight <| String.fromInt msgs
        , tableCellRightXl <| formatPercentFloat <| totalMsgs
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
                [ renderAliases device.aliases ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col [ Col.sm12 ]
                [ Html.a
                    [ { message = OpenNewAliasPopup
                      , preventDefault = True
                      , stopPropagation = False
                      }
                        |> Decode.succeed
                        |> Html.Events.custom "click"
                    , href "#"
                    , Html.Attributes.target "_self"
                    ]
                    [ Icons.render Icons.Add [ Spacing.mr1 ]
                    , Html.text "Add new alias..."
                    ]
                ]
            ]
        ]


deviceMetadataCard : Device -> CardWidth -> Grid.Column Msg
deviceMetadataCard device width =
    renderCard "Metadata"
        width
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ renderMetadata device.metadata ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col [ Col.sm12 ]
                [ Html.a
                    [ { message = OpenNewMetadataPopup
                      , preventDefault = True
                      , stopPropagation = False
                      }
                        |> Decode.succeed
                        |> Html.Events.custom "click"
                    , href "#"
                    , Html.Attributes.target "_self"
                    ]
                    [ Icons.render Icons.Add [ Spacing.mr1 ]
                    , Html.text "Add new item..."
                    ]
                ]
            ]
        ]


deviceGroupsCard : Device -> Bool -> CardWidth -> Grid.Column Msg
deviceGroupsCard device showAddToGroup width =
    renderCard "Groups"
        width
        [ Grid.row
            [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ renderGroups device.groups
                ]
            ]
        , Grid.row
            [ Row.attrs
                (if showAddToGroup then
                    [ Spacing.mt2 ]

                 else
                    [ Display.none ]
                )
            ]
            [ Grid.col [ Col.sm12 ]
                [ Html.a
                    [ { message = OpenGroupsPopup
                      , preventDefault = True
                      , stopPropagation = False
                      }
                        |> Decode.succeed
                        |> Html.Events.custom "click"
                    , href "#"
                    , Html.Attributes.target "_self"
                    ]
                    [ Icons.render Icons.Add [ Spacing.mr1 ]
                    , Html.text "Add to existing group..."
                    ]
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
                [ renderIntrospectionInfo device.id device.introspection ]
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
                        [ Html.span [ Spacing.mr2 ] [ Html.text data.interface ]
                        , Html.span [ Spacing.mr2 ] [ Html.text data.path ]
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
                [ Icons.render Icons.FullCircle [ class "icon-never-connected", Spacing.mr1 ]
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


buttonsRow : Bool -> Html Msg
buttonsRow deviceCredentialsInhibited =
    Grid.row []
        [ Grid.col
            [ Col.sm12
            , Col.attrs [ Flex.block, Flex.rowReverse ]
            ]
            [ Button.button
                [ Button.secondary
                , Button.onClick ShowConfirmModal
                ]
                [ Html.text "Wipe credential secret" ]
            , if deviceCredentialsInhibited then
                Button.button
                    [ Button.success
                    , Button.attrs [ Spacing.mr1 ]
                    , Button.onClick (SetCredentialsInhibited False)
                    ]
                    [ Html.text "Enable credentials request" ]

              else
                Button.button
                    [ Button.danger
                    , Button.attrs [ Spacing.mr1 ]
                    , Button.onClick (SetCredentialsInhibited True)
                    ]
                    [ Html.text "Inhibit credentials" ]
            ]
        ]


renderGroups : List String -> Html Msg
renderGroups groups =
    if List.isEmpty groups then
        Html.text "Device does not belong to any group"

    else
        Html.ul [] (List.map renderGroupValue groups)


renderGroupValue : String -> Html Msg
renderGroupValue group =
    Html.li []
        [ Html.a [ href <| Route.toString <| Route.Realm <| Route.GroupDevices group ]
            [ Html.text group ]
        ]


renderAliases : Dict String String -> Html Msg
renderAliases aliases =
    if Dict.isEmpty aliases then
        Html.text "Device has no aliases"

    else
        Table.simpleTable
            ( Table.simpleThead
                [ Table.th []
                    [ Html.text "Tag" ]
                , Table.th []
                    [ Html.text "Alias" ]
                , Table.th [ Table.cellAttr <| class "action-column" ]
                    [ Html.text "Actions" ]
                ]
            , Table.tbody []
                (aliases
                    |> Dict.toList
                    |> List.map (fieldValueTableRow EditAlias DeleteAlias)
                )
            )


renderMetadata : Dict String String -> Html Msg
renderMetadata metadata =
    if Dict.isEmpty metadata then
        Html.text "Device has no metadata"

    else
        Table.simpleTable
            ( Table.simpleThead
                [ Table.th []
                    [ Html.text "Field" ]
                , Table.th []
                    [ Html.text "Value" ]
                , Table.th [ Table.cellAttr <| class "action-column" ]
                    [ Html.text "Actions" ]
                ]
            , Table.tbody []
                (metadata
                    |> Dict.toList
                    |> List.map (fieldValueTableRow EditMetadata RemoveMetadata)
                )
            )


fieldValueTableRow : (String -> Msg) -> (String -> Msg) -> ( String, String ) -> Table.Row Msg
fieldValueTableRow editMessage deleteMessage ( key, value ) =
    Table.tr []
        [ Table.td []
            [ Html.text key ]
        , Table.td []
            [ Html.text value ]
        , Table.td [ Table.cellAttr <| class "text-center" ]
            [ Icons.render Icons.Edit
                [ class "color-grey action-icon"
                , Spacing.mr2
                , Html.Events.onClick (editMessage key)
                ]
            , Icons.render Icons.Erase
                [ class "color-red action-icon"
                , Html.Events.onClick (deleteMessage key)
                ]
            ]
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


renderIntrospectionInfo : String -> List Device.IntrospectionValue -> Html Msg
renderIntrospectionInfo deviceId introspectionValues =
    if List.isEmpty introspectionValues then
        Html.text "No introspection info"

    else
        Html.ul [] <| List.map (renderIntrospectionValue deviceId) introspectionValues


renderPreviousInterfacesInfo : List Device.IntrospectionValue -> Html Msg
renderPreviousInterfacesInfo previousInterfaces =
    if List.isEmpty previousInterfaces then
        Html.text "No previous interfaces info"

    else
        Html.ul [] (List.map renderPreviousIntrospectionValue previousInterfaces)


renderIntrospectionValue : String -> Device.IntrospectionValue -> Html Msg
renderIntrospectionValue deviceId value =
    case value of
        Device.InterfaceInfo name major minor _ _ ->
            Html.li []
                [ Html.a
                    [ href <| Route.toString <| Route.Realm (Route.ShowDeviceData deviceId name) ]
                    [ [ name, " v", String.fromInt major, ".", String.fromInt minor ]
                        |> String.join ""
                        |> Html.text
                    ]
                ]


renderPreviousIntrospectionValue : Device.IntrospectionValue -> Html Msg
renderPreviousIntrospectionValue value =
    case value of
        Device.InterfaceInfo name major minor _ _ ->
            Html.li []
                [ [ name, " v", String.fromInt major, ".", String.fromInt minor ]
                    |> String.join ""
                    |> Html.text
                ]


nonEmptyValue : ( String, Maybe String ) -> Maybe ( String, String )
nonEmptyValue ( label, maybeVal ) =
    Maybe.map (\v -> ( label, v )) maybeVal


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
    [ Sub.map OnDeviceEventReceived deviceEventReceived
    , Time.every (30 * 1000) UpdateDeviceInfo
    ]
        |> addWhen model.showSpinner (Sub.map SpinnerMsg Spinner.subscription)
        |> Sub.batch


deviceEventReceived : Sub (Result Decode.Error JSEvent)
deviceEventReceived =
    Ports.onDeviceEventReceived (Decode.decodeValue jsReplyDecoder)
