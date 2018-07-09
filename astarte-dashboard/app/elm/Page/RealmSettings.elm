module Page.RealmSettings exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Navigation


-- Types

import Route
import AstarteApi exposing (..)
import Types.Session exposing (Session)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.RealmConfig exposing (Config)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.FlashMessageHelpers as FlashMessageHelpers


-- bootstrap components

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing


type alias Model =
    { conf : Maybe Config
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { conf = Nothing
      }
    , AstarteApi.realmConfig session
        GetRealmConfDone
        GetRealmConfError
        RedirectToLogin
    )


type Msg
    = GetRealmConf
    | GetRealmConfDone Config
    | GetRealmConfError String
    | UpdateRealmConf
    | UpdateRealmConfDone String
    | UpdateRealmConfError String
    | UpdatePubKey String
    | RedirectToLogin
    | Forward ExternalMsg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetRealmConf ->
            ( model
            , AstarteApi.realmConfig session
                GetRealmConfDone
                GetRealmConfError
                RedirectToLogin
            , ExternalMsg.Noop
            )

        GetRealmConfDone config ->
            ( { model | conf = Just config }
            , Cmd.none
            , ExternalMsg.Noop
            )

        GetRealmConfError errorMessage ->
            ( model
            , Cmd.none
            , ("Cannot retrieve the realm configuration. " ++ errorMessage)
                |> ExternalMsg.AddFlashMessage FlashMessage.Error
            )

        UpdateRealmConf ->
            case model.conf of
                Just config ->
                    ( model
                    , AstarteApi.updateRealmConfig config
                        session
                        UpdateRealmConfDone
                        UpdateRealmConfError
                        RedirectToLogin
                    , ExternalMsg.Noop
                    )

                Nothing ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateRealmConfDone response ->
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Realm configuration has been successfully applied."
            )

        UpdateRealmConfError errorMessage ->
            ( model
            , Cmd.none
            , ("Cannot apply realm configuration. " ++ errorMessage)
                |> ExternalMsg.AddFlashMessage FlashMessage.Error
            )

        UpdatePubKey newPubKey ->
            let
                newConfig =
                    case model.conf of
                        Just config ->
                            { config | pubKey = newPubKey }

                        Nothing ->
                            { pubKey = newPubKey }
            in
                ( { model | conf = Just newConfig }
                , Cmd.none
                , ExternalMsg.Noop
                )

        RedirectToLogin ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm Route.Logout)
            , ExternalMsg.Noop
            )

        Forward msg ->
            ( model
            , Cmd.none
            , msg
            )


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.container
        [ Spacing.mt5Sm ]
        [ Grid.row
            [ Row.middleSm
            , Row.topSm
            ]
            [ Grid.col
                [ Col.sm12 ]
                [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
            ]
        , Grid.row
            [ Row.middleSm
            , Row.topSm
            ]
            [ Grid.col
                [ Col.sm12 ]
                [ renderConfig model.conf
                , Button.button
                    [ Button.primary
                    , Button.onClick GetRealmConf
                    , Button.attrs [ Spacing.mt2, Spacing.mr1 ]
                    ]
                    [ text "Reload" ]
                , Button.button
                    [ Button.primary
                    , Button.onClick UpdateRealmConf
                    , Button.attrs [ Spacing.mt2 ]
                    ]
                    [ text "Save" ]
                ]
            ]
        ]


renderConfig : Maybe Config -> Html Msg
renderConfig mConfig =
    case mConfig of
        Just conf ->
            Form.form []
                [ Form.row []
                    [ Form.col [ Col.sm12 ]
                        [ Form.group []
                            [ Form.label [ for "realmPublicKey" ] [ text "Public key" ]
                            , Textarea.textarea
                                [ Textarea.id "realmPublicKey"
                                , Textarea.rows 10
                                , Textarea.value conf.pubKey
                                , Textarea.onInput UpdatePubKey
                                ]
                            ]
                        ]
                    ]
                ]

        Nothing ->
            text ""
