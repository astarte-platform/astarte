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


port module Ports exposing
    ( TaggedDate
    , isoDateToLocalizedString
    , listenToDeviceEvents
    , loadReactPage
    , onDateConverted
    , onDeviceEventReceived
    , onPageRequested
    , onSessionChange
    , storeSession
    , unloadReactPage
    )

import Json.Encode exposing (Value)


port storeSession : Maybe String -> Cmd msg


port onSessionChange : (Value -> msg) -> Sub msg


type alias DeviceSocketParams =
    { secureConnection : Bool
    , appengineUrl : String
    , realm : String
    , token : String
    , deviceId : String
    , interfaces : List InterfaceId
    }


type alias InterfaceId =
    { name : String
    , major : Int
    }


port listenToDeviceEvents : DeviceSocketParams -> Cmd msg


port onDeviceEventReceived : (Value -> msg) -> Sub msg


type alias ReactPage =
    { name : String
    , url : String
    , opts : Value
    }


port loadReactPage : ReactPage -> Cmd msg


port unloadReactPage : () -> Cmd msg


port onPageRequested : (Value -> msg) -> Sub msg



-- As for 13/05/2020 there is no Elm package for datetime to local aware string conversion


type alias TaggedDate =
    { name : String
    , date : Maybe String
    }


port isoDateToLocalizedString : TaggedDate -> Cmd msg


port onDateConverted : (Value -> msg) -> Sub msg
