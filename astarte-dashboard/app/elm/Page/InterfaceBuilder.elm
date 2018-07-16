module Page.InterfaceBuilder exposing (Model, Msg, init, update, view, subscriptions)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Navigation
import Json.Encode as Encode
import Task
import Time
import Control exposing (Control)
import Control.Debounce as Debounce


-- Types

import AstarteApi
import Route
import Types.Session exposing (Session)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.Interface as Interface exposing (Interface)
import Types.InterfaceMapping as InterfaceMapping exposing (..)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.FlashMessageHelpers as FlashMessageHelpers


-- bootstrap components

import Bootstrap.Accordion as Accordion
import Bootstrap.Alert as Alert
import Bootstrap.Button as Button
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Form as Form
import Bootstrap.Form.Checkbox as Checkbox
import Bootstrap.Form.Fieldset as Fieldset
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Radio as Radio
import Bootstrap.Form.Select as Select
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Modal as Modal
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing


type alias Model =
    { interface : Interface
    , newMappingVisible : Bool
    , interfaceMapping : InterfaceMapping
    , interfaceEditMode : Bool
    , minMinor : Int
    , deleteModalVisibility : Modal.Visibility
    , confirmModalVisibility : Modal.Visibility
    , confirmInterfaceName : String
    , showSource : Bool
    , sourceBuffer : String
    , sourceBufferStatus : BufferStatus
    , debouncerControlState : Control.State Msg
    , accordionState : Accordion.State
    }


type BufferStatus
    = Valid
    | Invalid
    | Typing


init : Maybe ( String, Int ) -> Session -> ( Model, Cmd Msg )
init maybeInterfaceId session =
    ( { interface = Interface.empty
      , newMappingVisible = False
      , interfaceMapping = InterfaceMapping.empty
      , interfaceEditMode = False
      , minMinor = 0
      , deleteModalVisibility = Modal.hidden
      , confirmModalVisibility = Modal.hidden
      , confirmInterfaceName = ""
      , showSource = True
      , sourceBuffer = Interface.toPrettySource Interface.empty
      , sourceBufferStatus = Valid
      , debouncerControlState = Control.initialState
      , accordionState = Accordion.initialState
      }
    , case maybeInterfaceId of
        Just ( name, major ) ->
            AstarteApi.getInterface name
                major
                session
                GetInterfaceDone
                (ShowError "Cannot retrieve interface.")
                RedirectToLogin

        Nothing ->
            Cmd.none
    )


debounce : Msg -> Msg
debounce =
    Debounce.trailing DebounceMsg (1 * Time.second)


type ModalResult
    = ModalCancel
    | ModalOk


