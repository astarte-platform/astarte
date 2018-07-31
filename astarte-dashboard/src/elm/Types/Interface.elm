module Types.Interface exposing (..)

import Dict exposing (Dict)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode
import JsonHelpers
import Regex exposing (regex)


-- Types

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
    , minor = 0
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
    -> Interface
    -> Interface
setObjectMappingAttributes reliability retention expiry explicitTimestamp interface =
    let
        newMappings =
            Dict.map
                (\_ mapping ->
                    { mapping
                        | reliability = reliability
                        , retention = retention
                        , expiry = expiry
                        , explicitTimestamp = explicitTimestamp
                    }
                )
                interface.mappings
    in
        { interface | mappings = newMappings }



-- Encoding


encoder : Interface -> Value
encoder interface =
    [ [ ( "interface_name", Json.Encode.string interface.name )
      , ( "version_major", Json.Encode.int interface.major )
      , ( "version_minor", Json.Encode.int interface.minor )
      , ( "type", encodeInterfaceType interface.iType )
      , ( "ownership", encodeOwner interface.ownership )
      ]
    , JsonHelpers.encodeOptionalFields
        [ ( "aggregation", encodeAggregationType interface.aggregation, interface.aggregation == Individual )
        , ( "has_metadata", Json.Encode.bool interface.hasMeta, interface.hasMeta == False )
        , ( "description", Json.Encode.string interface.description, interface.description == "" )
        , ( "doc", Json.Encode.string interface.doc, interface.doc == "" )
        ]
    , [ ( "mappings"
        , Json.Encode.list
            (Dict.values interface.mappings
                |> List.map InterfaceMapping.interfaceMappingEncoder
            )
        )
      ]
    ]
        |> List.concat
        |> Json.Encode.object


encodeInterfaceType : InterfaceType -> Value
encodeInterfaceType o =
    case o of
        Datastream ->
            Json.Encode.string "datastream"

        Properties ->
            Json.Encode.string "properties"


encodeOwner : Owner -> Value
encodeOwner o =
    case o of
        Device ->
            Json.Encode.string "device"

        Server ->
            Json.Encode.string "server"


encodeAggregationType : AggregationType -> Value
encodeAggregationType a =
    case a of
        Individual ->
            Json.Encode.string "individual"

        Object ->
            Json.Encode.string "object"



-- Decoding


decoder : Decoder Interface
decoder =
    decode Interface
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
        |> Json.Decode.andThen
            (\interfaceMappingList ->
                List.map (\m -> ( m.endpoint, m )) interfaceMappingList
                    |> Dict.fromList
                    |> Json.Decode.succeed
            )


interfaceTypeDecoder : Decoder InterfaceType
interfaceTypeDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToInterfaceType >> JsonHelpers.resultToDecoder)


ownershipDecoder : Decoder Owner
ownershipDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToOwner >> JsonHelpers.resultToDecoder)


aggregationDecoder : Decoder AggregationType
aggregationDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToAggregation >> JsonHelpers.resultToDecoder)


stringToInterfaceType : String -> Result String InterfaceType
stringToInterfaceType s =
    case (String.toLower s) of
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
    Regex.contains (regex "^[a-zA-Z]+(\\.[a-zA-Z0-9]+)*$") interfaceName


toPrettySource : Interface -> String
toPrettySource interface =
    Json.Encode.encode 4 <| encoder interface


fromString : String -> Result String Interface
fromString source =
    decodeString decoder source


compareId : Interface -> Interface -> Bool
compareId a b =
    a.name == b.name && a.major == b.major
