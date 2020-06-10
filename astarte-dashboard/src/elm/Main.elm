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
import Html.Attributes exposing (class, classList, href, src, style)
import Icons exposing (Icon)
import Json.Decode as Decode exposing (Value, at, string)
import Json.Encode as Encode
import ListUtils exposing (addWhen)
import Page.Device as Device
import Page.DeviceData as DeviceData
import Page.InterfaceBuilder as InterfaceBuilder
import Page.Interfaces as Interfaces
import Page.Login as Login
import Page.ReactInit as ReactInit
import Page.RealmSettings as RealmSettings
import Page.TriggerBuilder as TriggerBuilder
import Page.Triggers as Triggers
import Ports
import Route exposing (RealmRoute, Route)
import Task
import Time exposing (Posix)
import Types.Config as Config exposing (Config)
import Types.ExternalMessage exposing (ExternalMsg(..))
import Types.FlashMessage as FlashMessage exposing (FlashMessage, Severity)
import Types.Session as Session exposing (LoginStatus(..), LoginType(..), Session)
import Url exposing (Url)
import Url.Builder


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
                |> processRoute configFromJavascript initialSession

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
    = Public PublicPage
    | Realm String RealmPage


type PublicPage
    = LoginPage Login.Model


type RealmPage
    = InterfacesPage Interfaces.Model
    | InterfaceBuilderPage InterfaceBuilder.Model
    | TriggersPage Triggers.Model
    | TriggerBuilderPage TriggerBuilder.Model
    | RealmSettingsPage RealmSettings.Model
    | DevicePage Device.Model
    | DeviceDataPage DeviceData.Model
    | ReactInitPage ReactPageCategory


type ReactPageCategory
    = Home
    | Devices
    | Groups
    | Flow
    | Pipelines



-- UPDATE