type Msg
    = SetNewMappingVisible Bool
    | GetInterfaceDone Interface
    | AddInterface
    | AddInterfaceDone String
    | DeleteInterfaceDone String
    | UpdateInterface
    | UpdateInterfaceDone String
    | AddMappingToInterface
    | RemoveMapping InterfaceMapping
    | ResetMapping
    | ShowDeleteModal
    | CloseDeleteModal ModalResult
    | ShowConfirmModal
    | CloseConfirmModal ModalResult
    | ShowError String String
    | RedirectToLogin
    | ToggleSource
    | InterfaceSourceChanged
    | UpdateSource String
    | DebounceMsg (Control Msg)
    | Forward ExternalMsg
      -- interface messages
    | UpdateInterfaceName String
    | UpdateInterfaceMajor String
    | UpdateInterfaceMinor String
    | UpdateInterfaceType Interface.InterfaceType
    | UpdateInterfaceAggregation Interface.AggregationType
    | UpdateInterfaceOwnership Interface.Owner
    | UpdateInterfaceTimestamp Bool
    | UpdateInterfaceHasMeta Bool
    | UpdateInterfaceDescription String
    | UpdateInterfaceDoc String
      -- mapping messages
    | UpdateMappingEndpoint String
    | UpdateMappingType String
    | UpdateMappingReliability String
    | UpdateMappingRetention String
    | UpdateMappingExpiry String
    | UpdateMappingAllowUnset Bool
    | UpdateMappingDescription String
    | UpdateMappingDoc String
      -- modal
    | UpdateConfirmInterfaceName String
      -- accordion
    | AccordionMsg Accordion.State


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        SetNewMappingVisible visible ->
            ( { model | newMappingVisible = visible }
            , Cmd.none
            , ExternalMsg.Noop
            )

        GetInterfaceDone interface ->
            ( { model
                | interface = interface
                , interfaceEditMode = True
                , minMinor = interface.minor
                , interfaceMapping = InterfaceMapping.empty
                , newMappingVisible = False
                , sourceBuffer = Interface.toPrettySource interface
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        AddInterface ->
            ( model
            , AstarteApi.addNewInterface model.interface
                session
                AddInterfaceDone
                (ShowError "Cannot install interface.")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        AddInterfaceDone response ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm Route.ListInterfaces)
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Interface succesfully installed."
            )

        UpdateInterface ->
            ( model
            , AstarteApi.updateInterface model.interface
                session
                UpdateInterfaceDone
                (ShowError "Cannot apply changes.")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        UpdateInterfaceDone response ->
            ( { model
                | minMinor = model.interface.minor
                , interface = Interface.sealMappings model.interface
              }
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Changes succesfully applied."
            )

        DeleteInterfaceDone response ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm Route.ListInterfaces)
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Interface succesfully deleted."
            )

        AddMappingToInterface ->
            let
                newInterface =
                    model.interface
                        |> Interface.addMapping model.interfaceMapping
            in
                ( { model
                    | interface = newInterface
                    , interfaceMapping = InterfaceMapping.empty
                    , newMappingVisible = False
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        ResetMapping ->
            ( { model
                | interfaceMapping = InterfaceMapping.empty
                , newMappingVisible = False
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        ShowDeleteModal ->
            ( { model
                | deleteModalVisibility = Modal.shown
                , confirmInterfaceName = "Cannot delete interface."
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        CloseDeleteModal modalResult ->
            case modalResult of
                ModalOk ->
                    ( { model | deleteModalVisibility = Modal.hidden }
                    , AstarteApi.deleteInterface model.interface.name
                        model.interface.major
                        session
                        DeleteInterfaceDone
                        (ShowError "")
                        RedirectToLogin
                    , ExternalMsg.Noop
                    )

                ModalCancel ->
                    ( { model | deleteModalVisibility = Modal.hidden }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        ShowConfirmModal ->
            ( { model | confirmModalVisibility = Modal.shown }
            , Cmd.none
            , ExternalMsg.Noop
            )

        CloseConfirmModal modalResult ->
            case modalResult of
                ModalOk ->
                    let
                        command =
                            if model.interfaceEditMode then
                                AstarteApi.updateInterface model.interface
                                    session
                                    UpdateInterfaceDone
                                    (ShowError "Cannot apply changes.")
                                    RedirectToLogin
                            else
                                AstarteApi.addNewInterface model.interface
                                    session
                                    AddInterfaceDone
                                    (ShowError "Cannot install interface.")
                                    RedirectToLogin
                    in
                        ( { model | confirmModalVisibility = Modal.hidden }
                        , command
                        , ExternalMsg.Noop
                        )

                ModalCancel ->
                    ( { model | confirmModalVisibility = Modal.hidden }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        ShowError actionError errorMessage ->
            ( model
            , Cmd.none
            , [ actionError, " ", errorMessage ]
                |> String.concat
                |> ExternalMsg.AddFlashMessage FlashMessage.Error
            )

        RedirectToLogin ->
            -- TODO: We should save page context, ask for login and then restore previous context
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm Route.Logout)
            , ExternalMsg.Noop
            )

        ToggleSource ->
            ( { model | showSource = not model.showSource }
            , Cmd.none
            , ExternalMsg.Noop
            )

        InterfaceSourceChanged ->
            case Interface.fromString model.sourceBuffer of
                Ok interface ->
                    if (not model.interfaceEditMode || Interface.compareId model.interface interface) then
                        ( { model
                            | sourceBuffer = Interface.toPrettySource interface
                            , sourceBufferStatus = Valid
                            , interface = interface
                          }
                        , Cmd.none
                        , ExternalMsg.Noop
                        )
                    else
                        ( { model | sourceBufferStatus = Invalid }
                        , Cmd.none
                        , "Interface name and major do not match"
                            |> ExternalMsg.AddFlashMessage FlashMessage.Error
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
            , Task.perform (\_ -> debounce InterfaceSourceChanged) (Task.succeed ())
            , ExternalMsg.Noop
            )

        DebounceMsg control ->
            let
                ( newModel, command ) =
                    Control.update
                        (\newstate -> { model | debouncerControlState = newstate })
                        model.debouncerControlState
                        control
            in
                ( newModel
                , command
                , ExternalMsg.Noop
                )

        Forward msg ->
            ( model
            , Cmd.none
            , msg
            )

        UpdateInterfaceName newName ->
            let
                newInterface =
                    model.interface |> Interface.setName newName
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateInterfaceMajor newMajor ->
            case (String.toInt newMajor) of
                Ok major ->
                    if (major >= 0) then
                        let
                            newInterface =
                                model.interface |> Interface.setMajor major
                        in
                            ( { model
                                | interface = newInterface
                                , sourceBuffer = Interface.toPrettySource newInterface
                              }
                            , Cmd.none
                            , ExternalMsg.Noop
                            )
                    else
                        ( model
                        , Cmd.none
                        , ExternalMsg.Noop
                        )

                Err _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateInterfaceMinor newMinor ->
            case (String.toInt newMinor) of
                Ok minor ->
                    if (minor >= model.minMinor) then
                        let
                            newInterface =
                                model.interface |> Interface.setMinor minor
                        in
                            ( { model
                                | interface = newInterface
                                , sourceBuffer = Interface.toPrettySource newInterface
                              }
                            , Cmd.none
                            , ExternalMsg.Noop
                            )
                    else
                        ( model
                        , Cmd.none
                        , ExternalMsg.Noop
                        )

                Err _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateInterfaceType newInterfaceType ->
            let
                newInterface =
                    if (newInterfaceType == Interface.Properties) then
                        model.interface
                            |> Interface.setType Interface.Properties
                            |> Interface.setAggregation Interface.Individual
                    else
                        model.interface
                            |> Interface.setType Interface.Datastream
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateInterfaceAggregation newAggregation ->
            let
                newInterface =
                    model.interface |> Interface.setAggregation newAggregation
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateInterfaceOwnership newOwner ->
            let
                newInterface =
                    model.interface |> Interface.setOwnership newOwner
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateInterfaceTimestamp timestamp ->
            let
                newInterface =
                    model.interface |> Interface.setExplicitTimestamp timestamp
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateInterfaceHasMeta hasMeta ->
            let
                newInterface =
                    model.interface |> Interface.setHasMeta hasMeta
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateInterfaceDescription newDescription ->
            let
                newInterface =
                    model.interface |> Interface.setDescription newDescription
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateInterfaceDoc newDoc ->
            let
                newInterface =
                    model.interface |> Interface.setDoc newDoc
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateMappingEndpoint newEndpoint ->
            ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setEndpoint newEndpoint }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateMappingType newType ->
            case (InterfaceMapping.stringToMappingType newType) of
                Ok mappingType ->
                    ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setType mappingType }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Err err ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.AddFlashMessage FlashMessage.Fatal <| "Parse error. " ++ err
                    )

        UpdateMappingReliability newReliability ->
            case (InterfaceMapping.stringToReliability newReliability) of
                Ok r ->
                    ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setReliability r }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Err err ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.AddFlashMessage FlashMessage.Fatal <| "Parse error. " ++ err
                    )

        UpdateMappingRetention newMapRetention ->
            case (InterfaceMapping.stringToRetention newMapRetention) of
                Ok r ->
                    ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setRetention r }
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

                Err err ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.AddFlashMessage FlashMessage.Fatal <| "Parse error. " ++ err
                    )

        UpdateMappingExpiry newMappingExpiry ->
            case (String.toInt newMappingExpiry) of
                Ok expiry ->
                    if (expiry >= 0) then
                        ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setExpiry expiry }
                        , Cmd.none
                        , ExternalMsg.Noop
                        )
                    else
                        ( model
                        , Cmd.none
                        , ExternalMsg.Noop
                        )

                Err _ ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateMappingAllowUnset allowUnset ->
            ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setAllowUnset allowUnset }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateMappingDescription newDescription ->
            ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setDescription newDescription }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateMappingDoc newDoc ->
            ( { model | interfaceMapping = model.interfaceMapping |> InterfaceMapping.setDoc newDoc }
            , Cmd.none
            , ExternalMsg.Noop
            )

        RemoveMapping mapping ->
            let
                newInterface =
                    model.interface
                        |> Interface.removeMapping mapping
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateConfirmInterfaceName userInput ->
            ( { model | confirmInterfaceName = userInput }
            , Cmd.none
            , ExternalMsg.Noop
            )

        AccordionMsg state ->
            ( { model | accordionState = state }
            , Cmd.none
            , ExternalMsg.Noop
            )


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.container
        [ Spacing.mt5Sm ]
        [ Grid.row
            [ Row.middleSm
            , Row.topSm
            ]
            [ Grid.col
                [ Col.sm12 ]
                [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
            ]
        , Grid.row []
            [ Grid.col
                [ if model.showSource then
                    Col.sm6
                  else
                    Col.sm12
                ]
                [ renderContent
                    model.interface
                    model.interfaceEditMode
                    model.interfaceMapping
                    model.newMappingVisible
                    model.accordionState
                ]
            , Grid.col
                [ if model.showSource then
                    Col.sm6
                  else
                    Col.attrs [ Display.none ]
                ]
                [ renderInterfaceSource model.interface model.sourceBuffer model.sourceBufferStatus ]
            ]
        , Grid.row []
            [ Grid.col
                [ Col.sm12 ]
                [ renderDeleteInterfaceModal model
                , renderConfirmModal model
                ]
            ]
        ]


renderContent : Interface -> Bool -> InterfaceMapping -> Bool -> Accordion.State -> Html Msg
renderContent interface interfaceEditMode interfaceMapping newMappingVisible accordionState =
    Grid.container []
        [ Form.form []
            [ Form.row []
                [ Form.col [ Col.sm12 ]
                    [ h3 []
                        [ text
                            (if interfaceEditMode then
                                interface.name
                             else
                                "Install a new interface"
                            )
                        , if (interfaceEditMode && interface.major == 0) then
                            Button.button
                                [ Button.warning
                                , Button.attrs [ Spacing.ml2 ]
                                , Button.onClick ShowDeleteModal
                                ]
                                [ text "Delete..." ]
                          else
                            text ""
                        , Button.button
                            [ Button.secondary
                            , Button.attrs [ class "float-right" ]
                            , Button.onClick ToggleSource
                            ]
                            [ text "->" ]
                        ]
                    ]
                ]
            , Form.row []
                [ Form.col [ Col.sm6 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceName" ] [ text "Name" ]
                        , Input.text
                            [ Input.id "interfaceName"
                            , Input.readonly interfaceEditMode
                            , Input.value interface.name
                            , Input.onInput UpdateInterfaceName
                            , if (Interface.isValidInterfaceName interface.name) then
                                Input.success
                              else
                                Input.danger
                            ]
                        ]
                    ]
                , Form.col [ Col.sm3 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceMajor" ] [ text "Major" ]
                        , Input.number
                            [ Input.id "interfaceMajor"
                            , Input.readonly interfaceEditMode
                            , Input.value <| toString interface.major
                            , Input.onInput UpdateInterfaceMajor
                            ]
                        ]
                    ]
                , Form.col [ Col.sm3 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceMinor" ] [ text "Minor" ]
                        , Input.number
                            [ Input.id "interfaceMinor"
                            , Input.value <| toString interface.minor
                            , Input.onInput UpdateInterfaceMinor
                            ]
                        ]
                    ]
                ]
            , Form.row []
                [ Form.col [ Col.sm3 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceType" ] [ text "Type" ]
                        , Fieldset.config
                            |> Fieldset.asGroup
                            |> Fieldset.children
                                (Radio.radioList "interfaceType"
                                    [ Radio.create
                                        [ Radio.id "itrb1"
                                        , Radio.disabled interfaceEditMode
                                        , Radio.checked <| interface.iType == Interface.Datastream
                                        , Radio.onClick <| UpdateInterfaceType Interface.Datastream
                                        ]
                                        "Datastream"
                                    , Radio.create
                                        [ Radio.id "itrb2"
                                        , Radio.disabled interfaceEditMode
                                        , Radio.checked <| interface.iType == Interface.Properties
                                        , Radio.onClick <| UpdateInterfaceType Interface.Properties
                                        ]
                                        "Properties"
                                    ]
                                )
                            |> Fieldset.view
                        ]
                    ]
                , Form.col [ Col.sm3 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceAggregation" ] [ text "Aggregation" ]
                        , Fieldset.config
                            |> Fieldset.asGroup
                            |> Fieldset.children
                                (Radio.radioList "interfaceAggregation"
                                    [ Radio.create
                                        [ Radio.id "iarb1"
                                        , Radio.disabled <| interfaceEditMode || interface.iType == Interface.Properties
                                        , Radio.checked <| interface.aggregation == Interface.Individual
                                        , Radio.onClick <| UpdateInterfaceAggregation Interface.Individual
                                        ]
                                        "Individual"
                                    , Radio.create
                                        [ Radio.id "iarb2"
                                        , Radio.disabled <| interfaceEditMode || interface.iType == Interface.Properties
                                        , Radio.checked <| interface.aggregation == Interface.Object
                                        , Radio.onClick <| UpdateInterfaceAggregation Interface.Object
                                        ]
                                        "Object"
                                    ]
                                )
                            |> Fieldset.view
                        ]
                    ]
                , Form.col [ Col.sm3 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceOwnership" ] [ text "Ownership" ]
                        , Fieldset.config
                            |> Fieldset.asGroup
                            |> Fieldset.children
                                (Radio.radioList "interfaceOwnership"
                                    [ Radio.create
                                        [ Radio.id "iorb1"
                                        , Radio.disabled interfaceEditMode
                                        , Radio.checked <| interface.ownership == Interface.Device
                                        , Radio.onClick <| UpdateInterfaceOwnership Interface.Device
                                        ]
                                        "Device"
                                    , Radio.create
                                        [ Radio.id "iorb2"
                                        , Radio.disabled interfaceEditMode
                                        , Radio.checked <| interface.ownership == Interface.Server
                                        , Radio.onClick <| UpdateInterfaceOwnership Interface.Server
                                        ]
                                        "Server"
                                    ]
                                )
                            |> Fieldset.view
                        ]
                    ]
                , Form.col [ Col.sm3 ]
                    [ Form.group []
                        [ Checkbox.checkbox
                            [ Checkbox.id "intExpTimestamp"
                            , Checkbox.disabled interfaceEditMode
                            , Checkbox.checked interface.explicitTimestamp
                            , Checkbox.onCheck UpdateInterfaceTimestamp
                            ]
                            "Explicit timestamp"
                        ]
                    ]
                ]
            , Form.row []
                [ Form.col [ Col.sm12 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceDescription" ] [ text "Description" ]
                        , Textarea.textarea
                            [ Textarea.id "interfaceDescription"
                            , Textarea.rows 3
                            , Textarea.value interface.description
                            , Textarea.onInput UpdateInterfaceDescription
                            ]
                        ]
                    ]
                ]
            , Form.row []
                [ Form.col [ Col.sm12 ]
                    [ Form.group []
                        [ Form.label [ for "interfaceDoc" ] [ text "Documentation" ]
                        , Textarea.textarea
                            [ Textarea.id "interfaceDoc"
                            , Textarea.rows 3
                            , Textarea.value interface.doc
                            , Textarea.onInput UpdateInterfaceDoc
                            ]
                        ]
                    ]
                ]
            , Form.row []
                [ Form.col [ Col.sm12 ]
                    [ Accordion.config AccordionMsg
                        |> Accordion.withAnimation
                        |> Accordion.cards
                            (interface.mappings
                                |> Dict.values
                                |> List.map renderMapping
                            )
                        |> Accordion.view accordionState
                    ]
                ]
            , Form.row []
                [ Form.col [ Col.sm12 ]
                    [ (if newMappingVisible then
                        renderAddNewMapping interfaceMapping
                       else
                        div []
                            [ (if Dict.isEmpty interface.mappings then
                                text "No mappings added"
                               else
                                text ""
                              )
                            , Button.button
                                [ Button.primary
                                , Button.attrs [ class "float-right", Spacing.ml2 ]
                                , Button.onClick <| SetNewMappingVisible True
                                ]
                                [ text "Add Mapping ..." ]
                            ]
                      )
                    ]
                ]
            , Form.row [ Row.rightSm ]
                [ Form.col [ Col.sm4 ]
                    [ renderConfirmButton interfaceEditMode ]
                ]
            ]
        ]


