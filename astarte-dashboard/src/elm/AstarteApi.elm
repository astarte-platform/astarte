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


module AstarteApi exposing
    ( AstarteErrorMessage
    , addNewInterface
    , addNewTrigger
    , deleteInterface
    , deleteTrigger
    , getInterface
    , getTrigger
    , listInterfaceMajors
    , listInterfaces
    , listTriggers
    , realmConfig
    , updateInterface
    , updateRealmConfig
    )

import Http
import Json.Decode as Decode
    exposing
        ( Decoder
        , andThen
        , at
        , decodeString
        , field
        , int
        , keyValuePairs
        , list
        , oneOf
        , string
        , succeed
        )
import Json.Encode as Encode
import Task
import Types.Interface as Interface exposing (Interface)
import Types.RealmConfig as RealmConfig exposing (Config)
import Types.Session exposing (Credentials, Session)
import Types.Trigger as Trigger exposing (Trigger)


type AstarteApiError
    = NeedsLogin
    | SimpleError String
    | DetailedError AstarteErrorMessage


type alias AstarteErrorMessage =
    { message : String
    , details : List String
    }


handleResponse : (a -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Result AstarteApiError a -> msg
handleResponse doneMessage errorMessage reloginMessage result =
    case result of
        Ok data ->
            doneMessage data

        Err (SimpleError message) ->
            errorMessage
                { message = message
                , details = []
                }

        Err (DetailedError astarteMessage) ->
            errorMessage astarteMessage

        Err NeedsLogin ->
            reloginMessage


requestToCommand : (a -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Http.Request a -> Cmd msg
requestToCommand doneMessage errorMessage reloginMessage request =
    request
        |> Http.toTask
        |> Task.mapError filterError
        |> Task.attempt (handleResponse doneMessage errorMessage reloginMessage)


filterError : Http.Error -> AstarteApiError
filterError error =
    case error of
        Http.BadUrl string ->
            SimpleError <| "Bad url " ++ string

        Http.Timeout ->
            SimpleError "Timeout"

        Http.NetworkError ->
            SimpleError "Network error"

        Http.BadStatus response ->
            case response.status.code of
                401 ->
                    NeedsLogin

                403 ->
                    SimpleError "Forbidden"

                404 ->
                    SimpleError "Resource not found"

                409 ->
                    let
                        messageDetails =
                            case decodeString (at [ "errors", "detail" ] string) response.body of
                                Ok message ->
                                    [ message ]

                                Err _ ->
                                    []

                        errorMessage =
                            { message = "Conflict"
                            , details = messageDetails
                            }
                    in
                    DetailedError errorMessage

                422 ->
                    let
                        messageDetails =
                            decodeString feedbackMessagesDecoder response.body
                                |> Result.toMaybe
                                |> Maybe.withDefault []

                        errorMessage =
                            { message = "Invalid entity"
                            , details = messageDetails
                            }
                    in
                    DetailedError errorMessage

                500 ->
                    SimpleError "Internal server error"

                _ ->
                    SimpleError <| "Status code " ++ toString response.status.code

        Http.BadPayload debugMessage response ->
            SimpleError <| "Bad payload " ++ response.body


feedbackMessagesDecoder : Decoder (List String)
feedbackMessagesDecoder =
    field "errors" (keyValuePairs (oneOf [ list string, nestedKeyPair ]))
        |> Decode.map prefixString


nestedKeyPair : Decoder (List String)
nestedKeyPair =
    list (keyValuePairs (list string))
        |> Decode.map nestedKeyPairHelper


nestedKeyPairHelper : List (List ( String, List String )) -> List String
nestedKeyPairHelper errors =
    errors
        |> List.indexedMap
            (\index mappingErrors ->
                ( toString (index + 1), prefixString mappingErrors )
            )
        |> prefixString


prefixString : List ( String, List String ) -> List String
prefixString list =
    List.foldl
        (\( prefix, sublist ) accumulator ->
            sublist
                |> List.map (\message -> translateIndex prefix ++ " " ++ message)
                |> List.append accumulator
        )
        []
        list


translateIndex : String -> String
translateIndex index =
    case index of
        "mappings" ->
            "mapping"

        "simple_triggers" ->
            "trigger"

        _ ->
            -- There is no String.replace in elm 0.18
            String.split "_" index
                |> String.join " "


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


realmConfig : Session -> (Config -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
realmConfig session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "GET"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/config/auth" ]
        , body = Http.emptyBody
        , expect = Http.expectJson <| field "data" RealmConfig.decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


updateRealmConfig : Config -> Session -> (String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
updateRealmConfig config session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "PUT"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/config/auth" ]
        , body = Http.jsonBody <| Encode.object [ ( "data", RealmConfig.encode config ) ]
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage



-- Interfaces


listInterfaces : Session -> (List String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
listInterfaces session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "GET"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/interfaces" ]
        , body = Http.emptyBody
        , expect = Http.expectJson <| field "data" (list string)
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


listInterfaceMajors : String -> Session -> (List Int -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
listInterfaceMajors interfaceName session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "GET"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/interfaces/", interfaceName ]
        , body = Http.emptyBody
        , expect = Http.expectJson <| field "data" (list int)
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


getInterface : String -> Int -> Session -> (Interface -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
getInterface interfaceName major session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "GET"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/interfaces/", interfaceName, "/", toString major ]
        , body = Http.emptyBody
        , expect = Http.expectJson <| field "data" Interface.decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


deleteInterface : String -> Int -> Session -> (String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
deleteInterface interfaceName major session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "DELETE"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/interfaces/", interfaceName, "/", toString major ]
        , body = Http.emptyBody
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


addNewInterface : Interface -> Session -> (String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
addNewInterface interface session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "POST"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/interfaces" ]
        , body = Http.jsonBody <| Encode.object [ ( "data", Interface.encode interface ) ]
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


updateInterface : Interface -> Session -> (String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
updateInterface interface session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "PUT"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/interfaces/", interface.name, "/", toString interface.major ]
        , body = Http.jsonBody <| Encode.object [ ( "data", Interface.encode interface ) ]
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage



-- Triggers


listTriggers : Session -> (List String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
listTriggers session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "GET"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/triggers" ]
        , body = Http.emptyBody
        , expect = Http.expectJson <| field "data" (list string)
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


getTrigger : String -> Session -> (Trigger -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
getTrigger triggerName session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "GET"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/triggers/", triggerName ]
        , body = Http.emptyBody
        , expect = Http.expectJson <| field "data" Trigger.decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


addNewTrigger : Trigger -> Session -> (String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
addNewTrigger trigger session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "POST"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/triggers/" ]
        , body = Http.jsonBody <| Encode.object [ ( "data", Trigger.encode trigger ) ]
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage


deleteTrigger : String -> Session -> (String -> msg) -> (AstarteErrorMessage -> msg) -> msg -> Cmd msg
deleteTrigger triggerName session doneMessage errorMessage reloginMessage =
    Http.request
        { method = "DELETE"
        , headers = buildHeaders session.credentials
        , url = String.concat [ getBaseUrl session, "/triggers/", triggerName ]
        , body = Http.emptyBody
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }
        |> requestToCommand doneMessage errorMessage reloginMessage
