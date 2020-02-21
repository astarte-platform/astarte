{-
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

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


module Ui.Card exposing (Width(..), htmlRow, textRow, view, viewHeadless)

import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Utilities.Border as Border
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html)
import Html.Attributes exposing (class)


type Width
    = FullWidth
    | HalfWidth


view : Width -> String -> List (Html msg) -> Grid.Column msg
view width cardName innerItems =
    let
        classWidth =
            case width of
                FullWidth ->
                    [ Col.xs12 ]

                HalfWidth ->
                    [ Col.xs12
                    , Col.md6
                    ]
    in
    Grid.col (classWidth ++ [ Col.attrs [ Spacing.p2 ] ])
        [ Grid.containerFluid
            [ class "bg-white", Border.rounded, Spacing.p3, Size.h100 ]
            ([ Grid.row
                [ Row.attrs [ Spacing.mt2 ] ]
                [ Grid.col [ Col.sm12 ]
                    [ Html.h5
                        [ Display.inline
                        , class "text-secondary"
                        , class "font-weight-normal"
                        , class "align-middle"
                        ]
                        [ Html.text cardName ]
                    ]
                ]
             ]
                ++ innerItems
            )
        ]


viewHeadless : Width -> List (Html msg) -> Grid.Column msg
viewHeadless width innerItems =
    let
        classWidth =
            case width of
                FullWidth ->
                    [ Col.xs12 ]

                HalfWidth ->
                    [ Col.xs12
                    , Col.md6
                    ]
    in
    Grid.col (classWidth ++ [ Col.attrs [ Spacing.p2 ] ])
        [ Grid.containerFluid
            [ class "bg-white", Border.rounded, Spacing.p3, Size.h100 ]
            innerItems
        ]


htmlRow : ( String, Html msg ) -> Html msg
htmlRow ( label, value ) =
    Grid.row
        [ Row.attrs [ Spacing.mt3 ] ]
        [ Grid.col [ Col.sm12 ]
            [ Html.h6 [] [ Html.text label ]
            , value
            ]
        ]


textRow : ( String, String ) -> Html msg
textRow ( label, value ) =
    htmlRow ( label, Html.text value )


boolRow : ( String, Bool ) -> Html msg
boolRow ( label, value ) =
    if value then
        textRow ( label, "True" )

    else
        textRow ( label, "False" )