renderConfirmButton : Bool -> Html Msg
renderConfirmButton editMode =
    Button.button
        [ Button.primary
        , Button.attrs [ class "float-right", Spacing.ml2 ]
        , Button.onClick ShowConfirmModal
        ]
        [ if editMode then
            text "Apply Changes"
          else
            text "Install Interface"
        ]


renderAddNewMapping : InterfaceMapping -> Html Msg
renderAddNewMapping mapping =
    Form.form []
        [ Form.row []
            [ Form.col [ Col.sm12 ]
                [ h3 [] [ text "Add a new mapping" ] ]
            ]
        , Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "mappingEndpoint" ] [ text "Endpoint" ]
                    , Input.text
                        [ Input.id "Endpoint"
                        , Input.value <| mapping.endpoint
                        , Input.onInput UpdateMappingEndpoint
                        , if (InterfaceMapping.isValidEndpoint mapping.endpoint) then
                            Input.success
                          else
                            Input.danger
                        ]
                    ]
                ]
            ]
        , Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "mappingTypes" ] [ text "Type" ]
                    , Select.select
                        [ Select.id "mappingTypes"
                        , Select.onChange UpdateMappingType
                        ]
                        (List.map (\t -> renderMappingTypeItem (t == mapping.mType) t) InterfaceMapping.mappingTypeList)
                    ]
                ]
            ]
        , Form.row []
            [ Form.col [ Col.sm6 ]
                [ Form.group []
                    [ Form.label [ for "mappingReliability" ] [ text "Reliability" ]
                    , Select.select
                        [ Select.id "mappingReliability"
                        , Select.onChange UpdateMappingReliability
                        ]
                        [ Select.item
                            [ value "unreliable"
                            , selected <| mapping.reliability == InterfaceMapping.Unreliable
                            ]
                            [ text "Unreliable" ]
                        , Select.item
                            [ value "guaranteed"
                            , selected <| mapping.reliability == InterfaceMapping.Guaranteed
                            ]
                            [ text "Guaranteed" ]
                        , Select.item
                            [ value "unique"
                            , selected <| mapping.reliability == InterfaceMapping.Unique
                            ]
                            [ text "Unique" ]
                        ]
                    ]
                ]
            , Form.col [ Col.sm6 ]
                [ Form.group []
                    [ Form.label [ for "mappingRetention" ] [ text "Retention" ]
                    , Select.select
                        [ Select.id "mappingRetention"
                        , Select.onChange UpdateMappingRetention
                        ]
                        [ Select.item
                            [ value "discard"
                            , selected <| mapping.retention == InterfaceMapping.Discard
                            ]
                            [ text "Discard" ]
                        , Select.item
                            [ value "volatile"
                            , selected <| mapping.retention == InterfaceMapping.Volatile
                            ]
                            [ text "Volatile" ]
                        , Select.item
                            [ value "stored"
                            , selected <| mapping.retention == InterfaceMapping.Stored
                            ]
                            [ text "Stored" ]
                        ]
                    ]
                ]
            ]
        , Form.row []
            [ Form.col [ Col.sm6 ]
                [ Form.group []
                    [ Form.label [ for "mappingExpiry" ] [ text "Expiry" ]
                    , Input.number
                        [ Input.id "mappingExpiry"
                        , Input.value <| toString mapping.expiry
                        , Input.onInput UpdateMappingExpiry
                        ]
                    ]
                ]
            , Form.col [ Col.sm6 ]
                [ Form.group []
                    [ Form.label [ for "mappingAllowUnset" ] [ text "Options" ]
                    , Checkbox.checkbox
                        [ Checkbox.id "mappingAllowUnset"
                        , Checkbox.checked mapping.allowUnset
                        , Checkbox.onCheck UpdateMappingAllowUnset
                        ]
                        "Allow unset"
                    ]
                ]
            ]
        , Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "mappingDescription" ] [ text "Description" ]
                    , Textarea.textarea
                        [ Textarea.id "mappingDescription"
                        , Textarea.rows 1
                        , Textarea.value <| mapping.description
                        , Textarea.onInput UpdateMappingDescription
                        ]
                    ]
                ]
            ]
        , Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.group []
                    [ Form.label [ for "mappingDoc" ] [ text "Documentation" ]
                    , Textarea.textarea
                        [ Textarea.id "mappingDoc"
                        , Textarea.rows 1
                        , Textarea.value <| mapping.doc
                        , Textarea.onInput UpdateMappingDoc
                        ]
                    ]
                ]
            ]
        , Form.row [ Row.rightSm ]
            [ Form.col [ Col.sm4 ]
                [ Button.button
                    [ Button.primary
                    , Button.attrs [ class "float-right", Spacing.ml2 ]
                    , Button.onClick AddMappingToInterface
                    ]
                    [ text "Add Mapping" ]
                , Button.button
                    [ Button.secondary
                    , Button.attrs [ class "float-right" ]
                    , Button.onClick ResetMapping
                    ]
                    [ text "Cancel" ]
                ]
            ]
        ]


