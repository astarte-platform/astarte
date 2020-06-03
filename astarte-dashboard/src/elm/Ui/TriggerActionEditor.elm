{-
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

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


module Ui.TriggerActionEditor exposing (Config, Msg(..), update, view)

import Bootstrap.Form as Form
import Bootstrap.Form.Checkbox as Checkbox
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup as InputGroup
import Bootstrap.Form.Select as Select
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid.Col as Col
import Bootstrap.Table as Table
import Bootstrap.Utilities.Spacing as Spacing
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes exposing (class, for, href, readonly, selected, value)
import Html.Events as Events
import Icons
import Json.Decode as Decode
import ListUtils exposing (addWhen)
import Regex exposing (Regex)
import Types.TriggerAction as TriggerAction exposing (TriggerAction)


type Msg
    = Noop
    | UpdateAction SupportedAction
    | UpdateAmqpAction AmqpActionMsg
    | UpdateHttpAction HttpActionMsg


type SupportedAction
    = HttpRequest
    | AmqpMessage


type SupportedTemplates
    = DefaultAstarteTemplate
    | MustacheTemplate


type HttpActionMsg
    = HttpNoop
    | UpdateUrl String
    | UpdateMethod TriggerAction.HttpMethod
    | UpdateTemplate SupportedTemplates
    | UpdateMustachePayload String


type AmqpActionMsg
    = AmqpNoop
    | UpdateExchange String
    | UpdateRoutingKey String
    | UpdateExpiration Int
    | UpdatePriority Int
    | UpdatePersistence Bool


type alias Config msg =
    { updateMsg : Msg -> msg
    , newHttpHeaderMsg : msg
    , editHttpHeaderMsg : String -> msg
    , deleteHttpHeaderMsg : String -> msg
    , newAmqpHeaderMsg : msg
    , editAmqpHeaderMsg : String -> msg
    , deleteAmqpHeaderMsg : String -> msg
    }



-- Update


update : Msg -> TriggerAction -> TriggerAction
update msg action =
    case ( msg, action ) of
        ( Noop, _ ) ->
            action

        ( UpdateAction HttpRequest, TriggerAction.Amqp _ ) ->
            TriggerAction.emptyHttpAction

        ( UpdateAction AmqpMessage, TriggerAction.Http _ ) ->
            TriggerAction.emptyAmqpAction

        ( UpdateAmqpAction amqpMsg, TriggerAction.Amqp config ) ->
            updateAmqpConfig amqpMsg config
                |> TriggerAction.Amqp

        ( UpdateHttpAction httpMsg, TriggerAction.Http config ) ->
            updateHttpConfig httpMsg config
                |> TriggerAction.Http

        -- No switching required
        ( UpdateAction HttpRequest, TriggerAction.Http _ ) ->
            action

        ( UpdateAction AmqpMessage, TriggerAction.Amqp _ ) ->
            action

        -- Ignore unmatched messages
        ( UpdateAmqpAction amqpMsg, TriggerAction.Http _ ) ->
            action

        ( UpdateHttpAction httpMsg, TriggerAction.Amqp _ ) ->
            action


updateAmqpConfig : AmqpActionMsg -> TriggerAction.AmqpActionConfig -> TriggerAction.AmqpActionConfig
updateAmqpConfig amqpMsg config =
    case amqpMsg of
        AmqpNoop ->
            config

        UpdateExchange newExchange ->
            { config | exchange = newExchange }

        UpdateRoutingKey newRoutingKey ->
            { config | routingKey = newRoutingKey }

        UpdateExpiration newExpiration ->
            { config | expirationms = newExpiration }

        UpdatePriority newPriority ->
            { config | priority = newPriority }

        UpdatePersistence newPersistence ->
            { config | persistent = newPersistence }


updateHttpConfig : HttpActionMsg -> TriggerAction.HttpActionConfig -> TriggerAction.HttpActionConfig
updateHttpConfig httpMsg config =
    case httpMsg of
        HttpNoop ->
            config

        UpdateUrl newUrl ->
            { config | url = newUrl }

        UpdateMethod newMethod ->
            { config | httpMethod = newMethod }

        UpdateTemplate newTemplateType ->
            case ( newTemplateType, config.template ) of
                ( DefaultAstarteTemplate, TriggerAction.Mustache _ ) ->
                    { config | template = TriggerAction.NoTemplate }

                ( MustacheTemplate, TriggerAction.NoTemplate ) ->
                    { config | template = TriggerAction.Mustache "" }

                -- No switching required
                ( MustacheTemplate, TriggerAction.Mustache _ ) ->
                    config

                ( DefaultAstarteTemplate, TriggerAction.NoTemplate ) ->
                    config

        UpdateMustachePayload mustacheTemplate ->
            case config.template of
                TriggerAction.Mustache _ ->
                    let
                        newTemplate =
                            TriggerAction.Mustache mustacheTemplate
                    in
                    { config | template = newTemplate }

                -- Ignore unmatching message
                TriggerAction.NoTemplate ->
                    config



-- Validation


exchangeFormatRegex : Regex
exchangeFormatRegex =
    Regex.fromString "^astarte_events_[a-zA-Z0-9]+_[a-zA-Z0-9_\\.\\:]+$"
        |> Maybe.withDefault Regex.never


routingKeyFormatRegex : Regex
routingKeyFormatRegex =
    Regex.fromString "^[^{}]+$"
        |> Maybe.withDefault Regex.never


isValidExchange : String -> Bool
isValidExchange exchange =
    Regex.contains exchangeFormatRegex exchange && (String.length exchange < 256)


isValidRoutingKey : String -> Bool
isValidRoutingKey routingKey =
    Regex.contains routingKeyFormatRegex routingKey && (String.length routingKey < 256)



-- View


view : Config msg -> TriggerAction -> Bool -> List (Html msg)
view config action editMode =
    let
        actionSelection =
            actionTypeSelector action editMode
                |> Html.map config.updateMsg

        actionSpecificHtml =
            case action of
                TriggerAction.Amqp amqpConfig ->
                    amqpTriggerAction amqpConfig
                        editMode
                        config.updateMsg
                        config.newAmqpHeaderMsg
                        config.editAmqpHeaderMsg
                        config.deleteAmqpHeaderMsg

                TriggerAction.Http httpConfig ->
                    httpTriggerAction httpConfig
                        editMode
                        config.updateMsg
                        config.newHttpHeaderMsg
                        config.editHttpHeaderMsg
                        config.deleteHttpHeaderMsg
    in
    actionSelection :: actionSpecificHtml


actionOptions : TriggerAction -> List (Select.Item Msg)
actionOptions selectedAction =
    let
        isHttp =
            case selectedAction of
                TriggerAction.Amqp _ ->
                    False

                TriggerAction.Http _ ->
                    True
    in
    [ ( "HTTP request", isHttp )
    , ( "AMQP Message", not isHttp )
    ]
        |> List.map simpleSelectOption


actionMessage : String -> Msg
actionMessage str =
    case str of
        "AMQP Message" ->
            UpdateAction AmqpMessage

        "HTTP request" ->
            UpdateAction HttpRequest

        _ ->
            Noop


actionTypeSelector : TriggerAction -> Bool -> Html Msg
actionTypeSelector action editMode =
    Form.row []
        [ Form.col []
            [ Form.group []
                [ Form.label [ for "triggerActionType" ] [ Html.text "Action type" ]
                , Select.select
                    [ Select.id "triggerActionType"
                    , Select.disabled editMode
                    , Select.onChange actionMessage
                    ]
                    (actionOptions action)
                ]
            ]
        ]



-- Amqp action


amqpTriggerAction :
    TriggerAction.AmqpActionConfig
    -> Bool
    -> (Msg -> msg)
    -> msg
    -> (String -> msg)
    -> (String -> msg)
    -> List (Html msg)
amqpTriggerAction config editMode messageTag newStaticHeader editStaticHeader deleteStaticHeader =
    [ amqpExchangeRow config.exchange editMode
        |> Html.map messageTag
    , amqpRoutingKeyRow config.routingKey editMode
        |> Html.map messageTag
    , Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "amqpPersistency" ] [ Html.text "Persistency" ]
                , Checkbox.checkbox
                    [ Checkbox.id "amqpPersistency"
                    , Checkbox.disabled editMode
                    , Checkbox.checked config.persistent
                    , Checkbox.onCheck UpdatePersistence
                    ]
                    "Publish persistent messages"
                    |> Html.map UpdateAmqpAction
                    |> Html.map messageTag
                ]
            ]
        ]
    , Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "amqpPriority" ] [ Html.text "Priority" ]
                , Input.number
                    [ Input.id "amqpPriority"
                    , Input.readonly editMode
                    , Input.value <| String.fromInt config.priority
                    , Input.onInput (stringToNumericMessage UpdatePriority AmqpNoop)
                    , Input.attrs [ Html.Attributes.min "0", Html.Attributes.max "9" ]
                    ]
                    |> Html.map UpdateAmqpAction
                    |> Html.map messageTag
                ]
            ]
        ]
    , Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "amqpExpiration" ] [ Html.text "Expiration" ]
                , InputGroup.number
                    [ Input.id "amqpExpiration"
                    , Input.disabled editMode
                    , Input.value <| String.fromInt config.expirationms
                    , Input.onInput (stringToNumericMessage UpdateExpiration AmqpNoop)
                    , Input.attrs [ Html.Attributes.min "1" ]
                    ]
                    |> InputGroup.config
                    |> InputGroup.successors
                        [ InputGroup.span [] [ Html.text "milliseconds" ] ]
                    |> InputGroup.view
                    |> Html.map UpdateAmqpAction
                    |> Html.map messageTag
                ]
            ]
        ]
    , staticAmqpHeaders config.staticHeaders editMode newStaticHeader editStaticHeader deleteStaticHeader
    ]


