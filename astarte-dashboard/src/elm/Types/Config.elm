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
    , Params
    , decoder
    , defaultAuthConfig
    , editorOnly
    , getAuthConfig
    , getParams
    , isEditorOnly
    )

import Json.Decode as Decode exposing (Decoder, andThen, field, list, maybe, nullable, string)
import Json.Decode.Pipeline exposing (optional)
import JsonHelpers as JsonHelpers


type Config
    = EditorOnly
    | Standard Params


type alias Params =
    { secureConnection : Bool
    , realmManagementApiUrl : String
    , appengineApiUrl : String
    , defaultRealm : Maybe String
    , defaultAuth : AuthType
    , enabledAuth : List AuthConfig
    }


editorOnly : Config
editorOnly =
    EditorOnly


type AuthType
    = OAuth
    | Token


type AuthConfig
    = OAuthConfig (Maybe String)
    | TokenConfig


isEditorOnly : Config -> Bool
isEditorOnly config =
    case config of
        EditorOnly ->
            True

        _ ->
            False


getParams : Config -> Maybe Params
getParams config =
    case config of
        EditorOnly ->
            Nothing

        Standard params ->
            Just params


getAuthConfig : AuthType -> Params -> Maybe AuthConfig
getAuthConfig authType configParams =
    configParams.enabledAuth
        |> List.filter (configMatch authType)
        |> List.head


defaultAuthConfig : Params -> AuthConfig
defaultAuthConfig configParams =
    configParams.enabledAuth
        |> List.filter (configMatch configParams.defaultAuth)
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


type alias ParamsChangeset =
    { realmManagementApiUrl : String
    , appengineApiUrl : String
    , defaultRealm : Maybe String
    , defaultAuth : AuthType
    , enabledAuth : List AuthConfig
    }


decoder : Decoder Config
decoder =
    Decode.map5 ParamsChangeset
        (Decode.field "realm_management_api_url" decodeHttpUrl)
        (Decode.field "appengine_api_url" decodeHttpUrl)
        (Decode.maybe <| Decode.field "default_realm" Decode.string)
        (Decode.field "default_auth" authTypeDecoder)
        (Decode.field "auth" <| Decode.list authConfigDecoder)
        |> Decode.andThen validateChangeset


decodeHttpUrl : Decoder String
decodeHttpUrl =
    Decode.string
        |> Decode.andThen
            (\str ->
                if String.startsWith "http" str then
                    Decode.succeed str

                else
                    Decode.fail "Provided string is not an http url"
            )


validateChangeset : ParamsChangeset -> Decoder Config
validateChangeset params =
    let
        urls =
            ( String.split "://" params.appengineApiUrl
            , String.split "://" params.realmManagementApiUrl
            )
    in
    case urls of
        ( [ "http", aeUrl ], [ "http", rmUrl ] ) ->
            Decode.succeed <|
                Standard
                    { secureConnection = False
                    , realmManagementApiUrl = aeUrl
                    , appengineApiUrl = rmUrl
                    , defaultRealm = params.defaultRealm
                    , defaultAuth = params.defaultAuth
                    , enabledAuth = params.enabledAuth
                    }

        ( [ "https", aeUrl ], [ "https", rmUrl ] ) ->
            Decode.succeed <|
                Standard
                    { secureConnection = True
                    , realmManagementApiUrl = aeUrl
                    , appengineApiUrl = rmUrl
                    , defaultRealm = params.defaultRealm
                    , defaultAuth = params.defaultAuth
                    , enabledAuth = params.enabledAuth
                    }

        _ ->
            Decode.fail "Realm Management and AppEngine protocol mismatch"


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
