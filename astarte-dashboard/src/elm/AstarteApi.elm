module AstarteApi exposing (..)

import Http
import Task
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode
import Navigation
import Route


-- Types

import Types.Session exposing (..)
import Types.Interface as Interface exposing (Interface)
import Types.Trigger as Trigger exposing (Trigger)
import Types.RealmConfig as RealmConfig exposing (Config)


type AstarteApiError
    = NeedsLogin
    | ErrorWithMessage String


handleResponse : (a -> msg) -> (String -> msg) -> msg -> Result AstarteApiError a -> msg
handleResponse doneMessage errorMessage reloginMessage result =
    case result of
        Ok data ->
            doneMessage data

        Err (ErrorWithMessage message) ->
            errorMessage message

        Err NeedsLogin ->
            reloginMessage


requestToCommand : (a -> msg) -> (String -> msg) -> msg -> Http.Request a -> Cmd msg
requestToCommand doneMessage errorMessage reloginMessage request =
    request
        |> Http.toTask
        |> Task.mapError filterError
        |> Task.attempt (handleResponse doneMessage errorMessage reloginMessage)


filterError : Http.Error -> AstarteApiError
filterError error =
    case error of
        Http.BadUrl string ->
            ErrorWithMessage <| "Bad url " ++ string

        Http.Timeout ->
            ErrorWithMessage "Timeout"

        Http.NetworkError ->
            ErrorWithMessage "Network error"

        Http.BadStatus response ->
            case response.status.code of
                401 ->
                    NeedsLogin

                403 ->
                    ErrorWithMessage "Forbidden"

                404 ->
                    ErrorWithMessage "Resource not found"

                422 ->
                    ErrorWithMessage "Invalid entity"

                500 ->
                    ErrorWithMessage "Internal server error"

                _ ->
                    ErrorWithMessage <| "Status code " ++ (toString response.status.code)

        Http.BadPayload debugMessage response ->
            ErrorWithMessage <| "Bad payload " ++ response.body


buildHeaders : Maybe Credentials -> List Http.Header
buildHeaders maybeCredentials =
    case maybeCredentials of
        Just credentials ->
            [ Http.header "Authorization" ("Bearer " ++ credentials.token) ]

        Nothing ->
            []


getBaseUrl : Session -> String
getBaseUrl session =
    let
        realm =
            case session.credentials of
                Nothing ->
                    ""

                Just c ->
                    c.realm
    in
        session.realmManagementApiUrl ++ realm



-- Realm config


realmConfig : Session -> (Config -> msg) -> (String -> msg) -> msg -> Cmd msg
realmConfig session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "GET"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/config/auth" ]
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" RealmConfig.decoder
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


updateRealmConfig : Config -> Session -> (String -> msg) -> (String -> msg) -> msg -> Cmd msg
updateRealmConfig config session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "PUT"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/config/auth" ]
            , body = Http.jsonBody <| Json.Encode.object [ ( "data", RealmConfig.encoder config ) ]
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage



-- Interfaces


listInterfaces : Session -> (List String -> msg) -> (String -> msg) -> msg -> Cmd msg
listInterfaces session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "GET"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/interfaces" ]
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" (list string)
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


listInterfaceMajors : String -> Session -> (List Int -> msg) -> (String -> msg) -> msg -> Cmd msg
listInterfaceMajors interfaceName session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "GET"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/interfaces/", interfaceName ]
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" (list int)
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


getInterface : String -> Int -> Session -> (Interface -> msg) -> (String -> msg) -> msg -> Cmd msg
getInterface interfaceName major session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "GET"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/interfaces/", interfaceName, "/", toString major ]
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" Interface.decoder
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


deleteInterface : String -> Int -> Session -> (String -> msg) -> (String -> msg) -> msg -> Cmd msg
deleteInterface interfaceName major session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "DELETE"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/interfaces/", interfaceName, "/", toString major ]
            , body = Http.emptyBody
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


addNewInterface : Interface -> Session -> (String -> msg) -> (String -> msg) -> msg -> Cmd msg
addNewInterface interface session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "POST"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/interfaces" ]
            , body = Http.jsonBody <| Json.Encode.object [ ( "data", Interface.encoder interface ) ]
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


updateInterface : Interface -> Session -> (String -> msg) -> (String -> msg) -> msg -> Cmd msg
updateInterface interface session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "PUT"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/interfaces/", interface.name, "/", toString interface.major ]
            , body = Http.jsonBody <| Json.Encode.object [ ( "data", Interface.encoder interface ) ]
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage



-- Triggers


listTriggers : Session -> (List String -> msg) -> (String -> msg) -> msg -> Cmd msg
listTriggers session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "GET"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/triggers" ]
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" (list string)
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


getTrigger : String -> Session -> (Trigger -> msg) -> (String -> msg) -> msg -> Cmd msg
getTrigger triggerName session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "GET"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/triggers/", triggerName ]
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" Trigger.decoder
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


addNewTrigger : Trigger -> Session -> (String -> msg) -> (String -> msg) -> msg -> Cmd msg
addNewTrigger trigger session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "POST"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/triggers/" ]
            , body = Http.jsonBody <| Json.Encode.object [ ( "data", Trigger.encoder trigger ) ]
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage


deleteTrigger : String -> Session -> (String -> msg) -> (String -> msg) -> msg -> Cmd msg
deleteTrigger triggerName session doneMessage errorMessage reloginMessage =
    let
        baseUrl =
            getBaseUrl session
    in
        Http.request
            { method = "DELETE"
            , headers = buildHeaders session.credentials
            , url = String.concat [ baseUrl, "/triggers/", triggerName ]
            , body = Http.emptyBody
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }
            |> requestToCommand doneMessage errorMessage reloginMessage
