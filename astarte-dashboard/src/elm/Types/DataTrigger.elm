module Types.DataTrigger exposing
    ( DataTrigger
    , DataTriggerEvent(..)
    , JsonType(..)
    , Operator(..)
    , dataTriggerEventToString
    , decoder
    , empty
    , encode
    , setInterfaceMajor
    , setInterfaceName
    , setKnownValue
    , setKnownValueType
    , setOperator
    , setPath
    , stringToDataTriggerEvent
    )

import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, nullable, string)
import Json.Decode.Pipeline exposing (decode, optional, required, resolve)
import Json.Encode as Encode
import JsonHelpers


type alias DataTrigger =
    { interfaceName : String
    , interfaceMajor : Int
    , on : DataTriggerEvent
    , path : String
    , operator : Operator
    , knownValue : String
    , knownValueType : JsonType
    }


empty : DataTrigger
empty =
    { interfaceName = ""
    , interfaceMajor = 0
    , on = IncomingData
    , path = ""
    , operator = Any
    , knownValue = ""
    , knownValueType = JString
    }


type DataTriggerEvent
    = IncomingData
    | ValueChange
    | ValueChangeApplied
    | PathCreated
    | PathRemoved
    | ValueStored


type Operator
    = Any
    | EqualTo
    | NotEqualTo
    | GreaterThan
    | GreaterOrEqualTo
    | LessThan
    | LessOrEqualTo
    | Contains
    | NotContains


type JsonType
    = JBool
    | JNumber
    | JString
    | JBoolArray
    | JNumberArray
    | JStringArray



-- Setters


setInterfaceName : String -> DataTrigger -> DataTrigger
setInterfaceName name dataTrigger =
    { dataTrigger | interfaceName = name }


setInterfaceMajor : Int -> DataTrigger -> DataTrigger
setInterfaceMajor major dataTrigger =
    { dataTrigger | interfaceMajor = major }


setDataTriggerEvent : DataTriggerEvent -> DataTrigger -> DataTrigger
setDataTriggerEvent dataTriggerEvent dataTrigger =
    { dataTrigger | on = dataTriggerEvent }


setPath : String -> DataTrigger -> DataTrigger
setPath path dataTrigger =
    { dataTrigger | path = path }


setOperator : Operator -> DataTrigger -> DataTrigger
setOperator operator dataTrigger =
    { dataTrigger | operator = operator }


setKnownValue : String -> DataTrigger -> DataTrigger
setKnownValue value dataTrigger =
    { dataTrigger | knownValue = value }


setKnownValueType : JsonType -> DataTrigger -> DataTrigger
setKnownValueType jType dataTrigger =
    { dataTrigger | knownValueType = jType }



-- Encoding


encode : DataTrigger -> Value
encode dataTrigger =
    Encode.object
        ([ ( "type", Encode.string "data_trigger" )
         , ( "interface_name", Encode.string dataTrigger.interfaceName )
         , ( "interface_major", Encode.int dataTrigger.interfaceMajor )
         , ( "on", dataTriggerEventEncoder dataTrigger.on )
         , ( "match_path", Encode.string dataTrigger.path )
         ]
            ++ operatorEncoder dataTrigger.operator dataTrigger.knownValue dataTrigger.knownValueType
        )


operatorEncoder : Operator -> String -> JsonType -> List ( String, Value )
operatorEncoder operator value valueType =
    let
        encodedValue =
            case valueType of
                JBool ->
                    value
                        |> String.toLower
                        |> (==) "true"
                        |> Encode.bool

                JNumber ->
                    value
                        |> String.toFloat
                        |> Result.withDefault 0
                        |> Encode.float

                _ ->
                    Encode.string value
    in
    case operator of
        Any ->
            [ ( "value_match_operator", Encode.string "*" ) ]

        EqualTo ->
            [ ( "value_match_operator", Encode.string "==" )
            , ( "known_value", encodedValue )
            ]

        NotEqualTo ->
            [ ( "value_match_operator", Encode.string "!=" )
            , ( "known_value", encodedValue )
            ]

        GreaterThan ->
            [ ( "value_match_operator", Encode.string ">" )
            , ( "known_value", encodedValue )
            ]

        GreaterOrEqualTo ->
            [ ( "value_match_operator", Encode.string ">=" )
            , ( "known_value", encodedValue )
            ]

        LessThan ->
            [ ( "value_match_operator", Encode.string "<" )
            , ( "known_value", encodedValue )
            ]

        LessOrEqualTo ->
            [ ( "value_match_operator", Encode.string "<=" )
            , ( "known_value", encodedValue )
            ]

        Contains ->
            [ ( "value_match_operator", Encode.string "contains" )
            , ( "known_value", encodedValue )
            ]

        NotContains ->
            [ ( "value_match_operator", Encode.string "not_contains" )
            , ( "known_value", encodedValue )
            ]


