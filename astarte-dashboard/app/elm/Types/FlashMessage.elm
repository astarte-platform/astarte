module Types.FlashMessage exposing (..)


type alias FlashMessage =
    { id : FlashMessageId
    , message : String
    , severity : Severity
    }


type FlashMessageId
    = FlashMessageId Int


type Severity
    = Notice
    | Warning
    | Error
    | Fatal


new : Int -> String -> Severity -> FlashMessage
new intId message severity =
    { id = FlashMessageId intId
    , message = message
    , severity = severity
    }
