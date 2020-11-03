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
    ( SimpleTrigger(..)
    , Trigger
    , decoder
    , empty
    , encode
    , fromString
    , setName
    , setSimpleTrigger
    , toPrettySource
    )

import Json.Decode as Decode exposing (Decoder, Value, andThen, decodeString, field, index, map, nullable, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required, resolve)
import Json.Encode as Encode
import Types.DataTrigger as DataTrigger exposing (DataTrigger)
import Types.DeviceTrigger as DeviceTrigger exposing (DeviceTrigger)
import Types.TriggerAction as TriggerAction exposing (TriggerAction)


type alias Trigger =
    { name : String
    , action : TriggerAction
    , simpleTrigger : SimpleTrigger
    }


type SimpleTrigger
    = Data DataTrigger
    | Device DeviceTrigger


empty : Trigger
empty =
    { name = ""
    , action = TriggerAction.default
    , simpleTrigger = Data DataTrigger.empty
    }



-- Setters


setName : String -> Trigger -> Trigger
setName name trigger =
    { trigger | name = name }


setSimpleTrigger : SimpleTrigger -> Trigger -> Trigger
setSimpleTrigger simpleTrigger trigger =
    { trigger | simpleTrigger = simpleTrigger }



-- Encoding


encode : Trigger -> Value
encode t =
    Encode.object
        [ ( "name", Encode.string t.name )
        , ( "action", TriggerAction.encode t.action )
        , ( "simple_triggers", Encode.list simpleTriggerEncoder [ t.simpleTrigger ] )
        ]


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
        |> required "action" TriggerAction.decoder
        |> required "simple_triggers" (index 0 simpleTriggerDecoder)


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
