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


module Page.Home exposing (Model, Msg, init, subscriptions, update, view)

import Assets
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html, a, br, div, h2, h5, img, p, text)
import Html.Attributes exposing (class, href, src, target)
import Spinner
import Types.ExternalMessage as ExternalMsg exposing (ExternalMsg)
import Types.FlashMessage exposing (FlashMessage)
import Types.FlashMessageHelpers as FlashMessageHelpers
import Types.Session exposing (Session)


type alias Model =
    { spinner : Spinner.Model
    , showSpinner : Bool
    }


init : Session -> ( Model, Cmd Msg )
init _ =
    ( { spinner = Spinner.init
      , showSpinner = False
      }
    , Cmd.none
    )


type Msg
    = Forward ExternalMsg
      -- spinner
    | SpinnerMsg Spinner.Msg


update : Session -> Msg -> Model -> ( Model, Cmd Msg, ExternalMsg )
update _ msg model =
    case msg of
        Forward externalMsg ->
            ( model
            , Cmd.none
            , externalMsg
            )

        SpinnerMsg spinnerMsg ->
            ( { model | spinner = Spinner.update spinnerMsg model.spinner }
            , Cmd.none
            , ExternalMsg.Noop
            )


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
                [ h5
                    [ Display.inline
                    , class "text-secondary"
                    , class "font-weight-normal"
                    , class "align-middle"
                    ]
                    [ text "Home" ]
                ]
            ]
        , Grid.row
            [ Row.attrs [ Spacing.mt2 ] ]
            [ Grid.col
                [ Col.sm12
                , Col.attrs [ Flex.block ]
                ]
                [ div
                    [ Display.inlineBlockMd
                    , Spacing.pl2
                    ]
                    [ h2
                        [ Spacing.pt3 ]
                        [ text "Welcome to Astarte Dashboard!" ]
                    , p
                        [ Spacing.pl2 ]
                        [ text "Here you can easily manage your interfaces and triggers."
                        , br [] []
                        , text "Read the"
                        , a [ target "_blank", href "https://docs.astarte-platform.org/" ] [ text " docs " ]
                        , text "for more detailed informations on Astarte."
                        ]
                    ]
                , div
                    [ Display.inlineBlockMd, Spacing.mxAuto ]
                    [ img [ src <| Assets.path Assets.homepageImage ] [] ]
                ]
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.showSpinner then
        Sub.map SpinnerMsg Spinner.subscription

    else
        Sub.none
