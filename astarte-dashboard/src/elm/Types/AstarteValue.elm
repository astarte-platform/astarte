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


module Types.AstarteValue exposing (AstarteValue, decoder, isBinaryBlob, isDateTime, isLongInt, toString)

import Json.Decode as Decode exposing (Decoder)
import Regex exposing (Regex)


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


longIntRegex : Regex
longIntRegex =
    Regex.fromString "^[\\+-]?[\\d]+$"
        |> Maybe.withDefault Regex.never


base64Regex : Regex
base64Regex =
    Regex.fromString "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$"
        |> Maybe.withDefault Regex.never


dateTimeRegex : Regex
dateTimeRegex =
    Regex.fromString "^([\\+-]?\\d{4}(?!\\d{2}\\b))((-?)((0[1-9]|1[0-2])(\\3([12]\\d|0[1-9]|3[01]))?|W([0-4]\\d|5[0-2])(-?[1-7])?|(00[1-9]|0[1-9]\\d|[12]\\d{2}|3([0-5]\\d|6[1-6])))([T\\s]((([01]\\d|2[0-3])((:?)[0-5]\\d)?|24\\:?00)([\\.,]\\d+(?!:))?)?(\\17[0-5]\\d([\\.,]\\d+)?)?([zZ]|([\\+-])([01]\\d|2[0-3]):?([0-5]\\d)?)?)?)?$"
        |> Maybe.withDefault Regex.never


isBinaryBlob : String -> Bool
isBinaryBlob value =
    Regex.contains base64Regex value


isDateTime : String -> Bool
isDateTime value =
    Regex.contains dateTimeRegex value


isLongInt : String -> Bool
isLongInt value =
    Regex.contains longIntRegex value


lontIntDecoder : Decoder String
lontIntDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                if Regex.contains longIntRegex str then
                    Decode.succeed str

                else
                    Decode.fail "Invalid long integer format"
            )


dateDecoder : Decoder String
dateDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                if Regex.contains longIntRegex str then
                    Decode.succeed str

                else
                    Decode.fail "Invalid date time format"
            )


binaryDecoder : Decoder String
binaryDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                if Regex.contains longIntRegex str then
                    Decode.succeed str

                else
                    Decode.fail "Invalid binary blob value"
            )


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
