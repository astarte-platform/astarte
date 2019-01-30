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


module Types.FlashMessageHelpers exposing (renderFlashMessages)

import Bootstrap.ListGroup as ListGroup
import Html exposing (Html, text)
import Html.Events exposing (onClick)
import Types.ExternalMessage exposing (ExternalMsg(..))
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)


renderFlashMessages : List FlashMessage -> (ExternalMsg -> a) -> Html a
renderFlashMessages messages tagger =
    if List.isEmpty messages then
        text ""

    else
        List.map renderFlashMessage messages
            |> ListGroup.ul
            |> Html.map tagger


renderFlashMessage : FlashMessage -> ListGroup.Item ExternalMsg
renderFlashMessage message =
    ListGroup.li
        [ case message.severity of
            FlashMessage.Notice ->
                ListGroup.info

            FlashMessage.Warning ->
                ListGroup.warning

            FlashMessage.Error ->
                ListGroup.danger

            FlashMessage.Fatal ->
                ListGroup.danger
        , ListGroup.attrs [ onClick <| DismissFlashMessage message.id ]
        ]
        [ text <| message.message ]
