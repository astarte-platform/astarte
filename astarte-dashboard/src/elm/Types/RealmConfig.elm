module Types.RealmConfig
    exposing
        ( Config
        , encode
        , decoder
        )

import Json.Decode as Decode exposing (Value, Decoder, map, field, string)
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
