module AstarteApi exposing (..)

import Http
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode


-- Types

import Types.Session exposing (..)
import Types.Interface as Interface exposing (Interface)
import Types.Trigger as Trigger exposing (Trigger)
import Types.RealmConfig as RealmConfig exposing (Config)


type Endpoint
    = ConfigAuth
    | UpdateConfigAuth
    | ListInterfaces
    | ListInterfaceMajors String
    | GetInterface String Int
    | NewInterface
    | ListTriggers
    | GetTrigger String
    | NewTrigger


endpointParams : Session -> Endpoint -> ( String, String )
endpointParams session endpoint =
    let
        realm =
            case session.credentials of
                Nothing ->
                    ""

                Just c ->
                    c.realm

        baseUrl =
            session.realmManagementApiUrl ++ realm
    in
        case endpoint of
            ConfigAuth ->
                ( "GET", baseUrl ++ "/config/auth" )

            UpdateConfigAuth ->
                ( "PUT", baseUrl ++ "/config/auth" )

            ListInterfaces ->
                ( "GET", baseUrl ++ "/interfaces" )

            ListInterfaceMajors interfaceName ->
                ( "GET", baseUrl ++ "/interfaces/" ++ interfaceName )

            GetInterface interfaceName major ->
                ( "GET", baseUrl ++ "/interfaces/" ++ interfaceName ++ "/" ++ (toString major) )

            NewInterface ->
                ( "POST", baseUrl ++ "/interfaces" )

            ListTriggers ->
                ( "GET", baseUrl ++ "/triggers" )

            GetTrigger triggerName ->
                ( "GET", baseUrl ++ "/triggers/" ++ triggerName )

            NewTrigger ->
                ( "POST", baseUrl ++ "/triggers" )


headers : Maybe Credentials -> List Http.Header
headers maybeCredentials =
    case maybeCredentials of
        Just credentials ->
            [ Http.header "Authorization" ("Bearer " ++ credentials.token) ]

        Nothing ->
            []



-- Realm config


getRealmConfigRequest : Session -> Http.Request Config
getRealmConfigRequest session =
    let
        ( method, url ) =
            endpointParams session ConfigAuth
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" RealmConfig.decoder
            , timeout = Nothing
            , withCredentials = False
            }


updateRealmConfigRequest : Config -> Session -> Http.Request String
updateRealmConfigRequest config session =
    let
        ( method, url ) =
            endpointParams session UpdateConfigAuth
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.jsonBody <| Json.Encode.object [ ( "data", RealmConfig.encoder config ) ]
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }



-- Interfaces


getInterfacesRequest : Session -> Http.Request (List String)
getInterfacesRequest session =
    let
        ( method, url ) =
            endpointParams session ListInterfaces
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" (list string)
            , timeout = Nothing
            , withCredentials = False
            }


getInterfaceMajorsRequest : String -> Session -> Http.Request (List Int)
getInterfaceMajorsRequest interfaceName session =
    let
        ( method, url ) =
            endpointParams session <| ListInterfaceMajors interfaceName
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" (list int)
            , timeout = Nothing
            , withCredentials = False
            }


getInterfaceRequest : String -> Int -> Session -> Http.Request Interface
getInterfaceRequest interfaceName major session =
    let
        ( method, url ) =
            endpointParams session <| GetInterface interfaceName major
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" Interface.decoder
            , timeout = Nothing
            , withCredentials = False
            }


addNewInterfaceRequest : Interface -> Session -> Http.Request String
addNewInterfaceRequest interface session =
    let
        ( method, url ) =
            endpointParams session NewInterface
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.jsonBody <| Json.Encode.object [ ( "data", Interface.encoder interface ) ]
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }



-- Triggers


getTriggersRequest : Session -> Http.Request (List String)
getTriggersRequest session =
    let
        ( method, url ) =
            endpointParams session ListTriggers
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" (list string)
            , timeout = Nothing
            , withCredentials = False
            }


getTriggerRequest : String -> Session -> Http.Request Trigger
getTriggerRequest triggerName session =
    let
        ( method, url ) =
            endpointParams session <| GetTrigger triggerName
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.emptyBody
            , expect = Http.expectJson <| field "data" Trigger.decoder
            , timeout = Nothing
            , withCredentials = False
            }


addNewTriggerRequest : Trigger -> Session -> Http.Request String
addNewTriggerRequest trigger session =
    let
        ( method, url ) =
            endpointParams session NewTrigger
    in
        Http.request
            { method = method
            , headers = headers session.credentials
            , url = url
            , body = Http.jsonBody <| Json.Encode.object [ ( "data", Trigger.encoder trigger ) ]
            , expect = Http.expectString
            , timeout = Nothing
            , withCredentials = False
            }
