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


module Modal.SelectGroup exposing (ExternalMsg(..), Model, Msg(..), init, update, view)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid.Col as Col
import Bootstrap.Modal as Modal
import Bootstrap.Utilities.Spacing as Spacing
import Html exposing (Html)
import Html.Attributes exposing (for, value)
import Html.Events
import Icons


type alias Model =
    { availableGroups : List String
    , selectedGroup : String
    , visibility : Modal.Visibility
    }


init : Bool -> List String -> Model
init shown groups =
    { availableGroups = groups
    , selectedGroup = ""
    , visibility =
        if shown then
            Modal.shown

        else
            Modal.hidden
    }


type ModalResult
    = ModalCancel
    | ModalOk


type Msg
    = Close ModalResult
    | UpdateSelection String


type ExternalMsg
    = Noop
    | SelectedGroup String


update : Msg -> Model -> ( Model, ExternalMsg )
update message model =
    case message of
        Close ModalCancel ->
            ( { model | visibility = Modal.hidden }
            , Noop
            )

        Close ModalOk ->
            ( { model | visibility = Modal.hidden }
            , SelectedGroup model.selectedGroup
            )

        UpdateSelection groupName ->
            ( { model | selectedGroup = groupName }
            , Noop
            )


view : Model -> Html Msg
view model =
    Modal.config (Close ModalCancel)
        |> Modal.large
        |> Modal.h5 [] [ Html.text "Select Existing Group" ]
        |> Modal.body []
            [ renderBody model.selectedGroup model.availableGroups ]
        |> Modal.footer []
            [ Button.button
                [ Button.secondary
                , Button.onClick <| Close ModalCancel
                ]
                [ Html.text "Cancel" ]
            , Button.button
                [ Button.primary
                , Button.disabled <| String.isEmpty model.selectedGroup
                , Button.onClick <| Close ModalOk
                ]
                [ Html.text "Confirm" ]
            ]
        |> Modal.view model.visibility


renderBody : String -> List String -> Html Msg
renderBody selectedGroup groups =
    Html.ul
        [ Html.Attributes.class "list-unstyled" ]
        (List.map (renderGroup selectedGroup) groups)


renderGroup : String -> String -> Html Msg
renderGroup currentItem groupName =
    Html.li
        (if groupName == currentItem then
            [ Spacing.p2
            , Html.Attributes.class "bg-success text-white"
            , Html.Events.onClick <| UpdateSelection ""
            ]

         else
            [ Spacing.p2
            , Html.Events.onClick <| UpdateSelection groupName
            ]
        )
        [ Icons.render Icons.Add [ Spacing.mr2 ]
        , Html.text groupName
        ]