renderInterfaceSource : Interface -> String -> BufferStatus -> Html Msg
renderInterfaceSource interface sourceBuffer status =
    Textarea.textarea
        [ Textarea.id "interfaceSource"
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
        , Textarea.attrs [ class "text-monospace" ]
        ]


renderMappingTypeItem : Bool -> InterfaceMapping.MappingType -> Select.Item Msg
renderMappingTypeItem itemSelected mappingType =
    Select.item
        [ value <| InterfaceMapping.mappingTypeToString mappingType
        , selected itemSelected
        ]
        [ text <| mappingTypeToEnglishString mappingType ]


renderMapping : InterfaceMapping -> Accordion.Card Msg
renderMapping mapping =
    Accordion.card
        { id = endpointToHtmlId mapping.endpoint
        , options = [ Card.attrs [ Spacing.mb2 ] ]
        , header = renderMappingHeader mapping
        , blocks =
            [ Accordion.block []
                [ Block.titleH5 [] [ text "Reliability" ]
                , Block.text [] [ text <| reliabilityToEnglishString mapping.reliability ]
                ]
            , Accordion.block []
                [ Block.titleH5 [] [ text "Retention" ]
                , Block.text [] [ text <| retentionToEnglishString mapping.retention ]
                ]
            , Accordion.block []
                [ Block.titleH5 [] [ text "Description" ]
                , Block.text []
                    [ if mapping.description == "" then
                        text "None"
                      else
                        text mapping.description
                    ]
                ]
            , Accordion.block []
                [ Block.titleH5 [] [ text "Doc" ]
                , Block.text []
                    [ if mapping.doc == "" then
                        text "None"
                      else
                        text mapping.doc
                    ]
                ]
            ]
        }


