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


module Page.TriggerBuilder exposing (Model, Msg, init, subscriptions, update, view)

import AstarteApi
import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Select as Select
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Modal as Modal
import Bootstrap.Table as Table
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Debouncer.Basic as Debouncer exposing (Debouncer, fromSeconds, toDebouncer)
import Dict exposing (Dict)
import Html exposing (Html, b, h5, text)
import Html.Attributes exposing (class, for, href, readonly, selected, value)
import Html.Events exposing (onSubmit)
import Icons
import Json.Decode as Decode
import Modal.AskKeyValue as AskKeyValue
import Modal.AskSingleValue as AskSingleValue
import Modal.ConfirmModal as ConfirmModal
import Regex exposing (Regex)
import Route
import Spinner
import Task
import Types.DataTrigger as DataTrigger exposing (DataTrigger, DataTriggerEvent)
import Types.DeviceTrigger as DeviceTrigger exposing (DeviceTrigger, DeviceTriggerEvent)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Interface as Interface exposing (Interface)
import Types.InterfaceMapping as InterfaceMapping exposing (InterfaceMapping, MappingType(..))
import Types.Session exposing (Session)
import Types.Trigger as Trigger exposing (Trigger)


type alias Model =
    { trigger : Trigger
    , editMode : Bool
    , refInterface : Maybe Interface
    , interfaces : List String
    , majors : List Int
    , mappingType : Maybe InterfaceMapping.MappingType
    , showSource : Bool
    , sourceBuffer : String
    , sourceBufferStatus : BufferStatus
    , sourceDebouncer : Debouncer Msg Msg
    , spinner : Spinner.Model
    , showSpinner : Bool
    , currentModal : Maybe PageModals

    -- decoupled types
    , selectedInterfaceName : String
    , selectedInterfaceMajor : Maybe Int
    }


type PageModals
    = NewCustomHeader AskKeyValue.Model (AskKeyValue.Msg -> Msg)
    | EditCustomHeader AskSingleValue.Model (AskSingleValue.Msg -> Msg) String
    | ConfirmCustomHeaderDeletion ConfirmModal.Model (ConfirmModal.Msg -> Msg) String
    | ConfirmTriggerDeletion String String


type BufferStatus
    = Valid
    | Invalid
    | Typing


init : Maybe String -> Session -> ( Model, Cmd Msg )
init maybeTriggerName session =
    let
        debouncer =
            Debouncer.manual
                |> Debouncer.settleWhenQuietFor (Just (fromSeconds 1))
                |> toDebouncer
    in
    ( { trigger = Trigger.empty
      , editMode = False
      , refInterface = Nothing
      , interfaces = []
      , majors = []
      , mappingType = Nothing
      , selectedInterfaceName = ""
      , selectedInterfaceMajor = Nothing
      , showSource = True
      , sourceBuffer = Trigger.toPrettySource Trigger.empty
      , sourceBufferStatus = Valid
      , sourceDebouncer = debouncer
      , spinner = Spinner.init
      , showSpinner = True
      , currentModal = Nothing
      }
    , case maybeTriggerName of
        Just name ->
            AstarteApi.getTrigger session.apiConfig
                name
                GetTriggerDone
                (ShowError "Could not retrieve selected trigger")
                RedirectToLogin

        Nothing ->
            AstarteApi.listInterfaces session.apiConfig
                GetInterfaceListDone
                (ShowError "Could not retrieve interface list")
                RedirectToLogin
    )


type ModalResult
    = ModalCancel
    | ModalOk