type Msg
    = Ignore
    | NavbarMsg Navbar.State
    | NewUrl Url
    | UrlRequest UrlRequest
    | UpdateRelativeURL (Maybe String)
    | UpdateSession (Maybe Session)
    | LoginMsg Login.Msg
    | InterfacesMsg Interfaces.Msg
    | InterfaceBuilderMsg InterfaceBuilder.Msg
    | RealmSettingsMsg RealmSettings.Msg
    | TriggersMsg Triggers.Msg
    | TriggerBuilderMsg TriggerBuilder.Msg
    | DeviceMsg Device.Msg
    | DeviceDataMsg DeviceData.Msg
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
            ( { model | session = session }
            , Cmd.none
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
        Public publicPage ->
            updatePublicPage publicPage msg model

        Realm realm realmPage ->
            updateRealmPage realm realmPage msg model


updatePublicPage : PublicPage -> Msg -> Model -> ( Model, Cmd Msg )
updatePublicPage publicPage msg model =
    case ( msg, publicPage ) of
        ( LoginMsg subMsg, LoginPage subModel ) ->
            let
                ( newModel, pageCommand, externalMsg ) =
                    Login.update model.session subMsg subModel

                updatedPageModel =
                    { model | selectedPage = Public <| LoginPage newModel }

                ( updatedModel, newCommands ) =
                    handleExternalMessage updatedPageModel externalMsg
            in
            ( updatedModel
            , Cmd.batch
                [ newCommands
                , Cmd.map LoginMsg pageCommand
                ]
            )

        -- Ignore messages from not matching pages
        ( _, _ ) ->
            ( model
            , Cmd.none
            )


updateRealmPage : String -> RealmPage -> Msg -> Model -> ( Model, Cmd Msg )
updateRealmPage realm realmPage msg model =
    let
        ( page, command, externalMsg ) =
            case ( msg, realmPage ) of
                ( InterfacesMsg subMsg, InterfacesPage subModel ) ->
                    updateRealmPageHelper realm (Interfaces.update model.session subMsg subModel) InterfacesMsg InterfacesPage

                ( InterfaceBuilderMsg subMsg, InterfaceBuilderPage subModel ) ->
                    updateRealmPageHelper realm (InterfaceBuilder.update model.session subMsg subModel) InterfaceBuilderMsg InterfaceBuilderPage

                ( RealmSettingsMsg subMsg, RealmSettingsPage subModel ) ->
                    updateRealmPageHelper realm (RealmSettings.update model.session subMsg subModel) RealmSettingsMsg RealmSettingsPage

                ( TriggersMsg subMsg, TriggersPage subModel ) ->
                    updateRealmPageHelper realm (Triggers.update model.session subMsg subModel) TriggersMsg TriggersPage

                ( TriggerBuilderMsg subMsg, TriggerBuilderPage subModel ) ->
                    updateRealmPageHelper realm (TriggerBuilder.update model.session subMsg subModel) TriggerBuilderMsg TriggerBuilderPage

                ( DeviceMsg subMsg, DevicePage subModel ) ->
                    updateRealmPageHelper realm (Device.update model.session subMsg subModel) DeviceMsg DevicePage

                ( DeviceDataMsg subMsg, DeviceDataPage subModel ) ->
                    updateRealmPageHelper realm (DeviceData.update model.session subMsg subModel) DeviceDataMsg DeviceDataPage

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
            setRoute model ( Just route, Nothing )

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
            -- already logged in
            initReactPage session Home "home" realmRoute

        Route.Home ->
            initReactPage session Home "home" realmRoute

        Route.Logout ->
            let
                ( page, _, updatedSession ) =
                    initLoginPage config session

                logoutPath =
                    case session.loginStatus of
                        LoggedIn (OAuthLogin authUrl) ->
                            Url.Builder.custom
                                (Url.Builder.CrossOrigin authUrl)
                                [ "logout" ]
                                [ Url.Builder.string "redirect_uri" session.hostUrl ]
                                Nothing

                        _ ->
                            Route.toString <| Route.RealmSelection (Just "token")
            in
            ( page
            , Cmd.batch
                [ Ports.storeSession Nothing
                , Browser.Navigation.load <| logoutPath
                ]
            , updatedSession
            )

        Route.RealmSettings ->
            initSettingsPage session session.apiConfig.realm

        Route.ListInterfaces ->
            initInterfacesPage session session.apiConfig.realm

        Route.NewInterface ->
            initInterfaceBuilderPage Nothing session session.apiConfig.realm

        Route.ShowInterface name major ->
            initInterfaceBuilderPage (Just ( name, major )) session session.apiConfig.realm

        Route.ListTriggers ->
            initTriggersPage session session.apiConfig.realm

        Route.NewTrigger ->
            initTriggerBuilderPage Nothing session session.apiConfig.realm

        Route.ShowTrigger name ->
            initTriggerBuilderPage (Just name) session session.apiConfig.realm

        Route.ShowDevice deviceId ->
            initDevicePage deviceId session session.apiConfig.realm

        Route.ShowDeviceData deviceId interfaceName ->
            initDeviceDataPage deviceId interfaceName session session.apiConfig.realm

        Route.DeviceList ->
            initReactPage session Devices "devices-list" realmRoute

        Route.RegisterDevice ->
            initReactPage session Devices "devices-register" realmRoute

        Route.GroupList ->
            initReactPage session Groups "group-list" realmRoute

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


initLoginPage : Config.Params -> Session -> ( Page, Cmd Msg, Session )
initLoginPage config session =
    let
        authType =
            case session.loginStatus of
                RequestLogin loginType ->
                    loginType

                _ ->
                    config.defaultAuth

        ( initialSubModel, initialPageCommand ) =
            Login.init config authType
    in
    ( Public (LoginPage initialSubModel)
    , Cmd.map LoginMsg initialPageCommand
    , session
    )


initInterfacesPage : Session -> String -> ( Page, Cmd Msg, Session )
initInterfacesPage session realm =
    let
        ( initialModel, initialCommand ) =
            Interfaces.init session
    in
    ( Realm realm (InterfacesPage initialModel)
    , Cmd.map InterfacesMsg initialCommand
    , session
    )


initInterfaceBuilderPage : Maybe ( String, Int ) -> Session -> String -> ( Page, Cmd Msg, Session )
initInterfaceBuilderPage maybeInterfaceId session realm =
    let
        pageMode =
            case maybeInterfaceId of
                Nothing ->
                    InterfaceBuilder.New

                Just ( name, major ) ->
                    InterfaceBuilder.Edit ( name, major )

        ( initialModel, initialCommand ) =
            InterfaceBuilder.init pageMode session
    in
    ( Realm realm (InterfaceBuilderPage initialModel)
    , Cmd.map InterfaceBuilderMsg initialCommand
    , session
    )


initTriggersPage : Session -> String -> ( Page, Cmd Msg, Session )
initTriggersPage session realm =
    let
        ( initialModel, initialCommand ) =
            Triggers.init session
    in
    ( Realm realm (TriggersPage initialModel)
    , Cmd.map TriggersMsg initialCommand
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


initDevicePage : String -> Session -> String -> ( Page, Cmd Msg, Session )
initDevicePage deviceId session realm =
    let
        ( initialModel, initialCommand ) =
            Device.init session deviceId
    in
    ( Realm realm (DevicePage initialModel)
    , Cmd.map DeviceMsg initialCommand
    , session
    )


initDeviceDataPage : String -> String -> Session -> String -> ( Page, Cmd Msg, Session )
initDeviceDataPage deviceId interfaceName session realm =
    let
        ( initialModel, initialCommand ) =
            DeviceData.init session deviceId interfaceName
    in
    ( Realm realm (DeviceDataPage initialModel)
    , Cmd.map DeviceDataMsg initialCommand
    , session
    )


initSettingsPage : Session -> String -> ( Page, Cmd Msg, Session )
initSettingsPage session realm =
    let
        ( initialModel, initialCommand ) =
            RealmSettings.init session
    in
    ( Realm realm (RealmSettingsPage initialModel)
    , Cmd.map RealmSettingsMsg initialCommand
    , session
    )


initInterfaceEditorPage : Session -> ( Page, Cmd Msg, Session )
initInterfaceEditorPage session =
    let
        ( initialModel, initialCommand ) =
            InterfaceBuilder.init InterfaceBuilder.EditorOnly session
    in
    ( Realm "" (InterfaceBuilderPage initialModel)
    , Cmd.map InterfaceBuilderMsg initialCommand
    , session
    )



-- ROUTE PROCESSING


setRoute : Model -> ( Maybe Route, Maybe String ) -> ( Model, Cmd Msg )
setRoute model ( maybeRoute, maybeToken ) =
    let
        ( page, command, updatedSession ) =
            processRoute model.config model.session ( maybeRoute, maybeToken )
    in
    ( { model
        | selectedPage = page
        , session = updatedSession
      }
    , if isReactBased page then
        command

      else
        Cmd.batch [ command, Ports.unloadReactPage () ]
    )


processRoute : Config -> Session -> ( Maybe Route, Maybe String ) -> ( Page, Cmd Msg, Session )
processRoute config session ( maybeRoute, maybeToken ) =
    let
        loggedIn =
            Session.isLoggedIn session

        configParams =
            Config.getParams config
    in
    case ( configParams, maybeRoute ) of
        ( Nothing, Nothing ) ->
            initInterfaceEditorPage session

        ( _, Just Route.InterfaceEditor ) ->
            initInterfaceEditorPage session

        ( Nothing, _ ) ->
            initInterfaceEditorPage session

        ( Just params, Nothing ) ->
            if loggedIn then
                processRealmRoute maybeToken Route.Home params session

            else
                initLoginPage params session

        ( Just params, Just Route.Root ) ->
            if loggedIn then
                processRealmRoute maybeToken Route.Home params session

            else
                initLoginPage params session

        ( Just params, Just (Route.RealmSelection loginTypeString) ) ->
            if loggedIn then
                processRealmRoute maybeToken Route.ListInterfaces params session

            else
                let
                    loginStatus =
                        case loginTypeString of
                            Just "token" ->
                                RequestLogin Config.Token

                            _ ->
                                RequestLogin Config.OAuth

                    updatedSession =
                        { session | loginStatus = loginStatus }
                in
                initLoginPage params updatedSession

        ( Just params, Just (Route.Realm realmRoute) ) ->
            processRealmRoute maybeToken realmRoute params session


processRealmRoute : Maybe String -> RealmRoute -> Config.Params -> Session -> ( Page, Cmd Msg, Session )
processRealmRoute maybeToken realmRoute config session =
    let
        apiConfig =
            session.apiConfig
    in
    if String.isEmpty apiConfig.realm then
        case realmRoute of
            Route.Auth maybeRealm maybeOauthUrl ->
                attemptLogin maybeRealm maybeToken maybeOauthUrl config session

            _ ->
                -- not authorized
                initLoginPage config session

    else
        case maybeToken of
            Just token ->
                -- update token
                let
                    sessionWithUpdatedToken =
                        session
                            |> Session.setToken token

                    ( page, command, updatedSession ) =
                        pageInit realmRoute config sessionWithUpdatedToken
                in
                ( page
                , Cmd.batch [ storeSession updatedSession, command ]
                , updatedSession
                )

            Nothing ->
                -- access granted
                pageInit realmRoute config session


attemptLogin : Maybe String -> Maybe String -> Maybe String -> Config.Params -> Session -> ( Page, Cmd Msg, Session )
attemptLogin maybeRealm maybeToken maybeOauthUrl config session =
    let
        apiConfig =
            session.apiConfig
    in
    case ( maybeRealm, maybeToken ) of
        ( Just realm, Just token ) ->
            -- login into realm
            let
                updatedApiConfig =
                    { apiConfig
                        | realm = realm
                        , token = token
                    }

                loginType =
                    case maybeOauthUrl of
                        Nothing ->
                            Session.TokenLogin

                        Just url ->
                            Session.OAuthLogin url

                sessionWithCredentials =
                    { session
                        | loginStatus = LoggedIn loginType
                        , apiConfig = updatedApiConfig
                    }

                ( page, command, updatedSession ) =
                    pageInit Route.Home config sessionWithCredentials
            in
            ( page
            , Cmd.batch [ storeSession updatedSession, command ]
            , updatedSession
            )

        _ ->
            -- missing parameters
            initLoginPage config session



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        ( showNavbar, realmName ) =
            case model.selectedPage of
                Public (LoginPage _) ->
                    ( False, "" )

                Realm realm _ ->
                    ( True, realm )
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
                        , Col.attrs [ class "nav-col" ]
                        ]

                     else
                        [ Col.attrs [ Display.none ] ]
                    )
                    [ renderNavbar model realmName ]
                , Grid.col
                    [ Col.attrs [ class "main-content", Spacing.p3 ] ]
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
            Route.InterfaceEditor
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
      , renderNavbarLink
            "Realm settings"
            Icons.Settings
            (isSettingsRelated selectedPage)
            (Route.Realm Route.RealmSettings)

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
        ]

      else
        []

    -- General
    , [ renderNavbarSeparator
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
        |> Html.nav [ class "nav navbar-dark", Flex.col ]


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
        componentsHealth =
            [ ( "AppEngine", appEngineHealth )
            , ( "Realm Management", realmManagementHealth )
            , ( "Pairing", pairingHealth )
            , ( "Flow", flowHealth )
            ]
    in
    Html.div
        [ class "nav-status nav-item", Spacing.pl4 ]
        [ Html.div [] [ Html.b [] [ Html.text "Realm" ] ]
        , Html.p [] [ Html.text realm ]
        , Html.div [] [ Html.b [] [ Html.text "API Status" ] ]
        , Html.div []
            (List.filterMap healthItem componentsHealth)
        ]


healthItem : ( String, Maybe Bool ) -> Maybe (Html Msg)
healthItem ( label, maybeHealthy ) =
    Maybe.map (healthItemHelper label) maybeHealthy


healthItemHelper : String -> Bool -> Html Msg
healthItemHelper label healthy =
    Html.div [ Spacing.my1 ]
        (if healthy then
            [ Icons.render Icons.FullCircle [ Spacing.mr2, class "color-green" ]
            , Html.text label
            ]

         else
            [ Icons.render Icons.FullCircle [ Spacing.mr2, class "color-red" ]
            , Html.text label
            ]
        )


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
        Realm _ (InterfacesPage _) ->
            True

        Realm _ (InterfaceBuilderPage _) ->
            True

        _ ->
            False


isTriggersRelated : Page -> Bool
isTriggersRelated page =
    case page of
        Realm _ (TriggersPage _) ->
            True

        Realm _ (TriggerBuilderPage _) ->
            True

        _ ->
            False


isSettingsRelated : Page -> Bool
isSettingsRelated page =
    case page of
        Realm _ (RealmSettingsPage _) ->
            True

        _ ->
            False


isDeviceRelated : Page -> Bool
isDeviceRelated page =
    case page of
        Realm _ (DevicePage _) ->
            True

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


isReactBased : Page -> Bool
isReactBased page =
    case page of
        Realm _ (ReactInitPage _) ->
            True

        _ ->
            False


renderPage : Model -> Page -> Html Msg
renderPage model page =
    case page of
        Public publicPage ->
            renderPublicPage model.flashMessages publicPage

        Realm _ realmPage ->
            renderProtectedPage model.flashMessages realmPage


renderPublicPage : List FlashMessage -> PublicPage -> Html Msg
renderPublicPage flashMessages page =
    case page of
        LoginPage submodel ->
            Login.view submodel flashMessages
                |> Html.map LoginMsg


renderProtectedPage : List FlashMessage -> RealmPage -> Html Msg
renderProtectedPage flashMessages page =
    case page of
        InterfacesPage submodel ->
            Interfaces.view submodel flashMessages
                |> Html.map InterfacesMsg

        InterfaceBuilderPage submodel ->
            InterfaceBuilder.view submodel flashMessages
                |> Html.map InterfaceBuilderMsg

        TriggersPage submodel ->
            Triggers.view submodel flashMessages
                |> Html.map TriggersMsg

        RealmSettingsPage submodel ->
            RealmSettings.view submodel flashMessages
                |> Html.map RealmSettingsMsg

        TriggerBuilderPage submodel ->
            TriggerBuilder.view submodel flashMessages
                |> Html.map TriggerBuilderMsg

        DevicePage submodel ->
            Device.view submodel flashMessages
                |> Html.map DeviceMsg

        DeviceDataPage submodel ->
            DeviceData.view submodel flashMessages
                |> Html.map DeviceDataMsg

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
        Public (LoginPage submodel) ->
            Sub.map LoginMsg <| Login.subscriptions submodel

        Realm _ (InterfaceBuilderPage submodel) ->
            Sub.map InterfaceBuilderMsg <| InterfaceBuilder.subscriptions submodel

        Realm _ (InterfacesPage submodel) ->
            Sub.map InterfacesMsg <| Interfaces.subscriptions submodel

        Realm _ (TriggerBuilderPage submodel) ->
            Sub.map TriggerBuilderMsg <| TriggerBuilder.subscriptions submodel

        Realm _ (TriggersPage submodel) ->
            Sub.map TriggersMsg <| Triggers.subscriptions submodel

        Realm _ (DevicePage submodel) ->
            Sub.map DeviceMsg <| Device.subscriptions submodel

        Realm _ (DeviceDataPage submodel) ->
            Sub.map DeviceDataMsg <| DeviceData.subscriptions submodel

        Realm _ (RealmSettingsPage submodel) ->
            Sub.map RealmSettingsMsg <| RealmSettings.subscriptions submodel

        _ ->
            Sub.none


sessionChange : Sub (Maybe Session)
sessionChange =
    Ports.onSessionChange (Decode.decodeValue Session.decoder >> Result.toMaybe)


storeSession : Session -> Cmd msg
storeSession session =
    Session.encode session
        |> Encode.encode 0
        |> Just
        |> Ports.storeSession


pageRequestedFromJS : Sub (Maybe String)
pageRequestedFromJS =
    Ports.onPageRequested (Decode.decodeValue Decode.string >> Result.toMaybe)
