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


module Types.Device exposing (Device, IntrospectionValue(..), decoder)

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (required)


type alias Device =
    { id : String
    , aliases : Dict String String
    , connected : Bool
    , introspection : List IntrospectionValue
    , totalReceivedMsgs : Int
    , totalReceivedBytes : Int
    , firstRegistration : Maybe String
    , firstCredentialsRequest : Maybe String
    , lastSeenIp : Maybe String
    , lastDisconnection : Maybe String
    , lastCredentialsRequestIp : Maybe String
    , lastConnection : Maybe String
    , credentialsinhibited : Bool
    , groups : List String
    , previousInterfaces : List IntrospectionValue
    }


type IntrospectionValue
    = InterfaceInfo String Int Int Int Int



-- Decoding


decoder : Decoder Device
decoder =
    Decode.succeed Device
        |> required "id" Decode.string
        |> required "aliases" (Decode.dict Decode.string)
        |> required "connected" Decode.bool
        |> required "introspection" introspectionsDecoder
        |> required "total_received_msgs" Decode.int
        |> required "total_received_bytes" Decode.int
        |> required "first_registration" (Decode.nullable Decode.string)
        |> required "first_credentials_request" (Decode.nullable Decode.string)
        |> required "last_seen_ip" (Decode.nullable Decode.string)
        |> required "last_disconnection" (Decode.nullable Decode.string)
        |> required "last_credentials_request_ip" (Decode.nullable Decode.string)
        |> required "last_connection" (Decode.nullable Decode.string)
        |> required "credentials_inhibited" Decode.bool
        |> required "groups" (Decode.list Decode.string)
        |> required "previous_interfaces" previousInterfacesDecoder


introspectionsDecoder : Decoder (List IntrospectionValue)
introspectionsDecoder =
    Decode.dict interfaceDataDecoder
        |> Decode.map introspectionHelper


introspectionHelper : Dict String InterfaceData -> List IntrospectionValue
introspectionHelper introspections =
    introspections
        |> Dict.toList
        |> List.map interfaceIdHelper


interfaceIdHelper : ( String, InterfaceData ) -> IntrospectionValue
interfaceIdHelper ( interfaceName, interfaceData ) =
    InterfaceInfo interfaceName interfaceData.major interfaceData.minor interfaceData.exchangedBytes interfaceData.exchangedMsgs


type alias InterfaceData =
    { major : Int
    , minor : Int
    , exchangedBytes : Int
    , exchangedMsgs : Int
    }


interfaceDataDecoder : Decoder InterfaceData
interfaceDataDecoder =
    Decode.map4 InterfaceData
        (Decode.field "major" Decode.int)
        (Decode.field "minor" Decode.int)
        (Decode.field "exchanged_bytes" Decode.int)
        (Decode.field "exchanged_msgs" Decode.int)


previousInterfacesDecoder : Decoder (List IntrospectionValue)
previousInterfacesDecoder =
    Decode.list previousInterfaceDataDecoder
        |> Decode.map (List.map previousInterfacesDecoderHelper)


previousInterfacesDecoderHelper : PreviousInterfaceData -> IntrospectionValue
previousInterfacesDecoderHelper interfaceData =
    InterfaceInfo interfaceData.name interfaceData.major interfaceData.minor interfaceData.exchangedBytes interfaceData.exchangedMsgs


type alias PreviousInterfaceData =
    { name : String
    , major : Int
    , minor : Int
    , exchangedBytes : Int
    , exchangedMsgs : Int
    }


previousInterfaceDataDecoder : Decoder PreviousInterfaceData
previousInterfaceDataDecoder =
    Decode.map5 PreviousInterfaceData
        (Decode.field "name" Decode.string)
        (Decode.field "major" Decode.int)
        (Decode.field "minor" Decode.int)
        (Decode.field "exchanged_bytes" Decode.int)
        (Decode.field "exchanged_msgs" Decode.int)
