module Types.InterfaceMapping exposing (..)

import Regex exposing (regex)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode
import Utilities


type alias InterfaceMapping =
    { endpoint : String
    , mType : MappingType
    , reliability : Reliability
    , retention : Retention
    , expiry : Int
    , allowUnset : Bool
    , description : String
    , doc : String
    }


empty : InterfaceMapping
empty =
    { endpoint = ""
    , mType = Single DoubleMapping
    , reliability = Unreliable
    , retention = Discard
    , expiry = 0
    , allowUnset = False
    , description = ""
    , doc = ""
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


setEndpoint : InterfaceMapping -> String -> InterfaceMapping
setEndpoint mapping endpoint =
    { mapping | endpoint = endpoint }


setType : InterfaceMapping -> MappingType -> InterfaceMapping
setType mapping mType =
    { mapping | mType = mType }


setReliability : InterfaceMapping -> Reliability -> InterfaceMapping
setReliability mapping reliability =
    { mapping | reliability = reliability }


setRetention : InterfaceMapping -> Retention -> InterfaceMapping
setRetention mapping retention =
    { mapping | retention = retention }


setExpiry : InterfaceMapping -> Int -> InterfaceMapping
setExpiry mapping expiry =
    { mapping | expiry = expiry }


setAllowUnset : InterfaceMapping -> Bool -> InterfaceMapping
setAllowUnset mapping allow =
    { mapping | allowUnset = allow }


setDescription : InterfaceMapping -> String -> InterfaceMapping
setDescription mapping description =
    { mapping | description = description }


setDoc : InterfaceMapping -> String -> InterfaceMapping
setDoc mapping doc =
    { mapping | doc = doc }



-- Encoding


interfaceMappingEncoder : InterfaceMapping -> Value
interfaceMappingEncoder mapping =
    [ [ ( "endpoint", Json.Encode.string mapping.endpoint )
      , ( "type", encodeMappingType mapping.mType )
      ]
    , Utilities.encodeOptionalFields
        [ ( "reliability", encodeReliability mapping.reliability, mapping.reliability == Unreliable )
        , ( "retention", encodeRetention mapping.retention, mapping.retention == Discard )
        , ( "expiry", Json.Encode.int mapping.expiry, mapping.expiry == 0 )
        , ( "allow_unset", Json.Encode.bool mapping.allowUnset, mapping.allowUnset == False )
        , ( "description", Json.Encode.string mapping.description, mapping.description == "" )
        , ( "doc", Json.Encode.string mapping.doc, mapping.doc == "" )
        ]
    ]
        |> List.concat
        |> Json.Encode.object


encodeMappingType : MappingType -> Value
encodeMappingType t =
    mappingTypeToString t
        |> Json.Encode.string


encodeReliability : Reliability -> Value
encodeReliability r =
    case r of
        Unreliable ->
            Json.Encode.string "unreliable"

        Guaranteed ->
            Json.Encode.string "guaranteed"

        Unique ->
            Json.Encode.string "unique"


encodeRetention : Retention -> Value
encodeRetention r =
    case r of
        Discard ->
            Json.Encode.string "discard"

        Volatile ->
            Json.Encode.string "volatile"

        Stored ->
            Json.Encode.string "stored"


mappingTypeToString : MappingType -> String
mappingTypeToString t =
    case t of
        Single baseType ->
            baseTypeToString baseType

        Array baseType ->
            baseTypeToString baseType
                |> (++) "array"


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
    decode InterfaceMapping
        |> required "endpoint" string
        |> required "type" mappingTypeDecoder
        |> optional "reliability" reliabilityDecoder Unreliable
        |> optional "retention" retentionDecoder Discard
        |> optional "expiry" int 0
        |> optional "allow_unset" bool False
        |> optional "description" string ""
        |> optional "doc" string ""


mappingTypeDecoder : Decoder MappingType
mappingTypeDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToMappingType >> Utilities.resultToDecoder)


reliabilityDecoder : Decoder Reliability
reliabilityDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToReliability >> Utilities.resultToDecoder)


retentionDecoder : Decoder Retention
retentionDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToRetention >> Utilities.resultToDecoder)


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



-- Utilities


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
            case (String.toFloat value) of
                Ok _ ->
                    True

                Err _ ->
                    False

        IntMapping ->
            case (String.toInt value) of
                Ok _ ->
                    True

                Err _ ->
                    False

        BoolMapping ->
            case (String.toLower value) of
                "true" ->
                    True

                "false" ->
                    True

                _ ->
                    False

        LongIntMapping ->
            Regex.contains (regex "^[\\+-]?[\\d]+$") value

        StringMapping ->
            True

        BinaryBlobMapping ->
            Regex.contains (regex "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$") value

        DateTimeMapping ->
            Regex.contains (regex "^([\\+-]?\\d{4}(?!\\d{2}\\b))((-?)((0[1-9]|1[0-2])(\\3([12]\\d|0[1-9]|3[01]))?|W([0-4]\\d|5[0-2])(-?[1-7])?|(00[1-9]|0[1-9]\\d|[12]\\d{2}|3([0-5]\\d|6[1-6])))([T\\s]((([01]\\d|2[0-3])((:?)[0-5]\\d)?|24\\:?00)([\\.,]\\d+(?!:))?)?(\\17[0-5]\\d([\\.,]\\d+)?)?([zZ]|([\\+-])([01]\\d|2[0-3]):?([0-5]\\d)?)?)?)?$") value


toList : String -> List String
toList arrayString =
    case decodeString (list string) arrayString of
        Ok stringList ->
            stringList

        Err _ ->
            [ arrayString ]


isValidEndpoint : String -> Bool
isValidEndpoint endpoint =
    Regex.contains (regex "^(/(%{([a-zA-Z][a-zA-Z0-9]*)}|[a-zA-Z][a-zA-Z0-9]*)){1,64}") endpoint
