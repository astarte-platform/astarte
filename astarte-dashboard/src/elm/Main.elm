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


module Main exposing (main)

import Assets
import AstarteApi
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Navbar as Navbar
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Size as Size
import Bootstrap.Utilities.Spacing as Spacing
import Browser exposing (UrlRequest(..))
import Browser.Navigation
import Html exposing (Html, a, div, hr, img, li, p, small, span, text, ul)
import Html.Attributes exposing (id, class, classList, href, src, style)
import Icons exposing (Icon)
import Json.Decode as Decode exposing (Value, at, string)
import ListUtils exposing (addWhen)
import Page.ReactInit as ReactInit
import Page.TriggerBuilder as TriggerBuilder
import Ports
import Route exposing (RealmRoute, Route)
import Task
import Time exposing (Posix)
import Types.Config as Config exposing (Config)
import Types.ExternalMessage exposing (ExternalMsg(..))
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.Session as Session exposing (LoginStatus(..), LoginType(..), Session)
import Url exposing (Url)


main : Program Value Model Msg
main =
    Browser.application
        { init = init
        , onUrlChange = NewUrl
        , onUrlRequest = UrlRequest
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { navigationKey : Browser.Navigation.Key
    , selectedPage : Page
    , flashMessages : List FlashMessage
    , messageCounter : Int
    , session : Session
    , navbarState : Navbar.State
    , config : Config
    , appEngineApiHealth : Maybe Bool
    , realmManagementApiHealth : Maybe Bool
    , pairingApiHealth : Maybe Bool
    , flowApiHealth : Maybe Bool
    }


init : Value -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init jsParam location key =
    let
        hostUrl =
            { location
                | path = "/"
                , query = Nothing
                , fragment = Nothing
            }
                |> Url.toString

        ( navbarState, navbarCmd ) =
            Navbar.initialState NavbarMsg

        configFromJavascript =
            Decode.decodeValue (at [ "config" ] Config.decoder) jsParam
                |> Result.toMaybe
                |> Maybe.withDefault Config.editorOnly

        previousSession =
            Decode.decodeValue (at [ "previousSession" ] string) jsParam
                |> Result.toMaybe
                |> Maybe.andThen (Decode.decodeString Session.decoder >> Result.toMaybe)

        initialSession =
            case previousSession of
                Nothing ->
                    initNewSession hostUrl configFromJavascript

                Just prevSession ->
                    { prevSession | hostUrl = hostUrl }

        ( initialPage, initialCommand, updatedSession ) =
            Route.fromUrl location
                |> processRoute key configFromJavascript initialSession

        initialModel =
            { navigationKey = key
            , selectedPage = initialPage
            , flashMessages = []
            , messageCounter = 0
            , session = updatedSession
            , navbarState = navbarState
            , config = configFromJavascript
            , appEngineApiHealth = Nothing
            , realmManagementApiHealth = Nothing
            , pairingApiHealth = Nothing
            , flowApiHealth = Nothing
            }

        healthChecks =
            case configFromJavascript of
                Config.EditorOnly ->
                    []

                Config.Standard params ->
                    if params.enableFlowPreview then
                        [ AstarteApi.appEngineApiHealth updatedSession.apiConfig AppEngineHealthCheckDone
                        , AstarteApi.realmManagementApiHealth updatedSession.apiConfig RealmManagementHealthCheckDone
                        , AstarteApi.pairingApiHealth updatedSession.apiConfig PairingHealthCheckDone
                        , AstarteApi.flowApiHealth updatedSession.apiConfig FlowHealthCheckDone
                        ]

                    else
                        [ AstarteApi.appEngineApiHealth updatedSession.apiConfig AppEngineHealthCheckDone
                        , AstarteApi.realmManagementApiHealth updatedSession.apiConfig RealmManagementHealthCheckDone
                        , AstarteApi.pairingApiHealth updatedSession.apiConfig PairingHealthCheckDone
                        ]
    in
    ( initialModel
    , [ [ navbarCmd
        , initialCommand
        ]
      , healthChecks
      ]
        |> List.concat
        |> Cmd.batch
    )


initNewSession : String -> Config -> Session
initNewSession hostUrl config =
    let
        apiConfig =
            case Config.getParams config of
                Just params ->
                    { secureConnection = params.secureConnection
                    , realmManagementUrl = params.realmManagementApiUrl
                    , appengineUrl = params.appengineApiUrl
                    , pairingUrl = params.pairingApiUrl
                    , flowUrl = params.flowApiUrl
                    , realm = ""
                    , token = ""
                    , enableFlowPreview = params.enableFlowPreview
                    }

                Nothing ->
                    { secureConnection = False
                    , realmManagementUrl = ""
                    , appengineUrl = ""
                    , pairingUrl = ""
                    , flowUrl = ""
                    , realm = ""
                    , token = ""
                    , enableFlowPreview = False
                    }
    in
    { hostUrl = hostUrl
    , loginStatus = NotLoggedIn
    , apiConfig = apiConfig
    }


type Page
    = LoginPage
    | Realm String RealmPage


type RealmPage
    = TriggerBuilderPage TriggerBuilder.Model
    | ReactInitPage ReactPageCategory


type ReactPageCategory
    = Home
    | Triggers
    | Interfaces
    | Devices
    | Groups
    | Flow
    | Pipelines
    | Blocks
    | RealmSettings



-- UPDATE


type Msg
    = Ignore
    | NavbarMsg Navbar.State
    | NewUrl Url
    | UrlRequest UrlRequest
    | UpdateRelativeURL (Maybe String)
    | UpdateSession (Maybe Session)
    | TriggerBuilderMsg TriggerBuilder.Msg
    | NewFlashMessage Severity String (List String) Posix
    | ClearOldFlashMessages Posix
    | AppEngineHealthCheckDone (Result AstarteApi.Error Bool)
    | RealmManagementHealthCheckDone (Result AstarteApi.Error Bool)
    | PairingHealthCheckDone (Result AstarteApi.Error Bool)
    | FlowHealthCheckDone (Result AstarteApi.Error Bool)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Ignore ->
            ( model
            , Cmd.none
            )

        NavbarMsg state ->
            ( { model | navbarState = state }
            , Cmd.none
            )

        NewUrl url ->
            setRoute model <| Route.fromUrl url

        UrlRequest requestUrl ->
            case requestUrl of
                Internal internalUrl ->
                    ( model
                    , Browser.Navigation.pushUrl model.navigationKey <| Url.toString internalUrl
                    )

                External externalUrl ->
                    ( model
                    , Browser.Navigation.load externalUrl
                    )

        UpdateRelativeURL (Just relativeURL) ->
            ( model
            , Browser.Navigation.pushUrl model.navigationKey relativeURL
            )

        UpdateRelativeURL Nothing ->
            ( model
            , Cmd.none
            )

        UpdateSession Nothing ->
            let
                newSession =
                    initNewSession model.session.hostUrl model.config
            in
            ( { model | session = newSession }
            , Cmd.none
            )

        UpdateSession (Just session) ->
            let
                apiConfig =
                    session.apiConfig

                healthChecks =
                    if apiConfig.enableFlowPreview then
                        [ AstarteApi.appEngineApiHealth apiConfig AppEngineHealthCheckDone
                        , AstarteApi.realmManagementApiHealth apiConfig RealmManagementHealthCheckDone
                        , AstarteApi.pairingApiHealth apiConfig PairingHealthCheckDone
                        , AstarteApi.flowApiHealth apiConfig FlowHealthCheckDone
                        ]

                    else
                        [ AstarteApi.appEngineApiHealth apiConfig AppEngineHealthCheckDone
                        , AstarteApi.realmManagementApiHealth apiConfig RealmManagementHealthCheckDone
                        , AstarteApi.pairingApiHealth apiConfig PairingHealthCheckDone
                        ]
            in
            ( { model | session = session }
            , Cmd.batch healthChecks
            )

        NewFlashMessage severity message details createdAt ->
            let
                displayTime =
                    case severity of
                        FlashMessage.Notice ->
                            3 * 1000

                        FlashMessage.Warning ->
                            6 * 1000

                        FlashMessage.Error ->
                            10 * 1000

                        FlashMessage.Fatal ->
                            24 * 60 * 60 * 1000

                dismissAt =
                    createdAt
                        |> Time.posixToMillis
                        |> (+) displayTime
                        |> Time.millisToPosix

                newFlashMessage =
                    FlashMessage.new model.messageCounter message details severity dismissAt
            in
            ( { model
                | flashMessages = newFlashMessage :: model.flashMessages
                , messageCounter = model.messageCounter + 1
              }
            , Cmd.none
            )

        ClearOldFlashMessages now ->
            let
                filteredMessages =
                    List.filter
                        (\m -> Time.posixToMillis m.dismissAt > Time.posixToMillis now)
                        model.flashMessages
            in
            ( { model | flashMessages = filteredMessages }
            , Cmd.none
            )

        AppEngineHealthCheckDone (Ok healty) ->
            ( { model | appEngineApiHealth = Just healty }
            , Cmd.none
            )

        RealmManagementHealthCheckDone (Ok healty) ->
            ( { model | realmManagementApiHealth = Just healty }
            , Cmd.none
            )

        PairingHealthCheckDone (Ok healty) ->
            ( { model | pairingApiHealth = Just healty }
            , Cmd.none
            )

        FlowHealthCheckDone (Ok healty) ->
            ( { model | flowApiHealth = Just healty }
            , Cmd.none
            )

        -- Page specific messages
        _ ->
            updatePage model.selectedPage msg model


updatePage : Page -> Msg -> Model -> ( Model, Cmd Msg )
updatePage page msg model =
    case page of
        LoginPage ->
            -- LoginPage is handled in Elm, nothing to update
            ( model
            , Cmd.none
            )

        Realm realm realmPage ->
            updateRealmPage realm realmPage msg model


updateRealmPage : String -> RealmPage -> Msg -> Model -> ( Model, Cmd Msg )
updateRealmPage realm realmPage msg model =
    let
        ( page, command, externalMsg ) =
            case ( msg, realmPage ) of
                ( TriggerBuilderMsg subMsg, TriggerBuilderPage subModel ) ->
                    updateRealmPageHelper realm (TriggerBuilder.update model.session subMsg subModel) TriggerBuilderMsg TriggerBuilderPage


                -- Ignore messages from not matching pages
                ( _, _ ) ->
                    ( model.selectedPage, Cmd.none, Noop )

        updatedPageModel =
            { model | selectedPage = page }

        ( updatedModel, newCommands ) =
            handleExternalMessage updatedPageModel externalMsg
    in
    ( updatedModel
    , Cmd.batch [ newCommands, command ]
    )


updateRealmPageHelper : String -> ( a, Cmd b, ExternalMsg ) -> (b -> Msg) -> (a -> RealmPage) -> ( Page, Cmd Msg, ExternalMsg )
updateRealmPageHelper realm ( newSubModel, pageCommand, msg ) subMsgTagger pageTagger =
    ( Realm realm (pageTagger newSubModel)
    , Cmd.map subMsgTagger pageCommand
    , msg
    )


handleExternalMessage : Model -> ExternalMsg -> ( Model, Cmd Msg )
handleExternalMessage model externalMsg =
    case externalMsg of
        Noop ->
            ( model
            , Cmd.none
            )

        RequestRoute route ->
            ( model
            , Browser.Navigation.pushUrl model.navigationKey <| Route.toString route
            )

        RequestRouteWithToken route fragment ->
            setRoute model ( Just route, Just fragment )

        AddFlashMessage severity message details ->
            ( model
            , Task.perform (NewFlashMessage severity message details) Time.now
            )

        DismissFlashMessage messageId ->
            ( { model | flashMessages = List.filter (\message -> message.id /= messageId) model.flashMessages }
            , Cmd.none
            )

        Batch messages ->
            List.foldl handleBatchedMessages ( model, Cmd.none ) messages


handleBatchedMessages : ExternalMsg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
handleBatchedMessages message ( model, cmd ) =
    let
        ( updatedModel, newCommands ) =
            handleExternalMessage model message
    in
    ( updatedModel
    , Cmd.batch [ cmd, newCommands ]
    )


pageInit : RealmRoute -> Config.Params -> Session -> ( Page, Cmd Msg, Session )
pageInit realmRoute config session =
    case realmRoute of
        Route.Auth _ _ ->
            initReactPage session Home "auth" realmRoute

        Route.Home ->
            initReactPage session Home "home" realmRoute

        Route.Logout ->
            initReactPage session Home "logout" realmRoute

        Route.RealmSettings ->
            initReactPage session RealmSettings "realm-settings" realmRoute

        Route.ListInterfaces ->
            initReactPage session Interfaces "interfaces" realmRoute

        Route.NewInterface ->
            initReactPage session Interfaces "interface-new" realmRoute

        Route.ShowInterface name major ->
            initReactPage session Interfaces "interface-edit" realmRoute

        Route.ListTriggers ->
            initReactPage session Triggers "trigger-list" realmRoute

        Route.NewTrigger ->
            initTriggerBuilderPage Nothing session session.apiConfig.realm

        Route.ShowTrigger name ->
            initTriggerBuilderPage (Just name) session session.apiConfig.realm

        Route.ShowDevice deviceId ->
            initReactPage session Devices "device-status" realmRoute

        Route.ShowDeviceData deviceId interfaceName ->
            initReactPage session Devices "device-data" realmRoute

        Route.DeviceList ->
            initReactPage session Devices "devices-list" realmRoute

        Route.RegisterDevice _ ->
            initReactPage session Devices "devices-register" realmRoute

        Route.GroupList ->
            initReactPage session Groups "group-list" realmRoute

        Route.NewGroup ->
            initReactPage session Groups "new-group" realmRoute

        Route.GroupDevices groupName ->
            initReactPage session Groups "group-devices" realmRoute

        Route.FlowInstances ->
            initReactPage session Flow "flow-instances" realmRoute

        Route.FlowConfigure _ ->
            initReactPage session Flow "flow-configure" realmRoute

        Route.FlowDetails _ ->
            initReactPage session Flow "flow-details" realmRoute

        Route.PipelineList ->
            initReactPage session Pipelines "pipeline-list" realmRoute

        Route.NewPipeline ->
            initReactPage session Pipelines "pipeline-new" realmRoute

        Route.PipelineShowSource _ ->
            initReactPage session Pipelines "pipeline-show-source" realmRoute

        Route.BlockList ->
            initReactPage session Blocks "block-list" realmRoute

        Route.NewBlock ->
            initReactPage session Blocks "block-new" realmRoute

        Route.BlockShowSource _ ->
            initReactPage session Blocks "block-show-source" realmRoute


initReactPage : Session -> ReactPageCategory -> String -> RealmRoute -> ( Page, Cmd Msg, Session )
initReactPage session category pageName pageRoute =
    let
        realm =
            session.apiConfig.realm
    in
    ( Realm realm <| ReactInitPage category
    , Cmd.map (\a -> Ignore) (ReactInit.init session pageName <| Route.Realm pageRoute)
    , session
    )


initLoginPage : Session -> ( Page, Cmd Msg, Session )
initLoginPage session =
    ( LoginPage
    , Cmd.map (\a -> Ignore) (ReactInit.init session "login" <| Route.RealmSelection Nothing)
    , session
    )


initTriggerBuilderPage : Maybe String -> Session -> String -> ( Page, Cmd Msg, Session )
initTriggerBuilderPage maybeTriggerName session realm =
    let
        ( initialModel, initialCommand ) =
            TriggerBuilder.init maybeTriggerName session realm
    in
    ( Realm realm (TriggerBuilderPage initialModel)
    , Cmd.map TriggerBuilderMsg initialCommand
    , session
    )



-- ROUTE PROCESSING


setRoute : Model -> ( Maybe Route, Maybe String ) -> ( Model, Cmd Msg )
setRoute model ( maybeRoute, maybeToken ) =
    let
        ( page, command, updatedSession ) =
            processRoute model.navigationKey model.config model.session ( maybeRoute, maybeToken )

        reactEnvCommand =
            if isReactBased page then
                Cmd.none

            else
                Ports.unloadReactPage ()
    in
    ( { model
        | selectedPage = page
        , session = updatedSession
      }
    , Cmd.batch
        [ command
        , reactEnvCommand
        ]
    )


processRoute : Browser.Navigation.Key -> Config -> Session -> ( Maybe Route, Maybe String ) -> ( Page, Cmd Msg, Session )
processRoute key config session ( maybeRoute, maybeToken ) =
    case ( Config.getParams config, maybeRoute ) of
        ( Nothing, _ ) ->
            initReactPage session Home "home" Route.Home

        ( Just params, Nothing ) ->
            -- unknown route
            if Session.isLoggedIn session then
                initReactPage session Home "home" Route.Home
                    |> attachCommand (replaceWithHomeUrlCmd key)

            else
                initLoginPage session
                    |> attachCommand (replaceWithLoginUrlCmd key)

        ( Just params, Just route ) ->
            handleKnownRoute key params session route maybeToken


handleKnownRoute : Browser.Navigation.Key -> Config.Params -> Session -> Route -> Maybe String -> ( Page, Cmd Msg, Session )
handleKnownRoute key params session route maybeToken =
    if Session.isLoggedIn session then
        case route of
            Route.Root ->
                initReactPage session Home "home" Route.Home

            Route.RealmSelection loginTypeString ->
                initReactPage session Home "home" Route.Home
                    |> attachCommand (replaceWithHomeUrlCmd key)

            Route.Realm realmRoute ->
                pageInit realmRoute params session

    else
        case route of
            Route.RealmSelection loginTypeString ->
                initLoginPage session

            Route.Realm (Route.Auth a b) ->
                pageInit (Route.Auth a b) params session

            _ ->
                initLoginPage session
                    |> attachCommand (replaceWithLoginUrlCmd key)


replaceWithHomeUrlCmd : Browser.Navigation.Key -> Cmd Msg
replaceWithHomeUrlCmd key =
    Browser.Navigation.replaceUrl key <| Route.toString (Route.Realm Route.Home)


replaceWithLoginUrlCmd : Browser.Navigation.Key -> Cmd Msg
replaceWithLoginUrlCmd key =
    Browser.Navigation.replaceUrl key <| Route.toString (Route.RealmSelection Nothing)


attachCommand : Cmd Msg -> ( Page, Cmd Msg, Session ) -> ( Page, Cmd Msg, Session )
attachCommand newCmd ( page, cmd, session ) =
    ( page
    , Cmd.batch
        [ newCmd
        , cmd
        ]
    , session
    )



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        realmName =
            model.session.apiConfig.realm

        showNavbar =
            Session.isLoggedIn model.session || model.config == Config.EditorOnly
    in
    { title = "Astarte - Dashboard"
    , body =
        [ Grid.containerFluid
            [ Spacing.px0 ]
            [ Grid.row
                [ Row.attrs [ class "no-gutters" ] ]
                [ Grid.col
                    (if showNavbar then
                        [ Col.xsAuto
                        , Col.attrs [ id "main-navbar", class "nav-col" ]
                        ]

                     else
                        [ Col.attrs [ id "main-navbar", Display.none ] ]
                    )
                    [ renderNavbar model realmName ]
                , Grid.col
                    [ Col.attrs [ class "main-content vh-100 overflow-auto" ] ]
                    [ renderPage model model.selectedPage ]
                ]
            ]
        ]
    }



{-
   as for elm-bootstrap 5.1.0, vertical navbars are not supported.
   This is the implementation using bootstrap css classes
-}


renderNavbar : Model -> String -> Html Msg
renderNavbar model realm =
    case model.config of
        Config.EditorOnly ->
            editorNavBar

        Config.Standard config ->
            standardNavBar
                model.selectedPage
                realm
                model.appEngineApiHealth
                model.realmManagementApiHealth
                model.pairingApiHealth
                model.flowApiHealth
                config.enableFlowPreview


editorNavBar : Html Msg
editorNavBar =
    Html.nav [ class "nav", Flex.col ]
        [ dashboardBrand
        , renderNavbarLink
            "Interface Editor"
            Icons.Interface
            False
            Route.Root
        ]


standardNavBar : Page -> String -> Maybe Bool -> Maybe Bool -> Maybe Bool -> Maybe Bool -> Bool -> Html Msg
standardNavBar selectedPage realmName aeApiHealth rmApiHealth pApiHealth fApiHealth enableFlowPreview =
    [ [ dashboardBrand
      , renderNavbarLink
            "Home"
            Icons.Home
            (isHomeRelated selectedPage)
            (Route.Realm Route.Home)

      -- Realm Management
      , renderNavbarSeparator
      , renderNavbarLink
            "Interfaces"
            Icons.Interface
            (isInterfacesRelated selectedPage)
            (Route.Realm Route.ListInterfaces)
      , renderNavbarLink
            "Triggers"
            Icons.Trigger
            (isTriggersRelated selectedPage)
            (Route.Realm Route.ListTriggers)

      -- AppEngine
      , renderNavbarSeparator
      , renderNavbarLink
            "Devices"
            Icons.Device
            (isDeviceRelated selectedPage)
            (Route.Realm Route.DeviceList)
      , renderNavbarLink
            "Groups"
            Icons.Group
            (isGroupRelated selectedPage)
            (Route.Realm Route.GroupList)
      ]

    -- Flow
    , if enableFlowPreview then
        [ renderNavbarSeparator
        , renderNavbarLink
            "Flows"
            Icons.Flow
            (isFlowRelated selectedPage)
            (Route.Realm Route.FlowInstances)
        , renderNavbarLink
            "Pipelines"
            Icons.Pipeline
            (isPipelinesRelated selectedPage)
            (Route.Realm Route.PipelineList)
        , renderNavbarLink
            "Blocks"
            Icons.Block
            (isBlocksRelated selectedPage)
            (Route.Realm Route.BlockList)
        ]

      else
        []

    -- General
    , [ renderNavbarSeparator
      , renderNavbarLink
            "Realm settings"
            Icons.Settings
            (isSettingsRelated selectedPage)
            (Route.Realm Route.RealmSettings)
      , renderNavbarSeparator
      , renderStatusRow realmName aeApiHealth rmApiHealth pApiHealth fApiHealth

      -- Common
      , renderNavbarSeparator
      , renderNavbarLink
            "Logout"
            Icons.Logout
            False
            (Route.Realm Route.Logout)
      ]
    ]
        |> List.concat
        |> Html.nav [ class "nav navbar-dark flex-nowrap vh-100 overflow-auto", Flex.col ]


dashboardBrand : Html Msg
dashboardBrand =
    Html.a
        [ href <| Route.toString (Route.Realm Route.Home)
        , class "nav-brand"
        , Spacing.mb3
        ]
        [ Html.img
            [ src <| Assets.path Assets.dashboardIcon
            , class "brand-logo"
            ]
            []
        ]


renderStatusRow : String -> Maybe Bool -> Maybe Bool -> Maybe Bool -> Maybe Bool -> Html Msg
renderStatusRow realm appEngineHealth realmManagementHealth pairingHealth flowHealth =
    let
        errorCount =
            [ appEngineHealth, realmManagementHealth, pairingHealth, flowHealth ]
                |> List.foldr
                    (\serviceOk errorcount ->
                        case serviceOk of
                            Just False ->
                                errorcount + 1

                            _ ->
                                errorcount
                    )
                    0
    in
    Html.div
        [ class "nav-status nav-item", Spacing.pl4 ]
        [ Html.div [] [ Html.b [] [ Html.text "Realm" ] ]
        , Html.p [] [ Html.text realm ]
        , Html.div [] [ Html.b [] [ Html.text "API Status" ] ]
        , if errorCount > 0 then
            Html.p [ Spacing.my1 ]
                [ Icons.render Icons.FullCircle [ Spacing.mr2, class "color-red" ]
                , Html.text "Degraded"
                ]

          else
            Html.p [ Spacing.my1 ]
                [ Icons.render Icons.FullCircle [ Spacing.mr2, class "color-green" ]
                , Html.text "Up and running"
                ]
        ]


renderNavbarLink : String -> Icon -> Bool -> Route -> Html Msg
renderNavbarLink name icon active route =
    Html.a
        [ classList
            [ ( "nav-link", True )
            , ( "active", active )
            ]
        , href <| Route.toString route
        ]
        [ Icons.render icon [ Spacing.mr2 ]
        , Html.text name
        ]


renderNavbarSeparator : Html Msg
renderNavbarSeparator =
    Html.div [ class "nav-item" ]
        [ Html.hr [] [] ]


isHomeRelated : Page -> Bool
isHomeRelated page =
    case page of
        Realm _ (ReactInitPage Home) ->
            True

        _ ->
            False


isInterfacesRelated : Page -> Bool
isInterfacesRelated page =
    case page of
        Realm _ (ReactInitPage Interfaces) ->
            True

        _ ->
            False


isTriggersRelated : Page -> Bool
isTriggersRelated page =
    case page of
        Realm _ (ReactInitPage Triggers) ->
            True

        Realm _ (TriggerBuilderPage _) ->
            True

        _ ->
            False


isSettingsRelated : Page -> Bool
isSettingsRelated page =
    case page of
        Realm _ (ReactInitPage RealmSettings) ->
            True

        _ ->
            False


isDeviceRelated : Page -> Bool
isDeviceRelated page =
    case page of
        Realm _ (ReactInitPage Devices) ->
            True

        _ ->
            False


isGroupRelated : Page -> Bool
isGroupRelated page =
    case page of
        Realm _ (ReactInitPage Groups) ->
            True

        _ ->
            False


isFlowRelated : Page -> Bool
isFlowRelated page =
    case page of
        Realm _ (ReactInitPage Flow) ->
            True

        _ ->
            False


isPipelinesRelated : Page -> Bool
isPipelinesRelated page =
    case page of
        Realm _ (ReactInitPage Pipelines) ->
            True

        _ ->
            False


isBlocksRelated : Page -> Bool
isBlocksRelated page =
    case page of
        Realm _ (ReactInitPage Blocks) ->
            True

        _ ->
            False


isReactBased : Page -> Bool
isReactBased page =
    case page of
        LoginPage ->
            True

        Realm _ (ReactInitPage _) ->
            True

        _ ->
            False


renderPage : Model -> Page -> Html Msg
renderPage model page =
    case page of
        LoginPage ->
            ReactInit.view model.flashMessages
                |> Html.map (\a -> Ignore)

        Realm _ realmPage ->
            renderProtectedPage model.flashMessages realmPage


renderProtectedPage : List FlashMessage -> RealmPage -> Html Msg
renderProtectedPage flashMessages page =
    case page of
        TriggerBuilderPage submodel ->
            TriggerBuilder.view submodel flashMessages
                |> Html.map TriggerBuilderMsg

        ReactInitPage _ ->
            ReactInit.view flashMessages
                |> Html.map (\a -> Ignore)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    [ Navbar.subscriptions model.navbarState NavbarMsg
    , Sub.map UpdateSession sessionChange
    , pageSubscriptions model.selectedPage
    , Sub.map UpdateRelativeURL pageRequestedFromJS
    ]
        |> addWhen (not <| List.isEmpty model.flashMessages) (Time.every 1000 ClearOldFlashMessages)
        |> Sub.batch


pageSubscriptions : Page -> Sub Msg
pageSubscriptions page =
    case page of
        Realm _ (TriggerBuilderPage submodel) ->
            Sub.map TriggerBuilderMsg <| TriggerBuilder.subscriptions submodel

        _ ->
            Sub.none


sessionChange : Sub (Maybe Session)
sessionChange =
    Ports.onSessionChange (Decode.decodeValue Session.decoder >> Result.toMaybe)


pageRequestedFromJS : Sub (Maybe String)
pageRequestedFromJS =
    Ports.onPageRequested (Decode.decodeValue Decode.string >> Result.toMaybe)