type Msg
    = Noop
    | GetTriggerDone Trigger
    | AddTrigger
    | AddTriggerDone
    | GetInterfaceListDone (List String)
    | GetInterfaceMajorsDone (List Int)
    | GetInterfaceDone Interface
    | DeleteTriggerDone
    | ShowError String AstarteApi.Error
    | RedirectToLogin
    | ToggleSource
    | TriggerSourceChanged
    | UpdateSource String
    | SourceDebounceMsg (Debouncer.Msg Msg)
    | Forward ExternalMsg
      -- Trigger messages
    | UpdateTriggerName String
    | UpdateTriggerUrl String
    | UpdateTriggerTemplate String
    | UpdateMustachePayload String
    | UpdateSimpleTriggerType String
    | UpdateActionMethod Trigger.HttpMethod
      -- Data Trigger
    | UpdateDataTriggerInterfaceName String
    | UpdateDataTriggerInterfaceMajor String
    | UpdateDataTriggerCondition String
    | UpdateDataTriggerPath String
    | UpdateDataTriggerOperator String
    | UpdateDataTriggerKnownValue String
      -- Device Trigger
    | UpdateDeviceTriggerId String
    | UpdateDeviceTriggerCondition String
      -- Modal
    | ShowDeleteModal
    | CloseDeleteModal ModalResult
    | UpdateConfirmTriggerName String
    | OpenNewHeaderPopup
    | OpenEditHeaderPopup String
    | OpenDeleteHeaderPopup String
    | UpdateKeyValueModal AskKeyValue.Msg
    | UpdateSingleValueModal AskSingleValue.Msg
    | UpdateConfirmModal ConfirmModal.Msg
      -- spinner
    | SpinnerMsg Spinner.Msg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        Noop ->
            ( model
            , Cmd.none
            , ExternalMsg.Noop
            )

        GetTriggerDone trigger ->
            case trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    ( { model
                        | trigger = trigger
                        , editMode = True
                        , interfaces = [ dataTrigger.interfaceName ]
                        , majors = [ dataTrigger.interfaceMajor ]
                        , selectedInterfaceName = dataTrigger.interfaceName
                        , selectedInterfaceMajor = Just dataTrigger.interfaceMajor
                        , sourceBuffer = Trigger.toPrettySource trigger
                        , sourceBufferStatus = Valid
                        , showSpinner = False
                      }
                    , if dataTrigger.interfaceName == "*" then
                        Cmd.none

                      else
                        AstarteApi.getInterface session.apiConfig
                            dataTrigger.interfaceName
                            dataTrigger.interfaceMajor
                            GetInterfaceDone
                            (ShowError "Could not retrieve selected interface")
                            RedirectToLogin
                    , ExternalMsg.Noop
                    )

                Trigger.Device _ ->
                    ( { model
                        | trigger = trigger
                        , editMode = True
                        , sourceBuffer = Trigger.toPrettySource trigger
                        , sourceBufferStatus = Valid
                        , showSpinner = False
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        GetInterfaceListDone interfaces ->
            case ( List.head interfaces, String.isEmpty model.selectedInterfaceName ) of
                ( Just interfaceName, True ) ->
                    ( { model
                        | interfaces = interfaces
                        , selectedInterfaceName = interfaceName
                        , showSpinner = False
                      }
                    , AstarteApi.listInterfaceMajors session.apiConfig
                        interfaceName
                        GetInterfaceMajorsDone
                        (ShowError <| "Could not retrieve major versions for " ++ interfaceName ++ " interface")
                        RedirectToLogin
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( { model
                        | interfaces = interfaces
                        , showSpinner = False
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        GetInterfaceMajorsDone majors ->
            case ( model.trigger.simpleTrigger, model.refInterface, List.head majors ) of
                ( Trigger.Data dataTrigger, Nothing, Just major ) ->
                    let
                        newSimpleTrigger =
                            dataTrigger
                                |> DataTrigger.setInterfaceMajor major
                                |> Trigger.Data

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | majors = majors
                        , selectedInterfaceMajor = Just major
                        , trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , AstarteApi.getInterface session.apiConfig
                        model.selectedInterfaceName
                        major
                        GetInterfaceDone
                        (ShowError "Could not retrieve selected interface")
                        RedirectToLogin
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( { model | majors = majors }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        GetInterfaceDone interface ->
            case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    let
                        mappingType =
                            matchPath dataTrigger.path <| Interface.mappingsAsList interface

                        newSimpleTrigger =
                            dataTrigger
                                |> DataTrigger.setInterfaceName interface.name
                                |> DataTrigger.setInterfaceMajor interface.major
                                |> DataTrigger.setKnownValueType (mappingTypeToJsonType mappingType)
                                |> Trigger.Data
                    in
                    ( { model
                        | trigger = Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                        , refInterface = Just interface
                        , mappingType = mappingType
                        , selectedInterfaceName = interface.name
                        , selectedInterfaceMajor = Just interface.major
                        , showSpinner = False
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Trigger.Device _ ->
                    ( { model | refInterface = Just interface }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        DeleteTriggerDone ->
            ( model
            , Cmd.none
            , ExternalMsg.Batch
                [ ExternalMsg.AddFlashMessage FlashMessage.Notice "Trigger successfully deleted." []
                , ExternalMsg.RequestRoute <| Route.Realm Route.ListTriggers
                ]
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
            -- TODO: We should save page context, ask for login and then restore previous context
            ( model
            , Cmd.none
            , ExternalMsg.RequestRoute <| Route.Realm Route.Logout
            )

        ToggleSource ->
            ( { model | showSource = not model.showSource }
            , Cmd.none
            , ExternalMsg.Noop
            )

        TriggerSourceChanged ->
            case Trigger.fromString model.sourceBuffer of
                Ok trigger ->
                    if not model.editMode || model.trigger.name == trigger.name then
                        ( { model
                            | sourceBuffer = Trigger.toPrettySource trigger
                            , sourceBufferStatus = Valid
                            , trigger = trigger
                          }
                        , Cmd.none
                        , ExternalMsg.Noop
                        )

                    else
                        ( { model | sourceBufferStatus = Invalid }
                        , Cmd.none
                        , ExternalMsg.AddFlashMessage
                            FlashMessage.Error
                            "Trigger name cannot be changed"
                            []
                        )

                Err _ ->
                    ( { model | sourceBufferStatus = Invalid }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateSource newSource ->
            ( { model
                | sourceBuffer = newSource
                , sourceBufferStatus = Typing
              }
            , Task.perform
                (\_ ->
                    TriggerSourceChanged
                        |> Debouncer.provideInput
                        |> SourceDebounceMsg
                )
                (Task.succeed ())
            , ExternalMsg.Noop
            )

        SourceDebounceMsg subMsg ->
            let
                ( subModel, subCmd, emittedMsg ) =
                    Debouncer.update subMsg model.sourceDebouncer

                mappedCmd =
                    Cmd.map SourceDebounceMsg subCmd

                updatedModel =
                    { model | sourceDebouncer = subModel }
            in
            case emittedMsg of
                Just emitted ->
                    let
                        ( newModel, updateCommand, externalCommand ) =
                            update session emitted updatedModel
                    in
                    ( newModel
                    , Cmd.batch [ updateCommand, mappedCmd ]
                    , externalCommand
                    )

                Nothing ->
                    ( updatedModel
                    , mappedCmd
                    , ExternalMsg.Noop
                    )

        Forward externalMsg ->
            ( model
            , Cmd.none
            , externalMsg
            )

        AddTrigger ->
            ( model
            , AstarteApi.addNewTrigger session.apiConfig
                model.trigger
                AddTriggerDone
                (ShowError "Could not install trigger")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        AddTriggerDone ->
            ( model
            , Cmd.none
            , ExternalMsg.Batch
                [ ExternalMsg.AddFlashMessage FlashMessage.Notice "Trigger succesfully installed." []
                , ExternalMsg.RequestRoute <| Route.Realm Route.ListTriggers
                ]
            )

        UpdateTriggerName newName ->
            let
                newTrigger =
                    Trigger.setName newName model.trigger
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateTriggerUrl newUrl ->
            let
                newTrigger =
                    Trigger.setUrl newUrl model.trigger
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateTriggerTemplate template ->
            let
                t =
                    case template of
                        "mustache" ->
                            Trigger.Mustache ""

                        _ ->
                            Trigger.NoTemplate

                newTrigger =
                    Trigger.setTemplate t model.trigger
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateMustachePayload payload ->
            case model.trigger.action.template of
                Trigger.Mustache _ ->
                    let
                        newTrigger =
                            Trigger.setTemplate (Trigger.Mustache payload) model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateSimpleTriggerType simpleTriggerType ->
            case simpleTriggerType of
                "data" ->
                    let
                        newSimpleTrigger =
                            Trigger.Data DataTrigger.empty

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                        , refInterface = Nothing
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                "device" ->
                    let
                        newSimpleTrigger =
                            Trigger.Device DeviceTrigger.empty

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.AddFlashMessage FlashMessage.Fatal "Parse error. Unknown simple trigger type" []
                    )

        UpdateActionMethod method ->
            let
                trigger =
                    model.trigger

                action =
                    trigger.action

                newAction =
                    { action | httpMethod = method }

                newTrigger =
                    { trigger | action = newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateDataTriggerInterfaceName interfaceName ->
            case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    let
                        ( newSimpleTrigger, command ) =
                            if interfaceName == "*" then
                                ( dataTrigger
                                    |> DataTrigger.setInterfaceName interfaceName
                                    |> DataTrigger.setPath "/*"
                                    |> DataTrigger.setOperator DataTrigger.Any
                                    |> Trigger.Data
                                , Cmd.none
                                )

                            else
                                ( dataTrigger
                                    |> DataTrigger.setInterfaceName interfaceName
                                    |> Trigger.Data
                                , AstarteApi.listInterfaceMajors session.apiConfig
                                    interfaceName
                                    GetInterfaceMajorsDone
                                    (ShowError <| "Could not retrieve major versions for " ++ interfaceName ++ " interface")
                                    RedirectToLogin
                                )

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                        , majors = []
                        , refInterface = Nothing
                        , selectedInterfaceName = interfaceName
                        , selectedInterfaceMajor = Nothing
                      }
                    , command
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDataTriggerInterfaceMajor interfaceMajor ->
            case ( model.trigger.simpleTrigger, String.toInt interfaceMajor ) of
                ( Trigger.Data dataTrigger, Just newMajor ) ->
                    let
                        newSimpleTrigger =
                            dataTrigger
                                |> DataTrigger.setInterfaceMajor newMajor
                                |> Trigger.Data

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | selectedInterfaceMajor = Just newMajor
                        , trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , AstarteApi.getInterface session.apiConfig
                        model.selectedInterfaceName
                        newMajor
                        GetInterfaceDone
                        (ShowError "Could not retrieve selected interface")
                        RedirectToLogin
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDataTriggerCondition dataTriggerEvent ->
            case ( model.trigger.simpleTrigger, DataTrigger.stringToDataTriggerEvent dataTriggerEvent ) of
                ( Trigger.Data dataTrigger, Ok newTriggerEvent ) ->
                    let
                        newSimpleTrigger =
                            Trigger.Data { dataTrigger | on = newTriggerEvent }

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDataTriggerPath path ->
            case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    let
                        mapping =
                            case model.refInterface of
                                Just interface ->
                                    Interface.mappingsAsList interface
                                        |> matchPath path

                                Nothing ->
                                    Nothing

                        newSimpleTrigger =
                            dataTrigger
                                |> DataTrigger.setPath path
                                |> DataTrigger.setKnownValueType (mappingTypeToJsonType mapping)
                                |> Trigger.Data

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                        , mappingType = mapping
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Trigger.Device _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDataTriggerOperator operatorString ->
            case ( model.trigger.simpleTrigger, idToOperator operatorString ) of
                ( Trigger.Data dataTrigger, operator ) ->
                    let
                        newSimpleTrigger =
                            dataTrigger
                                |> DataTrigger.setOperator operator
                                |> Trigger.Data

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDataTriggerKnownValue value ->
            case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    let
                        newSimpleTrigger =
                            dataTrigger
                                |> DataTrigger.setKnownValue value
                                |> Trigger.Data

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDeviceTriggerId deviceId ->
            case model.trigger.simpleTrigger of
                Trigger.Device deviceTrigger ->
                    let
                        newSimpleTrigger =
                            deviceTrigger
                                |> DeviceTrigger.setDeviceId deviceId
                                |> Trigger.Device

                        newTrigger =
                            Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Trigger.Data _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDeviceTriggerCondition condition ->
            case model.trigger.simpleTrigger of
                Trigger.Device deviceTrigger ->
                    case DeviceTrigger.stringToDeviceTriggerEvent condition of
                        Ok triggerEvent ->
                            let
                                newSimpleTrigger =
                                    deviceTrigger
                                        |> DeviceTrigger.setOn triggerEvent
                                        |> Trigger.Device

                                newTrigger =
                                    Trigger.setSimpleTrigger newSimpleTrigger model.trigger
                            in
                            ( { model
                                | trigger = newTrigger
                                , sourceBuffer = Trigger.toPrettySource newTrigger
                              }
                            , Cmd.none
                            , ExternalMsg.Noop
                            )

                        Err err ->
                            ( model
                            , Cmd.none
                            , ExternalMsg.AddFlashMessage
                                FlashMessage.Fatal
                                ("Parse error. " ++ err)
                                []
                            )

                Trigger.Data _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        ShowDeleteModal ->
            ( { model | currentModal = Just (ConfirmTriggerDeletion model.trigger.name "") }
            , Cmd.none
            , ExternalMsg.Noop
            )

        CloseDeleteModal result ->
            case ( model.currentModal, result ) of
                ( Just (ConfirmTriggerDeletion _ confirmTriggerName), ModalOk ) ->
                    if model.trigger.name == confirmTriggerName then
                        ( { model | currentModal = Nothing }
                        , AstarteApi.deleteTrigger session.apiConfig
                            model.trigger.name
                            DeleteTriggerDone
                            (ShowError "Could not delete trigger")
                            RedirectToLogin
                        , ExternalMsg.Noop
                        )

                    else
                        ( model
                        , Cmd.none
                        , ExternalMsg.Noop
                        )

                _ ->
                    ( { model | currentModal = Nothing }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateConfirmTriggerName newConfirmTriggerName ->
            case model.currentModal of
                Just (ConfirmTriggerDeletion triggerName _) ->
                    ( { model | currentModal = Just (ConfirmTriggerDeletion triggerName newConfirmTriggerName) }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        OpenNewHeaderPopup ->
            let
                modal =
                    NewCustomHeader (AskKeyValue.init "Add New Header" "Header" "Value" AskKeyValue.AnyValue True) UpdateKeyValueModal
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenEditHeaderPopup header ->
            let
                modalModel =
                    AskSingleValue.init
                        ("Edit Value for Header \"" ++ header ++ "\"")
                        "Value"
                        AskSingleValue.AnyValue
                        True

                modal =
                    EditCustomHeader modalModel UpdateSingleValueModal header
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenDeleteHeaderPopup header ->
            let
                modalModel =
                    ConfirmModal.init
                        "Warning"
                        ("Remove custom header \"" ++ header ++ "\"?")
                        (Just "Remove header")
                        (Just ConfirmModal.Danger)
                        True

                modal =
                    ConfirmCustomHeaderDeletion modalModel UpdateConfirmModal header
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateKeyValueModal modalMsg ->
            case model.currentModal of
                Just (NewCustomHeader modalModel msgTag) ->
                    let
                        ( newModalModel, externalCommand ) =
                            AskKeyValue.update modalMsg modalModel

                        ( updatedModel, cmd ) =
                            { model | currentModal = Just (NewCustomHeader newModalModel msgTag) }
                                |> handleKeyValueModalCommand session externalCommand
                    in
                    ( updatedModel
                    , cmd
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateSingleValueModal modalMsg ->
            case model.currentModal of
                Just (EditCustomHeader modalModel msgTag header) ->
                    let
                        ( newModalModel, externalCommand ) =
                            AskSingleValue.update modalMsg modalModel

                        ( updatedModel, cmd ) =
                            { model | currentModal = Just (EditCustomHeader newModalModel msgTag header) }
                                |> handleSingleValueModalCommand session externalCommand header
                    in
                    ( updatedModel
                    , cmd
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateConfirmModal modalMsg ->
            case model.currentModal of
                Just (ConfirmCustomHeaderDeletion modalModel msgTag header) ->
                    let
                        ( newModalModel, externalCommand ) =
                            ConfirmModal.update modalMsg modalModel

                        ( updatedModel, cmd ) =
                            { model | currentModal = Just (ConfirmCustomHeaderDeletion newModalModel msgTag header) }
                                |> handleConfirmModalCommand session externalCommand header
                    in
                    ( updatedModel
                    , cmd
                    , ExternalMsg.Noop
                    )

                _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        SpinnerMsg spinnerMsg ->
            ( { model | spinner = Spinner.update spinnerMsg model.spinner }
            , Cmd.none
            , ExternalMsg.Noop
            )


handleKeyValueModalCommand : Session -> AskKeyValue.ExternalMsg -> Model -> ( Model, Cmd Msg )
handleKeyValueModalCommand session msg model =
    case msg of
        AskKeyValue.Confirm header value ->
            let
                trigger =
                    model.trigger

                action =
                    trigger.action

                newAction =
                    { action | customHeaders = Dict.insert header value action.customHeaders }

                newTrigger =
                    { trigger | action = newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        _ ->
            ( model
            , Cmd.none
            )


handleSingleValueModalCommand : Session -> AskSingleValue.ExternalMsg -> String -> Model -> ( Model, Cmd Msg )
handleSingleValueModalCommand session msg header model =
    case msg of
        AskSingleValue.Confirm value ->
            let
                trigger =
                    model.trigger

                action =
                    trigger.action

                newAction =
                    { action | customHeaders = Dict.insert header value action.customHeaders }

                newTrigger =
                    { trigger | action = newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        _ ->
            ( model
            , Cmd.none
            )


handleConfirmModalCommand : Session -> ConfirmModal.ExternalMsg -> String -> Model -> ( Model, Cmd Msg )
handleConfirmModalCommand session msg header model =
    case msg of
        ConfirmModal.Confirm ->
            let
                trigger =
                    model.trigger

                action =
                    trigger.action

                newAction =
                    { action | customHeaders = Dict.remove header action.customHeaders }

                newTrigger =
                    { trigger | action = newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        _ ->
            ( model
            , Cmd.none
            )


matchPath : String -> List InterfaceMapping -> Maybe InterfaceMapping.MappingType
matchPath path mappings =
    List.foldr (regMatch path) Nothing mappings


regMatch : String -> InterfaceMapping -> Maybe InterfaceMapping.MappingType -> Maybe InterfaceMapping.MappingType
regMatch path mapping prevValue =
    let
        tokenizedPath =
            String.split "/" path

        tokenizedEndpoint =
            String.split "/" mapping.endpoint
    in
    if innerMatch tokenizedPath tokenizedEndpoint True then
        Just mapping.mType

    else
        prevValue


innerMatch : List String -> List String -> Bool -> Bool
innerMatch xa yb prevValue =
    case ( xa, yb, prevValue ) of
        ( [ x ], [ y ], True ) ->
            innerMatchHelp x y

        ( x :: a, y :: b, True ) ->
            innerMatch a b <| innerMatchHelp x y

        ( _, _, _ ) ->
            False


innerMatchHelp : String -> String -> Bool
innerMatchHelp first second =
    isPlaceholder second || (first == second)


isPlaceholder : String -> Bool
isPlaceholder token =
    Regex.contains placeholderRegex token


placeholderRegex : Regex
placeholderRegex =
    Regex.fromString "^%{([a-zA-Z][a-zA-Z0-9]*)}$"
        |> Maybe.withDefault Regex.never


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
                [ if model.showSource then
                    Col.sm6

                  else
                    Col.sm12
                ]
                [ renderContent model ]
            , Grid.col
                [ if model.showSource then
                    Col.sm6

                  else
                    Col.attrs [ Display.none ]
                ]
                [ renderTriggerSource
                    model.sourceBuffer
                    model.sourceBufferStatus
                    model.editMode
                ]
            ]
        , if model.showSpinner then
            Spinner.view Spinner.defaultConfig model.spinner

          else
            text ""
        , renderModals model.currentModal
        ]


renderContent : Model -> Html Msg
renderContent model =
    Form.form [ Spacing.mt2Sm ]
        ([ Form.row []
            [ Form.col []
                [ Html.h3
                    [ class "text-truncate" ]
                    [ text
                        (if model.editMode then
                            model.trigger.name

                         else
                            "Install a New Trigger"
                        )
                    , if model.editMode then
                        Button.button
                            [ Button.warning
                            , Button.attrs [ Spacing.ml2, class "text-secondary" ]
                            , Button.onClick ShowDeleteModal
                            ]
                            [ Icons.render Icons.Delete [ Spacing.mr2 ]
                            , text "Delete..."
                            ]

                      else
                        text ""
                    ]
                ]
            , Form.col [ Col.smAuto ]
                [ Button.button
                    [ Button.secondary
                    , Button.onClick ToggleSource
                    ]
                    [ Icons.render Icons.ToggleSidebar [] ]
                ]
            ]
         , Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "triggerName" ] [ text "Name" ]
                    , Input.text
                        [ Input.id "triggerName"
                        , Input.readonly model.editMode
                        , Input.value model.trigger.name
                        , Input.onInput UpdateTriggerName
                        ]
                    ]
                ]
            ]
         ]
            ++ renderSimpleTrigger model
            ++ renderTriggerAction model.trigger.action model.editMode
            ++ [ Form.row
                    [ if model.editMode then
                        Row.attrs [ Display.none ]

                      else
                        Row.rightSm
                    ]
                    [ Form.col [ Col.sm4 ]
                        [ Button.button
                            [ Button.primary
                            , Button.attrs [ class "float-right", Spacing.ml2 ]
                            , Button.onClick AddTrigger
                            ]
                            [ text "Install Trigger" ]
                        ]
                    ]
               ]
        )


renderTriggerAction : Trigger.Action -> Bool -> List (Html Msg)
renderTriggerAction action editMode =
    [ Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "triggerActionType" ] [ text "Action type" ]
                , Select.select
                    [ Select.id "triggerActionType"
                    , Select.disabled editMode
                    ]
                    [ Select.item
                        [ value "http" ]
                        [ text "HTTP request" ]
                    ]
                ]
            ]
        ]
    , Form.row []
        [ Form.col [ Col.sm4 ]
            [ Form.group []
                [ Form.label [ for "triggerMethod" ] [ text "HTTP method" ]
                , Select.select
                    [ Select.id "triggerMethod"
                    , Select.disabled editMode
                    , Select.onChange actionMethodMessage
                    ]
                    (actionHttpMethodOptions action.httpMethod)
                ]
            ]
        , Form.col [ Col.sm8 ]
            [ Form.group []
                [ Form.label [ for "triggerUrl" ] [ text "Action URL" ]
                , Input.text
                    [ Input.id "triggerUrl"
                    , Input.readonly editMode
                    , Input.value action.url
                    , Input.onInput UpdateTriggerUrl
                    ]
                ]
            ]
        ]
    , Form.row []
        (renderTriggerTemplate action.template editMode)
    , Form.row []
        [ Form.col
            [ Col.sm12
            , Col.attrs [ Spacing.pb1 ]
            ]
            (renderCustomHeaders action.customHeaders editMode)
        ]
    ]


actionHttpMethodOptions : Trigger.HttpMethod -> List (Select.Item Msg)
actionHttpMethodOptions selectedMethod =
    [ ( "DELETE", selectedMethod == Trigger.Delete )
    , ( "GET", selectedMethod == Trigger.Get )
    , ( "HEAD", selectedMethod == Trigger.Head )
    , ( "OPTIONS", selectedMethod == Trigger.Options )
    , ( "PATCH", selectedMethod == Trigger.Patch )
    , ( "POST", selectedMethod == Trigger.Post )
    , ( "PUT", selectedMethod == Trigger.Put )
    ]
        |> List.map simpleSelectOption


simpleSelectOption : ( String, Bool ) -> Select.Item Msg
simpleSelectOption ( selectValue, isSelected ) =
    Select.item
        [ value selectValue
        , selected isSelected
        ]
        [ Html.text selectValue ]


actionMethodMessage : String -> Msg
actionMethodMessage str =
    case str of
        "DELETE" ->
            UpdateActionMethod Trigger.Delete

        "GET" ->
            UpdateActionMethod Trigger.Get

        "HEAD" ->
            UpdateActionMethod Trigger.Head

        "OPTIONS" ->
            UpdateActionMethod Trigger.Options

        "PATCH" ->
            UpdateActionMethod Trigger.Patch

        "POST" ->
            UpdateActionMethod Trigger.Post

        "PUT" ->
            UpdateActionMethod Trigger.Put

        _ ->
            Noop


renderCustomHeaders : Dict String String -> Bool -> List (Html Msg)
renderCustomHeaders customHeaders editMode =
    if editMode then
        [ renderHeadersTable customHeaders ]

    else
        [ renderEditableHeadersTable customHeaders
        , Html.a
            [ { message = OpenNewHeaderPopup
              , preventDefault = True
              , stopPropagation = False
              }
                |> Decode.succeed
                |> Html.Events.custom "click"
            , href "#"
            , Html.Attributes.target "_self"
            ]
            [ Icons.render Icons.Add [ Spacing.mr1 ]
            , Html.text "Add custom request headers..."
            ]
        ]


renderHeadersTable : Dict String String -> Html Msg
renderHeadersTable customHeaders =
    if Dict.isEmpty customHeaders then
        Html.text ""

    else
        Table.simpleTable
            ( Table.simpleThead
                [ Table.th []
                    [ Html.text "Header" ]
                , Table.th []
                    [ Html.text "Value" ]
                ]
            , Table.tbody []
                (customHeaders
                    |> Dict.toList
                    |> List.map httpHeaderTableRow
                )
            )


renderEditableHeadersTable : Dict String String -> Html Msg
renderEditableHeadersTable customHeaders =
    if Dict.isEmpty customHeaders then
        Html.text ""

    else
        Table.simpleTable
            ( Table.simpleThead
                [ Table.th []
                    [ Html.text "Header" ]
                , Table.th []
                    [ Html.text "Value" ]
                , Table.th [ Table.cellAttr <| class "action-column" ]
                    [ Html.text "Actions" ]
                ]
            , Table.tbody []
                (customHeaders
                    |> Dict.toList
                    |> List.map (httpHeaderTableRowWithControls OpenEditHeaderPopup OpenDeleteHeaderPopup)
                )
            )


httpHeaderTableRow : ( String, String ) -> Table.Row Msg
httpHeaderTableRow ( header, value ) =
    Table.tr []
        [ Table.td []
            [ Html.text header ]
        , Table.td []
            [ Html.text value ]
        ]


httpHeaderTableRowWithControls : (String -> Msg) -> (String -> Msg) -> ( String, String ) -> Table.Row Msg
httpHeaderTableRowWithControls editMsg deleteMsg ( header, value ) =
    Table.tr []
        [ Table.td []
            [ Html.text header ]
        , Table.td []
            [ Html.text value ]
        , Table.td [ Table.cellAttr <| class "text-center" ]
            [ Icons.render Icons.Edit
                [ class "color-grey action-icon"
                , Spacing.mr2
                , Html.Events.onClick (editMsg header)
                ]
            , Icons.render Icons.Erase
                [ class "color-red action-icon"
                , Html.Events.onClick (deleteMsg header)
                ]
            ]
        ]


renderTriggerTemplate : Trigger.Template -> Bool -> List (Form.Col Msg)
renderTriggerTemplate template editMode =
    let
        isMustache =
            case template of
                Trigger.NoTemplate ->
                    False

                Trigger.Mustache _ ->
                    True
    in
    [ Form.col [ Col.sm12 ]
        [ Form.group []
            [ Form.label [ for "triggerTemplateType" ] [ text "Payload type" ]
            , Select.select
                [ Select.id "triggerTemplateType"
                , Select.disabled editMode
                , Select.onChange UpdateTriggerTemplate
                ]
                [ Select.item
                    [ value "notemplate"
                    , selected <| not isMustache
                    ]
                    [ text "Use default event format (JSON)" ]
                , Select.item
                    [ value "mustache"
                    , selected isMustache
                    ]
                    [ text "Mustache Template" ]
                ]
            ]
        , renderTemplateBody template editMode
        ]
    ]


renderTemplateBody : Trigger.Template -> Bool -> Html Msg
renderTemplateBody template editMode =
    case template of
        Trigger.NoTemplate ->
            text ""

        Trigger.Mustache templateBody ->
            Form.group []
                [ Form.label [ for "actionPayload" ] [ text "Payload" ]
                , Textarea.textarea
                    [ Textarea.id "actionPayload"
                    , Textarea.attrs [ readonly editMode ]
                    , Textarea.value templateBody
                    , Textarea.onInput UpdateMustachePayload
                    ]
                ]


renderSimpleTrigger : Model -> List (Html Msg)
renderSimpleTrigger model =
    let
        isDataTrigger =
            case model.trigger.simpleTrigger of
                Trigger.Data _ ->
                    True

                Trigger.Device _ ->
                    False
    in
    Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "triggerSimpleTriggerType" ] [ text "Trigger type" ]
                , Select.select
                    [ Select.id "triggerSimpleTriggerType"
                    , Select.disabled model.editMode
                    , Select.onChange UpdateSimpleTriggerType
                    ]
                    [ Select.item
                        [ value "device"
                        , selected <| not isDataTrigger
                        ]
                        [ text "Device Trigger" ]
                    , Select.item
                        [ value "data"
                        , selected isDataTrigger
                        ]
                        [ text "Data Trigger" ]
                    ]
                ]
            ]
        ]
        :: (case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    renderDataTrigger dataTrigger model

                Trigger.Device deviceTrigger ->
                    renderDeviceTrigger deviceTrigger model.editMode
           )


renderDataTrigger : DataTrigger -> Model -> List (Html Msg)
renderDataTrigger dataTrigger model =
    let
        isAnyInterface =
            model.selectedInterfaceName == "*"
    in
    [ Form.row []
        [ Form.col
            [ if isAnyInterface then
                Col.sm12

              else
                Col.sm8
            ]
            [ Form.group []
                [ Form.label [ for "triggerInterfaceName" ] [ text "Interface name" ]
                , Select.select
                    [ Select.id "triggerInterfaceName"
                    , Select.disabled model.editMode
                    , Select.onChange UpdateDataTriggerInterfaceName
                    , case model.refInterface of
                        Nothing ->
                            if model.selectedInterfaceName == "*" then
                                Select.success

                            else
                                Select.danger

                        Just _ ->
                            Select.success
                    ]
                    (renderAvailableInterfaces dataTrigger.interfaceName model.interfaces)
                ]
            ]
        , Form.col
            [ if isAnyInterface then
                Col.attrs [ Display.none ]

              else
                Col.sm4
            ]
            [ Form.group []
                [ Form.label [ for "triggerInterfaceMajor" ] [ text "Interface major" ]
                , Select.select
                    [ Select.id "triggerInterfaceMajor"
                    , Select.disabled model.editMode
                    , Select.onChange UpdateDataTriggerInterfaceMajor
                    , case model.refInterface of
                        Nothing ->
                            Select.danger

                        Just _ ->
                            Select.success
                    ]
                    (List.map (interfaceMajors dataTrigger.interfaceMajor) model.majors)
                ]
            ]
        ]
    , Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "triggerCondition" ] [ text "Trigger condition" ]
                , Select.select
                    [ Select.id "triggerCondition"
                    , Select.disabled model.editMode
                    , Select.onChange UpdateDataTriggerCondition
                    ]
                    (List.map
                        (dataTriggerEventOptions dataTrigger.on)
                        [ ( DataTrigger.IncomingData, "Incoming Data" )
                        , ( DataTrigger.ValueChange, "Value Change" )
                        , ( DataTrigger.ValueChangeApplied, "Value Change Applied" )
                        , ( DataTrigger.PathCreated, "Path Created" )
                        , ( DataTrigger.PathRemoved, "Path Removed" )
                        , ( DataTrigger.ValueStored, "Value Stored" )
                        ]
                    )
                ]
            ]
        ]
    , Form.row
        (if isAnyInterface then
            [ Row.attrs [ Display.none ] ]

         else
            []
        )
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "triggerPath" ] [ text "Path" ]
                , Input.text
                    [ Input.id "triggerPath"
                    , Input.readonly model.editMode
                    , Input.value dataTrigger.path
                    , Input.onInput UpdateDataTriggerPath
                    , if (dataTrigger.path /= "/*") && (model.mappingType == Nothing) then
                        Input.danger

                      else
                        Input.success
                    ]
                ]
            ]
        ]
    , Form.row
        (if isAnyInterface then
            [ Row.attrs [ Display.none ] ]

         else
            []
        )
        [ Form.col [ Col.sm4 ]
            [ Form.group []
                [ Form.label [ for "triggerOperator" ] [ text "Operator" ]
                , Select.select
                    [ Select.id "triggerCondition"
                    , Select.disabled model.editMode
                    , Select.onChange UpdateDataTriggerOperator
                    ]
                    (renderAvailableOperators dataTrigger.operator model.mappingType)
                ]
            ]
        , Form.col [ Col.sm8 ]
            [ case dataTrigger.operator of
                DataTrigger.Any ->
                    text ""

                _ ->
                    Form.group []
                        [ Form.label [ for "triggerKnownValue" ] [ text "Value" ]
                        , Input.text
                            [ Input.id "triggerKnownValue"
                            , Input.readonly model.editMode
                            , Input.value dataTrigger.knownValue
                            , Input.onInput UpdateDataTriggerKnownValue
                            , if isValidKnownValue model.mappingType dataTrigger.knownValue then
                                Input.success

                              else
                                Input.danger
                            ]
                        ]
            ]
        ]
    ]


