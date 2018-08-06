module Route exposing (..)

import Navigation exposing (Location)
import UrlParser as Url exposing (..)


-- ROUTING --


type Route
    = Root
    | RealmSelection (Maybe String)
    | Realm RealmRoute


type RealmRoute
    = Auth (Maybe String) (Maybe String)
    | Logout
    | RealmSettings
    | ListInterfaces
    | NewInterface
    | ShowInterface String Int
    | ListTriggers
    | NewTrigger
    | ShowTrigger String


route : Parser (Route -> a) a
route =
    oneOf
        [ Url.map Root (s "")
        , Url.map RealmSelection (s "login" <?> stringParam "type")
        , Url.map Realm (realmRoute)
        ]


realmRoute : Parser (RealmRoute -> a) a
realmRoute =
    oneOf
        [ Url.map Auth (s "auth" <?> stringParam "realm" <?> stringParam "authUrl")
        , Url.map Logout (s "logout")
        , Url.map RealmSettings (s "settings")
        , Url.map ListInterfaces (s "interfaces")
        , Url.map NewInterface (s "interfaces" </> s "new")
        , Url.map ShowInterface (s "interfaces" </> string </> int)
        , Url.map ListTriggers (s "triggers")
        , Url.map NewTrigger (s "triggers" </> s "new")
        , Url.map ShowTrigger (s "triggers" </> string)
        ]


fromLocation : Location -> ( Maybe Route, Maybe String )
fromLocation location =
    ( parsePath route location
    , parseToken location.hash
    )


toString : Route -> String
toString route =
    let
        pieces =
            case route of
                Root ->
                    [ "" ]

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

                Realm Logout ->
                    [ "logout" ]

                Realm RealmSettings ->
                    [ "settings" ]

                Realm ListInterfaces ->
                    [ "interfaces" ]

                Realm NewInterface ->
                    [ "interfaces", "new" ]

                Realm (ShowInterface name major) ->
                    [ "interfaces", name, Basics.toString major ]

                Realm ListTriggers ->
                    [ "triggers" ]

                Realm NewTrigger ->
                    [ "triggers", "new" ]

                Realm (ShowTrigger name) ->
                    [ "triggers", name ]
    in
        "/" ++ String.join "/" pieces


parseToken : String -> Maybe String
parseToken hash =
    if String.isEmpty hash then
        Nothing
    else
        String.split "&" hash
            |> List.filter (String.contains "access_token")
            |> List.head
            |> Maybe.map (String.split "=")
            |> Maybe.map List.reverse
            |> Maybe.map List.head
            |> Maybe.withDefault Nothing
