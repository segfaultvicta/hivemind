module Hivemind exposing (..)

import Html exposing (..)
import Html.Attributes exposing (class, href, id, property, selected, src, style, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as JD
import Json.Decode.Pipeline exposing (decode, hardcoded, optional, required)
import Json.Encode as JE
import Phoenix
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Push as Push
import Phoenix.Socket as Socket exposing (AbnormalClose, Socket)
import Time exposing (Time)


main : Program InitFlags Model Msg
main =
    Html.programWithFlags
        { init = init
        , view = view
        , subscriptions = subscriptions
        , update = update
        }


type alias Model =
    { loc : String
    , connectionStatus : ConnectionStatus
    , currentTime : Time
    , phone : Bool
    , socketUrl : String
    , username : String
    , user_sentiment : String
    , happy : Int
    , neutral : Int
    , sad : Int
    , blocks : List Block
    }


type alias Block =
    { username : String, sentiment : String }


type alias InitFlags =
    { loc : String
    , width : Int
    , socketUrl : String
    }


type ConnectionStatus
    = Connected
    | Disconnected
    | ScheduledReconnect { time : Time }


init : InitFlags -> ( Model, Cmd Msg )
init flags =
    ( { loc = flags.loc
      , connectionStatus = Disconnected
      , currentTime = 0
      , phone = flags.width < 600
      , socketUrl = flags.socketUrl
      , username = ""
      , user_sentiment = "neutral"
      , happy = 0
      , neutral = 100
      , sad = 0
      , blocks = []
      }
    , Cmd.none
    )



-- ACTION, UPDATE


type Msg
    = SocketClosedAbnormally AbnormalClose
    | ConnectionStatusChanged ConnectionStatus
    | Tick Time
    | InitChannel JD.Value
    | SelectSentiment String
    | HiveUpdate JD.Value
    | SentimentSelected JD.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SocketClosedAbnormally abnormalClose ->
            { model
                | connectionStatus =
                    ScheduledReconnect { time = roundDownToSecond (model.currentTime + abnormalClose.reconnectWait) }
            }
                ! []

        ConnectionStatusChanged status ->
            { model | connectionStatus = status } ! []

        Tick time ->
            { model | currentTime = time } ! []

        InitChannel payload ->
            case JD.decodeValue updateDecoder payload of
                Ok payloadContainer ->
                    { model
                        | username = payloadContainer.name
                        , happy = payloadContainer.happy
                        , neutral = payloadContainer.neutral
                        , sad = payloadContainer.sad
                        , blocks = payloadContainer.blocks
                    }
                        ! []

                Err err ->
                    let
                        _ =
                            Debug.log "initChannel payload error: " ( err, payload )
                    in
                        model ! []

        HiveUpdate payload ->
            case JD.decodeValue updateDecoder payload of
                Ok payloadContainer ->
                    { model
                        | happy = payloadContainer.happy
                        , neutral = payloadContainer.neutral
                        , sad = payloadContainer.sad
                        , blocks = payloadContainer.blocks
                    }
                        ! []

                Err err ->
                    let
                        _ =
                            Debug.log "hiveUpdate payload error: " ( err, payload )
                    in
                        model ! []

        SelectSentiment newSentiment ->
            let
                push =
                    Push.init ("room:" ++ model.loc) "sentiment"
                        |> Push.withPayload
                            (JE.object
                                [ ( "sentiment", JE.string newSentiment )
                                ]
                            )
                        |> Push.onOk (\response -> SentimentSelected response)
            in
                model ! [ Phoenix.push model.socketUrl push ]

        SentimentSelected payload ->
            case JD.decodeValue sentimentSelectedDecoder payload of
                Ok payloadContainer ->
                    { model | user_sentiment = payloadContainer.new_sentiment } ! []

                Err err ->
                    let
                        _ =
                            Debug.log "sentimentSelected payload error: " ( err, payload )
                    in
                        model ! []



-- UPDATE HELPERS


roundDownToSecond : Time -> Time
roundDownToSecond ms =
    (ms / 1000) |> truncate |> (*) 1000 |> toFloat



-- DECODERS


type alias UpdatePayloadContainer =
    { name : String
    , happy : Int
    , neutral : Int
    , sad : Int
    , blocks : List Block
    }


updateDecoder : JD.Decoder UpdatePayloadContainer
updateDecoder =
    JD.map5 (\name happy neutral sad blocks -> UpdatePayloadContainer name happy neutral sad blocks)
        (JD.field "name" JD.string)
        (JD.field "happy" JD.int)
        (JD.field "neutral" JD.int)
        (JD.field "sad" JD.int)
        (JD.field "blocks" blocksDecoder)


type alias SentimentSelectedContainer =
    { new_sentiment : String }


sentimentSelectedDecoder =
    JD.map (\new_sentiment -> SentimentSelectedContainer new_sentiment)
        (JD.field "new_sentiment" JD.string)


blocksDecoder : JD.Decoder (List Block)
blocksDecoder =
    JD.list blockDecoder


blockDecoder : JD.Decoder Block
blockDecoder =
    JD.map2 (\username sentiment -> Block username sentiment)
        (JD.field "username" JD.string)
        (JD.field "sentiment" JD.string)



-- SUBSCRIPTIONS


socket : Model -> Socket Msg
socket model =
    Socket.init model.socketUrl
        |> Socket.onOpen (ConnectionStatusChanged Connected)
        |> Socket.onClose (\_ -> ConnectionStatusChanged Disconnected)
        |> Socket.onAbnormalClose SocketClosedAbnormally
        |> Socket.reconnectTimer (\backoffIteration -> (backoffIteration + 1) * 5000 |> toFloat)


connect : Model -> Channel Msg
connect model =
    Channel.init ("room:" ++ model.loc)
        |> Channel.onJoin InitChannel
        |> Channel.on "hive_update" (\msg -> HiveUpdate msg)
        |> Channel.withDebug


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ phoenixSubscription model, Time.every Time.second Tick ]


