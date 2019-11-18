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


module Types.AstarteValue exposing (AstarteValue, decoder, toString)

import Json.Decode as Decode exposing (Decoder)


type AstarteValue
    = Single BaseType
    | Array (List BaseType)


type BaseType
    = Double_ Float
    | Int_ Int
    | Bool_ Bool
    | LongInt_ String
    | String_ String
    | Binary_ String
    | Date_ String


decoder : Decoder AstarteValue
decoder =
    Decode.oneOf
        [ Decode.map Single valueDecoder
        , Decode.map Array (Decode.list valueDecoder)
        ]


valueDecoder : Decoder BaseType
valueDecoder =
    Decode.oneOf
        [ Decode.map Bool_ Decode.bool
        , Decode.map Int_ Decode.int
        , Decode.map Double_ Decode.float
        , Decode.map LongInt_ lontIntDecoder
        , Decode.map Date_ dateDecoder
        , Decode.map Binary_ binaryDecoder
        , Decode.map String_ Decode.string
        ]


lontIntDecoder : Decoder String
lontIntDecoder =
    Decode.fail "Not implemented"


dateDecoder : Decoder String
dateDecoder =
    Decode.fail "Not implemented"


binaryDecoder : Decoder String
binaryDecoder =
    Decode.fail "Not implemented"


toString : AstarteValue -> String
toString value =
    case value of
        Single val ->
            valueToString val

        Array list ->
            List.map valueToString list
                |> String.join ", "
                |> (\arr -> "[ " ++ arr ++ " ]")


valueToString : BaseType -> String
valueToString value =
    case value of
        Double_ val ->
            String.fromFloat val

        Int_ val ->
            String.fromInt val

        Bool_ val ->
            boolToString val

        LongInt_ val ->
            val

        String_ val ->
            "\"" ++ val ++ "\""

        Binary_ val ->
            "<< " ++ val ++ " >>"

        Date_ val ->
            val


boolToString : Bool -> String
boolToString value =
    if value then
        "true"

    else
        "false"