amqpExchangeRow : String -> Bool -> Html Msg
amqpExchangeRow exchange editMode =
    let
        isValid =
            isValidExchange exchange

        isInvalid =
            exchange /= "" && not isValid && not editMode
    in
    Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "amqpExchange" ] [ Html.text "Exchange" ]
                , [ Input.id "amqpExchange"
                  , Input.readonly editMode
                  , Input.value exchange
                  , Input.onInput UpdateExchange
                  ]
                    |> addWhen isValid Input.success
                    |> addWhen isInvalid Input.danger
                    |> Input.text
                    |> Html.map UpdateAmqpAction
                ]
            ]
        ]


amqpRoutingKeyRow : String -> Bool -> Html Msg
amqpRoutingKeyRow routingKey editMode =
    let
        isValid =
            isValidRoutingKey routingKey

        isInvalid =
            routingKey /= "" && not isValid && not editMode
    in
    Form.row []
        [ Form.col [ Col.sm12 ]
            [ Form.group []
                [ Form.label [ for "amqpRoutingKey" ] [ Html.text "Routing key" ]
                , [ Input.id "amqpRoutingKey"
                  , Input.readonly editMode
                  , Input.value routingKey
                  , Input.onInput UpdateRoutingKey
                  ]
                    |> addWhen isValid Input.success
                    |> addWhen isInvalid Input.danger
                    |> Input.text
                    |> Html.map UpdateAmqpAction
                ]
            ]
        ]



