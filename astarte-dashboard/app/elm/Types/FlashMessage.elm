module Types.FlashMessage exposing (..)

import Time exposing (Time)


type alias FlashMessage =
    { id : FlashMessageId
    , message : String
    , severity : Severity
    , dismissAt : Time
    }


type FlashMessageId
    = FlashMessageId Int


type Severity
    = Notice
    | Warning
    | Error
    | Fatal


new : Int -> String -> Severity -> Time -> FlashMessage
new intId message severity dismissAt =
    { id = FlashMessageId intId
    , message = message
    , severity = severity
    , dismissAt = dismissAt
    }
