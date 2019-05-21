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


module Types.Session exposing
    ( LoginStatus(..)
    , LoginType(..)
    , Session
    , decoder
    , encode
    , isLoggedIn
    , setToken
    )

import AstarteApi
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (hardcoded, required)
import Json.Encode as Encode exposing (Value)
import JsonHelpers as JsonHelpers
import Types.Config as Config


type alias Session =
    { hostUrl : String
    , loginStatus : LoginStatus
    , apiConfig : AstarteApi.Config
    }


type LoginStatus
    = NotLoggedIn
    | RequestLogin Config.AuthType
    | LoggedIn LoginType


type LoginType
    = TokenLogin
    | OAuthLogin String


isLoggedIn : Session -> Bool
isLoggedIn session =
    case session.loginStatus of
        LoggedIn _ ->
            True

        _ ->
            False


setToken : String -> Session -> Session
setToken token session =
    let
        config =
            session.apiConfig

        updatedConfig =
            { config | token = token }
    in
    { session | apiConfig = updatedConfig }



-- Encoding


encode : Session -> Value
encode session =
    Encode.object
        [ ( "login_type", encodeLoginStatus session.loginStatus )
        , ( "api_config", AstarteApi.encodeConfig session.apiConfig )
        ]


encodeLoginStatus : LoginStatus -> Value
encodeLoginStatus loginStatus =
    case loginStatus of
        LoggedIn TokenLogin ->
            Encode.string "TokenLogin"

        LoggedIn (OAuthLogin oauthUrl) ->
            Encode.string oauthUrl

        _ ->
            Encode.string ""



-- Decoding


decoder : Decoder Session
decoder =
    Decode.succeed Session
        |> hardcoded ""
        |> required "login_type" loginStatusDecoder
        |> required "api_config" AstarteApi.configDecoder


loginStatusDecoder : Decoder LoginStatus
loginStatusDecoder =
    Decode.string
        |> Decode.andThen (stringToLoginStatus >> JsonHelpers.resultToDecoder)


stringToLoginStatus : String -> Result String LoginStatus
stringToLoginStatus s =
    case s of
        "" ->
            Ok NotLoggedIn

        "TokenLogin" ->
            Ok <| LoggedIn TokenLogin

        url ->
            Ok <| LoggedIn (OAuthLogin url)
