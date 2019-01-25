module Types.RealmConfig exposing
    ( Config
    , decoder
    , encode
    )

import Json.Decode as Decode exposing (Decoder, Value, field, map, string)
import Json.Encode as Encode


type alias Config =
    { pubKey : String
    }


encode : Config -> Value
encode config =
    Encode.object
        [ ( "jwt_public_key_pem", Encode.string config.pubKey ) ]


decoder : Decoder Config
decoder =
    map Config (field "jwt_public_key_pem" string)
