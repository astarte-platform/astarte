{-
   This file is part of Astarte.

   Copyright 2018 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-}


module Types.Config exposing
    ( AuthConfig(..)
    , AuthType(..)
    , Config
    , decoder
    , defaultAuthConfig
    , empty
    , getAuthConfig
    )

import Json.Decode as Decode exposing (Decoder, andThen, field, list, maybe, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
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
    Decode.succeed Config
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
    case String.toLower s of
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
    Decode.succeed OAuthConfig
        |> optional "oauth_api_url" (nullable string) Nothing


tokenConfigDecoder : Decoder AuthConfig
tokenConfigDecoder =
    Decode.succeed TokenConfig