-- Amqp static headers


staticAmqpHeaders :
    Dict String String
    -> Bool
    -> msg
    -> (String -> msg)
    -> (String -> msg)
    -> Html msg
staticAmqpHeaders staticHeaders editMode newStaticHeader editStaticHeader deleteStaticHeader =
    let
        table =
            if editMode then
                headersTable staticHeaders

            else
                editableheadersTable staticHeaders editStaticHeader deleteStaticHeader

        addHeaderLink =
            Html.a
                [ { message = newStaticHeader
                  , preventDefault = True
                  , stopPropagation = False
                  }
                    |> Decode.succeed
                    |> Events.custom "click"
                , href "#"
                , Html.Attributes.target "_self"
                ]
                [ Icons.render Icons.Add [ Spacing.mr1 ]
                , Html.text "Add static AMQP headers"
                ]

        rowContent =
            []
                |> addWhen (not <| Dict.isEmpty staticHeaders) table
                |> addWhen (not <| editMode) addHeaderLink
    in
    if List.isEmpty rowContent then
        Html.text ""

    else
        Form.row []
            [ Form.col [ Col.sm12 ]
                rowContent
            ]



-- Http action


httpTriggerAction :
    TriggerAction.HttpActionConfig
    -> Bool
    -> (Msg -> msg)
    -> msg
    -> (String -> msg)
    -> (String -> msg)
    -> List (Html msg)
