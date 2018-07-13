module Page.Interfaces exposing (Model, Msg, init, update, view)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Navigation


-- Types

import AstarteApi exposing (..)
import Route
import Types.Session exposing (Session)
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.Interface exposing (Interface)
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.FlashMessageHelpers as FlashMessageHelpers


-- bootstrap components

import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup exposing (LinkButtonItem)
import Bootstrap.Form as Form
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing


type alias Model =
    { interfaces : Dict String (List Int)
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { interfaces = Dict.empty
      }
    , AstarteApi.listInterfaces session
        GetInterfaceListDone
        (ShowError "Cannot retrieve interfaces.")
        RedirectToLogin
    )


type Msg
    = GetInterfaceList
    | GetInterfaceListDone (List String)
    | GetInterfaceMajors String
    | GetInterfaceMajorsDone String (List Int)
    | OpenInterfaceBuilder
    | ShowInterface String Int
    | Forward ExternalMsg
    | ShowError String String
    | RedirectToLogin


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetInterfaceList ->
            ( model
            , AstarteApi.listInterfaces session
                GetInterfaceListDone
                (ShowError "Cannot retrieve interfaces.")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        GetInterfaceListDone interfaces ->
            ( { model
                | interfaces =
                    interfaces
                        |> List.map (\x -> ( x, [] ))
                        |> Dict.fromList
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        GetInterfaceMajors interfaceName ->
            ( model
            , AstarteApi.listInterfaceMajors interfaceName
                session
                (GetInterfaceMajorsDone interfaceName)
                (ShowError <| String.concat [ "Cannot retrieve major versions for ", interfaceName, " interface." ])
                RedirectToLogin
            , ExternalMsg.Noop
            )

        GetInterfaceMajorsDone interfaceName majors ->
            ( { model | interfaces = Dict.update interfaceName (\_ -> Just majors) model.interfaces }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenInterfaceBuilder ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm Route.NewInterface)
            , ExternalMsg.Noop
            )

        ShowInterface name major ->
            ( model
            , Navigation.modifyUrl <| Route.toString (Route.Realm <| Route.ShowInterface name major)
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
            [ Row.middleSm
            , Row.topSm
            ]
            [ Grid.col
                [ Col.sm12 ]
                [ ListGroup.ul <| renderInterfaces model.interfaces
                , Button.button
                    [ Button.primary
                    , Button.onClick GetInterfaceList
                    , Button.attrs [ Spacing.mt2, Spacing.mr1 ]
                    ]
                    [ text "Reload" ]
                , Button.button
                    [ Button.primary
                    , Button.onClick OpenInterfaceBuilder
                    , Button.attrs [ Spacing.mt2 ]
                    ]
                    [ text "Install a New Interface ..." ]
                ]
            ]
        ]


renderInterfaces : Dict String (List Int) -> List (ListGroup.Item Msg)
renderInterfaces interfaces =
    Dict.toList interfaces
        |> List.map renderSingleInterface


renderSingleInterface : ( String, List Int ) -> ListGroup.Item Msg
renderSingleInterface ( interfaceName, majors ) =
    ListGroup.li []
        [ ButtonGroup.linkButtonGroup [] <|
            (++)
                [ ButtonGroup.linkButton
                    [ Button.roleLink
                    , Button.outlineSecondary
                    , Button.onClick <| GetInterfaceMajors interfaceName
                    ]
                    [ text interfaceName ]
                ]
                (renderInterfaceMajors interfaceName majors)
        ]


renderInterfaceMajors : String -> List Int -> List (LinkButtonItem Msg)
renderInterfaceMajors interfaceName majors =
    List.map (\v -> renderSingleMajor interfaceName v) majors


renderSingleMajor : String -> Int -> LinkButtonItem Msg
renderSingleMajor interfaceName major =
    ButtonGroup.linkButton
        [ Button.roleLink
        , Button.outlineSecondary
        , Button.onClick <| ShowInterface interfaceName major
        ]
        [ text <| "v" ++ (toString major) ]
