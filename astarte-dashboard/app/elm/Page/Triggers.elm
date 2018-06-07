module Page.Triggers exposing (Model, Msg, init, update, view)

import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Navigation


-- Types

import AstarteApi exposing (..)
import Route
import Utilities
import Types.Session exposing (Session)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)


-- bootstrap components

import Bootstrap.Button as Button
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing


type alias Model =
    { triggers : List String
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { triggers = []
      }
    , Http.send GetTriggerListDone <|
        AstarteApi.getTriggersRequest session
    )


type Msg
    = GetTriggerList
    | GetTriggerListDone (Result Http.Error (List String))
    | AddNewTrigger
    | ShowTrigger String
    | Forward ExternalMsg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetTriggerList ->
            ( model
            , Http.send GetTriggerListDone <|
                AstarteApi.getTriggersRequest session
            , ExternalMsg.Noop
            )

        GetTriggerListDone (Ok triggerNames) ->
            ( { model | triggers = triggerNames }
            , Cmd.none
            , ExternalMsg.Noop
            )

        GetTriggerListDone (Err err) ->
            ( model
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error "Cannot retrieve triggers."
            )

        AddNewTrigger ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm Route.NewTrigger)
            , ExternalMsg.Noop
            )

        ShowTrigger name ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm <| Route.ShowTrigger name)
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
                [ ListGroup.ul <| List.map renderSingleTrigger model.triggers
                , Button.button
                    [ Button.primary
                    , Button.attrs [ Spacing.mt2, Spacing.mr2 ]
                    , Button.onClick GetTriggerList
                    ]
                    [ text "Reload" ]
                , Button.button
                    [ Button.primary
                    , Button.attrs [ Spacing.mt2 ]
                    , Button.onClick AddNewTrigger
                    ]
                    [ text "Add New Trigger ..." ]
                ]
            ]
        ]


renderSingleTrigger : String -> ListGroup.Item Msg
renderSingleTrigger triggerName =
    ListGroup.li []
        [ Button.button
            [ Button.roleLink
            , Button.outlineSecondary
            , Button.onClick <| ShowTrigger triggerName
            ]
            [ text triggerName ]
        ]
