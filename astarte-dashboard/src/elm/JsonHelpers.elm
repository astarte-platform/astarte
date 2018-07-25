module JsonHelpers exposing (resultToDecoder, encodeOptionalFields)

import Http
import Json.Decode exposing (Decoder, Value)


resultToDecoder : Result String a -> Decoder a
resultToDecoder result =
    case result of
        Ok value ->
            Json.Decode.succeed value

        Err err ->
            Json.Decode.fail err


encodeOptionalFields : List ( String, Value, Bool ) -> List ( String, Value )
encodeOptionalFields fieldList =
    List.filterMap encodeOptionalHelper fieldList


encodeOptionalHelper : ( String, Value, Bool ) -> Maybe ( String, Value )
encodeOptionalHelper ( fieldName, value, isDefault ) =
    if isDefault then
        Nothing
    else
        Just ( fieldName, value )
