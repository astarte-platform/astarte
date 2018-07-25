module Page.Triggers exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Navigation
import Json.Decode as Decode


-- Types

import AstarteApi exposing (..)
import Route
import Types.Session exposing (Session)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.FlashMessageHelpers as FlashMessageHelpers


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
    , AstarteApi.listTriggers session
        GetTriggerListDone
        (ShowError "Cannot retrieve triggers. ")
        RedirectToLogin
    )


type Msg
    = GetTriggerList
    | GetTriggerListDone (List String)
    | AddNewTrigger
    | ShowTrigger String
    | ShowError String String
    | RedirectToLogin
    | Forward ExternalMsg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetTriggerList ->
            ( model
            , AstarteApi.listTriggers session
                GetTriggerListDone
                (ShowError "Cannot retrieve triggers. ")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        GetTriggerListDone triggerNames ->
            ( { model | triggers = triggerNames }
            , Cmd.none
            , ExternalMsg.Noop
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

        ShowError actionError errorMessage ->
            ( model
            , Cmd.none
            , [ actionError, " ", errorMessage ]
                |> String.concat
                |> ExternalMsg.AddFlashMessage FlashMessage.Error
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
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ h5 [ Display.inline ]
                    [ if List.isEmpty model.triggers then
                        text "No trigger installed"
                      else
                        text "Triggers"
                    ]
                , Button.button
                    [ Button.primary
                    , Button.onClick AddNewTrigger
                    , Button.attrs [ class "float-right" ]
                    ]
                    [ text "Install a New trigger ..." ]
                , Button.button
                    [ Button.primary
                    , Button.onClick GetTriggerList
                    , Button.attrs [ class "float-right", Spacing.mr1 ]
                    ]
                    [ text "Reload" ]
                ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ ListGroup.ul <| List.map renderSingleTrigger model.triggers ]
            ]
        ]


renderSingleTrigger : String -> ListGroup.Item Msg
renderSingleTrigger triggerName =
    ListGroup.li
        [ ListGroup.attrs [ Spacing.p0, Spacing.mb2 ] ]
        [ h4
            [ class "card-header" ]
            [ a
                [ href "#"
                , Html.Events.onWithOptions
                    "click"
                    { stopPropagation = True
                    , preventDefault = True
                    }
                    (Decode.succeed <| ShowTrigger triggerName)
                ]
                [ text triggerName ]
            ]
        ]