httpTriggerAction config editMode messageTag newCustomHeader editCustomHeader deleteCustomHeader =
    [ Form.row []
        [ Form.col [ Col.sm4 ]
            [ Form.group []
                [ Form.label [ for "triggerMethod" ] [ Html.text "Method" ]
                , Select.select
                    [ Select.id "triggerMethod"
                    , Select.disabled editMode
                    , Select.onChange actionMethodMessage
                    ]
                    (actionHttpMethodOptions config.httpMethod)
                ]
            ]
        , Form.col [ Col.sm8 ]
            [ Form.group []
                [ Form.label [ for "triggerUrl" ] [ Html.text "URL" ]
                , Input.text
                    [ Input.id "triggerUrl"
                    , Input.readonly editMode
                    , Input.value config.url
                    , Input.onInput UpdateUrl
                    ]
                ]
            ]
        ]
        |> Html.map UpdateHttpAction
        |> Html.map messageTag
    , payloadTemplate config.template editMode
        |> Html.map UpdateHttpAction
        |> Html.map messageTag
    , customHttpHeaders config.customHeaders editMode newCustomHeader editCustomHeader deleteCustomHeader
    ]



-- Http method


actionHttpMethodOptions : TriggerAction.HttpMethod -> List (Select.Item HttpActionMsg)
actionHttpMethodOptions selectedMethod =
    [ ( "DELETE", selectedMethod == TriggerAction.Delete )
    , ( "GET", selectedMethod == TriggerAction.Get )
    , ( "HEAD", selectedMethod == TriggerAction.Head )
    , ( "OPTIONS", selectedMethod == TriggerAction.Options )
    , ( "PATCH", selectedMethod == TriggerAction.Patch )
    , ( "POST", selectedMethod == TriggerAction.Post )
    , ( "PUT", selectedMethod == TriggerAction.Put )
    ]
        |> List.map simpleSelectOption


actionMethodMessage : String -> HttpActionMsg
actionMethodMessage str =
    case str of
        "DELETE" ->
            UpdateMethod TriggerAction.Delete

        "GET" ->
            UpdateMethod TriggerAction.Get

        "HEAD" ->
            UpdateMethod TriggerAction.Head

        "OPTIONS" ->
            UpdateMethod TriggerAction.Options

        "PATCH" ->
            UpdateMethod TriggerAction.Patch

        "POST" ->
            UpdateMethod TriggerAction.Post

        "PUT" ->
            UpdateMethod TriggerAction.Put

        _ ->
            HttpNoop



-- Http template


payloadTemplate : TriggerAction.Template -> Bool -> Html HttpActionMsg
payloadTemplate template editMode =
    let
        templateTypeSelector =
            Form.col
                [ Col.sm12 ]
                [ templateSelection template editMode ]
    in
    Form.row []
        (case template of
            TriggerAction.NoTemplate ->
                [ templateTypeSelector ]

            TriggerAction.Mustache templateBody ->
                [ templateTypeSelector
                , Form.col
                    [ Col.sm12 ]
                    [ Form.group []
                        [ Form.label [ for "actionPayload" ] [ Html.text "Payload" ]
                        , Textarea.textarea
                            [ Textarea.id "actionPayload"
                            , Textarea.attrs [ readonly editMode ]
                            , Textarea.value templateBody
                            , Textarea.onInput UpdateMustachePayload
                            ]
                        ]
                    ]
                ]
        )


templateOptions : TriggerAction.Template -> List (Select.Item HttpActionMsg)
templateOptions selectedTemplate =
    let
        isMustache =
            case selectedTemplate of
                TriggerAction.NoTemplate ->
                    False

                TriggerAction.Mustache _ ->
                    True
    in
    [ ( "Use default event format (JSON)", not isMustache )
    , ( "Mustache", isMustache )
    ]
        |> List.map simpleSelectOption


