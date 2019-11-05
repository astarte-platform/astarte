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
    ( Config
    , Error
    , addNewInterface
    , addNewTrigger
    , configDecoder
    , deleteInterface
    , deleteTrigger
    , detailedDeviceList
    , deviceInfos
    , deviceList
    , encodeConfig
    , errorToHumanReadable
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
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode exposing (Value)
import JsonHelpers
import Task
import Types.Device as Device exposing (Device)
import Types.Interface as Interface exposing (Interface)
import Types.RealmConfig as RealmConfig exposing (RealmConfig)
import Types.Trigger as Trigger exposing (Trigger)
import Url.Builder exposing (crossOrigin)


type Error
    = HttpError Http.Error
    | NeedsLogin
    | Forbidden
    | ResourceNotFound
    | Conflict String
    | InvalidEntity (List String)
    | InternalServerError


type alias Config =
    { realmManagementUrl : String
    , appengineUrl : String
    , realm : String
    , token : String
    }


type ExpectingData a
    = AnswerWithData (Result Error a)


type WithoutData
    = Answer (Result Error ())


expectAstarteReply : (Result Error a -> msg) -> Decoder a -> Http.Expect msg
expectAstarteReply toMsg replyDecoder =
    Http.expectStringResponse toMsg <|
        handleHttpResponse replyDecoder


expectWhateverAstarteReply : (Result Error () -> msg) -> Http.Expect msg
expectWhateverAstarteReply toMsg =
    Http.expectStringResponse toMsg handleHttpResponseIgnoringContent


handleHttpResponse : Decoder a -> Http.Response String -> Result Error a
handleHttpResponse decoder response =
    case response of
        Http.BadUrl_ url ->
            Err <| HttpError (Http.BadUrl url)

        Http.Timeout_ ->
            Err <| HttpError Http.Timeout

        Http.NetworkError_ ->
            Err <| HttpError Http.NetworkError

        Http.BadStatus_ metadata body ->
            Err <| parseBadStatus metadata body

        Http.GoodStatus_ metadata body ->
            case decodeString decoder body of
                Ok value ->
                    Ok value

                Err err ->
                    Err <| HttpError (Http.BadBody (Decode.errorToString err))


handleHttpResponseIgnoringContent : Http.Response String -> Result Error ()
handleHttpResponseIgnoringContent response =
    case response of
        Http.BadUrl_ url ->
            Err <| HttpError (Http.BadUrl url)

        Http.Timeout_ ->
            Err <| HttpError Http.Timeout

        Http.NetworkError_ ->
            Err <| HttpError Http.NetworkError

        Http.BadStatus_ metadata body ->
            Err <| parseBadStatus metadata body

        Http.GoodStatus_ metadata body ->
            Ok ()


parseBadStatus : Http.Metadata -> String -> Error
parseBadStatus metadata body =
    case metadata.statusCode of
        401 ->
            NeedsLogin

        403 ->
            Forbidden

        404 ->
            ResourceNotFound

        409 ->
            case decodeString (at [ "errors", "detail" ] string) body of
                Ok message ->
                    Conflict message

                Err _ ->
                    Conflict ""

        422 ->
            case decodeString feedbackMessagesDecoder body of
                Ok messageList ->
                    InvalidEntity messageList

                Err _ ->
                    InvalidEntity []

        500 ->
            InternalServerError

        code ->
            HttpError (Http.BadStatus code)


mapResponse : (a -> msg) -> (Error -> msg) -> msg -> ExpectingData a -> msg
mapResponse doneMsg errorMsg reloginMsg (AnswerWithData result) =
    case result of
        Ok resultData ->
            doneMsg resultData

        Err NeedsLogin ->
            reloginMsg

        Err apiError ->
            errorMsg apiError


mapEmptyResponse : msg -> (Error -> msg) -> msg -> WithoutData -> msg
mapEmptyResponse doneMsg errorMsg reloginMsg (Answer result) =
    case result of
        Ok _ ->
            doneMsg

        Err NeedsLogin ->
            reloginMsg

        Err apiError ->
            errorMsg apiError


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
                ( String.fromInt (index + 1), prefixString mappingErrors )
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
            String.replace " " "_" index


buildHeaders : String -> List Http.Header
buildHeaders token =
    if String.isEmpty token then
        []

    else
        [ Http.header "Authorization" ("Bearer " ++ token) ]



-- Realm config


realmConfig : Config -> (RealmConfig -> msg) -> (Error -> msg) -> msg -> Cmd msg
realmConfig apiConfig okMsg errorMsg loginMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/config/auth" ]
        , body = Http.emptyBody
        , expect = expectAstarteReply AnswerWithData <| field "data" RealmConfig.decoder
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapResponse okMsg errorMsg loginMsg)


