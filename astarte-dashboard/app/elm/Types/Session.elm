module Types.Session exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, hardcoded)
import Json.Encode as Encode exposing (Value)


type alias Session =
    { credentials : Maybe Credentials
    , authUrl : String
    , realmManagementApiUrl : String
    , hostUrl : String
    }


empty : Session
empty =
    { credentials = Nothing
    , authUrl = ""
    , realmManagementApiUrl = ""
    , hostUrl = ""
    }


setCredentials : Maybe Credentials -> Session -> Session
setCredentials cred session =
    { session | credentials = cred }


setAuthUrl : String -> Session -> Session
setAuthUrl authUrl session =
    { session | authUrl = authUrl }


setRealmManagementApiUrl : String -> Session -> Session
setRealmManagementApiUrl realmManagementApiUrl session =
    { session | realmManagementApiUrl = realmManagementApiUrl }


setHostUrl : String -> Session -> Session
setHostUrl hostUrl session =
    { session | hostUrl = hostUrl }


type alias Credentials =
    { realm : String
    , token : String
    }


setToken : Credentials -> String -> Credentials
setToken credentials token =
    { credentials | token = token }



-- Encoding


encode : Session -> Value
encode session =
    Encode.object
        [ ( "credentials"
          , case session.credentials of
                Just credentials ->
                    encodeCredentials credentials

                Nothing ->
                    Encode.null
          )
        , ( "authUrl", Encode.string session.authUrl )
        , ( "realmManagementApiUrl", Encode.string session.realmManagementApiUrl )
        ]


encodeCredentials : Credentials -> Value
encodeCredentials credentials =
    Encode.object
        [ ( "realm", Encode.string credentials.realm )
        , ( "token", Encode.string credentials.token )
        ]



-- Decoding


decoder : Decoder Session
decoder =
    decode Session
        |> required "credentials" (Decode.nullable credentialsDecoder)
        |> required "authUrl" Decode.string
        |> required "realmManagementApiUrl" Decode.string
        |> hardcoded ""


credentialsDecoder : Decoder Credentials
credentialsDecoder =
    decode Credentials
        |> required "realm" Decode.string
        |> required "token" Decode.string