dataTriggerEventEncoder : DataTriggerEvent -> Value
dataTriggerEventEncoder dataEvent =
    dataEvent
        |> dataTriggerEventToString
        |> Encode.string


dataTriggerEventToString : DataTriggerEvent -> String
dataTriggerEventToString d =
    case d of
        IncomingData ->
            "incoming_data"

        ValueChange ->
            "value_change"

        ValueChangeApplied ->
            "value_change_applied"

        PathCreated ->
            "path_created"

        PathRemoved ->
            "path_removed"

        ValueStored ->
            "value_stored"



-- Decoding


decoder : Decoder DataTrigger
decoder =
    decode toDecoder
        |> required "interface_name" string
        |> required "interface_major" int
        |> required "on" dataTriggerEventDecoder
        |> required "match_path" string
        |> required "value_match_operator" dataTriggerOperatorDecoder
        |> optional "known_value" (nullable knownValueDecoder) Nothing
        |> resolve


toDecoder : String -> Int -> DataTriggerEvent -> String -> Operator -> Maybe ( String, JsonType ) -> Decoder DataTrigger
toDecoder iName iMajor on path operator maybeKnownValue =
    case maybeKnownValue of
        Just ( value, jType ) ->
            Decode.succeed (DataTrigger iName iMajor on path operator value jType)

        Nothing ->
            Decode.succeed (DataTrigger iName iMajor on path operator "" JString)


knownValueDecoder : Decoder ( String, JsonType )
knownValueDecoder =
    Decode.oneOf
        [ Decode.map (\value -> ( toString value, JBool )) bool
        , Decode.map (\value -> ( toString value, JNumber )) int
        , Decode.map (\value -> ( toString value, JNumber )) float
        , Decode.map (\value -> ( value, JString )) string
        ]


dataTriggerEventDecoder : Decoder DataTriggerEvent
dataTriggerEventDecoder =
    Decode.string
        |> Decode.andThen (stringToDataTriggerEvent >> JsonHelpers.resultToDecoder)


dataTriggerOperatorDecoder : Decoder Operator
dataTriggerOperatorDecoder =
    Decode.string
        |> Decode.andThen (stringToOperator >> JsonHelpers.resultToDecoder)


stringToDataTriggerEvent : String -> Result String DataTriggerEvent
stringToDataTriggerEvent s =
    case s of
        "incoming_data" ->
            Ok IncomingData

        "value_change" ->
            Ok ValueChange

        "value_change_applied" ->
            Ok ValueChangeApplied

        "path_created" ->
            Ok PathCreated

        "path_removed" ->
            Ok PathRemoved

        "value_stored" ->
            Ok ValueStored

        _ ->
            Err <| "Unknown data trigger event: " ++ s


stringToOperator : String -> Result String Operator
stringToOperator operatorString =
    case operatorString of
        "*" ->
            Ok Any

        "==" ->
            Ok EqualTo

        "!=" ->
            Ok NotEqualTo

        ">" ->
            Ok GreaterThan

        ">=" ->
            Ok GreaterOrEqualTo

        "<" ->
            Ok LessThan

        "<=" ->
            Ok LessOrEqualTo

        "contains" ->
            Ok Contains

        "not_contains" ->
            Ok NotContains

        _ ->
            Err <| "Unknown operator " ++ operatorString
