module Types.DataTrigger exposing (..)

import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode
import JsonHelpers
import Types.InterfaceMapping as InterfaceMapping


type alias DataTrigger =
    { interfaceName : String
    , interfaceMajor : Int
    , on : DataTriggerEvent
    , path : String
    , operator : Operator
    }


empty : DataTrigger
empty =
    { interfaceName = ""
    , interfaceMajor = 0
    , on = IncomingData
    , path = ""
    , operator = Any
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
    | EqualTo String
    | NotEqualTo String
    | GreaterThan String
    | GreaterOrEqualTo String
    | LessThan String
    | LessOrEqualTo String
    | Contains String
    | NotContains String



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



-- Encoding


encoder : DataTrigger -> Value
encoder dataTrigger =
    Json.Encode.object
        ([ ( "type", Json.Encode.string "data_trigger" )
         , ( "interface_name", Json.Encode.string dataTrigger.interfaceName )
         , ( "interface_major", Json.Encode.int dataTrigger.interfaceMajor )
         , ( "on", dataTriggerEventEncoder dataTrigger.on )
         , ( "match_path", Json.Encode.string dataTrigger.path )
         ]
            ++ operatorEncoder dataTrigger.operator
        )


operatorEncoder : Operator -> List ( String, Value )
operatorEncoder o =
    case o of
        Any ->
            [ ( "value_match_operator", Json.Encode.string "*" ) ]

        EqualTo value ->
            [ ( "value_match_operator", Json.Encode.string "==" )
            , ( "known_value", Json.Encode.string value )
            ]

        NotEqualTo value ->
            [ ( "value_match_operator", Json.Encode.string "!=" )
            , ( "known_value", Json.Encode.string value )
            ]

        GreaterThan value ->
            [ ( "value_match_operator", Json.Encode.string ">" )
            , ( "known_value", Json.Encode.string value )
            ]

        GreaterOrEqualTo value ->
            [ ( "value_match_operator", Json.Encode.string ">=" )
            , ( "known_value", Json.Encode.string value )
            ]

        LessThan value ->
            [ ( "value_match_operator", Json.Encode.string "<" )
            , ( "known_value", Json.Encode.string value )
            ]

        LessOrEqualTo value ->
            [ ( "value_match_operator", Json.Encode.string "<=" )
            , ( "known_value", Json.Encode.string value )
            ]

        Contains value ->
            [ ( "value_match_operator", Json.Encode.string "contains" )
            , ( "known_value", Json.Encode.string value )
            ]

        NotContains value ->
            [ ( "value_match_operator", Json.Encode.string "not_contains" )
            , ( "known_value", Json.Encode.string value )
            ]


dataTriggerEventEncoder : DataTriggerEvent -> Value
dataTriggerEventEncoder dataEvent =
    dataEvent
        |> dataTriggerEventToString
        |> Json.Encode.string


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
    let
        toDecoder : String -> Int -> DataTriggerEvent -> String -> String -> Maybe String -> Decoder DataTrigger
        toDecoder iName iMajor on path operatorString maybeKnownValue =
            case (stringsToOperator operatorString maybeKnownValue) of
                Ok operator ->
                    Json.Decode.succeed <| DataTrigger iName iMajor on path operator

                Err err ->
                    Json.Decode.fail err
    in
        decode toDecoder
            |> required "interface_name" string
            |> required "interface_major" int
            |> required "on" dataTriggerEventDecoder
            |> required "match_path" string
            |> required "value_match_operator" string
            |> optional "known_value" (nullable knownValueDecoder) Nothing
            |> resolve


knownValueDecoder : Decoder String
knownValueDecoder =
    Json.Decode.oneOf
        [ string
        , Json.Decode.map toString int
        , Json.Decode.map toString float
        ]


dataTriggerEventDecoder : Decoder DataTriggerEvent
dataTriggerEventDecoder =
    Json.Decode.string
        |> Json.Decode.andThen (stringToDataTriggerEvent >> JsonHelpers.resultToDecoder)


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
            Err <| "Uknown data trigger event: " ++ s


stringsToOperator : String -> Maybe String -> Result String Operator
stringsToOperator operatorString maybeKnownValue =
    case ( operatorString, maybeKnownValue ) of
        ( "*", _ ) ->
            Ok Any

        ( "==", Just value ) ->
            Ok <| EqualTo value

        ( "!=", Just value ) ->
            Ok <| NotEqualTo value

        ( ">", Just value ) ->
            Ok <| GreaterThan value

        ( ">=", Just value ) ->
            Ok <| GreaterOrEqualTo value

        ( "<", Just value ) ->
            Ok <| LessThan value

        ( "<=", Just value ) ->
            Ok <| LessOrEqualTo value

        ( "contains", Just value ) ->
            Ok <| Contains value

        ( "not_contains", Just value ) ->
            Ok <| NotContains value

        ( _, Nothing ) ->
            Err <| "Missing known_value required by the operator " ++ operatorString

        ( _, _ ) ->
            Err <| "Unknown operator " ++ operatorString
