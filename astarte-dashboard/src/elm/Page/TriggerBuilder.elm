{-
   This file is part of Astarte.

   Copyright 2018-2020 Ispirata Srl

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
import Types.TriggerAction as TriggerAction
import Ui.TriggerActionEditor as TriggerActionEditor


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
    , currentRealm : String
    , actionEditorConfig : TriggerActionEditor.Config Msg

    -- decoupled types
    , selectedInterfaceName : String
    , selectedInterfaceMajor : Maybe Int
    }


type PageModals
    = NewCustomHeader AskKeyValue.Model (AskKeyValue.Msg -> Msg)
    | EditCustomHeader AskSingleValue.Model (AskSingleValue.Msg -> Msg) String
    | ConfirmCustomHeaderDeletion ConfirmModal.Model (ConfirmModal.Msg -> Msg) String
    | NewAmqpStaticHeader AskKeyValue.Model (AskKeyValue.Msg -> Msg)
    | EditAmqpStaticHeader AskSingleValue.Model (AskSingleValue.Msg -> Msg) String
    | ConfirmAmqpStaticHeaderDeletion ConfirmModal.Model (ConfirmModal.Msg -> Msg) String
    | ConfirmTriggerDeletion String String


type BufferStatus
    = Valid
    | Invalid
    | Typing


