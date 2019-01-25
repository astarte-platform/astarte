module Types.DeviceTrigger exposing
    ( DeviceTrigger
    , DeviceTriggerEvent(..)
    , decoder
    , deviceTriggerEventToString
    , empty
    , encode
    , setDeviceId
    , setOn
    , stringToDeviceTriggerEvent
    )

import Json.Decode as Decode exposing (Decoder, Value, string)
import Json.Decode.Pipeline exposing (decode, required)
import Json.Encode as Encode
import JsonHelpers


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


encode : DeviceTrigger -> Value
encode deviceTrigger =
    Encode.object
        [ ( "type", Encode.string "device_trigger" )
        , ( "device_id", Encode.string deviceTrigger.deviceId )
        , ( "on", deviceTriggerEventEncoder deviceTrigger.on )
        ]


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
    decode DeviceTrigger
        |> required "device_id" string
        |> required "on" deviceTriggerEventDecoder


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
