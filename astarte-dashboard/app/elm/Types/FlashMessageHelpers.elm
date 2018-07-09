module Types.FlashMessageHelpers exposing (renderFlashMessages)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)


-- Types

import Types.ExternalMessage exposing (ExternalMsg(..))
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)


-- bootstrap components

import Bootstrap.ListGroup as ListGroup


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
