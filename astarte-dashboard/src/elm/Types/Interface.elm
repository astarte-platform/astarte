module Types.Interface
    exposing
        ( Interface
        , InterfaceType(..)
        , Owner(..)
        , AggregationType(..)
        , empty
        , encode
        , decoder
        , setName
        , setMajor
        , setMinor
        , setType
        , setOwnership
        , setAggregation
        , setHasMeta
        , setDescription
        , setDoc
        , addMapping
        , removeMapping
        , editMapping
        , sealMappings
        , setObjectMappingAttributes
        , mappingsAsList
        , compareId
        , isValidInterfaceName
        , isGoodInterfaceName
        , toPrettySource
        , fromString
        )

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, Value, list, int, bool, string, decodeString)
import Json.Decode.Pipeline exposing (decode, required, optional)
import Json.Encode as Encode
import JsonHelpers
import Regex exposing (regex)
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
        , Encode.list
            (Dict.values interface.mappings
                |> List.map InterfaceMapping.encode
            )
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


isGoodInterfaceName : String -> Bool
isGoodInterfaceName interfaceName =
    Regex.contains (regex "^([a-z]{2,3}\\.){1,2}[a-zA-z]+\\.[a-zA-Z][a-zA-Z0-9]*$") interfaceName


toPrettySource : Interface -> String
toPrettySource interface =
    Encode.encode 4 <| encode interface


fromString : String -> Result String Interface
fromString source =
    decodeString decoder source


compareId : Interface -> Interface -> Bool
compareId a b =
    a.name == b.name && a.major == b.major
