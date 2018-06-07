module Types.ExternalMessage exposing (..)

import Types.FlashMessage exposing (FlashMessageId, Severity)


type ExternalMsg
    = Noop
    | AddFlashMessage Severity String
    | DismissFlashMessage FlashMessageId
