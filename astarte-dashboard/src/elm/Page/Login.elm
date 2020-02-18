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


module Page.Login exposing (Model, Msg, init, update, view)

import Assets
import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Browser.Navigation
import Html exposing (Html, a, img, text)
import Html.Attributes exposing (class, for, href, placeholder, src, target)
import Route
import Types.Config as Config exposing (AuthConfig(..), AuthType(..), getAuthConfig)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)
import Url.Builder


type alias Model =
    { realm : String
    , authUrl : String
    , showAuthUrl : Bool
    , token : String
    , loginType : Config.AuthType
    , allowSwitching : Bool
    }


init : Config.Params -> AuthType -> ( Model, Cmd Msg )
init config requestedAuth =
    let
        requestedAuthConfig =
            config
                |> getAuthConfig requestedAuth

        ( authType, authConfig ) =
            case requestedAuthConfig of
                Nothing ->
                    ( config.defaultAuth
                    , config |> Config.defaultAuthConfig
                    )

                Just reqConfig ->
                    ( requestedAuth
                    , reqConfig
                    )

        ( authUrl, showAuthUrl ) =
            case authConfig of
                OAuthConfig maybeUrl ->
                    ( maybeUrl |> Maybe.withDefault ""
                    , isNothing maybeUrl
                    )

                TokenConfig ->
                    ( ""
                    , True
                    )
    in
    ( { realm = config.defaultRealm |> Maybe.withDefault ""
      , token = ""
      , authUrl = authUrl
      , showAuthUrl = showAuthUrl
      , loginType = authType
      , allowSwitching = List.length config.enabledAuth > 1
      }
    , Cmd.none
    )


isNothing : Maybe a -> Bool
isNothing maybeVal =
    case maybeVal of
        Just _ ->
            False

        Nothing ->
            True


