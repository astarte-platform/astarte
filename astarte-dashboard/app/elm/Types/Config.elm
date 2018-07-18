module Types.Config
    exposing
        ( Config
        , AuthType(..)
        , AuthConfig(..)
        , empty
        , getAuthConfig
        , defaultAuthConfig
        , decoder
        )

import Json.Decode as Decode exposing (Decoder, string, nullable, list, field, maybe, andThen)
import Json.Decode.Pipeline exposing (decode, required, optional)
import JsonHelpers as JsonHelpers


type alias Config =
    { realmManagementApiUrl : String
    , defaultRealm : Maybe String
    , defaultAuth : AuthType
    , enabledAuth : List AuthConfig
    }


empty : Config
empty =
    { realmManagementApiUrl = ""
    , defaultRealm = Nothing
    , defaultAuth = Token
    , enabledAuth = [ TokenConfig ]
    }


type AuthType
    = OAuth
    | Token


type AuthConfig
    = OAuthConfig (Maybe String)
    | TokenConfig


getAuthConfig : AuthType -> Config -> Maybe AuthConfig
getAuthConfig authType config =
    config.enabledAuth
        |> List.filter (configMatch authType)
        |> List.head


defaultAuthConfig : Config -> AuthConfig
defaultAuthConfig config =
    config.enabledAuth
        |> List.filter (configMatch config.defaultAuth)
        |> List.head
        -- If it's a valid config, this will never trigger
        |> Maybe.withDefault TokenConfig


configMatch : AuthType -> AuthConfig -> Bool
configMatch authType authConfig =
    case ( authType, authConfig ) of
        ( OAuth, OAuthConfig _ ) ->
            True

        ( Token, TokenConfig ) ->
            True

        _ ->
            False



-- Decoding


decoder : Decoder Config
decoder =
    decode Config
        |> required "realm_management_api_url" string
        |> optional "default_realm" (nullable string) Nothing
        |> required "default_auth" authTypeDecoder
        |> required "auth" (list authConfigDecoder)


authTypeDecoder : Decoder AuthType
authTypeDecoder =
    Decode.string
        |> Decode.andThen (stringToAuthType >> JsonHelpers.resultToDecoder)


stringToAuthType : String -> Result String AuthType
stringToAuthType s =
    case (String.toLower s) of
        "oauth" ->
            Ok OAuth

        "token" ->
            Ok Token

        _ ->
            Err <| "Unknown auth type: " ++ s


authConfigDecoder : Decoder AuthConfig
authConfigDecoder =
    field "type" authTypeDecoder
        |> andThen authConfigDecoderHelper


authConfigDecoderHelper : AuthType -> Decoder AuthConfig
authConfigDecoderHelper authType =
    case authType of
        OAuth ->
            oauthConfigDecoder

        Token ->
            tokenConfigDecoder


oauthConfigDecoder : Decoder AuthConfig
oauthConfigDecoder =
    decode OAuthConfig
        |> optional "oauth_api_url" (nullable string) Nothing


tokenConfigDecoder : Decoder AuthConfig
tokenConfigDecoder =
    decode TokenConfig