templateMessage : String -> HttpActionMsg
templateMessage str =
    case str of
        "Use default event format (JSON)" ->
            UpdateTemplate DefaultAstarteTemplate

        "Mustache" ->
            UpdateTemplate MustacheTemplate

        _ ->
            HttpNoop


templateSelection : TriggerAction.Template -> Bool -> Html HttpActionMsg
templateSelection template editMode =
    Form.group []
        [ Form.label [ for "triggerTemplateType" ] [ Html.text "Payload type" ]
        , Select.select
            [ Select.id "triggerTemplateType"
            , Select.disabled editMode
            , Select.onChange templateMessage
            ]
            (templateOptions template)
        ]



-- Http custom headers


customHttpHeaders :
    Dict String String
    -> Bool
    -> msg
    -> (String -> msg)
    -> (String -> msg)
    -> Html msg
customHttpHeaders customHeaders editMode newCustomHeader editCustomHeader deleteCustomHeader =
    let
        table =
            if editMode then
                headersTable customHeaders

            else
                editableheadersTable customHeaders editCustomHeader deleteCustomHeader

        addHeaderLink =
            Html.a
                [ { message = newCustomHeader
                  , preventDefault = True
                  , stopPropagation = False
                  }
                    |> Decode.succeed
                    |> Events.custom "click"
                , href "#"
                , Html.Attributes.target "_self"
                ]
                [ Icons.render Icons.Add [ Spacing.mr1 ]
                , Html.text "Add custom HTTP headers"
                ]

        rowContent =
            []
                |> addWhen (not <| Dict.isEmpty customHeaders) table
                |> addWhen (not <| editMode) addHeaderLink
    in
    if List.isEmpty rowContent then
        Html.text ""

    else
        Form.row []
            [ Form.col [ Col.sm12 ]
                rowContent
            ]



-- Html utilities


headersTable : Dict String String -> Html msg
headersTable headers =
    Table.simpleTable
        ( Table.simpleThead
            [ Table.th []
                [ Html.text "Header" ]
            , Table.th []
                [ Html.text "Value" ]
            ]
        , Table.tbody []
            (headers
                |> Dict.toList
                |> List.map keyValueTableRow
            )
        )


editableheadersTable : Dict String String -> (String -> msg) -> (String -> msg) -> Html msg
editableheadersTable headers editHeader deleteHeader =
    if Dict.isEmpty headers then
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
                (headers
                    |> Dict.toList
                    |> List.map (keyValueTableRowWithControls editHeader deleteHeader)
                )
            )


keyValueTableRow : ( String, String ) -> Table.Row msg
keyValueTableRow ( header, value ) =
    Table.tr []
        [ Table.td []
            [ Html.text header ]
        , Table.td []
            [ Html.text value ]
        ]


keyValueTableRowWithControls :
    (String -> msg)
    -> (String -> msg)
    -> ( String, String )
    -> Table.Row msg
keyValueTableRowWithControls editMsg deleteMsg ( header, value ) =
    Table.tr []
        [ Table.td []
            [ Html.text header ]
        , Table.td []
            [ Html.text value ]
        , Table.td [ Table.cellAttr <| class "text-center" ]
            [ Icons.render Icons.Edit
                [ class "color-grey action-icon"
                , Spacing.mr2
                , Events.onClick (editMsg header)
                ]
            , Icons.render Icons.Erase
                [ class "color-red action-icon"
                , Events.onClick (deleteMsg header)
                ]
            ]
        ]


stringToNumericMessage : (Int -> msg) -> msg -> String -> msg
stringToNumericMessage numericMessage noopMessage value =
    case String.toInt value of
        Just num ->
            numericMessage num

        Nothing ->
            noopMessage


simpleSelectOption : ( String, Bool ) -> Select.Item msg
simpleSelectOption ( selectValue, isSelected ) =
    Select.item
        [ value selectValue
        , selected isSelected
        ]
        [ Html.text selectValue ]