phoenixSubscription model =
    Phoenix.connect (socket model) [ connect model ]



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "hivemind-interface" ]
        [ div [ class "navbar navbar-expand room-name" ]
            [ div [ class "container d-flex justify-content-center" ] [ text ("You're " ++ model.username ++ " in " ++ model.loc) ]
            ]
        , div [ class "container-fluid sentiment-tracking" ] (renderSentimentTracker model)
        , div [ class "container d-flex justify-content-center blocking-sentiments" ] (renderBlockingSentiments model.blocks)
        , div [ class "container sentiment-select" ] (renderSentimentSelection model)
        , div [ class "container d-flex justify-content-center explanations" ] (renderExplanatoryText)
        ]


renderSentimentTracker : Model -> List (Html Msg)
renderSentimentTracker model =
    [ div [ class "progress" ]
        [ div [ class "progress-bar progress-bar-striped progress-bar-animated bg-info", style [ ( "width", intToPercentageString (model.happy) ) ] ] [ text (intToPercentageString (model.happy)) ]
        , div [ class "progress-bar bg-warning", style [ ( "width", intToPercentageString (model.neutral) ) ] ] [ text (intToPercentageString (model.neutral)) ]
        , div [ class "progress-bar progress-bar-striped progress-bar-animated bg-danger", style [ ( "width", intToPercentageString (model.sad) ) ] ] [ text (intToPercentageString (model.sad)) ]
        ]
    ]


renderSentimentSelection : Model -> List (Html Msg)
renderSentimentSelection model =
    [ div [ class "row d-flex justify-content-center temperature-sentiments" ]
        [ div [ class ("sentiment-icon temperature-happy" ++ (selectionStatus model "happy")) ] [ i [ class "fas fa-3x fa-smile", onClick (SelectSentiment "happy") ] [] ]
        , div [ class ("sentiment-icon temperature-neutral" ++ (selectionStatus model "neutral")) ] [ i [ class "fas fa-3x fa-meh", onClick (SelectSentiment "neutral") ] [] ]
        , div [ class ("sentiment-icon temperature-sad" ++ (selectionStatus model "sad")) ] [ i [ class "fas fa-3x fa-frown", onClick (SelectSentiment "sad") ] [] ]
        ]
    , div [ class "row d-flex justify-content-center blocker-sentiments" ]
        [ div [ class ("sentiment-icon blocker-question" ++ (selectionStatus model "question")) ] [ i [ class "fas fa-3x fa-question-circle", onClick (SelectSentiment "question") ] [] ]
        , div [ class ("sentiment-icon blocker-poo" ++ (selectionStatus model "poo")) ] [ i [ class "fas fa-3x fa-exclamation-triangle", onClick (SelectSentiment "poo") ] [] ]
        , div [ class ("sentiment-icon blocker-raisedhand" ++ (selectionStatus model "raisedhand")) ] [ i [ class "fas fa-3x fa-hand-paper", onClick (SelectSentiment "raisedhand") ] [] ]
        , div [ class ("sentiment-icon blocker-hardno" ++ (selectionStatus model "hardno")) ] [ i [ class "fas fa-3x fa-thumbs-down", onClick (SelectSentiment "hardno") ] [] ]
        ]
    ]


renderBlockingSentiments : List Block -> List (Html Msg)
renderBlockingSentiments blocks =
    [ ul [] (List.map renderBlockingSentiment blocks) ]


renderBlockingSentiment : Block -> Html Msg
renderBlockingSentiment block =
    let
        blocking_text =
            case block.sentiment of
                "question" ->
                    " needs more information."

                "poo" ->
                    " wants the conversation to get back on track."

                "raisedhand" ->
                    " wants a chance to speak."

                "hardno" ->
                    " has a serious problem."

                _ ->
                    ""
    in
        div [ class "blocking-sentiment" ] [ text (block.username ++ blocking_text) ]


renderExplanatoryText : List (Html Msg)
renderExplanatoryText =
    [ ul [ class "explanatory" ]
        [ li [] [ i [ class "fas fa-2x fa-question-circle" ] [], text "Question - need more information, or need information to be stated more clearly." ]
        , li [] [ i [ class "fas fa-2x fa-exclamation-triangle" ] [], text "Point of Order - the conversation has strayed from its topic." ]
        , li [] [ i [ class "fas fa-2x fa-hand-paper" ] [], text "Raised Hand - you have a response or wish to add to the conversation." ]
        , li [] [ i [ class "fas fa-2x fa-thumbs-down" ] [], text "Hard Block - you have a severe consensus-blocking issue with something." ]
        ]
    ]



-- VIEW HELPERS


selectionStatus : Model -> String -> String
selectionStatus model sentiment =
    if model.user_sentiment == sentiment then
        " sentiment-selected"
    else
        " sentiment-unselected"


intToPercentageString : Int -> String
intToPercentageString pct =
    toString (pct) ++ "%"