updateRealmConfig : Config -> RealmConfig -> msg -> (Error -> msg) -> msg -> Cmd msg
updateRealmConfig apiConfig realmConf okMsg errorMsg loginMsg =
    Http.request
        { method = "PUT"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/config/auth" ]
        , body = Http.jsonBody <| Encode.object [ ( "data", RealmConfig.encode realmConf ) ]
        , expect = expectWhateverAstarteReply Answer
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapEmptyResponse okMsg errorMsg loginMsg)



-- Interfaces


listInterfaces : Config -> (List String -> msg) -> (Error -> msg) -> msg -> Cmd msg
listInterfaces apiConfig okMsg errorMsg loginMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/interfaces" ]
        , body = Http.emptyBody
        , expect = expectAstarteReply AnswerWithData <| field "data" (list string)
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapResponse okMsg errorMsg loginMsg)


listInterfaceMajors : Config -> String -> (List Int -> msg) -> (Error -> msg) -> msg -> Cmd msg
listInterfaceMajors apiConfig interfaceName okMsg errorMsg loginMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/interfaces/", interfaceName ]
        , body = Http.emptyBody
        , expect = expectAstarteReply AnswerWithData <| field "data" (list int)
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapResponse okMsg errorMsg loginMsg)


getInterface : Config -> String -> Int -> (Interface -> msg) -> (Error -> msg) -> msg -> Cmd msg
getInterface apiConfig interfaceName major okMsg errorMsg loginMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/interfaces/", interfaceName, "/", String.fromInt major ]
        , body = Http.emptyBody
        , expect = expectAstarteReply AnswerWithData <| field "data" Interface.decoder
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapResponse okMsg errorMsg loginMsg)


deleteInterface : Config -> String -> Int -> msg -> (Error -> msg) -> msg -> Cmd msg
deleteInterface apiConfig interfaceName major okMsg errorMsg loginMsg =
    Http.request
        { method = "DELETE"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/interfaces/", interfaceName, "/", String.fromInt major ]
        , body = Http.emptyBody
        , expect = expectWhateverAstarteReply Answer
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapEmptyResponse okMsg errorMsg loginMsg)


addNewInterface : Config -> Interface -> msg -> (Error -> msg) -> msg -> Cmd msg
addNewInterface apiConfig interface okMsg errorMsg loginMsg =
    Http.request
        { method = "POST"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/interfaces" ]
        , body = Http.jsonBody <| Encode.object [ ( "data", Interface.encode interface ) ]
        , expect = expectWhateverAstarteReply Answer
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapEmptyResponse okMsg errorMsg loginMsg)


updateInterface : Config -> Interface -> msg -> (Error -> msg) -> msg -> Cmd msg
updateInterface apiConfig interface okMsg errorMsg loginMsg =
    Http.request
        { method = "PUT"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/interfaces/", interface.name, "/", String.fromInt interface.major ]
        , body = Http.jsonBody <| Encode.object [ ( "data", Interface.encode interface ) ]
        , expect = expectWhateverAstarteReply Answer
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapEmptyResponse okMsg errorMsg loginMsg)



-- Triggers


listTriggers : Config -> (List String -> msg) -> (Error -> msg) -> msg -> Cmd msg
listTriggers apiConfig okMsg errorMsg loginMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/triggers" ]
        , body = Http.emptyBody
        , expect = expectAstarteReply AnswerWithData <| field "data" (list string)
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapResponse okMsg errorMsg loginMsg)


getTrigger : Config -> String -> (Trigger -> msg) -> (Error -> msg) -> msg -> Cmd msg
getTrigger apiConfig triggerName okMsg errorMsg loginMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/triggers/", triggerName ]
        , body = Http.emptyBody
        , expect = expectAstarteReply AnswerWithData <| field "data" Trigger.decoder
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapResponse okMsg errorMsg loginMsg)


