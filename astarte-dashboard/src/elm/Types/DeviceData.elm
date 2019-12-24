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


module Types.DeviceData exposing (DeviceData(..), decoder, flatten)

import Dict exposing (Dict)
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Time
import Types.AstarteValue as AstarteValue exposing (AstarteValue)


type DeviceData
    = PathToken String (List DeviceData)
    | PathValue String AstarteValue Time.Posix


type TreeNode
    = InternalNode (Dict String TreeNode)
    | Leaf AstarteValue Time.Posix


flatten : List DeviceData -> List ( String, AstarteValue, Time.Posix )
flatten datalist =
    List.map (flattenValue "") datalist
        |> List.foldl (++) []
        |> List.reverse


flattenValue : String -> DeviceData -> List ( String, AstarteValue, Time.Posix )
flattenValue baseToken data =
    case data of
        PathToken token sublist ->
            List.map (flattenValue (baseToken ++ "/" ++ token)) sublist
                |> List.foldl (++) []

        PathValue token value time ->
            [ ( baseToken ++ "/" ++ token, value, time ) ]



-- Decoding


decoder : Decoder (List DeviceData)
decoder =
    treeDecoder
        |> Decode.andThen (unwrap >> Decode.succeed)


treeDecoder : Decoder (Dict String TreeNode)
treeDecoder =
    Decode.dict <|
        Decode.oneOf
            [ Decode.map2 Leaf
                (Decode.field "value" AstarteValue.decoder)
                (Decode.field "reception_timestamp" Iso8601.decoder)
            , Decode.map InternalNode <| Decode.lazy (\_ -> treeDecoder)
            ]


unwrap : Dict String TreeNode -> List DeviceData
unwrap dict =
    Dict.toList dict
        |> List.map nodeToDeviceData


nodeToDeviceData : ( String, TreeNode ) -> DeviceData
nodeToDeviceData ( token, tag ) =
    case tag of
        InternalNode dict ->
            PathToken token <| unwrap dict

        Leaf value time ->
            PathValue token value time
