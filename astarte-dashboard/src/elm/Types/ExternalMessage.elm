module Types.ExternalMessage exposing (ExternalMsg(..))

import Types.FlashMessage exposing (FlashMessageId, Severity)


type ExternalMsg
    = Noop
    | AddFlashMessage Severity String
    | DismissFlashMessage FlashMessageId
