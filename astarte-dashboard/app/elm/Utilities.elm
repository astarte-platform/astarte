module Utilities exposing (..)

import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Decode exposing (Decoder, Value)


-- Types

import Types.ExternalMessage exposing (ExternalMsg(..))
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)


-- bootstrap components

import Bootstrap.ListGroup as ListGroup


resultToDecoder : Result String a -> Decoder a
resultToDecoder result =
    case result of
        Ok value ->
            Json.Decode.succeed value

        Err err ->
            Json.Decode.fail err


encodeOptionalFields : List ( String, Value, Bool ) -> List ( String, Value )
encodeOptionalFields fieldList =
    List.filterMap encodeOptionalHelper fieldList


encodeOptionalHelper : ( String, Value, Bool ) -> Maybe ( String, Value )
encodeOptionalHelper ( fieldName, value, isDefault ) =
    if isDefault then
        Nothing
    else
        Just ( fieldName, value )


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
