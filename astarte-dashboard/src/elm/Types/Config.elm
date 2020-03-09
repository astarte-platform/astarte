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
    , pairingApiUrl : String
    , flowApiUrl : String
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
    { astarteApiUrl : Maybe String
    , appengineApiUrl : Maybe String
    , realmManagementApiUrl : Maybe String
    , pairingApiUrl : Maybe String
    , flowApiUrl : Maybe String
    , defaultRealm : Maybe String
    , defaultAuth : AuthType
    , enabledAuth : List AuthConfig
    }


decoder : Decoder Config
decoder =
    Decode.map8 ParamsChangeset
        (Decode.maybe <| Decode.field "astarte_api_url" decodeAstarteUrl)
        (Decode.maybe <| Decode.field "appengine_api_url" decodeHttpUrl)
        (Decode.maybe <| Decode.field "realm_management_api_url" decodeHttpUrl)
        (Decode.maybe <| Decode.field "pairing_api_url" decodeHttpUrl)
        (Decode.maybe <| Decode.field "flow_api_url" decodeHttpUrl)
        (Decode.maybe <| Decode.field "default_realm" Decode.string)
        (Decode.field "default_auth" authTypeDecoder)
        (Decode.field "auth" <| Decode.list authConfigDecoder)
        |> Decode.andThen validateChangeset


decodeAstarteUrl : Decoder String
decodeAstarteUrl =
    Decode.oneOf
        [ decodeHttpUrl
        , decodeExact "localhost"
        ]


decodeExact : String -> Decoder String
decodeExact match =
    Decode.string
        |> Decode.andThen
            (\str ->
                if str == match then
                    Decode.succeed str

                else
                    Decode.fail <| "Provided string didn't match " ++ match
            )


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
        astarteUrls =
            case params.astarteApiUrl of
                Just "localhost" ->
                    { appengineApiUrl =
                        params.appengineApiUrl
                            |> Maybe.withDefault "http://localhost:4002"
                    , realmManagementApiUrl =
                        params.realmManagementApiUrl
                            |> Maybe.withDefault "http://localhost:4000"
                    , pairingApiUrl =
                        params.pairingApiUrl
                            |> Maybe.withDefault "http://localhost:4003"
                    , flowApiUrl =
                        params.flowApiUrl
                            |> Maybe.withDefault "http://localhost:4009"
                    }

                Just baseUrl ->
                    { appengineApiUrl =
                        params.appengineApiUrl
                            |> Maybe.withDefault (baseUrl ++ "/appengine")
                    , realmManagementApiUrl =
                        params.realmManagementApiUrl
                            |> Maybe.withDefault (baseUrl ++ "/realmmanagement")
                    , pairingApiUrl =
                        params.pairingApiUrl
                            |> Maybe.withDefault (baseUrl ++ "/pairing")
                    , flowApiUrl =
                        params.flowApiUrl
                            |> Maybe.withDefault (baseUrl ++ "/flow")
                    }

                Nothing ->
                    { appengineApiUrl =
                        params.appengineApiUrl
                            |> Maybe.withDefault ""
                    , realmManagementApiUrl =
                        params.realmManagementApiUrl
                            |> Maybe.withDefault ""
                    , pairingApiUrl =
                        params.pairingApiUrl
                            |> Maybe.withDefault ""
                    , flowApiUrl =
                        params.flowApiUrl
                            |> Maybe.withDefault ""
                    }
    in
    Decode.succeed <|
        Standard
            { secureConnection = String.startsWith "https://" astarteUrls.appengineApiUrl
            , appengineApiUrl = removeProtocol astarteUrls.appengineApiUrl
            , realmManagementApiUrl = removeProtocol astarteUrls.realmManagementApiUrl
            , pairingApiUrl = removeProtocol astarteUrls.pairingApiUrl
            , flowApiUrl = removeProtocol astarteUrls.flowApiUrl
            , defaultRealm = params.defaultRealm
            , defaultAuth = params.defaultAuth
            , enabledAuth = params.enabledAuth
            }


removeProtocol : String -> String
removeProtocol url =
    String.split "://" url
        |> List.reverse
        |> List.head
        |> Maybe.withDefault ""


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