isValidKnownValue : Maybe InterfaceMapping.MappingType -> String -> Bool
isValidKnownValue maybeType value =
    case maybeType of
        Just mType ->
            InterfaceMapping.isValidType mType value

        Nothing ->
            False


renderAvailableInterfaces : String -> List String -> List (Select.Item Msg)
renderAvailableInterfaces selectedInterface installedInterfaces =
    availableInterfaces installedInterfaces
        |> selectOptions selectedInterface


renderAvailableOperators : DataTrigger.Operator -> Maybe InterfaceMapping.MappingType -> List (Select.Item Msg)
renderAvailableOperators selectedOperator mappingType =
    aviableOperators mappingType
        |> selectOptions (operatorToId selectedOperator)


selectOptions : String -> List ( String, String ) -> List (Select.Item Msg)
selectOptions selectedId options =
    options
        |> List.map
            (\( id, txt ) ->
                renderOption id (id == selectedId) txt
            )


renderDeviceTrigger : DeviceTrigger -> Bool -> List (Html Msg)
renderDeviceTrigger deviceTrigger editMode =
    [ Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "triggerDeviceId" ] [ text "Device id" ]
                , Input.text
                    [ Input.id "triggerDeviceId"
                    , Input.readonly editMode
                    , Input.value deviceTrigger.deviceId
                    , Input.onInput UpdateDeviceTriggerId
                    ]
                ]
            ]
        ]
    , Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "triggerDeviceOn" ] [ text "Trigger condition" ]
                , Select.select
                    [ Select.id "triggerDeviceOn"
                    , Select.disabled editMode
                    , Select.onChange UpdateDeviceTriggerCondition
                    ]
                    (List.map
                        (deviceTriggerEventOptions deviceTrigger.on)
                        [ ( DeviceTrigger.DeviceConnected, "Device Connected" )
                        , ( DeviceTrigger.DeviceDisconnected, "Device Disconnected" )
                        , ( DeviceTrigger.DeviceError, "Device Error" )
                        , ( DeviceTrigger.EmptyCacheReceived, "Empty Cache Received" )
                        ]
                    )
                ]
            ]
        ]
    ]


