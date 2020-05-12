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


module Page.Interfaces exposing (Model, Msg, init, subscriptions, update, view)

import AstarteApi
import Bootstrap.Accordion as Accordion
import Bootstrap.Card as Card
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing
import Dict exposing (Dict)
import Html exposing (Html, a, h5, text)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Icons
import ListUtils exposing (addWhen)
import Route
import Spinner
import Time
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage as FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)


type alias Model =
    { interfaces : Dict String (List Int)
    , accordionState : Accordion.State
    , spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { interfaces = Dict.empty
      , accordionState = Accordion.initialState
      , spinner = Spinner.init
      , showSpinner = True
      }
    , AstarteApi.listInterfaces session.apiConfig
        GetInterfaceListDone
        (ShowError "Could not retrieve interface list")
        RedirectToLogin
    )


type Msg
    = GetInterfaceList
    | GetInterfaceListDone (List String)
    | GetInterfaceMajors String
    | GetInterfaceMajorsDone String (List Int)
    | OpenInterfaceBuilder
    | RefreshInterfaceList Time.Posix
    | Forward ExternalMsg
    | ShowError String AstarteApi.Error
    | RedirectToLogin
      -- accordion
    | AccordionMsg Accordion.State
      -- spinner
    | SpinnerMsg Spinner.Msg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update session msg model =
    case msg of
        GetInterfaceList ->
            ( { model | showSpinner = True }
            , AstarteApi.listInterfaces session.apiConfig
                GetInterfaceListDone
                (ShowError "Could not retrieve interface list")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        GetInterfaceListDone interfaces ->
            ( { model
                | interfaces =
                    interfaces
                        |> List.map (\x -> ( x, [] ))
                        |> Dict.fromList
                , showSpinner = not (List.isEmpty interfaces)
              }
            , interfaces
                |> List.map (\name -> getInterfaceMajorsHelper session.apiConfig name)
                |> Cmd.batch
            , ExternalMsg.Noop
            )

        GetInterfaceMajors interfaceName ->
            ( model
            , getInterfaceMajorsHelper session.apiConfig interfaceName
            , ExternalMsg.Noop
            )

        GetInterfaceMajorsDone interfaceName majors ->
            ( { model
                | interfaces =
                    Dict.update
                        interfaceName
                        (\_ -> Just <| List.reverse majors)
                        model.interfaces
                , showSpinner = False
              }
            , Cmd.none
            , ExternalMsg.Noop
            )

        OpenInterfaceBuilder ->
            ( model
            , Cmd.none
            , ExternalMsg.RequestRoute <| Route.Realm Route.NewInterface
            )

        ShowError actionError apiError ->
            let
                ( apiErrorTitle, apiErrorDetails ) =
                    AstarteApi.errorToHumanReadable apiError

                flashmessageTitle =
                    String.concat [ actionError, ": ", apiErrorTitle ]
            in
            ( { model | showSpinner = False }
            , Cmd.none
            , ExternalMsg.AddFlashMessage FlashMessage.Error flashmessageTitle apiErrorDetails
            )

        RedirectToLogin ->
            ( model
            , Cmd.none
            , ExternalMsg.RequestRoute <| Route.Realm Route.Logout
            )

        RefreshInterfaceList _ ->
            ( model
            , AstarteApi.listInterfaces session.apiConfig
                GetInterfaceListDone
                (ShowError "Could not refresh interface list")
                RedirectToLogin
            , ExternalMsg.Noop
            )

        Forward externalMsg ->
            ( model
            , Cmd.none
            , externalMsg
            )

        AccordionMsg state ->
            ( { model | accordionState = state }
            , Cmd.none
            , ExternalMsg.Noop
            )

        SpinnerMsg spinnerMsg ->
            ( { model | spinner = Spinner.update spinnerMsg model.spinner }
            , Cmd.none
            , ExternalMsg.Noop
            )


getInterfaceMajorsHelper : AstarteApi.Config -> String -> Cmd Msg
getInterfaceMajorsHelper apiConfig interfaceName =
    AstarteApi.listInterfaceMajors
        apiConfig
        interfaceName
        (GetInterfaceMajorsDone interfaceName)
        (ShowError <| String.concat [ "Could not retrieve major versions for ", interfaceName, " interface" ])
        RedirectToLogin


view : Model -> List FlashMessage -> Html Msg
view model flashMessages =
    Grid.containerFluid
        [ class "bg-white"
        , Border.rounded
        , Spacing.pb3
        ]
        [ Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ FlashMessageHelpers.renderFlashMessages flashMessages Forward ]
            ]
        , if model.showSpinner then
            Spinner.view Spinner.defaultConfig model.spinner

          else
            text ""
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12 ]
                [ Html.h3 []
                    [ Html.text "Interfaces" ]
                ]
            ]
        , Grid.row [ Row.attrs [ Spacing.mt3 ] ]
            [ Grid.col [ Col.sm12 ]
                [ ListGroup.ul
                    (model.interfaces
                        |> Dict.toList
                        |> List.map interfaceLinks
                        |> addWhen (Dict.isEmpty model.interfaces) noInterfaceInstalledRow
                        |> (::) addInterfaceRow
                    )
                ]
            ]
        ]


noInterfaceInstalledRow : ListGroup.Item Msg
noInterfaceInstalledRow =
    ListGroup.li []
        [ Html.text "No interface installed" ]


addInterfaceRow : ListGroup.Item Msg
addInterfaceRow =
    ListGroup.li []
        [ Html.a
            [ href <| Route.toString <| Route.Realm Route.NewInterface ]
            [ Icons.render Icons.Add [ Spacing.mr2 ]
            , Html.text "Install a new interface..."
            ]
        ]


interfaceLinks : ( String, List Int ) -> ListGroup.Item Msg
interfaceLinks ( interfaceName, majors ) =
    let
        latestVer =
            List.maximum majors
    in
    case latestVer of
        Nothing ->
            ListGroup.li [] [ Html.text interfaceName ]

        Just latest ->
            ListGroup.li []
                [ Grid.containerFluid [ Spacing.p0 ]
                    [ Grid.simpleRow
                        [ Grid.col []
                            [ Html.a
                                [ href <| Route.toString <| Route.Realm (Route.ShowInterface interfaceName latest) ]
                                [ Icons.render Icons.Interface [ Spacing.mr2 ]
                                , Html.text interfaceName
                                ]
                            ]
                        , Grid.col [ Col.mdAuto ]
                            (List.map (majorBadgeLink interfaceName) majors)
                        ]
                    ]
                ]


majorBadgeLink : String -> Int -> Html Msg
majorBadgeLink interfaceName major =
    let
        badgeColorClass =
            if major == 0 then
                "badge-secondary"

            else
                "badge-primary"
    in
    Html.a
        [ class "badge"
        , class badgeColorClass
        , Spacing.mr1
        , Spacing.px2
        , Spacing.py1
        , href <| Route.toString <| Route.Realm (Route.ShowInterface interfaceName major)
        ]
        [ Html.text <| "v" ++ String.fromInt major ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    [ Accordion.subscriptions model.accordionState AccordionMsg
    , Time.every (30 * 1000) RefreshInterfaceList
    ]
        |> addWhen model.showSpinner (Sub.map SpinnerMsg Spinner.subscription)
        |> Sub.batch
