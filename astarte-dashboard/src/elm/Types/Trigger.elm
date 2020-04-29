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


module Types.Trigger exposing
    ( Action
    , HttpMethod(..)
    , SimpleTrigger(..)
    , Template(..)
    , Trigger
    , decoder
    , empty
    , encode
    , fromString
    , setName
    , setSimpleTrigger
    , setTemplate
    , setUrl
    , toPrettySource
    )

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, Value, andThen, decodeString, field, index, map, nullable, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required, resolve)
import Json.Encode as Encode
import Types.DataTrigger as DataTrigger exposing (DataTrigger)
import Types.DeviceTrigger as DeviceTrigger exposing (DeviceTrigger)


type alias Trigger =
    { name : String
    , action : Action
    , simpleTrigger : SimpleTrigger
    }


type alias Action =
    { url : String
    , httpMethod : HttpMethod
    , customHeaders : Dict String String
    , template : Template
    }


empty : Trigger
empty =
    { name = ""
    , action = emptyAction
    , simpleTrigger = Data DataTrigger.empty
    }


emptyAction : Action
emptyAction =
    { url = ""
    , httpMethod = Post
    , customHeaders = Dict.empty
    , template = NoTemplate
    }


type Template
    = NoTemplate
    | Mustache String


type HttpMethod
    = Delete
    | Get
    | Head
    | Options
    | Patch
    | Post
    | Put


type SimpleTrigger
    = Data DataTrigger
    | Device DeviceTrigger



-- Setters


setName : String -> Trigger -> Trigger
setName name trigger =
    { trigger | name = name }


setUrl : String -> Trigger -> Trigger
setUrl url trigger =
    let
        action =
            trigger.action

        newAction =
            { action | url = url }
    in
    { trigger | action = newAction }


setTemplate : Template -> Trigger -> Trigger
setTemplate template trigger =
    let
        action =
            trigger.action

        newAction =
            { action | template = template }
    in
    { trigger | action = newAction }


setSimpleTrigger : SimpleTrigger -> Trigger -> Trigger
setSimpleTrigger simpleTrigger trigger =
    { trigger | simpleTrigger = simpleTrigger }



-- Encoding


encode : Trigger -> Value
encode t =
    Encode.object
        [ ( "name", Encode.string t.name )
        , ( "action", encodeAction t.action )
        , ( "simple_triggers", Encode.list simpleTriggerEncoder [ t.simpleTrigger ] )
        ]


encodeAction : Action -> Value
encodeAction action =
    Encode.object
        ([ ( "http_url", Encode.string action.url )
         , ( "http_method", encodeMethod action.httpMethod )
         , ( "http_custom_headers", Encode.dict identity Encode.string action.customHeaders )
         ]
            ++ templateEncoder action.template
        )


templateEncoder : Template -> List ( String, Value )
templateEncoder template =
    case template of
        NoTemplate ->
            []

        Mustache mustacheTemplate ->
            [ ( "template_type", Encode.string "mustache" )
            , ( "template", Encode.string mustacheTemplate )
            ]


encodeMethod : HttpMethod -> Value
encodeMethod method =
    case method of
        Delete ->
            Encode.string "delete"

        Get ->
            Encode.string "get"

        Head ->
            Encode.string "head"

        Options ->
            Encode.string "options"

        Patch ->
            Encode.string "patch"

        Post ->
            Encode.string "post"

        Put ->
            Encode.string "put"


simpleTriggerEncoder : SimpleTrigger -> Value
simpleTriggerEncoder simpleTrigger =
    case simpleTrigger of
        Data dataTrigger ->
            DataTrigger.encode dataTrigger

        Device deviceTrigger ->
            DeviceTrigger.encode deviceTrigger



-- Decoding


decoder : Decoder Trigger
decoder =
    Decode.succeed Trigger
        |> required "name" string
        |> required "action" actionDecoder
        |> required "simple_triggers" (index 0 simpleTriggerDecoder)


actionDecoder : Decoder Action
actionDecoder =
    Decode.oneOf [ decodePostAction, decodeStandardAction ]


decodePostAction : Decoder Action
decodePostAction =
    Decode.succeed buildAction
        |> required "http_post_url" Decode.string
        |> hardcoded Post
        |> optional "http_custom_headers" (Decode.nullable <| Decode.dict Decode.string) Nothing
        |> optional "template_type" (Decode.nullable Decode.string) Nothing
        |> optional "template" (Decode.nullable Decode.string) Nothing
        |> resolve


decodeStandardAction : Decoder Action
decodeStandardAction =
    Decode.succeed buildAction
        |> required "http_url" Decode.string
        |> required "http_method" methodDecoder
        |> optional "http_custom_headers" (Decode.nullable <| Decode.dict Decode.string) Nothing
        |> optional "template_type" (Decode.nullable Decode.string) Nothing
        |> optional "template" (Decode.nullable Decode.string) Nothing
        |> resolve


buildAction : String -> HttpMethod -> Maybe (Dict String String) -> Maybe String -> Maybe String -> Decoder Action
buildAction url method maybeHeaders maybeTemplateType maybeTemplate =
    let
        headers =
            Maybe.withDefault Dict.empty maybeHeaders
    in
    case stringsToTemplate maybeTemplateType maybeTemplate of
        Ok template ->
            Decode.succeed <| Action url method headers template

        Err err ->
            Decode.fail err


stringsToTemplate : Maybe String -> Maybe String -> Result String Template
stringsToTemplate maybeTemplateType maybeTemplate =
    case ( maybeTemplateType, maybeTemplate ) of
        ( Nothing, _ ) ->
            Ok NoTemplate

        ( Just "mustache", Just template ) ->
            Ok <| Mustache template

        ( Just "mustache", Nothing ) ->
            Err "Mustache requires a template"

        ( Just templateType, _ ) ->
            Err <| "Uknown template type: " ++ templateType


methodDecoder : Decoder HttpMethod
methodDecoder =
    Decode.string
        |> andThen
            (\str ->
                case str of
                    "delete" ->
                        Decode.succeed Delete

                    "get" ->
                        Decode.succeed Get

                    "head" ->
                        Decode.succeed Head

                    "options" ->
                        Decode.succeed Options

                    "patch" ->
                        Decode.succeed Patch

                    "post" ->
                        Decode.succeed Post

                    "put" ->
                        Decode.succeed Put

                    _ ->
                        Decode.fail "Unsupported HTTP method"
            )


simpleTriggerDecoder : Decoder SimpleTrigger
simpleTriggerDecoder =
    field "type" string
        |> andThen
            (\str ->
                case str of
                    "data_trigger" ->
                        map Data DataTrigger.decoder

                    "device_trigger" ->
                        map Device DeviceTrigger.decoder

                    _ ->
                        Decode.fail <| "Uknown trigger type " ++ str
            )



-- JsonHelpers


fromString : String -> Result Decode.Error Trigger
fromString source =
    decodeString decoder source


toPrettySource : Trigger -> String
toPrettySource trigger =
    Encode.encode 4 <| encode trigger
