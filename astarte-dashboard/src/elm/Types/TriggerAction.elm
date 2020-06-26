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


module Types.TriggerAction exposing
    ( AmqpActionConfig
    , HttpActionConfig
    , HttpMethod(..)
    , Template(..)
    , TriggerAction(..)
    , decoder
    , default
    , emptyAmqpAction
    , emptyHttpAction
    , encode
    )

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Decode.Pipeline exposing (hardcoded, optional, required, resolve)
import Json.Encode as Encode
import ListUtils exposing (addWhen)


type TriggerAction
    = Amqp AmqpActionConfig
    | Http HttpActionConfig


type alias AmqpActionConfig =
    { exchange : String
    , routingKey : String
    , staticHeaders : Dict String String
    , expirationms : Int
    , priority : Int
    , persistent : Bool
    }


type alias HttpActionConfig =
    { url : String
    , httpMethod : HttpMethod
    , staticHeaders : Dict String String
    , template : Template
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


emptyHttpAction : TriggerAction
emptyHttpAction =
    Http
        { url = ""
        , httpMethod = Post
        , staticHeaders = Dict.empty
        , template = NoTemplate
        }


emptyAmqpAction : TriggerAction
emptyAmqpAction =
    Amqp
        { exchange = ""
        , routingKey = ""
        , staticHeaders = Dict.empty
        , expirationms = 0
        , priority = 0
        , persistent = False
        }


default : TriggerAction
default =
    emptyHttpAction



-- Encoding


encode : TriggerAction -> Value
encode action =
    case action of
        Amqp config ->
            [ ( "amqp_message_persistent", Encode.bool config.persistent )
            , ( "amqp_message_expiration_ms", Encode.int config.expirationms )
            , ( "amqp_exchange", Encode.string config.exchange )
            ]
                |> addWhen (config.routingKey /= "")
                    ( "amqp_routing_key", Encode.string config.routingKey )
                |> addWhen (config.priority > 0)
                    ( "amqp_message_priority", Encode.int config.priority )
                |> addWhen (not <| Dict.isEmpty config.staticHeaders)
                    ( "amqp_static_headers", Encode.dict identity Encode.string config.staticHeaders )
                |> List.reverse
                |> Encode.object

        Http config ->
            Encode.object
                ([ ( "http_url", Encode.string config.url )
                 , ( "http_method", encodeMethod config.httpMethod )
                 , ( "http_static_headers", Encode.dict identity Encode.string config.staticHeaders )
                 ]
                    ++ templateEncoder config.template
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



-- Decoding


decoder : Decoder TriggerAction
decoder =
    Decode.oneOf
        [ decodeAmqpAction
        , decodeHttpPostAction
        , decodeStandardHttpAction
        ]


decodeAmqpAction : Decoder TriggerAction
decodeAmqpAction =
    Decode.succeed AmqpActionConfig
        |> required "amqp_exchange" Decode.string
        |> optional "amqp_routing_key" Decode.string ""
        |> optional "amqp_static_headers" (Decode.dict Decode.string) Dict.empty
        |> required "amqp_message_expiration_ms" Decode.int
        |> optional "amqp_message_priority" Decode.int 0
        |> required "amqp_message_persistent" Decode.bool
        |> Decode.andThen
            (\config ->
                Decode.succeed (Amqp config)
            )


decodeHttpPostAction : Decoder TriggerAction
decodeHttpPostAction =
    Decode.succeed buildHttpAction
        |> required "http_post_url" Decode.string
        |> hardcoded Post
        |> optional "http_static_headers" (Decode.nullable <| Decode.dict Decode.string) Nothing
        |> optional "template_type" (Decode.nullable Decode.string) Nothing
        |> optional "template" (Decode.nullable Decode.string) Nothing
        |> resolve


decodeStandardHttpAction : Decoder TriggerAction
decodeStandardHttpAction =
    Decode.succeed buildHttpAction
        |> required "http_url" Decode.string
        |> required "http_method" methodDecoder
        |> optional "http_static_headers" (Decode.nullable <| Decode.dict Decode.string) Nothing
        |> optional "template_type" (Decode.nullable Decode.string) Nothing
        |> optional "template" (Decode.nullable Decode.string) Nothing
        |> resolve


buildHttpAction : String -> HttpMethod -> Maybe (Dict String String) -> Maybe String -> Maybe String -> Decoder TriggerAction
buildHttpAction url method maybeHeaders maybeTemplateType maybeTemplate =
    let
        headers =
            Maybe.withDefault Dict.empty maybeHeaders
    in
    case stringsToTemplate maybeTemplateType maybeTemplate of
        Ok template ->
            Decode.succeed <| Http <| HttpActionConfig url method headers template

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
        |> Decode.andThen
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