renderTriggerSource : String -> BufferStatus -> Bool -> Html Msg
renderTriggerSource sourceBuffer status editMode =
    Textarea.textarea
        [ Textarea.id "triggerSource"
        , Textarea.attrs [ readonly editMode ]
        , Textarea.rows 30
        , Textarea.value sourceBuffer
        , case status of
            Valid ->
                Textarea.success

            Invalid ->
                Textarea.danger

            Typing ->
                Textarea.attrs []
        , Textarea.onInput UpdateSource
        , Textarea.attrs [ class "text-monospace", Size.h100 ]
        ]


renderDeleteTriggerModal : String -> String -> Html Msg
renderDeleteTriggerModal triggerName confirmTriggerName =
    Modal.config (CloseDeleteModal ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ text "Confirmation Required" ]
        |> Modal.body []
            [ Form.form [ onSubmit (CloseDeleteModal ModalOk) ]
                [ Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ text "You are going to remove "
                        , b [] [ text <| triggerName ++ ". " ]
                        , text "This might cause data loss, removed triggers cannot be restored. Are you sure?"
                        ]
                    ]
                , Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ text "Please type "
                        , b [] [ text triggerName ]
                        , text " to proceed."
                        ]
                    ]
                , Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ Input.text
                            [ Input.id "confirmTriggerName"
                            , Input.placeholder "Trigger Name"
                            , Input.value confirmTriggerName
                            , Input.onInput UpdateConfirmTriggerName
                            ]
                        ]
                    ]
                ]
            ]
        |> Modal.footer []
            [ Button.button
                [ Button.secondary
                , Button.onClick <| CloseDeleteModal ModalCancel
                ]
                [ text "Cancel" ]
            , Button.button
                [ Button.primary
                , Button.disabled <| triggerName /= confirmTriggerName
                , Button.onClick <| CloseDeleteModal ModalOk
                ]
                [ text "Confirm" ]
            ]
        |> Modal.view Modal.shown


