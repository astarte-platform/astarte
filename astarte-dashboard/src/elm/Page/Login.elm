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
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html, a, img, text)
import Html.Attributes exposing (class, href, placeholder, src)
import Http
import Maybe.Extra exposing (isNothing)
import Navigation
import Route
import Types.Config as Config exposing (AuthConfig(..), AuthType(..), Config, getAuthConfig)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)


type alias Model =
    { realm : String
    , authUrl : String
    , showAuthUrl : Bool
    , token : String
    , loginType : Config.AuthType
    , allowSwitching : Bool
    }


init : Config -> AuthType -> ( Model, Cmd Msg )
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

        Forward msg ->
            ( model
            , Cmd.none
            , msg
            )


loginWithToken : Model -> ( Model, Cmd Msg, ExternalMsg )
loginWithToken model =
    if String.isEmpty model.realm || String.isEmpty model.token then
        ( model
        , Cmd.none
        , ExternalMsg.Noop
        )

    else
        let
            tokenHash =
                "#access_token=" ++ model.token

            authUrl =
                Route.Auth (Just model.realm) Nothing
                    |> Route.Realm
                    |> Route.toString
        in
        ( model
        , Navigation.modifyUrl <| authUrl ++ tokenHash
        , ExternalMsg.Noop
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

            fullUrl =
                buildUrl
                    (model.authUrl ++ "/auth")
                    [ ( "client_id", "astarte-dashboard" )
                    , ( "response_type", "token" )
                    , ( "redirect_uri", returnUri )
                    ]
        in
        ( model
        , Navigation.load fullUrl
        , ExternalMsg.Noop
        )


buildUrl : String -> List ( String, String ) -> String
buildUrl baseUrl args =
    case args of
        [] ->
            baseUrl

        _ ->
            baseUrl ++ "?" ++ String.join "&" (List.map queryPair args)


queryPair : ( String, String ) -> String
queryPair ( key, value ) =
    Http.encodeUri key ++ "=" ++ Http.encodeUri value


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.container []
        [ Grid.row
            [ Row.centerSm
            , Row.attrs [ Spacing.mt5 ]
            ]
            [ Grid.col [ Col.sm3 ]
                [ img
                    [ src <| Assets.path Assets.loginImage
                    , Size.w100
                    , class "login-logo"
                    ]
                    []
                ]
            ]
        , Grid.row
            [ Row.centerSm ]
            [ Grid.col
                [ Col.sm5 ]
                [ Form.form
                    [ class "bg-white"
                    , Spacing.p3
                    , Border.rounded
                    ]
                    [ Form.row []
                        [ Form.col [ Col.sm12 ]
                            [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
                        ]
                    , Form.row []
                        [ Form.col [ Col.sm12 ]
                            [ Input.text
                                [ Input.id "astarteRealm"
                                , Input.placeholder "Astarte Realm"
                                , Input.value model.realm
                                , Input.onInput UpdateRealm
                                ]
                            ]
                        ]
                    , renderAuthInfo model
                    , Form.row
                        (if model.allowSwitching then
                            []

                         else
                            [ Row.attrs [ Display.none ] ]
                        )
                        [ Form.col [ Col.sm12 ]
                            [ toggleLoginTypeLink model.loginType ]
                        ]
                    , Form.row
                        [ Row.topSm
                        , Row.centerSm
                        ]
                        [ Form.col
                            [ Col.sm4 ]
                            [ Button.button
                                [ Button.primary
                                , Button.attrs [ Size.w100 ]
                                , Button.onClick Login
                                ]
                                [ text "Login" ]
                            ]
                        ]
                    ]
                ]
            ]
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
                    [ Textarea.textarea
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
                        [ Input.text
                            [ Input.id "authUrl"
                            , Input.placeholder "Authentication server URL"
                            , Input.value model.authUrl
                            , Input.onInput UpdateAuthUrl
                            ]
                        ]
                    ]

            else
                text ""
