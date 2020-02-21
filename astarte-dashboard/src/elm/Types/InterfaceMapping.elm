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


module Types.InterfaceMapping exposing
    ( BaseType(..)
    , DatabaseRetention(..)
    , InterfaceMapping
    , MappingType(..)
    , Reliability(..)
    , Retention(..)
    , decoder
    , empty
    , encode
    , isGoodEndpoint
    , isValid
    , isValidEndpoint
    , isValidType
    , mappingTypeList
    , mappingTypeToEnglishString
    , mappingTypeToString
    , reliabilityToEnglishString
    , retentionToEnglishString
    , setAllowUnset
    , setDatabaseRetention
    , setDescription
    , setDoc
    , setDraft
    , setEndpoint
    , setExpiry
    , setExplicitTimestamp
    , setReliability
    , setRetention
    , setTTL
    , setType
    , stringToDatabaseRetention
    , stringToMappingType
    , stringToReliability
    , stringToRetention
    )

import Json.Decode as Decode exposing (Decoder, Value, bool, decodeString, int, list, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as Encode
import JsonHelpers
import Regex exposing (Regex)
import Types.AstarteValue as AstarteValue


type alias InterfaceMapping =
    { endpoint : String
    , mType : MappingType
    , reliability : Reliability
    , retention : Retention
    , expiry : Int
    , databaseRetention : DatabaseRetention
    , ttl : Int
    , allowUnset : Bool
    , explicitTimestamp : Bool
    , description : String
    , doc : String
    , draft : Bool
    }


empty : InterfaceMapping
empty =
    { endpoint = ""
    , mType = Single DoubleMapping
    , reliability = Unreliable
    , retention = Discard
    , expiry = 0
    , databaseRetention = NoTTL
    , ttl = 60
    , allowUnset = False
    , explicitTimestamp = False
    , description = ""
    , doc = ""
    , draft = True
    }


type MappingType
    = Single BaseType
    | Array BaseType


type BaseType
    = DoubleMapping
    | IntMapping
    | BoolMapping
    | LongIntMapping
    | StringMapping
    | BinaryBlobMapping
    | DateTimeMapping


type Reliability
    = Unreliable
    | Guaranteed
    | Unique


type Retention
    = Discard
    | Volatile
    | Stored


type DatabaseRetention
    = NoTTL
    | UseTTL



-- Regular expressions


validEndpointRegex : Regex
validEndpointRegex =
    Regex.fromString "^(/(%{([a-zA-Z][a-zA-Z0-9_]*)}|[a-zA-Z][a-zA-Z0-9_]*)){1,64}$"
        |> Maybe.withDefault Regex.never


isValid : InterfaceMapping -> Bool
isValid mapping =
    [ isValidEndpoint mapping.endpoint
    , (mapping.retention == Discard && mapping.expiry == 0)
        || (mapping.retention /= Discard && mapping.expiry >= 0)
    ]
        |> List.all ((==) True)


mappingTypeList : List MappingType
mappingTypeList =
    [ Single DoubleMapping
    , Single IntMapping
    , Single BoolMapping
    , Single LongIntMapping
    , Single StringMapping
    , Single BinaryBlobMapping
    , Single DateTimeMapping
    , Array DoubleMapping
    , Array IntMapping
    , Array BoolMapping
    , Array LongIntMapping
    , Array StringMapping
    , Array BinaryBlobMapping
    , Array DateTimeMapping
    ]



-- Setters


setEndpoint : String -> InterfaceMapping -> InterfaceMapping
setEndpoint endpoint mapping =
    { mapping | endpoint = endpoint }


setType : MappingType -> InterfaceMapping -> InterfaceMapping
setType mType mapping =
    { mapping | mType = mType }


setReliability : Reliability -> InterfaceMapping -> InterfaceMapping
setReliability reliability mapping =
    { mapping | reliability = reliability }


setRetention : Retention -> InterfaceMapping -> InterfaceMapping
setRetention retention mapping =
    { mapping | retention = retention }


setExpiry : Int -> InterfaceMapping -> InterfaceMapping
setExpiry expiry mapping =
    { mapping | expiry = expiry }


setDatabaseRetention : DatabaseRetention -> InterfaceMapping -> InterfaceMapping
setDatabaseRetention databaseRetention mapping =
    { mapping | databaseRetention = databaseRetention }


setTTL : Int -> InterfaceMapping -> InterfaceMapping
setTTL ttl mapping =
    { mapping | ttl = ttl }


setAllowUnset : Bool -> InterfaceMapping -> InterfaceMapping
setAllowUnset allow mapping =
    { mapping | allowUnset = allow }


setExplicitTimestamp : Bool -> InterfaceMapping -> InterfaceMapping
setExplicitTimestamp explicitTimestamp mapping =
    { mapping | explicitTimestamp = explicitTimestamp }


setDescription : String -> InterfaceMapping -> InterfaceMapping
setDescription description mapping =
    { mapping | description = description }


setDoc : String -> InterfaceMapping -> InterfaceMapping
setDoc doc mapping =
    { mapping | doc = doc }


setDraft : InterfaceMapping -> Bool -> InterfaceMapping
setDraft mapping draft =
    { mapping | draft = draft }



-- Encoding


encode : InterfaceMapping -> Value
encode mapping =
    [ [ ( "endpoint", Encode.string mapping.endpoint )
      , ( "type", encodeMappingType mapping.mType )
      ]
    , JsonHelpers.encodeOptionalFields
        [ ( "reliability", encodeReliability mapping.reliability, mapping.reliability == Unreliable )
        , ( "retention", encodeRetention mapping.retention, mapping.retention == Discard )
        , ( "expiry", Encode.int mapping.expiry, mapping.expiry == 0 )
        , ( "database_retention_policy", databaseRetentionEncoder mapping.databaseRetention, mapping.databaseRetention == NoTTL )
        , ( "database_retention_ttl", Encode.int mapping.ttl, mapping.databaseRetention == NoTTL )
        , ( "allow_unset", Encode.bool mapping.allowUnset, mapping.allowUnset == False )
        , ( "explicit_timestamp", Encode.bool mapping.explicitTimestamp, mapping.explicitTimestamp == False )
        , ( "description", Encode.string mapping.description, mapping.description == "" )
        , ( "doc", Encode.string mapping.doc, mapping.doc == "" )
        ]
    ]
        |> List.concat
        |> Encode.object


encodeMappingType : MappingType -> Value
encodeMappingType t =
    mappingTypeToString t
        |> Encode.string


encodeReliability : Reliability -> Value
encodeReliability r =
    case r of
        Unreliable ->
            Encode.string "unreliable"

        Guaranteed ->
            Encode.string "guaranteed"

        Unique ->
            Encode.string "unique"


encodeRetention : Retention -> Value
encodeRetention r =
    case r of
        Discard ->
            Encode.string "discard"

        Volatile ->
            Encode.string "volatile"

        Stored ->
            Encode.string "stored"


databaseRetentionEncoder : DatabaseRetention -> Value
databaseRetentionEncoder r =
    case r of
        NoTTL ->
            Encode.string "no_ttl"

        UseTTL ->
            Encode.string "use_ttl"


mappingTypeToString : MappingType -> String
mappingTypeToString t =
    case t of
        Single baseType ->
            baseTypeToString baseType

        Array baseType ->
            baseTypeToString baseType ++ "array"


baseTypeToString : BaseType -> String
baseTypeToString baseType =
    case baseType of
        DoubleMapping ->
            "double"

        IntMapping ->
            "integer"

        BoolMapping ->
            "boolean"

        LongIntMapping ->
            "longinteger"

        StringMapping ->
            "string"

        BinaryBlobMapping ->
            "binaryblob"

        DateTimeMapping ->
            "datetime"



-- Decoding


decoder : Decoder InterfaceMapping
decoder =
    Decode.succeed InterfaceMapping
        |> required "endpoint" string
        |> required "type" mappingTypeDecoder
        |> optional "reliability" reliabilityDecoder Unreliable
        |> optional "retention" retentionDecoder Discard
        |> optional "expiry" int 0
        |> optional "database_retention_policy" databaseRetentionDecoder NoTTL
        |> optional "database_retention_ttl" int 60
        |> optional "allow_unset" bool False
        |> optional "explicit_timestamp" bool False
        |> optional "description" string ""
        |> optional "doc" string ""
        |> hardcoded False


mappingTypeDecoder : Decoder MappingType
mappingTypeDecoder =
    Decode.string
        |> Decode.andThen (stringToMappingType >> JsonHelpers.resultToDecoder)


reliabilityDecoder : Decoder Reliability
reliabilityDecoder =
    Decode.string
        |> Decode.andThen (stringToReliability >> JsonHelpers.resultToDecoder)


retentionDecoder : Decoder Retention
retentionDecoder =
    Decode.string
        |> Decode.andThen (stringToRetention >> JsonHelpers.resultToDecoder)


databaseRetentionDecoder : Decoder DatabaseRetention
databaseRetentionDecoder =
    Decode.string
        |> Decode.andThen (stringToDatabaseRetention >> JsonHelpers.resultToDecoder)


stringToMappingType : String -> Result String MappingType
stringToMappingType s =
    case s of
        "double" ->
            Ok <| Single DoubleMapping

        "integer" ->
            Ok <| Single IntMapping

        "boolean" ->
            Ok <| Single BoolMapping

        "longinteger" ->
            Ok <| Single LongIntMapping

        "string" ->
            Ok <| Single StringMapping

        "binaryblob" ->
            Ok <| Single BinaryBlobMapping

        "datetime" ->
            Ok <| Single DateTimeMapping

        "doublearray" ->
            Ok <| Array DoubleMapping

        "integerarray" ->
            Ok <| Array IntMapping

        "booleanarray" ->
            Ok <| Array BoolMapping

        "longintegerarray" ->
            Ok <| Array LongIntMapping

        "stringarray" ->
            Ok <| Array StringMapping

        "binaryblobarray" ->
            Ok <| Array BinaryBlobMapping

        "datetimearray" ->
            Ok <| Array DateTimeMapping

        _ ->
            Err <| "Unknown mapping type: " ++ s


stringToReliability : String -> Result String Reliability
stringToReliability s =
    case s of
        "unreliable" ->
            Ok Unreliable

        "guaranteed" ->
            Ok Guaranteed

        "unique" ->
            Ok Unique

        _ ->
            Err <| "Unknown reliability: " ++ s


stringToRetention : String -> Result String Retention
stringToRetention s =
    case s of
        "discard" ->
            Ok Discard

        "volatile" ->
            Ok Volatile

        "stored" ->
            Ok Stored

        _ ->
            Err <| "Unknown retention: " ++ s


stringToDatabaseRetention : String -> Result String DatabaseRetention
stringToDatabaseRetention s =
    case s of
        "no_ttl" ->
            Ok NoTTL

        "use_ttl" ->
            Ok UseTTL

        _ ->
            Err <| "Unknown retention policy: " ++ s



-- JsonHelpers


isValidType : MappingType -> String -> Bool
isValidType mType value =
    case mType of
        Single baseType ->
            validateBaseType baseType value

        Array baseType ->
            value
                |> toList
                |> List.all (validateBaseType baseType)


validateBaseType : BaseType -> String -> Bool
validateBaseType baseType value =
    case baseType of
        DoubleMapping ->
            case String.toFloat value of
                Just _ ->
                    True

                Nothing ->
                    False

        IntMapping ->
            case String.toInt value of
                Just _ ->
                    True

                Nothing ->
                    False

        BoolMapping ->
            case String.toLower value of
                "true" ->
                    True

                "false" ->
                    True

                _ ->
                    False

        LongIntMapping ->
            AstarteValue.isLongInt value

        StringMapping ->
            True

        BinaryBlobMapping ->
            AstarteValue.isBinaryBlob value

        DateTimeMapping ->
            AstarteValue.isDateTime value


toList : String -> List String
toList arrayString =
    case decodeString (list string) arrayString of
        Ok stringList ->
            stringList

        Err _ ->
            [ arrayString ]


isValidEndpoint : String -> Bool
isValidEndpoint endpoint =
    Regex.contains validEndpointRegex endpoint


isGoodEndpoint : String -> Bool -> Bool
isGoodEndpoint endpoint isObject =
    if isObject then
        isValidEndpoint endpoint && (endpointDepth endpoint > 1)

    else
        isValidEndpoint endpoint


endpointDepth : String -> Int
endpointDepth endpoint =
    String.foldl
        (\c level ->
            if c == '/' then
                level + 1

            else
                level
        )
        0
        endpoint



-- String helpers


mappingTypeToEnglishString : MappingType -> String
mappingTypeToEnglishString t =
    case t of
        Single DoubleMapping ->
            "Double"

        Single IntMapping ->
            "Integer"

        Single BoolMapping ->
            "Boolean"

        Single LongIntMapping ->
            "Long integer"

        Single StringMapping ->
            "String"

        Single BinaryBlobMapping ->
            "Binary blob"

        Single DateTimeMapping ->
            "Date and time"

        Array DoubleMapping ->
            "Array of doubles"

        Array IntMapping ->
            "Array of integers"

        Array BoolMapping ->
            "Array of booleans"

        Array LongIntMapping ->
            "Array of long integers"

        Array StringMapping ->
            "Array of strings"

        Array BinaryBlobMapping ->
            "Array of binary blobs"

        Array DateTimeMapping ->
            "Array of date and time"


reliabilityToEnglishString : Reliability -> String
reliabilityToEnglishString reliability =
    case reliability of
        Unreliable ->
            "Unreliable"

        Guaranteed ->
            "Guaranteed"

        Unique ->
            "Unique"


retentionToEnglishString : Retention -> String
retentionToEnglishString retention =
    case retention of
        Discard ->
            "Discard"

        Volatile ->
            "Volatile"

        Stored ->
            "Stored"