renderModals : Maybe PageModals -> Html Msg
renderModals currentModal =
    case currentModal of
        Nothing ->
            Html.text ""

        Just (NewCustomHeader model messageHandler) ->
            AskKeyValue.view model
                |> Html.map messageHandler

        Just (EditCustomHeader model messageHandler _) ->
            AskSingleValue.view model
                |> Html.map messageHandler

        Just (ConfirmCustomHeaderDeletion model messageHandler _) ->
            ConfirmModal.view model
                |> Html.map messageHandler

        Just (ConfirmTriggerDeletion triggerName confirmTriggerName) ->
            renderDeleteTriggerModal triggerName confirmTriggerName


availableInterfaces : List String -> List ( String, String )
availableInterfaces installedInterfaces =
    installedInterfaces
        |> List.map (\v -> ( v, v ))
        |> (::) ( "*", "Any interface" )


aviableOperators : Maybe InterfaceMapping.MappingType -> List ( String, String )
aviableOperators mType =
    case mType of
        Nothing ->
            defaultOperators

        Just (Single InterfaceMapping.StringMapping) ->
            allOperators

        Just (Single InterfaceMapping.BinaryBlobMapping) ->
            allOperators

        Just (Single _) ->
            numericOperators

        Just (Array _) ->
            allOperators


