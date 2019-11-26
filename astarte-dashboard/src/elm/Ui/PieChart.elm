{-
   This file is part of Astarte.

   Copyright 2019 Ispirata Srl

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


module Ui.PieChart exposing (view)

import Array exposing (Array)
import Color exposing (Color)
import Path
import Shape exposing (defaultPieConfig)
import TypedSvg exposing (g, svg)
import TypedSvg.Attributes exposing (fill, stroke, transform, viewBox)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (Fill(..), Transform(..))


type alias Params =
    { width : Float
    , height : Float
    , colors : List Color
    , data : List ( String, Float )
    }


view : Params -> Svg msg
view params =
    let
        colorArray =
            Array.fromList params.colors

        radius =
            min params.width params.height / 2

        pieData =
            params.data
                |> List.map Tuple.second
                |> Shape.pie { defaultPieConfig | outerRadius = radius }

        makeSlice index datum =
            Path.element (Shape.arc datum) [ fill <| Fill <| Maybe.withDefault Color.black <| Array.get index colorArray, stroke Color.white ]
    in
    svg [ viewBox 0 0 params.width params.height ]
        [ g [ transform [ Translate (params.width / 2) (params.height / 2) ] ]
            [ g [] <| List.indexedMap makeSlice pieData ]
        ]
