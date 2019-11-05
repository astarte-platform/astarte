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


module Route exposing
    ( RealmRoute(..)
    , Route(..)
    , fromUrl
    , toString
    )

import Url exposing (Url)
import Url.Parser exposing ((</>), (<?>), Parser, int, map, oneOf, parse, s, string, top)
import Url.Parser.Query as Query



-- ROUTING --


type Route
    = Root
    | InterfaceEditor
    | RealmSelection (Maybe String)
    | Realm RealmRoute


type RealmRoute
    = Auth (Maybe String) (Maybe String)
    | Home
    | Logout
    | RealmSettings
    | ListInterfaces
    | NewInterface
    | ShowInterface String Int
    | ListTriggers
    | NewTrigger
    | ShowTrigger String
    | DeviceList
    | ShowDevice String


routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ map Root (s "")
        , map InterfaceEditor (s "interface_editor")
        , map RealmSelection (s "login" <?> Query.string "type")
        , map Realm realmRouteParser
        ]


realmRouteParser : Parser (RealmRoute -> a) a
realmRouteParser =
    oneOf
        [ map Home top
        , map Auth (s "auth" <?> Query.string "realm" <?> Query.string "authUrl")
        , map Logout (s "logout")
        , map RealmSettings (s "settings")
        , map ListInterfaces (s "interfaces")
        , map NewInterface (s "interfaces" </> s "new")
        , map ShowInterface (s "interfaces" </> string </> int)
        , map ListTriggers (s "triggers")
        , map NewTrigger (s "triggers" </> s "new")
        , map ShowTrigger (s "triggers" </> string)
        , map DeviceList (s "devices")
        , map ShowDevice (s "devices" </> string)
        ]


fromUrl : Url -> ( Maybe Route, Maybe String )
fromUrl url =
    ( parse routeParser url
    , parseToken url.fragment
    )


toString : Route -> String
toString route =
    let
        pieces =
            case route of
                Root ->
                    [ "" ]

                InterfaceEditor ->
                    [ "interface_editor" ]

                RealmSelection maybeType ->
                    case maybeType of
                        Just loginType ->
                            [ "login?type=" ++ loginType ]

                        Nothing ->
                            [ "login" ]

                Realm (Auth r a) ->
                    case ( r, a ) of
                        ( Just realm, Just authUrl ) ->
                            [ "auth?realm=" ++ realm ++ "&authUrl=" ++ authUrl ]

                        ( Just realm, Nothing ) ->
                            [ "auth?realm=" ++ realm ]

                        _ ->
                            [ "" ]

                Realm Home ->
                    []

                Realm Logout ->
                    [ "logout" ]

                Realm RealmSettings ->
                    [ "settings" ]

                Realm ListInterfaces ->
                    [ "interfaces" ]

                Realm NewInterface ->
                    [ "interfaces", "new" ]

                Realm (ShowInterface name major) ->
                    [ "interfaces", name, String.fromInt major ]

                Realm ListTriggers ->
                    [ "triggers" ]

                Realm NewTrigger ->
                    [ "triggers", "new" ]

                Realm (ShowTrigger name) ->
                    [ "triggers", name ]

                Realm DeviceList ->
                    [ "devices" ]

                Realm (ShowDevice deviceId) ->
                    [ "devices", deviceId ]
    in
    "/" ++ String.join "/" pieces


parseToken : Maybe String -> Maybe String
parseToken maybeFragment =
    case maybeFragment of
        Nothing ->
            Nothing

        Just hash ->
            if String.isEmpty hash then
                Nothing

            else
                String.split "&" hash
                    |> List.filter (String.contains "access_token")
                    |> List.head
                    |> Maybe.map (String.split "=")
                    |> Maybe.map List.reverse
                    |> Maybe.andThen List.head
