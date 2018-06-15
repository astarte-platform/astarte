module Page.Login exposing (Model, Msg, init, update, view)

import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Navigation


-- Types

import Utilities
import Route
import Types.Session exposing (Session, LoginType(..))
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)


-- bootstrap components

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Bootstrap.Utilities.Flex as Flex


type alias Model =
    { realm : String
    , authUrl : String
    , token : String
    , loginType : LoginType
    }


init : Session -> ( Model, Cmd Msg )
init session =
    let
        authUrl =
            case session.loginType of
                OAuthFromConfig defaultAuthUrl ->
                    defaultAuthUrl

                _ ->
                    ""
    in
        ( { realm = ""
          , token = ""
          , authUrl = authUrl
          , loginType = session.loginType
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

                _ ->
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
    if (String.isEmpty model.realm || String.isEmpty model.token) then
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
    if (String.isEmpty model.realm || String.isEmpty model.authUrl) then
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
    (Http.encodeUri key) ++ "=" ++ (Http.encodeUri value)


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.container
        [ Spacing.mt5Sm ]
        [ Grid.row
            [ Row.middleSm
            , Row.centerSm
            , Row.attrs [ style [ ( "min-height", "60vh" ) ] ]
            ]
            [ Grid.col
                [ Col.sm5 ]
                [ Form.form
                    []
                    [ Form.row
                        [ Row.centerSm ]
                        [ Form.col [ Col.sm7 ]
                            [ img
                                [ src "login.svg"
                                , Size.w100
                                ]
                                []
                            ]
                        ]
                    , Form.row []
                        [ Form.col [ Col.sm12 ]
                            [ Utilities.renderFlashMessages flashMessages Forward ]
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
                    , Form.row []
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


toggleLoginTypeLink : LoginType -> Html Msg
toggleLoginTypeLink loginType =
    case loginType of
        Token ->
            a
                [ class "float-right"
                , Route.RealmSelection Nothing
                    |> Route.toString
                    |> href
                ]
                [ text "Switch to OAuth login" ]

        _ ->
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
                        , Textarea.attrs [ (placeholder "Auth Token") ]
                        , Textarea.rows 4
                        , Textarea.value model.token
                        , Textarea.onInput UpdateToken
                        ]
                    ]
                ]

        OAuth ->
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

        OAuthFromConfig _ ->
            text ""