defaultOperators : List ( String, String )
defaultOperators =
    [ ( "any", "*" ) ]


numericOperators : List ( String, String )
numericOperators =
    [ ( "any", "*" )
    , ( "equalTo", "==" )
    , ( "notEqualTo", "!=" )
    , ( "greaterThan", ">" )
    , ( "greaterOrEqualTo", ">=" )
    , ( "lessThan", "<" )
    , ( "lessOrEqualTo", "<=" )
    ]


allOperators : List ( String, String )
allOperators =
    [ ( "any", "*" )
    , ( "equalTo", "==" )
    , ( "notEqualTo", "!=" )
    , ( "greaterThan", ">" )
    , ( "greaterOrEqualTo", ">=" )
    , ( "lessThan", "<" )
    , ( "lessOrEqualTo", ">=" )
    , ( "contains", "Contains" )
    , ( "notContains", "Not Contains" )
    ]


operatorToId : DataTrigger.Operator -> String
operatorToId operator =
    case operator of
        DataTrigger.Any ->
            "any"

        DataTrigger.EqualTo ->
            "equalTo"

        DataTrigger.NotEqualTo ->
            "notEqualTo"

        DataTrigger.GreaterThan ->
            "greaterThan"

        DataTrigger.GreaterOrEqualTo ->
            "greaterOrEqualTo"

        DataTrigger.LessThan ->
            "lessThan"

        DataTrigger.LessOrEqualTo ->
            "lessOrEqualTo"

        DataTrigger.Contains ->
            "contains"

        DataTrigger.NotContains ->
            "notContains"


