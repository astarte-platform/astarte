{-
   This file is part of Astarte.

   Copyright 2019-2020 Ispirata Srl

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


module Types.DeviceEvent exposing (DeviceError(..), DeviceEvent, ErrorParams, Event(..), PathValue(..), decoder)

import Dict exposing (Dict)
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Time
import Types.AstarteValue as AstarteValue exposing (AstarteValue)


type alias DeviceEvent =
    { deviceId : String
    , timestamp : Time.Posix
    , data : Event
    }


type Event
    = DeviceConnected ConnectionParams
    | DeviceDisconnected
    | DeviceError ErrorParams
    | IncomingData ValueParams
    | UnsetProperty PathParams
    | ValueStored ValueParams
    | ValueChanged ValueChangeParams
    | ValueChangeApplied ValueChangeParams
    | PathCreated ValueParams
    | PathRemoved PathParams
    | Other String


type DeviceError
    = WriteOnServerOwnedInterface
    | InvalidInterface
    | InvalidPath
    | MappingNotFound
    | InterfaceLoadingFailed
    | AmbiguousPath
    | UndecodableBsonPayload
    | UnexpectedValueType
    | ValueSizeExceeded
    | UnexpectedObjectKey
    | InvalidIntrospection
    | UnexpectedControlMessage
    | DeviceSessionNotFound
    | ResendInterfacePropertiesFailed
    | EmptyCacheError
    | UserDefined String


type PathValue
    = SingleValue AstarteValue
    | ObjectValue (Dict String AstarteValue)


type alias ConnectionParams =
    { ip : String }


type alias ValueParams =
    { interface : String
    , path : String
    , value : PathValue
    }


type alias ValueChangeParams =
    { interface : String
    , path : String
    , oldValue : AstarteValue
    , newValue : AstarteValue
    }


type alias PathParams =
    { interface : String
    , path : String
    }


type alias ErrorParams =
    { errorType : DeviceError
    , metadata : Dict String String
    }



-- Decoding


decoder : Decoder DeviceEvent
decoder =
    Decode.map3 DeviceEvent
        (Decode.field "device_id" Decode.string)
        (Decode.field "timestamp" Iso8601.decoder)
        (Decode.field "event" eventDecoder)


eventDecoder : Decoder Event
eventDecoder =
    Decode.oneOf
        [ knownEventsDecoder
        , Decode.map Other <| Decode.field "type" Decode.string
        ]


knownEventsDecoder : Decoder Event
knownEventsDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen knownEventsDecoderHelper


knownEventsDecoderHelper : String -> Decoder Event
knownEventsDecoderHelper eventType =
    case eventType of
        "device_connected" ->
            Decode.map DeviceConnected connectionParamsDecoder

        "device_disconnected" ->
            Decode.succeed DeviceDisconnected

        "device_error" ->
            Decode.map DeviceError errorParamsDecoder

        "incoming_data" ->
            Decode.field "value" (Decode.nullable Decode.value)
            |> Decode.andThen (\val ->
                case val of
                    Nothing ->
                        Decode.map UnsetProperty pathParamsDecoder

                    _ ->
                        Decode.map IncomingData valueParamsDecoder
                )

        "value_stored" ->
            Decode.map ValueStored valueParamsDecoder

        "value_changed" ->
            Decode.map ValueChanged valueChangeParamsDecoder

        "value_change_applied" ->
            Decode.map ValueChangeApplied valueChangeParamsDecoder

        "path_created" ->
            Decode.map PathCreated valueParamsDecoder

        "path_removed" ->
            Decode.map PathRemoved pathParamsDecoder

        _ ->
            Decode.fail <| "Unknown event type " ++ eventType


knownDeviceErrorHelper : String -> Decoder DeviceError
knownDeviceErrorHelper errorName =
    case errorName of
        "write_on_server_owned_interface" ->
            Decode.succeed WriteOnServerOwnedInterface

        "invalid_interface" ->
            Decode.succeed InvalidInterface

        "invalid_path" ->
            Decode.succeed InvalidPath

        "mapping_not_found" ->
            Decode.succeed MappingNotFound

        "interface_loading_failed" ->
            Decode.succeed InterfaceLoadingFailed

        "ambiguous_path" ->
            Decode.succeed AmbiguousPath

        "undecodable_bson_payload" ->
            Decode.succeed UndecodableBsonPayload

        "unexpected_value_type" ->
            Decode.succeed UnexpectedValueType

        "value_size_exceeded" ->
            Decode.succeed ValueSizeExceeded

        "unexpected_object_key" ->
            Decode.succeed UnexpectedObjectKey

        "invalid_introspection" ->
            Decode.succeed InvalidIntrospection

        "unexpected_control_message" ->
            Decode.succeed UnexpectedControlMessage

        "device_session_not_found" ->
            Decode.succeed DeviceSessionNotFound

        "resend_interface_properties_failed" ->
            Decode.succeed ResendInterfacePropertiesFailed

        "empty_cache_error" ->
            Decode.succeed EmptyCacheError

        name ->
            Decode.succeed <| UserDefined name


connectionParamsDecoder : Decoder ConnectionParams
connectionParamsDecoder =
    Decode.map ConnectionParams <| Decode.field "device_ip_address" Decode.string


valueParamsDecoder : Decoder ValueParams
valueParamsDecoder =
    Decode.map3 ValueParams
        (Decode.field "interface" Decode.string)
        (Decode.field "path" Decode.string)
        (Decode.field "value" pathValueDecoder)


valueChangeParamsDecoder : Decoder ValueChangeParams
valueChangeParamsDecoder =
    Decode.map4 ValueChangeParams
        (Decode.field "interface" Decode.string)
        (Decode.field "path" Decode.string)
        (Decode.field "old_value" AstarteValue.decoder)
        (Decode.field "new_value" AstarteValue.decoder)


pathParamsDecoder : Decoder PathParams
pathParamsDecoder =
    Decode.map2 PathParams
        (Decode.field "interface" Decode.string)
        (Decode.field "path" Decode.string)


errorParamsDecoder : Decoder ErrorParams
errorParamsDecoder =
    Decode.map2 ErrorParams
        (Decode.field "error_name" deviceErrorDecoder)
        (Decode.field "metadata" <| Decode.dict Decode.string)


deviceErrorDecoder : Decoder DeviceError
deviceErrorDecoder =
    Decode.string
        |> Decode.andThen knownDeviceErrorHelper


pathValueDecoder : Decoder PathValue
pathValueDecoder =
    Decode.oneOf [ singleValueDecoder, objectValueDecoder ]


singleValueDecoder : Decoder PathValue
singleValueDecoder =
    AstarteValue.decoder
        |> Decode.map SingleValue


objectValueDecoder : Decoder PathValue
objectValueDecoder =
    Decode.dict AstarteValue.decoder
        |> Decode.map ObjectValue
