module Page.InterfaceBuilder exposing (Model, Msg, init, update, view)

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

import Bootstrap.Alert as Alert
import Bootstrap.Button as Button
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
    , confirmInterfaceName : String
    , showSource : Bool
    , sourceBuffer : String
    , sourceBufferStatus : BufferStatus
    , debouncerControlState : Control.State Msg
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
      , confirmInterfaceName = ""
      , showSource = True
      , sourceBuffer = Interface.toPrettySource Interface.empty
      , sourceBufferStatus = Valid
      , debouncerControlState = Control.initialState
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
    | ResetMapping
    | ShowDeleteModal
    | CloseDeleteModal ModalResult
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
            ( { model | minMinor = model.interface.minor }
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
                newMapping =
                    model.interfaceMapping

                interface =
                    model.interface

                newInterface =
                    { interface | mappings = Dict.insert newMapping.endpoint newMapping interface.mappings }
            in
                ( { model
                    | interface = newInterface
                    , interfaceMapping = InterfaceMapping.empty
                    , newMappingVisible = False
                    , sourceBuffer = Interface.toPrettySource interface
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
                    Interface.setName model.interface newName
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
                                Interface.setMajor model.interface major
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
                                Interface.setMinor model.interface minor
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
                    Interface.setType model.interface newInterfaceType
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
                    Interface.setAggregation model.interface newAggregation
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
                    Interface.setOwnership model.interface newOwner
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
                    Interface.setExplicitTimestamp model.interface timestamp
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
                    Interface.setHasMeta model.interface hasMeta
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
                    Interface.setDescription model.interface newDescription
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
                    Interface.setDoc model.interface newDoc
            in
                ( { model
                    | interface = newInterface
                    , sourceBuffer = Interface.toPrettySource newInterface
                  }
                , Cmd.none
                , ExternalMsg.Noop
                )

        UpdateMappingEndpoint newEndpoint ->
            ( { model | interfaceMapping = InterfaceMapping.setEndpoint model.interfaceMapping newEndpoint }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateMappingType newType ->
            case (InterfaceMapping.stringToMappingType newType) of
                Ok mappingType ->
                    ( { model | interfaceMapping = InterfaceMapping.setType model.interfaceMapping mappingType }
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
                    ( { model | interfaceMapping = InterfaceMapping.setReliability model.interfaceMapping r }
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
                    ( { model | interfaceMapping = InterfaceMapping.setRetention model.interfaceMapping r }
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
                        ( { model | interfaceMapping = InterfaceMapping.setExpiry model.interfaceMapping expiry }
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
            ( { model | interfaceMapping = InterfaceMapping.setAllowUnset model.interfaceMapping allowUnset }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateMappingDescription newDescription ->
            ( { model | interfaceMapping = InterfaceMapping.setDescription model.interfaceMapping newDescription }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateMappingDoc newDoc ->
            ( { model | interfaceMapping = InterfaceMapping.setDoc model.interfaceMapping newDoc }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateConfirmInterfaceName userInput ->
            ( { model | confirmInterfaceName = userInput }
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
                [ renderDeleteInterfaceModal model ]
            ]
        ]


renderContent : Interface -> Bool -> InterfaceMapping -> Bool -> Html Msg
renderContent interface interfaceEditMode interfaceMapping newMappingVisible =
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
                                        , Radio.disabled interfaceEditMode
                                        , Radio.checked <| interface.aggregation == Interface.Individual
                                        , Radio.onClick <| UpdateInterfaceAggregation Interface.Individual
                                        ]
                                        "Individual"
                                    , Radio.create
                                        [ Radio.id "iarb2"
                                        , Radio.disabled interfaceEditMode
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
                    [ ListGroup.ul
                        (Dict.values interface.mappings
                            |> List.map renderMapping
                            |> List.append
                                [ ListGroup.li
                                    []
                                    [ (if newMappingVisible then
                                        (renderAddNewMapping interfaceMapping)
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
    if editMode then
        Button.button
            [ Button.primary
            , Button.attrs [ class "float-right", Spacing.ml2 ]
            , Button.onClick UpdateInterface
            ]
            [ text "Apply Changes" ]
    else
        Button.button
            [ Button.primary
            , Button.attrs [ class "float-right", Spacing.ml2 ]
            , Button.onClick AddInterface
            ]
            [ text "Install Interface" ]


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


renderMapping : InterfaceMapping -> ListGroup.Item Msg
renderMapping mapping =
    ListGroup.li []
        [ h4 [ Display.inline ] [ text mapping.endpoint ]
        , p [ Display.inline ] [ text <| " : " ++ (mappingTypeToEnglishString mapping.mType) ]
        ]


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
