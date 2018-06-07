module Types.DeviceTrigger exposing (..)

import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode
import Utilities


type alias DeviceTrigger =
    { deviceId : String
    , on : DeviceTriggerEvent
    }


empty : DeviceTrigger
empty =
    { deviceId = ""
    , on = DeviceConnected
    }


type DeviceTriggerEvent
    = DeviceConnected
    | DeviceDisconnected
    | DeviceError
    | EmptyCacheReceived



-- Setters


setDeviceId : String -> DeviceTrigger -> DeviceTrigger
setDeviceId deviceId deviceTrigger =
    { deviceTrigger | deviceId = deviceId }


setOn : DeviceTriggerEvent -> DeviceTrigger -> DeviceTrigger
setOn deviceTriggerEvent deviceTrigger =
    { deviceTrigger | on = deviceTriggerEvent }



-- Encoding


encoder : DeviceTrigger -> Value
encoder deviceTrigger =
    Json.Encode.object
        [ ( "type", Json.Encode.string "device_trigger" )
        , ( "device_id", Json.Encode.string deviceTrigger.deviceId )
        , ( "on", deviceTriggerEventEncoder deviceTrigger.on )
        ]


deviceTriggerEventEncoder : DeviceTriggerEvent -> Value
deviceTriggerEventEncoder deviceEvent =
    deviceEvent
        |> deviceTriggerEventToString
        |> Json.Encode.string


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
    decode DeviceTrigger
        |> required "device_id" string
        |> required "on" deviceTriggerEventDecoder


deviceTriggerEventDecoder : Decoder DeviceTriggerEvent
deviceTriggerEventDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToDeviceTriggerEvent >> Utilities.resultToDecoder)


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