endpointToHtmlId : String -> String
endpointToHtmlId endpoint =
    endpoint
        |> String.map
            (\c ->
                if c == '/' then
                    '-'
                else
                    c
            )
        |> String.append "m"


renderMappingHeader : InterfaceMapping -> Accordion.Header Msg
renderMappingHeader mapping =
    Accordion.headerH4 [] (Accordion.toggle [] [ text mapping.endpoint ])
        |> Accordion.appendHeader
            [ small
                [ Display.inline, Spacing.p2 ]
                [ text <| mappingTypeToEnglishString mapping.mType ]
            , renderMappingControls mapping
            ]


renderMappingControls : InterfaceMapping -> Html Msg
renderMappingControls mapping =
    if mapping.draft then
        Button.button
            [ Button.primary
            , Button.attrs [ class "float-right" ]
            , Button.onClick <| RemoveMapping mapping
            ]
            [ text "Remove" ]
    else
        text ""


renderDeleteInterfaceModal : Model -> Html Msg
renderDeleteInterfaceModal model =
    Modal.config (CloseDeleteModal ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ text "Confirmation Required" ]
        |> Modal.body []
            [ Form.form []
                [ Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ text "You are going to remove "
                        , b [] [ text <| model.interface.name ++ " v0. " ]
                        , text "This might cause data loss, removed interfaces cannot be restored. Are you sure?"
                        ]
                    ]
                , Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ text "Please type "
                        , b [] [ text model.interface.name ]
                        , text " to proceed."
                        ]
                    ]
                , Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ Input.text
                            [ Input.id "confirmInterfaceName"
                            , Input.placeholder "Interface Name"
                            , Input.value model.confirmInterfaceName
                            , Input.onInput UpdateConfirmInterfaceName
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
                , Button.disabled <| model.interface.name /= model.confirmInterfaceName
                , Button.onClick <| CloseDeleteModal ModalOk
                ]
                [ text "Confirm" ]
            ]
        |> Modal.view model.deleteModalVisibility


