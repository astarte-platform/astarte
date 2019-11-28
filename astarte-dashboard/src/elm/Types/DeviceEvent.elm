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


module Types.DeviceEvent exposing (DeviceEvent, Event(..), decoder)

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
    | IncomingData ValueParams
    | ValueStored ValueParams
    | ValueChanged ValueChangeParams
    | ValueChangeApplied ValueChangeParams
    | PathCreated ValueParams
    | PathRemoved PathParams
    | Other String


type alias ConnectionParams =
    { ip : String }


type alias ValueParams =
    { interface : String
    , path : String
    , value : AstarteValue
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

        "incoming_data" ->
            Decode.map IncomingData valueParamsDecoder

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


connectionParamsDecoder : Decoder ConnectionParams
connectionParamsDecoder =
    Decode.map ConnectionParams <| Decode.field "type" Decode.string


valueParamsDecoder : Decoder ValueParams
valueParamsDecoder =
    Decode.map3 ValueParams
        (Decode.field "interface" Decode.string)
        (Decode.field "path" Decode.string)
        (Decode.field "value" AstarteValue.decoder)


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
