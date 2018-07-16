module Types.Interface exposing (..)

import Dict exposing (Dict)
import Http
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode
import JsonHelpers
import Regex exposing (regex)


-- Types

import Types.InterfaceMapping as InterfaceMapping exposing (InterfaceMapping)
import Types.Session exposing (Session)


type alias Interface =
    { name : String
    , major : Int
    , minor : Int
    , iType : InterfaceType
    , ownership : Owner
    , aggregation : AggregationType
    , explicitTimestamp : Bool
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
    , explicitTimestamp = False
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


setName : Interface -> String -> Interface
setName interface name =
    { interface | name = name }


setMajor : Interface -> Int -> Interface
setMajor interface major =
    { interface | major = major }


setMinor : Interface -> Int -> Interface
setMinor interface minor =
    { interface | minor = minor }


setType : Interface -> InterfaceType -> Interface
setType interface iType =
    { interface | iType = iType }


setOwnership : Interface -> Owner -> Interface
setOwnership interface owner =
    { interface | ownership = owner }


setAggregation : Interface -> AggregationType -> Interface
setAggregation interface aggregation =
    { interface | aggregation = aggregation }


setExplicitTimestamp : Interface -> Bool -> Interface
setExplicitTimestamp interface explicitTimestamp =
    { interface | explicitTimestamp = explicitTimestamp }


setHasMeta : Interface -> Bool -> Interface
setHasMeta interface hasMeta =
    { interface | hasMeta = hasMeta }


setDescription : Interface -> String -> Interface
setDescription interface description =
    { interface | description = description }


setDoc : Interface -> String -> Interface
setDoc interface doc =
    { interface | doc = doc }


addMapping : InterfaceMapping -> Interface -> Interface
addMapping mapping interface =
    { interface
        | mappings =
            interface.mappings
                |> Dict.insert mapping.endpoint mapping
    }


removeMapping : InterfaceMapping -> Interface -> Interface
removeMapping mapping interface =
    { interface
        | mappings =
            interface.mappings
                |> Dict.remove mapping.endpoint
    }


sealMappings : Interface -> Interface
sealMappings interface =
    { interface
        | mappings =
            interface.mappings
                |> Dict.map (\_ m -> InterfaceMapping.setDraft m False)
    }



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
        , ( "explicit_timestamp", Json.Encode.bool interface.explicitTimestamp, interface.explicitTimestamp == False )
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
        |> optional "explicit_timestamp" bool False
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