renderConfirmModal : Model -> Html Msg
renderConfirmModal model =
    Modal.config (CloseConfirmModal ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ text "Confirmation Required" ]
        |> Modal.body []
            [ Grid.container []
                [ Grid.row []
                    [ Grid.col
                        [ Col.sm12 ]
                        (confirmModalWarningText
                            model.interfaceEditMode
                            model.interface.name
                            model.interface.major
                        )
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
        |> Modal.view model.confirmModalVisibility


confirmModalWarningText : Bool -> String -> Int -> List (Html Msg)
confirmModalWarningText editMode interfaceName interfaceMajor =
    if editMode then
        [ text "Update the interface "
        , b [] [ text interfaceName ]
        , text "?"
        ]
    else
        [ text "You are about to install the interface "
        , b [] [ text interfaceName ]
        , text "."
        , if (interfaceMajor > 0) then
            p [] [ text "Interface major is greater than zero, that means you will not be able to change already installed mappings." ]
          else
            p [] [ text "This is a draft interface, so you will be able to delete it afterwards." ]
        , text "Confirm?"
        ]


mappingTypeToEnglishString : MappingType -> String
mappingTypeToEnglishString t =
    case t of
        Single DoubleMapping ->
            "Double"

        Single IntMapping ->
            "Integer"

        Single BoolMapping ->
            "Boolean"

        Single LongIntMapping ->
            "Long integer"

        Single StringMapping ->
            "String"

        Single BinaryBlobMapping ->
            "Binary blob"

        Single DateTimeMapping ->
            "Date and time"

        Array DoubleMapping ->
            "Array of doubles"

        Array IntMapping ->
            "Array of integers"

        Array BoolMapping ->
            "Array of booleans"

        Array LongIntMapping ->
            "Array of long integers"

        Array StringMapping ->
            "Array of strings"

        Array BinaryBlobMapping ->
            "Array of binary blobs"

        Array DateTimeMapping ->
            "Array of date and time"


reliabilityToEnglishString : InterfaceMapping.Reliability -> String
reliabilityToEnglishString reliability =
    case reliability of
        InterfaceMapping.Unreliable ->
            "Unreliable"

        InterfaceMapping.Guaranteed ->
            "Guaranteed"

        InterfaceMapping.Unique ->
            "Unique"


retentionToEnglishString : InterfaceMapping.Retention -> String
retentionToEnglishString retention =
    case retention of
        InterfaceMapping.Discard ->
            "Discard"

        InterfaceMapping.Volatile ->
            "Volatile"

        InterfaceMapping.Stored ->
            "Stored"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Accordion.subscriptions model.accordionState AccordionMsg
