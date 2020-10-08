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


module Types.Interface exposing
    ( AggregationType(..)
    , Interface
    , InterfaceType(..)
    , Owner(..)
    , addMapping
    , compareId
    , decoder
    , editMapping
    , empty
    , encode
    , fromString
    , isGoodInterfaceName
    , isValidInterfaceName
    , mappingsAsList
    , removeMapping
    , sealMappings
    , setAggregation
    , setDescription
    , setDoc
    , setHasMeta
    , setMajor
    , setMinor
    , setName
    , setObjectMappingAttributes
    , setOwnership
    , setType
    , toPrettySource
    )

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, Value, bool, decodeString, int, list, string)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode as Encode
import JsonHelpers
import Regex exposing (Regex)
import Types.InterfaceMapping as InterfaceMapping exposing (InterfaceMapping)


type alias Interface =
    { name : String
    , major : Int
    , minor : Int
    , iType : InterfaceType
    , ownership : Owner
    , aggregation : AggregationType
    , hasMeta : Bool
    , description : String
    , doc : String
    , mappings : Dict String InterfaceMapping
    }


empty : Interface
empty =
    { name = ""
    , major = 0
    , minor = 1
    , iType = Properties
    , ownership = Device
    , aggregation = Individual
    , hasMeta = False
    , description = ""
    , doc = ""
    , mappings = Dict.empty
    }


type InterfaceType
    = Datastream
    | Properties


type Owner
    = Device
    | Server


type AggregationType
    = Individual
    | Object



-- Regex


validInterfaceNameRegex : Regex
validInterfaceNameRegex =
    Regex.fromString "^([a-zA-Z][a-zA-Z0-9]*\\.([a-zA-Z0-9][a-zA-Z0-9-]*\\.)*)?[a-zA-Z][a-zA-Z0-9]*$"
        |> Maybe.withDefault Regex.never



-- Setters


setName : String -> Interface -> Interface
setName name interface =
    { interface | name = name }


setMajor : Int -> Interface -> Interface
setMajor major interface =
    { interface | major = major }


setMinor : Int -> Interface -> Interface
setMinor minor interface =
    { interface | minor = minor }


setType : InterfaceType -> Interface -> Interface
setType iType interface =
    let
        updatedMappings =
            if iType == Datastream then
                Dict.map (\_ m -> m |> InterfaceMapping.setAllowUnset False) interface.mappings

            else
                Dict.map
                    (\_ mapping ->
                        { mapping
                            | reliability = InterfaceMapping.Unreliable
                            , retention = InterfaceMapping.Discard
                            , expiry = 0
                            , explicitTimestamp = False
                        }
                    )
                    interface.mappings
    in
    { interface
        | iType = iType
        , mappings = updatedMappings
    }


setOwnership : Owner -> Interface -> Interface
setOwnership owner interface =
    { interface | ownership = owner }


setAggregation : AggregationType -> Interface -> Interface
setAggregation aggregation interface =
    { interface | aggregation = aggregation }


setHasMeta : Bool -> Interface -> Interface
setHasMeta hasMeta interface =
    { interface | hasMeta = hasMeta }


setDescription : String -> Interface -> Interface
setDescription description interface =
    { interface | description = description }


setDoc : String -> Interface -> Interface
setDoc doc interface =
    { interface | doc = doc }


addMapping : InterfaceMapping -> Interface -> Interface
addMapping mapping interface =
    let
        previousItem =
            Dict.get mapping.endpoint interface.mappings
    in
    case previousItem of
        Nothing ->
            insertMapping mapping interface

        Just m ->
            if m.draft then
                insertMapping mapping interface

            else
                interface


editMapping : InterfaceMapping -> Interface -> Interface
editMapping mapping interface =
    let
        previousItem =
            Dict.get mapping.endpoint interface.mappings
    in
    case previousItem of
        Nothing ->
            interface

        Just m ->
            if m.draft then
                insertMapping mapping interface

            else
                interface


insertMapping : InterfaceMapping -> Interface -> Interface
insertMapping mapping interface =
    { interface | mappings = Dict.insert mapping.endpoint mapping interface.mappings }


removeMapping : InterfaceMapping -> Interface -> Interface
removeMapping mapping interface =
    { interface
        | mappings =
            interface.mappings
                |> Dict.remove mapping.endpoint
    }


sealMappings : Interface -> Interface
sealMappings interface =
    let
        newMappings =
            Dict.map
                (\_ mapping -> InterfaceMapping.setDraft mapping False)
                interface.mappings
    in
    { interface | mappings = newMappings }


setObjectMappingAttributes :
    InterfaceMapping.Reliability
    -> InterfaceMapping.Retention
    -> Int
    -> Bool
    -> InterfaceMapping.DatabaseRetention
    -> Int
    -> Interface
    -> Interface
setObjectMappingAttributes reliability retention expiry explicitTimestamp databaseRetention ttl interface =
    let
        newMappings =
            Dict.map
                (\_ mapping ->
                    { mapping
                        | reliability = reliability
                        , retention = retention
                        , expiry = expiry
                        , explicitTimestamp = explicitTimestamp
                        , databaseRetention = databaseRetention
                        , ttl = ttl
                    }
                )
                interface.mappings
    in
    { interface | mappings = newMappings }