idToOperator : String -> DataTrigger.Operator
idToOperator operatorString =
    case operatorString of
        "any" ->
            DataTrigger.Any

        "equalTo" ->
            DataTrigger.EqualTo

        "notEqualTo" ->
            DataTrigger.NotEqualTo

        "greaterThan" ->
            DataTrigger.GreaterThan

        "greaterOrEqualTo" ->
            DataTrigger.GreaterOrEqualTo

        "lessThan" ->
            DataTrigger.LessThan

        "lessOrEqualTo" ->
            DataTrigger.LessOrEqualTo

        "contains" ->
            DataTrigger.Contains

        "notContains" ->
            DataTrigger.NotContains

        _ ->
            DataTrigger.Any


mappingTypeToJsonType : Maybe InterfaceMapping.MappingType -> DataTrigger.JsonType
mappingTypeToJsonType mType =
    case mType of
        Just (Single InterfaceMapping.DoubleMapping) ->
            DataTrigger.JNumber

        Just (Single InterfaceMapping.IntMapping) ->
            DataTrigger.JNumber

        Just (Single InterfaceMapping.BoolMapping) ->
            DataTrigger.JBool

        Just (Single InterfaceMapping.LongIntMapping) ->
            DataTrigger.JString

        Just (Single InterfaceMapping.StringMapping) ->
            DataTrigger.JString

        Just (Single InterfaceMapping.BinaryBlobMapping) ->
            DataTrigger.JString

        Just (Single InterfaceMapping.DateTimeMapping) ->
            DataTrigger.JString

        Just (Array InterfaceMapping.DoubleMapping) ->
            DataTrigger.JNumberArray

        Just (Array InterfaceMapping.IntMapping) ->
            DataTrigger.JNumberArray

        Just (Array InterfaceMapping.BoolMapping) ->
            DataTrigger.JBoolArray

        Just (Array InterfaceMapping.LongIntMapping) ->
            DataTrigger.JStringArray

        Just (Array InterfaceMapping.StringMapping) ->
            DataTrigger.JStringArray

        Just (Array InterfaceMapping.BinaryBlobMapping) ->
            DataTrigger.JStringArray

        Just (Array InterfaceMapping.DateTimeMapping) ->
            DataTrigger.JStringArray

        Nothing ->
            DataTrigger.JString


