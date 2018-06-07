module Page.RealmSettings exposing (Model, Msg, init, update, view)

import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)


-- Types

import AstarteApi exposing (..)
import Utilities
import Types.Session exposing (Session)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.RealmConfig exposing (Config)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)


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
    , Http.send GetRealmConfDone <|
        AstarteApi.getRealmConfigRequest session
    )


type Msg
    = GetRealmConf
    | GetRealmConfDone (Result Http.Error Config)
    | UpdateRealmConf
    | UpdateRealmConfDone (Result Http.Error String)
    | UpdatePubKey String
    | Forward ExternalMsg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetRealmConf ->
            ( model
            , Http.send GetRealmConfDone <|
                AstarteApi.getRealmConfigRequest session
            , ExternalMsg.Noop
            )

        GetRealmConfDone (Ok config) ->
            ( { model | conf = Just config }
            , Cmd.none
            , ExternalMsg.Noop
            )

        GetRealmConfDone (Err err) ->
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error "Cannot retrieve the realm configuration."
            )

        UpdateRealmConf ->
            case model.conf of
                Just config ->
                    ( model
                    , Http.send UpdateRealmConfDone <|
                        AstarteApi.updateRealmConfigRequest config session
                    , ExternalMsg.Noop
                    )

                Nothing ->
                    ( model
                    , Cmd.none
                    , ExternalMsg.Noop
                    )

        UpdateRealmConfDone (Ok response) ->
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Notice "Realm configuration has been successfully applied."
            )

        UpdateRealmConfDone (Err err) ->
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error "Cannot apply realm configuration."
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
                [ Utilities.renderFlashMessages flashMessages Forward ]
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
