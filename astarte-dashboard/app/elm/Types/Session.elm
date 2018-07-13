module Types.Session exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, hardcoded)
import Json.Encode as Encode exposing (Value)
import JsonHelpers as JsonHelpers


type alias Session =
    { credentials : Maybe Credentials
    , loginType : LoginType
    , authUrl : Maybe String
    , realmManagementApiUrl : String
    , hostUrl : String
    }


empty : Session
empty =
    { credentials = Nothing
    , loginType = OAuth
    , authUrl = Nothing
    , realmManagementApiUrl = ""
    , hostUrl = ""
    }


setCredentials : Maybe Credentials -> Session -> Session
setCredentials cred session =
    { session | credentials = cred }


setLoginType : LoginType -> Session -> Session
setLoginType loginType session =
    { session | loginType = loginType }


setAuthUrl : Maybe String -> Session -> Session
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


type LoginType
    = OAuth
    | OAuthFromConfig String
    | Token



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
        , ( "loginType", encodeLoginType session.loginType )
        , ( "authUrl"
          , case session.authUrl of
                Just authUrl ->
                    Encode.string authUrl

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
        ]


encodeLoginType : LoginType -> Value
encodeLoginType loginType =
    case loginType of
        Token ->
            Encode.string "Token"

        OAuth ->
            Encode.string "OAuth"

        OAuthFromConfig a ->
            Encode.string a



-- Decoding


decoder : Decoder Session
decoder =
    decode Session
        |> required "credentials" (Decode.nullable credentialsDecoder)
        |> required "loginType" loginTypeDecoder
        |> required "authUrl" (Decode.nullable Decode.string)
        |> required "realmManagementApiUrl" Decode.string
        |> hardcoded ""


credentialsDecoder : Decoder Credentials
credentialsDecoder =
    decode Credentials
        |> required "realm" Decode.string
        |> required "token" Decode.string


loginTypeDecoder : Decoder LoginType
loginTypeDecoder =
    Decode.string
        |> Decode.andThen (stringToLoginType >> JsonHelpers.resultToDecoder)


stringToLoginType : String -> Result String LoginType
stringToLoginType s =
    case s of
        "Token" ->
            Ok Token

        "OAuth" ->
            Ok OAuth

        a ->
            Ok <| OAuthFromConfig a