-- Encoding


encode : Interface -> Value
encode interface =
    [ [ ( "interface_name", Encode.string interface.name )
      , ( "version_major", Encode.int interface.major )
      , ( "version_minor", Encode.int interface.minor )
      , ( "type", encodeInterfaceType interface.iType )
      , ( "ownership", encodeOwner interface.ownership )
      ]
    , JsonHelpers.encodeOptionalFields
        [ ( "aggregation", encodeAggregationType interface.aggregation, interface.aggregation == Individual )
        , ( "has_metadata", Encode.bool interface.hasMeta, interface.hasMeta == False )
        , ( "description", Encode.string interface.description, interface.description == "" )
        , ( "doc", Encode.string interface.doc, interface.doc == "" )
        ]
    , [ ( "mappings"
        , Encode.list InterfaceMapping.encode <|
            Dict.values interface.mappings
        )
      ]
    ]
        |> List.concat
        |> Encode.object


encodeInterfaceType : InterfaceType -> Value
encodeInterfaceType o =
    case o of
        Datastream ->
            Encode.string "datastream"

        Properties ->
            Encode.string "properties"


encodeOwner : Owner -> Value
encodeOwner o =
    case o of
        Device ->
            Encode.string "device"

        Server ->
            Encode.string "server"


encodeAggregationType : AggregationType -> Value
encodeAggregationType a =
    case a of
        Individual ->
            Encode.string "individual"

        Object ->
            Encode.string "object"



-- Decoding


decoder : Decoder Interface
decoder =
    Decode.succeed Interface
        |> required "interface_name" string
        |> required "version_major" int
        |> required "version_minor" int
        |> required "type" interfaceTypeDecoder
        |> required "ownership" ownershipDecoder
        |> optional "aggregation" aggregationDecoder Individual
        |> optional "has_metadata" bool False
        |> optional "description" string ""
        |> optional "doc" string ""
        |> required "mappings" mappingDictDecoder


mappingDictDecoder : Decoder (Dict String InterfaceMapping)
mappingDictDecoder =
    list InterfaceMapping.decoder
        |> Decode.andThen
            (\interfaceMappingList ->
                List.map (\m -> ( m.endpoint, m )) interfaceMappingList
                    |> Dict.fromList
                    |> Decode.succeed
            )


interfaceTypeDecoder : Decoder InterfaceType
interfaceTypeDecoder =
    Decode.string
        |> Decode.andThen (stringToInterfaceType >> JsonHelpers.resultToDecoder)


ownershipDecoder : Decoder Owner
ownershipDecoder =
    Decode.string
        |> Decode.andThen (stringToOwner >> JsonHelpers.resultToDecoder)


aggregationDecoder : Decoder AggregationType
aggregationDecoder =
    Decode.string
        |> Decode.andThen (stringToAggregation >> JsonHelpers.resultToDecoder)


stringToInterfaceType : String -> Result String InterfaceType
stringToInterfaceType s =
    case String.toLower s of
        "datastream" ->
            Ok Datastream

        "properties" ->
            Ok Properties

        _ ->
            Err <| "Unknown interface type: " ++ s


stringToOwner : String -> Result String Owner
stringToOwner s =
    case s of
        "device" ->
            Ok Device

        "server" ->
            Ok Server

        _ ->
            Err <| "Unknown owner: " ++ s


stringToAggregation : String -> Result String AggregationType
stringToAggregation s =
    case s of
        "individual" ->
            Ok Individual

        "object" ->
            Ok Object

        _ ->
            Err <| "Unknown aggregation: " ++ s



-- JsonHelpers


mappingsAsList : Interface -> List InterfaceMapping
mappingsAsList interface =
    Dict.values interface.mappings


isValidInterfaceName : String -> Bool
isValidInterfaceName interfaceName =
    Regex.contains validInterfaceNameRegex interfaceName


isGoodInterfaceName : String -> Bool
isGoodInterfaceName interfaceName =
    let
        groups =
            interfaceName
                |> String.split "."
                |> List.reverse

        ( topGroup, otherGroups ) =
            case groups of
                a :: b ->
                    ( a, b )

                [] ->
                    ( "", [] )
    in
    isValidInterfaceName interfaceName
        && isTitleCase topGroup
        && List.all isLowerCase otherGroups


isLowerCase : String -> Bool
isLowerCase str =
    String.all isLowerOrSymbol str


isLowerOrSymbol : Char -> Bool
isLowerOrSymbol c =
    Char.isLower c || (not <| Char.isAlpha c)


isTitleCase : String -> Bool
isTitleCase str =
    case String.uncons str of
        Just ( c, _ ) ->
            Char.isUpper c

        Nothing ->
            False


toPrettySource : Interface -> String
toPrettySource interface =
    Encode.encode 4 <| encode interface


fromString : String -> Result Decode.Error Interface
fromString source =
    decodeString decoder source


compareId : Interface -> Interface -> Bool
compareId a b =
    a.name == b.name && a.major == b.major
