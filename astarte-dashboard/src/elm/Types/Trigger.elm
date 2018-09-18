module Types.Trigger exposing (..)

import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode


-- Types

import Types.DataTrigger as DataTrigger exposing (DataTrigger)
import Types.DeviceTrigger as DeviceTrigger exposing (DeviceTrigger)


type alias Trigger =
    { name : String

    -- action
    , url : String
    , template : Template

    -- Simple triggers
    , simpleTrigger : SimpleTrigger
    }


empty : Trigger
empty =
    { name = ""
    , url = ""
    , template = NoTemplate
    , simpleTrigger = Data DataTrigger.empty
    }


type Template
    = NoTemplate
    | Mustache String


type SimpleTrigger
    = Data DataTrigger
    | Device DeviceTrigger



-- Setters


setName : String -> Trigger -> Trigger
setName name trigger =
    { trigger | name = name }


setUrl : String -> Trigger -> Trigger
setUrl url trigger =
    { trigger | url = url }


setTemplate : Template -> Trigger -> Trigger
setTemplate template trigger =
    { trigger | template = template }


setSimpleTrigger : SimpleTrigger -> Trigger -> Trigger
setSimpleTrigger simpleTrigger trigger =
    { trigger | simpleTrigger = simpleTrigger }



-- Encoding


encoder : Trigger -> Value
encoder t =
    Json.Encode.object
        [ ( "name", Json.Encode.string t.name )
        , ( "action"
          , Json.Encode.object
                ([ ( "http_post_url", Json.Encode.string t.url ) ]
                    ++ (templateEncoder t.template)
                )
          )
        , ( "simple_triggers"
          , Json.Encode.list
                [ simpleTriggerEncoder t.simpleTrigger ]
          )
        ]


templateEncoder : Template -> List ( String, Value )
templateEncoder template =
    case template of
        NoTemplate ->
            []

        Mustache mustacheTemplate ->
            [ ( "template_type", Json.Encode.string "mustache" )
            , ( "template", Json.Encode.string mustacheTemplate )
            ]


simpleTriggerEncoder : SimpleTrigger -> Value
simpleTriggerEncoder simpleTrigger =
    case simpleTrigger of
        Data dataTrigger ->
            DataTrigger.encoder dataTrigger

        Device deviceTrigger ->
            DeviceTrigger.encoder deviceTrigger



-- Decoding


decoder : Decoder Trigger
decoder =
    let
        toDecoder : String -> String -> Maybe String -> Maybe String -> SimpleTrigger -> Decoder Trigger
        toDecoder name url maybeTemplateType maybeTemplate simpleTrigger =
            case (stringsToTemplate maybeTemplateType maybeTemplate) of
                Ok template ->
                    Json.Decode.succeed <| Trigger name url template simpleTrigger

                Err err ->
                    Json.Decode.fail err
    in
        decode toDecoder
            |> required "name" string
            |> requiredAt [ "action", "http_post_url" ] string
            |> optionalAt [ "action", "template_type" ] (nullable string) Nothing
            |> optionalAt [ "action", "template" ] (nullable string) Nothing
            |> required "simple_triggers" (index 0 simpleTriggerDecoder)
            |> resolve


stringsToTemplate : Maybe String -> Maybe String -> Result String Template
stringsToTemplate maybeTemplateType maybeTemplate =
    case ( maybeTemplateType, maybeTemplate ) of
        ( Nothing, _ ) ->
            Ok NoTemplate

        ( Just "mustache", Just template ) ->
            Ok <| Mustache template

        ( Just "mustache", Nothing ) ->
            Err "Mustache requires a template"

        ( Just templateType, _ ) ->
            Err <| "Uknown template type: " ++ templateType


simpleTriggerDecoder : Decoder SimpleTrigger
simpleTriggerDecoder =
    field "type" string
        |> andThen
            (\str ->
                case str of
                    "data_trigger" ->
                        map Data DataTrigger.decoder

                    "device_trigger" ->
                        map Device DeviceTrigger.decoder

                    _ ->
                        Json.Decode.fail <| "Uknown trigger type " ++ str
            )



-- JsonHelpers


fromString : String -> Result String Trigger
fromString source =
    decodeString decoder source


toPrettySource : Trigger -> String
toPrettySource trigger =
    Json.Encode.encode 4 <| encoder trigger
