module Types.RealmConfig exposing (..)

import Json.Decode exposing (..)
import Json.Encode


type alias Config =
    { pubKey : String
    }


encoder : Config -> Value
encoder config =
    Json.Encode.object
        [ ( "jwt_public_key_pem", Json.Encode.string config.pubKey ) ]


decoder : Decoder Config
decoder =
    map Config (field "jwt_public_key_pem" string)