init : Maybe String -> Session -> String -> ( Model, Cmd Msg )
init maybeTriggerName session currentRealm =
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
      , currentRealm = currentRealm
      , actionEditorConfig =
            { updateMsg = UpdateAction
            , newHttpHeaderMsg = OpenNewHttpHeaderPopup
            , editHttpHeaderMsg = OpenEditHttpHeaderPopup
            , deleteHttpHeaderMsg = OpenDeleteHttpHeaderPopup
            , newAmqpHeaderMsg = OpenNewAmqpHeaderPopup
            , editAmqpHeaderMsg = OpenEditAmqpHeaderPopup
            , deleteAmqpHeaderMsg = OpenDeleteAmqpHeaderPopup
            }
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
    | UpdateSimpleTriggerType String
    | UpdateAction TriggerActionEditor.Msg
      -- Data Trigger
    | UpdateDataTriggerTarget TargetChoice
    | UpdateDataTriggerDeviceId String
    | UpdateDataTriggerGroupName String
    | UpdateDataTriggerInterfaceName String
    | UpdateDataTriggerInterfaceMajor String
    | UpdateDataTriggerCondition String
    | UpdateDataTriggerPath String
    | UpdateDataTriggerOperator String
    | UpdateDataTriggerKnownValue String
      -- Device Trigger
    | UpdateDeviceTriggerTarget TargetChoice
    | UpdateDeviceTriggerDeviceId String
    | UpdateDeviceTriggerGroupName String
    | UpdateDeviceTriggerCondition String
      -- Modal
    | ShowDeleteModal
    | CloseDeleteModal ModalResult
    | UpdateConfirmTriggerName String
    | OpenNewHttpHeaderPopup
    | OpenEditHttpHeaderPopup String
    | OpenDeleteHttpHeaderPopup String
    | OpenNewAmqpHeaderPopup
    | OpenEditAmqpHeaderPopup String
    | OpenDeleteAmqpHeaderPopup String
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
                        , case trigger.simpleTrigger of
                            Trigger.Data dataTrigger ->
                                AstarteApi.getInterface session.apiConfig
                                    dataTrigger.interfaceName
                                    dataTrigger.interfaceMajor
                                    GetInterfaceDone
                                    (ShowError "Could not retrieve selected interface")
                                    RedirectToLogin

                            _ ->
                                Cmd.none
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

        UpdateAction actionEditorMsg ->
            let
                newAction =
                    TriggerActionEditor.update actionEditorMsg model.trigger.action

                oldTrigger =
                    model.trigger

                newTrigger =
                    { oldTrigger | action = newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateDataTriggerTarget targetChoice ->
            case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    let
                        newTarget =
                            case targetChoice of
                                AllDevices ->
                                    DataTrigger.AllDevices

                                SpecificDevice ->
                                    DataTrigger.SpecificDevice ""

                                DeviceGroup ->
                                    DataTrigger.DeviceGroup ""

                        newSimpleTrigger =
                            Trigger.Data { dataTrigger | target = newTarget }

                        oldTrigger =
                            model.trigger

                        newTrigger =
                            { oldTrigger | simpleTrigger = newSimpleTrigger }
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Trigger.Device _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDataTriggerDeviceId deviceId ->
            case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    let
                        newSimpleTrigger =
                            Trigger.Data { dataTrigger | target = DataTrigger.SpecificDevice deviceId }

                        oldTrigger =
                            model.trigger

                        newTrigger =
                            { oldTrigger | simpleTrigger = newSimpleTrigger }
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Trigger.Device _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateDataTriggerGroupName groupName ->
            case model.trigger.simpleTrigger of
                Trigger.Data dataTrigger ->
                    let
                        newSimpleTrigger =
                            Trigger.Data { dataTrigger | target = DataTrigger.DeviceGroup groupName }

                        oldTrigger =
                            model.trigger

                        newTrigger =
                            { oldTrigger | simpleTrigger = newSimpleTrigger }
                    in
                    ( { model
                        | trigger = newTrigger
                        , sourceBuffer = Trigger.toPrettySource newTrigger
                      }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Trigger.Device _ ->
                    ( model
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

        UpdateDeviceTriggerTarget targetChoice ->
            case model.trigger.simpleTrigger of
                Trigger.Device deviceTrigger ->
                    let
                        newTarget =
                            case targetChoice of
                                AllDevices ->
                                    DeviceTrigger.AllDevices

                                SpecificDevice ->
                                    DeviceTrigger.SpecificDevice ""

                                DeviceGroup ->
                                    DeviceTrigger.DeviceGroup ""

                        newSimpleTrigger =
                            Trigger.Device { deviceTrigger | target = newTarget }

                        oldTrigger =
                            model.trigger

                        newTrigger =
                            { oldTrigger | simpleTrigger = newSimpleTrigger }
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

        UpdateDeviceTriggerDeviceId deviceId ->
            case model.trigger.simpleTrigger of
                Trigger.Device deviceTrigger ->
                    let
                        newSimpleTrigger =
                            Trigger.Device { deviceTrigger | target = DeviceTrigger.SpecificDevice deviceId }

                        oldTrigger =
                            model.trigger

                        newTrigger =
                            { oldTrigger | simpleTrigger = newSimpleTrigger }
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

        UpdateDeviceTriggerGroupName groupName ->
            case model.trigger.simpleTrigger of
                Trigger.Device deviceTrigger ->
                    let
                        newSimpleTrigger =
                            Trigger.Device { deviceTrigger | target = DeviceTrigger.DeviceGroup groupName }

                        oldTrigger =
                            model.trigger

                        newTrigger =
                            { oldTrigger | simpleTrigger = newSimpleTrigger }
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

        OpenNewHttpHeaderPopup ->
            let
                modal =
                    NewCustomHeader (AskKeyValue.init "Add Custom HTTP Header" "Header" "Value" AskKeyValue.AnyValue True) UpdateKeyValueModal
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenEditHttpHeaderPopup header ->
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

        OpenDeleteHttpHeaderPopup header ->
            let
                modalModel =
                    ConfirmModal.init
                        "Remove Header"
                        (Html.text ("Remove custom header \"" ++ header ++ "\"?"))
                        (Just "Remove header")
                        (Just ConfirmModal.Danger)
                        True
                        True

                modal =
                    ConfirmCustomHeaderDeletion modalModel UpdateConfirmModal header
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenNewAmqpHeaderPopup ->
            let
                modal =
                    NewAmqpStaticHeader (AskKeyValue.init "Add Custom AMQP Header" "Header" "Value" AskKeyValue.AnyValue True) UpdateKeyValueModal
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenEditAmqpHeaderPopup header ->
            let
                modalModel =
                    AskSingleValue.init
                        ("Edit Value for Header \"" ++ header ++ "\"")
                        "Value"
                        AskSingleValue.AnyValue
                        True

                modal =
                    EditAmqpStaticHeader modalModel UpdateSingleValueModal header
            in
            ( { model | currentModal = Just modal }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenDeleteAmqpHeaderPopup header ->
            let
                modalModel =
                    ConfirmModal.init
                        "Remove Header"
                        (Html.text ("Remove static header \"" ++ header ++ "\"?"))
                        (Just "Remove header")
                        (Just ConfirmModal.Danger)
                        True
                        True

                modal =
                    ConfirmAmqpStaticHeaderDeletion modalModel UpdateConfirmModal header
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

                Just (NewAmqpStaticHeader modalModel msgTag) ->
                    let
                        ( newModalModel, externalCommand ) =
                            AskKeyValue.update modalMsg modalModel

                        ( updatedModel, cmd ) =
                            { model | currentModal = Just (NewAmqpStaticHeader newModalModel msgTag) }
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

                Just (EditAmqpStaticHeader modalModel msgTag header) ->
                    let
                        ( newModalModel, externalCommand ) =
                            AskSingleValue.update modalMsg modalModel

                        ( updatedModel, cmd ) =
                            { model | currentModal = Just (EditAmqpStaticHeader newModalModel msgTag header) }
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

                Just (ConfirmAmqpStaticHeaderDeletion modalModel msgTag header) ->
                    let
                        ( newModalModel, externalCommand ) =
                            ConfirmModal.update modalMsg modalModel

                        ( updatedModel, cmd ) =
                            { model | currentModal = Just (ConfirmAmqpStaticHeaderDeletion newModalModel msgTag header) }
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
    case ( msg, model.trigger.action ) of
        ( AskKeyValue.Confirm header value, TriggerAction.Http action ) ->
            let
                trigger =
                    model.trigger

                newAction =
                    { action | staticHeaders = Dict.insert header value action.staticHeaders }

                newTrigger =
                    { trigger | action = TriggerAction.Http newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        ( AskKeyValue.Confirm header value, TriggerAction.Amqp action ) ->
            let
                trigger =
                    model.trigger

                newAction =
                    { action | staticHeaders = Dict.insert header value action.staticHeaders }

                newTrigger =
                    { trigger | action = TriggerAction.Amqp newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        ( _, _ ) ->
            ( model
            , Cmd.none
            )


handleSingleValueModalCommand : Session -> AskSingleValue.ExternalMsg -> String -> Model -> ( Model, Cmd Msg )
handleSingleValueModalCommand session msg header model =
    case ( msg, model.trigger.action ) of
        ( AskSingleValue.Confirm value, TriggerAction.Http action ) ->
            let
                trigger =
                    model.trigger

                newAction =
                    { action | staticHeaders = Dict.insert header value action.staticHeaders }

                newTrigger =
                    { trigger | action = TriggerAction.Http newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        ( AskSingleValue.Confirm value, TriggerAction.Amqp action ) ->
            let
                trigger =
                    model.trigger

                newAction =
                    { action | staticHeaders = Dict.insert header value action.staticHeaders }

                newTrigger =
                    { trigger | action = TriggerAction.Amqp newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        ( _, _ ) ->
            ( model
            , Cmd.none
            )


handleConfirmModalCommand : Session -> ConfirmModal.ExternalMsg -> String -> Model -> ( Model, Cmd Msg )
handleConfirmModalCommand session msg header model =
    case ( msg, model.trigger.action ) of
        ( ConfirmModal.Confirm, TriggerAction.Http action ) ->
            let
                trigger =
                    model.trigger

                newAction =
                    { action | staticHeaders = Dict.remove header action.staticHeaders }

                newTrigger =
                    { trigger | action = TriggerAction.Http newAction }
            in
            ( { model
                | trigger = newTrigger
                , sourceBuffer = Trigger.toPrettySource newTrigger
              }
            , Cmd.none
            )

        ( ConfirmModal.Confirm, TriggerAction.Amqp action ) ->
            let
                trigger =
                    model.trigger

                newAction =
                    { action | staticHeaders = Dict.remove header action.staticHeaders }

                newTrigger =
                    { trigger | action = TriggerAction.Amqp newAction }
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
    isPlaceholder first
        || isPlaceholder second
        || (first == second)


isPlaceholder : String -> Bool
isPlaceholder token =
    Regex.contains placeholderRegex token


placeholderRegex : Regex
placeholderRegex =
    Regex.fromString "^%{[a-zA-Z][a-zA-Z0-9_]*}$"
        |> Maybe.withDefault Regex.never


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.containerFluid [ Spacing.p3 ]
        [ Grid.row []
            [ Grid.col [ Col.sm12 ]
                [ Html.h2
                    [ Spacing.pl2 ]
                    [ Html.a
                        [ href "/triggers", Spacing.mr2, class "align-bottom" ]
                        [ Icons.render Icons.Back [] ]
                    , Html.text "Trigger Editor"
                    ]
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
            ]
        , Grid.row []
            [ Grid.col []
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
        , renderButtonsRow model.editMode model.showSource
        , if model.showSpinner then
            Spinner.view Spinner.defaultConfig model.spinner

          else
            text ""
        , model.currentModal
            |> Maybe.map renderModals
            |> Maybe.withDefault (Html.text "")
        ]


renderContent : Model -> Html Msg
renderContent model =
    Grid.containerFluid
        [ class "bg-white"
        , Border.rounded
        , Spacing.p3
        ]
        [ Form.form []
            (List.concat
                [ [ Form.row []
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
                , renderSimpleTrigger model
                , TriggerActionEditor.view
                    model.actionEditorConfig
                    model.trigger.action
                    model.editMode
                    model.currentRealm
                ]
            )
        ]


renderButtonsRow : Bool -> Bool -> Html Msg
renderButtonsRow editMode showSource =
    Grid.row
        [ Row.rightSm
        , Row.attrs [ Spacing.pt3, Spacing.px3 ]
        ]
        [ Grid.col
            [ Col.smAuto
            , Col.attrs [ Spacing.px1 ]
            ]
            [ Button.button
                [ Button.secondary
                , Button.onClick ToggleSource
                ]
                [ if showSource then
                    Html.text "Hide source"

                  else
                    Html.text "Show source"
                ]
            ]
        , Grid.col
            [ Col.smAuto
            , Col.attrs [ Spacing.px1 ]
            ]
            (if editMode then
                [ Button.button
                    [ Button.danger
                    , Button.onClick ShowDeleteModal
                    ]
                    [ Html.text "Delete trigger" ]
                ]

             else
                [ Button.button
                    [ Button.primary
                    , Button.onClick AddTrigger
                    ]
                    [ Html.text "Install Trigger" ]
                ]
            )
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


triggerEventOptions : DataTriggerEvent -> Bool -> List (Select.Item Msg)
triggerEventOptions currentEvent isPropertyInterface =
    let
        availableEvents =
            if isPropertyInterface then
                [ ( DataTrigger.IncomingData, "Incoming Data" )
                , ( DataTrigger.ValueChange, "Value Change" )
                , ( DataTrigger.ValueChangeApplied, "Value Change Applied" )
                , ( DataTrigger.PathCreated, "Path Created" )
                , ( DataTrigger.PathRemoved, "Path Removed" )
                , ( DataTrigger.ValueStored, "Value Stored" )
                ]

            else
                [ ( DataTrigger.IncomingData, "Incoming Data" )
                , ( DataTrigger.ValueStored, "Value Stored" )
                ]
    in
    List.map (dataTriggerEventOptions currentEvent) availableEvents


isValidPath : String -> DataTriggerEvent -> Maybe MappingType -> Bool
isValidPath path event mappingType =
    let
        isAny =
            path == "/*"

        isValueChangeEvent =
            event == DataTrigger.ValueChange || event == DataTrigger.ValueChangeApplied

        matchesMapping =
            mappingType /= Nothing
    in
    -- TODO: this is a workaround, re-enable ValueChange after being fixed in Astarte. See astarte-platform/astarte#513
    matchesMapping || (isAny && not isValueChangeEvent)


renderDataTrigger : DataTrigger -> Model -> List (Html Msg)
renderDataTrigger dataTrigger model =
    let
        isAnyInterface =
            model.selectedInterfaceName == "*"

        isPropertyInterface =
            model.refInterface
                |> Maybe.map (\interface -> interface.iType == Interface.Properties)
                |> Maybe.withDefault False
    in
    [ renderDataTriggerTarget model.editMode dataTrigger.target
    , Form.row []
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
                    (triggerEventOptions dataTrigger.on isPropertyInterface)
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
                    , if isValidPath dataTrigger.path dataTrigger.on model.mappingType then
                        Input.success

                    else
                        Input.danger
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
                    [ Select.id "triggerOperator"
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


renderDataTriggerTarget : Bool -> DataTrigger.Target -> Html Msg
renderDataTriggerTarget editMode target =
    case target of
        DataTrigger.AllDevices ->
            Form.row []
                [ Form.col [ Col.sm12 ]
                    [ renderDataTriggerTargetSelect editMode target ]
                ]

        DataTrigger.DeviceGroup groupName ->
            Form.row []
                [ Form.col [ Col.sm4 ]
                    [ renderDataTriggerTargetSelect editMode target ]
                , Form.col [ Col.sm8 ]
                    [ Form.group []
                        [ Form.label [ for "triggerGroupName" ] [ text "Group Name" ]
                        , Input.text
                            [ Input.id "triggerGroupName"
                            , Input.readonly editMode
                            , Input.value groupName
                            , Input.onInput UpdateDataTriggerGroupName
                            ]
                        ]
                    ]
                ]

        DataTrigger.SpecificDevice deviceId ->
            Form.row []
                [ Form.col [ Col.sm4 ]
                    [ renderDataTriggerTargetSelect editMode target ]
                , Form.col [ Col.sm8 ]
                    [ Form.group []
                        [ Form.label [ for "triggerDeviceId" ] [ text "Device id" ]
                        , Input.text
                            [ Input.id "triggerDeviceId"
                            , Input.readonly editMode
                            , Input.value deviceId
                            , Input.onInput UpdateDataTriggerDeviceId
                            ]
                        ]
                    ]
                ]


renderDataTriggerTargetSelect : Bool -> DataTrigger.Target -> Html Msg
renderDataTriggerTargetSelect editMode target =
    let
        targetChoice =
            case target of
                DataTrigger.AllDevices ->
                    AllDevices

                DataTrigger.DeviceGroup _ ->
                    DeviceGroup

                DataTrigger.SpecificDevice _ ->
                    SpecificDevice
    in
    Form.group []
        [ Form.label [ for "triggerTargetSelect" ] [ text "Target" ]
        , Select.select
            [ Select.id "triggerTargetSelect"
            , Select.disabled editMode
            , Select.onChange updateDataTriggerTarget
            ]
            [ Select.item
                [ value "all_devices"
                , selected (targetChoice == AllDevices)
                ]
                [ text "All devices" ]
            , Select.item
                [ value "specific_device"
                , selected (targetChoice == SpecificDevice)
                ]
                [ text "Device" ]
            , Select.item
                [ value "device_group"
                , selected (targetChoice == DeviceGroup)
                ]
                [ text "Group" ]
            ]
        ]


updateDataTriggerTarget : String -> Msg
updateDataTriggerTarget targetChoice =
    case targetChoice of
        "all_devices" ->
            UpdateDataTriggerTarget AllDevices

        "specific_device" ->
            UpdateDataTriggerTarget SpecificDevice

        "device_group" ->
            UpdateDataTriggerTarget DeviceGroup

        _ ->
            Noop


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
    renderDeviceTriggerTarget editMode deviceTrigger.target
        ++ [ Form.row []
                [ Form.col [ Col.sm12 ]
                    [ Form.group []
                        [ Form.label [ for "triggerCondition" ] [ text "Trigger condition" ]
                        , Select.select
                            [ Select.id "triggerCondition"
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


type TargetChoice
    = AllDevices
    | DeviceGroup
    | SpecificDevice


renderDeviceTriggerTarget : Bool -> DeviceTrigger.Target -> List (Html Msg)
renderDeviceTriggerTarget editMode target =
    case target of
        DeviceTrigger.AllDevices ->
            [ Form.row []
                [ Form.col [ Col.sm12 ]
                    [ renderDeviceTriggerTargetSelect editMode target ]
                ]
            ]

        DeviceTrigger.DeviceGroup groupName ->
            [ Form.row []
                [ Form.col [ Col.sm4 ]
                    [ renderDeviceTriggerTargetSelect editMode target ]
                , Form.col [ Col.sm8 ]
                    [ Form.group []
                        [ Form.label [ for "triggerGroupName" ] [ text "Group Name" ]
                        , Input.text
                            [ Input.id "triggerGroupName"
                            , Input.readonly editMode
                            , Input.value groupName
                            , Input.onInput UpdateDeviceTriggerGroupName
                            ]
                        ]
                    ]
                ]
            ]

        DeviceTrigger.SpecificDevice deviceId ->
            [ Form.row []
                [ Form.col [ Col.sm4 ]
                    [ renderDeviceTriggerTargetSelect editMode target ]
                , Form.col [ Col.sm8 ]
                    [ Form.group []
                        [ Form.label [ for "triggerDeviceId" ] [ text "Device id" ]
                        , Input.text
                            [ Input.id "triggerDeviceId"
                            , Input.readonly editMode
                            , Input.value deviceId
                            , Input.onInput UpdateDeviceTriggerDeviceId
                            ]
                        ]
                    ]
                ]
            ]


renderDeviceTriggerTargetSelect : Bool -> DeviceTrigger.Target -> Html Msg
renderDeviceTriggerTargetSelect editMode target =
    let
        targetChoice =
            case target of
                DeviceTrigger.AllDevices ->
                    AllDevices

                DeviceTrigger.DeviceGroup _ ->
                    DeviceGroup

                DeviceTrigger.SpecificDevice _ ->
                    SpecificDevice
    in
    Form.group []
        [ Form.label [ for "triggerTargetSelect" ] [ text "Target" ]
        , Select.select
            [ Select.id "triggerTargetSelect"
            , Select.disabled editMode
            , Select.onChange updateDeviceTriggerTarget
            ]
            [ Select.item
                [ value "all_devices"
                , selected (targetChoice == AllDevices)
                ]
                [ text "All devices" ]
            , Select.item
                [ value "specific_device"
                , selected (targetChoice == SpecificDevice)
                ]
                [ text "Device" ]
            , Select.item
                [ value "device_group"
                , selected (targetChoice == DeviceGroup)
                ]
                [ text "Group" ]
            ]
        ]


updateDeviceTriggerTarget : String -> Msg
updateDeviceTriggerTarget targetChoice =
    case targetChoice of
        "all_devices" ->
            UpdateDeviceTriggerTarget AllDevices

        "specific_device" ->
            UpdateDeviceTriggerTarget SpecificDevice

        "device_group" ->
            UpdateDeviceTriggerTarget DeviceGroup

        _ ->
            Noop


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


renderModals : PageModals -> Html Msg
renderModals currentModal =
    case currentModal of
        NewCustomHeader model messageHandler ->
            AskKeyValue.view model
                |> Html.map messageHandler

        EditCustomHeader model messageHandler _ ->
            AskSingleValue.view model
                |> Html.map messageHandler

        ConfirmCustomHeaderDeletion model messageHandler _ ->
            ConfirmModal.view model
                |> Html.map messageHandler

        NewAmqpStaticHeader model messageHandler ->
            AskKeyValue.view model
                |> Html.map messageHandler

        EditAmqpStaticHeader model messageHandler _ ->
            AskSingleValue.view model
                |> Html.map messageHandler

        ConfirmAmqpStaticHeaderDeletion model messageHandler _ ->
            ConfirmModal.view model
                |> Html.map messageHandler

        ConfirmTriggerDeletion triggerName confirmTriggerName ->
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
    , ( "lessOrEqualTo", "<=" )
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