interfacesOption : String -> String -> Select.Item Msg
interfacesOption selectedInterface interfaceName =
    renderOption
        interfaceName
        (selectedInterface == interfaceName)
        interfaceName


interfaceMajors : Int -> Int -> Select.Item Msg
interfaceMajors selectedMajor major =
    renderOption
        (String.fromInt major)
        (selectedMajor == major)
        (String.fromInt major)


dataTriggerEventOptions : DataTriggerEvent -> ( DataTriggerEvent, String ) -> Select.Item Msg
dataTriggerEventOptions selectedEvent ( dataEvent, label ) =
    renderOption
        (DataTrigger.dataTriggerEventToString dataEvent)
        (dataEvent == selectedEvent)
        label


deviceTriggerEventOptions : DeviceTriggerEvent -> ( DeviceTriggerEvent, String ) -> Select.Item Msg
deviceTriggerEventOptions selectedEvent ( deviceEvent, label ) =
    renderOption
        (DeviceTrigger.deviceTriggerEventToString deviceEvent)
        (deviceEvent == selectedEvent)
        label


renderOption : String -> Bool -> String -> Select.Item Msg
renderOption optionValue isSelected optionLabel =
    Select.item
        [ value optionValue
        , selected isSelected
        ]
        [ text optionLabel ]


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.showSpinner then
        Sub.map SpinnerMsg Spinner.subscription

    else
        Sub.none
