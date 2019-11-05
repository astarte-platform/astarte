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
import Json.Decode.Pipeline exposing (optional, required)


type alias Device =
    { id : String
    , aliases : Dict String String
    , connected : Bool
    , introspection : List IntrospectionValue
    , totalReceivedMsgs : Int
    , totalReceivedBytes : Int
    , firstRegistration : String
    , firstCredentialsRequest : String
    , lastSeenIp : String
    , lastDisconnection : String
    , lastCredentialsRequestIp : String
    , lastConnection : String
    }


type IntrospectionValue
    = InterfaceRef String Int Int



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
        |> required "first_registration" Decode.string
        |> required "first_credentials_request" Decode.string
        |> required "last_seen_ip" Decode.string
        |> optional "last_connection" Decode.string ""
        |> required "last_credentials_request_ip" Decode.string
        |> required "last_connection" Decode.string


introspectionsDecoder : Decoder (List IntrospectionValue)
introspectionsDecoder =
    Decode.dict interfaceVersionDecoder
        |> Decode.map introspectionHelper


introspectionHelper : Dict String InterfaceVersion -> List IntrospectionValue
introspectionHelper introspections =
    introspections
        |> Dict.toList
        |> List.map interfaceIdHelper


interfaceIdHelper : ( String, InterfaceVersion ) -> IntrospectionValue
interfaceIdHelper ( interfaceName, interfaceVersion ) =
    InterfaceRef interfaceName interfaceVersion.major interfaceVersion.minor


type alias InterfaceVersion =
    { major : Int
    , minor : Int
    }


interfaceVersionDecoder : Decoder InterfaceVersion
interfaceVersionDecoder =
    Decode.map2 InterfaceVersion
        (Decode.field "major" Decode.int)
        (Decode.field "minor" Decode.int)
