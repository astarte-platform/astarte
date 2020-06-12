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


module Ui.Card exposing (Width(..), simpleText, subTitle, view)

import Bootstrap.Card as Card
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html)
import Html.Attributes exposing (class)


type Width
    = FullWidth
    | HalfWidth


view : String -> Width -> List (Html msg) -> List (Html msg) -> Grid.Column msg
view cardName width innerItems bottomItems =
    Grid.col (colOptionsFromWidth width ++ [ Col.attrs [ Spacing.mb4 ] ])
        [ Html.div [ class "card", Size.h100 ]
            [ Html.h5 [ class "card-header" ]
                [ Html.text cardName ]
            , Html.div [ class "card-body", Flex.block, Flex.col ]
                (if List.isEmpty bottomItems then
                    innerItems

                 else
                    innerItems ++ [ Html.div [ Spacing.mtAuto ] bottomItems ]
                )
            ]
        ]


colOptionsFromWidth : Width -> List (Col.Option msg)
colOptionsFromWidth width =
    case width of
        FullWidth ->
            [ Col.xs12 ]

        HalfWidth ->
            [ Col.xs12
            , Col.md6
            ]


subTitle : String -> Html msg
subTitle title =
    Html.h6 [] [ Html.text title ]


simpleText : String -> Html msg
simpleText text =
    Html.p [] [ Html.text text ]
