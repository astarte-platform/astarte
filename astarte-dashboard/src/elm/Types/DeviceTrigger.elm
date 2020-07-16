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


module Types.DeviceTrigger exposing
    ( DeviceTrigger
    , DeviceTriggerEvent(..)
    , Target(..)
    , decoder
    , deviceTriggerEventToString
    , empty
    , encode
    , setOn
    , stringToDeviceTriggerEvent
    )

import Json.Decode as Decode exposing (Decoder, Value, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Json.Encode as Encode
import JsonHelpers


type alias DeviceTrigger =
    { target : Target
    , on : DeviceTriggerEvent
    }


empty : DeviceTrigger
empty =
    { target = AllDevices
    , on = DeviceConnected
    }


type DeviceTriggerEvent
    = DeviceConnected
    | DeviceDisconnected
    | DeviceError
    | EmptyCacheReceived


type Target
    = AllDevices
    | DeviceGroup String
    | SpecificDevice String



-- Setters


setOn : DeviceTriggerEvent -> DeviceTrigger -> DeviceTrigger
setOn deviceTriggerEvent deviceTrigger =
    { deviceTrigger | on = deviceTriggerEvent }



-- Encoding


encode : DeviceTrigger -> Value
encode deviceTrigger =
    [ [ ( "type", Encode.string "device_trigger" )
      , ( "on", deviceTriggerEventEncoder deviceTrigger.on )
      ]
    , encodeTarget deviceTrigger.target
    ]
        |> List.concat
        |> Encode.object


encodeTarget : Target -> List ( String, Value )
encodeTarget target =
    case target of
        AllDevices ->
            []

        DeviceGroup groupName ->
            [ ( "group_name", Encode.string groupName ) ]

        SpecificDevice deviceId ->
            [ ( "device_id", Encode.string deviceId ) ]


deviceTriggerEventEncoder : DeviceTriggerEvent -> Value
deviceTriggerEventEncoder deviceEvent =
    deviceEvent
        |> deviceTriggerEventToString
        |> Encode.string


deviceTriggerEventToString : DeviceTriggerEvent -> String
deviceTriggerEventToString d =
    case d of
        DeviceConnected ->
            "device_connected"

        DeviceDisconnected ->
            "device_disconnected"

        DeviceError ->
            "device_error"

        EmptyCacheReceived ->
            "device_empty_cache_received"



-- Decoding


decoder : Decoder DeviceTrigger
decoder =
    Decode.succeed deviceTriggerDecoderHelper
        |> optional "group_name" string "*"
        |> optional "device_id" string "*"
        |> required "on" deviceTriggerEventDecoder
        |> resolve


deviceTriggerDecoderHelper : String -> String -> DeviceTriggerEvent -> Decoder DeviceTrigger
deviceTriggerDecoderHelper groupName deviceId on =
    case ( groupName, deviceId ) of
        ( "*", "*" ) ->
            Decode.succeed
                { target = AllDevices
                , on = on
                }

        ( _, "*" ) ->
            Decode.succeed
                { target = DeviceGroup groupName
                , on = on
                }

        ( "*", _ ) ->
            Decode.succeed
                { target = SpecificDevice deviceId
                , on = on
                }

        ( _, _ ) ->
            Decode.fail "Cannot have both device ID and group name"


deviceTriggerEventDecoder : Decoder DeviceTriggerEvent
deviceTriggerEventDecoder =
    Decode.string
        |> Decode.andThen (stringToDeviceTriggerEvent >> JsonHelpers.resultToDecoder)


stringToDeviceTriggerEvent : String -> Result String DeviceTriggerEvent
stringToDeviceTriggerEvent s =
    case s of
        "device_connected" ->
            Ok DeviceConnected

        "device_disconnected" ->
            Ok DeviceDisconnected

        "device_error" ->
            Ok DeviceError

        "device_empty_cache_received" ->
            Ok EmptyCacheReceived

        _ ->
            Err <| "Uknown device trigger event: " ++ s