addNewTrigger : Config -> Trigger -> msg -> (Error -> msg) -> msg -> Cmd msg
addNewTrigger apiConfig trigger okMsg errorMsg loginMsg =
    Http.request
        { method = "POST"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/triggers" ]
        , body = Http.jsonBody <| Encode.object [ ( "data", Trigger.encode trigger ) ]
        , expect = expectWhateverAstarteReply Answer
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapEmptyResponse okMsg errorMsg loginMsg)


deleteTrigger : Config -> String -> msg -> (Error -> msg) -> msg -> Cmd msg
deleteTrigger apiConfig triggerName okMsg errorMsg loginMsg =
    Http.request
        { method = "DELETE"
        , headers = buildHeaders apiConfig.token
        , url = String.concat [ apiConfig.realmManagementUrl, "/", apiConfig.realm, "/triggers/", triggerName ]
        , body = Http.emptyBody
        , expect = expectWhateverAstarteReply Answer
        , timeout = Nothing
        , tracker = Nothing
        }
        |> Cmd.map (mapEmptyResponse okMsg errorMsg loginMsg)



-- Devices


deviceList : Config -> (Result Error (List String) -> msg) -> Cmd msg
deviceList apiConfig resultMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = crossOrigin apiConfig.appengineUrl [ apiConfig.realm, "devices" ] []
        , body = Http.emptyBody
        , expect = expectAstarteReply resultMsg <| field "data" (list string)
        , timeout = Nothing
        , tracker = Nothing
        }


detailedDeviceList : Config -> (Result Error (List Device) -> msg) -> Cmd msg
detailedDeviceList apiConfig resultMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url =
            crossOrigin apiConfig.appengineUrl
                [ apiConfig.realm, "devices" ]
                [ Url.Builder.string "details" "true" ]
        , body = Http.emptyBody
        , expect = expectAstarteReply resultMsg <| field "data" (Decode.list Device.decoder)
        , timeout = Nothing
        , tracker = Nothing
        }


deviceInfos : Config -> String -> (Result Error Device -> msg) -> Cmd msg
deviceInfos apiConfig deviceId resultMsg =
    Http.request
        { method = "GET"
        , headers = buildHeaders apiConfig.token
        , url = crossOrigin apiConfig.appengineUrl [ apiConfig.realm, "devices", deviceId ] []
        , body = Http.emptyBody
        , expect = expectAstarteReply resultMsg <| field "data" Device.decoder
        , timeout = Nothing
        , tracker = Nothing
        }


encodeConfig : Config -> Value
encodeConfig config =
    Encode.object
        [ ( "realm_management_url", Encode.string config.realmManagementUrl )
        , ( "appengine_url", Encode.string config.appengineUrl )
        , ( "realm", Encode.string config.realm )
        , ( "token", Encode.string config.token )
        ]


configDecoder : Decoder Config
configDecoder =
    Decode.succeed Config
        |> required "realm_management_url" Decode.string
        |> required "appengine_url" Decode.string
        |> required "realm" Decode.string
        |> required "token" Decode.string



-- Heritage from previous 0.18 version
-- TODO: move this outside the Api


errorToHumanReadable : Error -> ( String, List String )
errorToHumanReadable error =
    case error of
        HttpError (Http.BadUrl url) ->
            ( "Bad url" ++ url, [] )

        HttpError Http.Timeout ->
            ( "Timeout", [] )

        HttpError Http.NetworkError ->
            ( "Network error", [] )

        HttpError (Http.BadStatus code) ->
            ( "Bad status" ++ String.fromInt code, [] )

        HttpError (Http.BadBody body) ->
            ( "Unexpected response from Astarte API", [ body ] )

        NeedsLogin ->
            ( "Token expired", [] )

        Forbidden ->
            ( "Forbidden", [] )

        ResourceNotFound ->
            ( "Resource not found", [] )

        Conflict message ->
            ( "Conflict", [ message ] )

        InvalidEntity messages ->
            ( "Invalid entity", messages )

        InternalServerError ->
            ( "Internal server error", [] )
