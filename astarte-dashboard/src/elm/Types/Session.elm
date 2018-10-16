module Types.Session
    exposing
        ( Session
        , Credentials
        , LoginType(..)
        , encode
        , decoder
        , init
        , setCredentials
        , setRealmManagementApiUrl
        , setHostUrl
        , setToken
        )

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, hardcoded)
import Json.Encode as Encode exposing (Value)
import JsonHelpers as JsonHelpers


type alias Session =
    { credentials : Maybe Credentials
    , realmManagementApiUrl : String
    , hostUrl : String
    }


init : String -> String -> Session
init rmApiUrl hostUrl =
    { credentials = Nothing
    , realmManagementApiUrl = rmApiUrl
    , hostUrl = hostUrl
    }


setCredentials : Maybe Credentials -> Session -> Session
setCredentials cred session =
    { session | credentials = cred }


setRealmManagementApiUrl : String -> Session -> Session
setRealmManagementApiUrl realmManagementApiUrl session =
    { session | realmManagementApiUrl = realmManagementApiUrl }


setHostUrl : String -> Session -> Session
setHostUrl hostUrl session =
    { session | hostUrl = hostUrl }


type alias Credentials =
    { realm : String
    , token : String
    , loginType : LoginType
    }


setToken : Credentials -> String -> Credentials
setToken credentials token =
    { credentials | token = token }


type LoginType
    = OAuthLogin String
    | TokenLogin



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
        , ( "realmManagementApiUrl", Encode.string session.realmManagementApiUrl )
        ]


encodeCredentials : Credentials -> Value
encodeCredentials credentials =
    Encode.object
        [ ( "realm", Encode.string credentials.realm )
        , ( "token", Encode.string credentials.token )
        , ( "login_type", encodeLoginType credentials.loginType )
        ]


encodeLoginType : LoginType -> Value
encodeLoginType loginType =
    case loginType of
        TokenLogin ->
            Encode.string "TokenLogin"

        OAuthLogin oauthUrl ->
            Encode.string oauthUrl



-- Decoding


decoder : Decoder Session
decoder =
    decode Session
        |> required "credentials" (Decode.nullable credentialsDecoder)
        |> required "realmManagementApiUrl" Decode.string
        |> hardcoded ""


credentialsDecoder : Decoder Credentials
credentialsDecoder =
    decode Credentials
        |> required "realm" Decode.string
        |> required "token" Decode.string
        |> required "login_type" loginTypeDecoder


loginTypeDecoder : Decoder LoginType
loginTypeDecoder =
    Decode.string
        |> Decode.andThen (stringToLoginType >> JsonHelpers.resultToDecoder)


stringToLoginType : String -> Result String LoginType
stringToLoginType s =
    case s of
        "TokenLogin" ->
            Ok TokenLogin

        url ->
            Ok <| OAuthLogin url
