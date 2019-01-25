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