type Msg
    = Login
    | UpdateRealm String
    | UpdateAuthUrl String
    | UpdateToken String
    | Forward ExternalMsg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        Login ->
            case model.loginType of
                Token ->
                    loginWithToken model

                OAuth ->
                    loginWithOAuth model session.hostUrl

        UpdateRealm newRealm ->
            ( { model | realm = newRealm }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateAuthUrl newUrl ->
            ( { model | authUrl = newUrl }
            , Cmd.none
            , ExternalMsg.Noop
            )

        UpdateToken newToken ->
            ( { model | token = newToken }
            , Cmd.none
            , ExternalMsg.Noop
            )

        Forward externalMsg ->
            ( model
            , Cmd.none
            , externalMsg
            )


loginWithToken : Model -> ( Model, Cmd Msg, ExternalMsg )
loginWithToken model =
    if String.isEmpty model.realm || String.isEmpty model.token then
        ( model
        , Cmd.none
        , ExternalMsg.Noop
        )

    else
        ( model
        , Cmd.none
        , ExternalMsg.RequestRouteWithToken
            (Route.Realm <| Route.Auth (Just model.realm) Nothing)
            model.token
        )


loginWithOAuth : Model -> String -> ( Model, Cmd Msg, ExternalMsg )
loginWithOAuth model hostUrl =
    if String.isEmpty model.realm || String.isEmpty model.authUrl then
        ( model
        , Cmd.none
        , ExternalMsg.Noop
        )

    else
        let
            returnUri =
                Route.Auth (Just model.realm) (Just model.authUrl)
                    |> Route.Realm
                    |> Route.toString
                    |> String.append hostUrl

            externalUrl =
                Url.Builder.custom
                    (Url.Builder.CrossOrigin model.authUrl)
                    [ "auth" ]
                    [ Url.Builder.string "client_id" "astarte-dashboard"
                    , Url.Builder.string "response_type" "token"
                    , Url.Builder.string "redirect_uri" returnUri
                    ]
                    Nothing

            fullUrl =
                if String.startsWith "http" externalUrl then
                    externalUrl

                else
                    "http://" ++ externalUrl
        in
        ( model
        , Browser.Navigation.load fullUrl
        , ExternalMsg.Noop
        )


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.containerFluid []
        [ Grid.row []
            [ imageColumn
            , formColumn model flashMessages
            ]
        ]


formColumn : Model -> List FlashMessage -> Grid.Column Msg
formColumn model flashMessages =
    Grid.col
        [ Col.lg6
        , Col.md12
        , Col.attrs
            [ class "bg-white"
            , Flex.block
            , Flex.col
            , Flex.alignItemsCenter
            , Flex.justifyCenter
            ]
        ]
        [ FlashMessageHelpers.renderFlashMessages flashMessages Forward
        , loginForm model
        ]


loginForm : Model -> Html Msg
loginForm model =
    Form.form
        [ class "login-form"
        , Spacing.p3
        , Size.w100
        ]
        [ Form.row []
            [ Form.col [ Col.sm12 ]
                [ Html.h1 [] [ Html.text "Sign In" ]
                ]
            ]
        , Form.row []
            [ Form.col [ Col.sm12 ]
                [ Form.label [ for "astarteRealm" ] [ text "Realm" ]
                , Input.text
                    [ Input.id "astarteRealm"
                    , Input.placeholder "Astarte Realm"
                    , Input.value model.realm
                    , Input.onInput UpdateRealm
                    ]
                ]
            ]
        , renderAuthInfo model
        , Form.row []
            [ Form.col
                [ Col.sm12 ]
                [ Button.button
                    [ Button.primary
                    , Button.attrs [ Size.w100, Size.w100 ]
                    , Button.onClick Login
                    ]
                    [ text "Login" ]
                ]
            ]
        , Form.row
            (if model.allowSwitching then
                []

             else
                [ Row.attrs [ Display.none ] ]
            )
            [ Form.col [ Col.sm12 ]
                [ toggleLoginTypeLink model.loginType ]
            ]
        , additionalInfos model.loginType
        ]


imageColumn : Grid.Column Msg
imageColumn =
    Grid.col
        [ Col.lg6
        , Col.attrs
            [ Flex.blockLg
            , Flex.col
            , Flex.alignItemsCenter
            , Flex.justifyCenter
            , Display.none
            , Spacing.p0
            , class "position-relative no-gutters"
            , class "login-image-container"
            ]
        ]
        [ Html.img
            [ src <| Assets.path Assets.loginBackgroundTop
            , Size.w100
            , class "position-absolute"
            , class "top-background-image"
            ]
            []
        , Html.img
            [ src <| Assets.path Assets.loginBackgroundBottom
            , Size.w100
            , class "position-absolute"
            , class "bottom-background-image"
            ]
            []
        , Html.img
            [ src <| Assets.path Assets.loginLogo
            , class "logo"
            , Spacing.m4
            ]
            []
        , Html.img
            [ src <| Assets.path Assets.loginAstarteMascotte
            , class "mascotte"
            , Spacing.m4
            ]
            []
        ]


toggleLoginTypeLink : AuthType -> Html Msg
toggleLoginTypeLink authType =
    case authType of
        Token ->
            a
                [ class "float-right"
                , Route.RealmSelection Nothing
                    |> Route.toString
                    |> href
                ]
                [ text "Switch to OAuth login" ]

        OAuth ->
            a
                [ class "float-right"
                , Route.RealmSelection (Just "token")
                    |> Route.toString
                    |> href
                ]
                [ text "Switch to token login" ]


renderAuthInfo : Model -> Html Msg
renderAuthInfo model =
    case model.loginType of
        Token ->
            Form.row []
                [ Form.col [ Col.sm12 ]
                    [ Form.label [ for "authToken" ] [ text "Token" ]
                    , Textarea.textarea
                        [ Textarea.id "authToken"
                        , Textarea.attrs [ placeholder "Auth Token" ]
                        , Textarea.rows 4
                        , Textarea.value model.token
                        , Textarea.onInput UpdateToken
                        ]
                    ]
                ]

        OAuth ->
            if model.showAuthUrl then
                Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ Form.label [ for "authUrl" ] [ text "Authentication URL" ]
                        , Input.text
                            [ Input.id "authUrl"
                            , Input.placeholder "Authentication server URL"
                            , Input.value model.authUrl
                            , Input.onInput UpdateAuthUrl
                            ]
                        ]
                    ]

            else
                text ""


additionalInfos : AuthType -> Html Msg
additionalInfos loginType =
    case loginType of
        Token ->
            Form.row [ Row.attrs [ Spacing.mt5 ] ]
                [ Form.col [ Col.sm12 ]
                    [ Grid.containerFluid
                        [ Border.all
                        , Border.rounded
                        , Spacing.p2
                        , class "bg-light"
                        ]
                        [ Html.text "A valid JWT token should be used, you can use "
                        , Html.a
                            [ href "https://github.com/astarte-platform/astartectl#installation"
                            , target "_blank"
                            ]
                            [ Html.text "astartectl" ]
                        , Html.text " to generate one:"
                        , Html.br [] []
                        , Html.code []
                            [ Html.text "$ astartectl utils gen-jwt all-realm-apis -k your_key.pem" ]
                        ]
                    ]
                ]

        OAuth ->
            text ""
