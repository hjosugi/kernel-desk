module FormPanic.View exposing (view)

import FormPanic.Rules exposing (accepted, rules)
import FormPanic.Types exposing (Model, Msg(..), Rule, Screen(..), currentFace, timeLimit)
import Html exposing (Html, button, div, h1, h2, header, input, label, li, main_, option, p, section, select, small, span, strong, text, ul)
import Html.Attributes exposing (checked, class, classList, disabled, for, id, placeholder, selected, style, type_, value)
import Html.Events exposing (on, onCheck, onClick, onInput)
import Json.Decode as Decode
import String
import Svg exposing (circle, defs, linearGradient, path, rect, stop, svg, text_)
import Svg.Attributes as SvgAttr


view : Model -> Html Msg
view model =
    div [ class "game-shell" ]
        [ header [ class "topbar" ]
            [ div [ class "brand" ]
                [ viewSeal
                , div []
                    [ h1 [] [ text "Form Panic Bureau" ]
                    , p [] [ text "60秒で理不尽フォームを受理させるブラウザゲーム" ]
                    ]
                ]
            , viewTimer model
            ]
        , main_ [ class "game-board" ]
            [ section [ class "side-panel" ]
                [ viewProgress model
                , viewRules model
                ]
            , section [ class "play-panel" ]
                [ viewBanner model
                , case model.screen of
                    Ready ->
                        viewReady

                    Playing ->
                        viewForm model

                    Won ->
                        viewResult True model

                    Lost ->
                        viewResult False model
                ]
            ]
        ]


viewSeal : Html Msg
viewSeal =
    svg [ SvgAttr.viewBox "0 0 96 96", SvgAttr.class "seal" ]
        [ defs []
            [ linearGradient [ SvgAttr.id "sealGradient", SvgAttr.x1 "0", SvgAttr.x2 "1", SvgAttr.y1 "0", SvgAttr.y2 "1" ]
                [ stop [ SvgAttr.offset "0%", SvgAttr.stopColor "#e23d62" ] []
                , stop [ SvgAttr.offset "100%", SvgAttr.stopColor "#137c8b" ] []
                ]
            ]
        , rect [ SvgAttr.x "8", SvgAttr.y "8", SvgAttr.width "80", SvgAttr.height "80", SvgAttr.rx "18", SvgAttr.fill "url(#sealGradient)" ] []
        , path [ SvgAttr.d "M25 60 L39 31 L53 60 L48 60 L44 51 L34 51 L30 60 Z M36 46 L42 46 L39 39 Z", SvgAttr.fill "#fff7e8" ] []
        , circle [ SvgAttr.cx "66", SvgAttr.cy "35", SvgAttr.r "8", SvgAttr.fill "#fff7e8" ] []
        , text_ [ SvgAttr.x "21", SvgAttr.y "75", SvgAttr.fill "#fff7e8", SvgAttr.fontSize "10", SvgAttr.fontWeight "700" ] [ Svg.text "ACCEPT?" ]
        ]


viewTimer : Model -> Html Msg
viewTimer model =
    let
        pct =
            (toFloat model.secondsLeft / toFloat timeLimit) * 100
    in
    div [ class "timer" ]
        [ span [] [ text "TIME" ]
        , strong [ classList [ ( "danger", model.secondsLeft <= 10 ) ] ] [ text (String.fromInt model.secondsLeft ++ "s") ]
        , div [ class "timer-track" ] [ div [ class "timer-fill", style "width" (String.fromFloat pct ++ "%") ] [] ]
        ]


viewProgress : Model -> Html Msg
viewProgress model =
    let
        items =
            rules model

        done =
            List.length (List.filter .passed items)

        total =
            List.length items
    in
    div [ class "card" ]
        [ h2 [] [ text "Progress" ]
        , div [ class "big-count" ] [ text (String.fromInt done ++ "/" ++ String.fromInt total) ]
        , p [] [ text "毎回ルールが変わります。チェックリストどおりに埋めてください。" ]
        ]


viewRules : Model -> Html Msg
viewRules model =
    div [ class "card" ]
        [ h2 [] [ text "Checklist" ]
        , ul [ class "rule-list" ] (List.map viewRule (rules model))
        ]


viewRule : Rule -> Html Msg
viewRule rule =
    li [ classList [ ( "rule", True ), ( "ok", rule.passed ) ] ]
        [ span [ class "rule-dot" ]
            [ text
                (if rule.passed then
                    "OK"

                 else
                    "!"
                )
            ]
        , div []
            [ strong [] [ text rule.title ]
            , small [] [ text rule.hint ]
            ]
        ]


viewBanner : Model -> Html Msg
viewBanner model =
    div [ class "banner" ]
        [ strong [] [ text (screenLabel model.screen) ]
        , span [] [ text model.message ]
        ]


viewReady : Html Msg
viewReady =
    div [ class "ready-card" ]
        [ h2 [] [ text "受付番号 404" ]
        , p [] [ text "ルールは毎回ランダムです。左のチェックリストを全部そろえて、ボタンが ACCEPT になった瞬間に押してください。ボタンは少しだけ逃げます。" ]
        , button [ type_ "button", class "primary-action", onClick Start ] [ text "Start" ]
        ]


viewForm : Model -> Html Msg
viewForm model =
    div [ class "form-card" ]
        [ div [ class "form-grid" ]
            [ field "氏名"
                [ input [ type_ "text", placeholder "Yamada Taro", value model.fullName, onInput FullNameChanged ] [] ]
            , field "メール"
                [ input [ type_ "text", placeholder "you@example.dev", value model.email, onInput EmailChanged ] [] ]
            , field "窓口"
                [ select [ value model.window, onInput WindowChanged ]
                    [ option [ value "none", selected (model.window == "none") ] [ text "選択してください" ]
                    , option [ value "window-1", selected (model.window == "window-1") ] [ text "1番: 早そう" ]
                    , option [ value "window-2", selected (model.window == "window-2") ] [ text "2番: 閉鎖中" ]
                    , option [ value "window-3", selected (model.window == "window-3") ] [ text "3番: 普通" ]
                    , option [ value "window-4", selected (model.window == "window-4") ] [ text "4番: 偉そう" ]
                    ]
                ]
            , field ("番号つまみ: " ++ model.slider)
                [ input [ type_ "range", Html.Attributes.min "0", Html.Attributes.max "100", value model.slider, onInput SliderChanged ] [] ]
            , div [ class "checks" ]
                [ checkRow "terms" "利用規約に同意します" model.terms ToggleTerms
                , checkRow "robot" "私はロボットではない可能性があります" model.notRobot ToggleRobot
                , checkRow "decoy" "同意を取り消します" model.decoy ToggleDecoy
                ]
            ]
        , viewActions model
        ]


viewActions : Model -> Html Msg
viewActions model =
    let
        ready =
            accepted model

        face =
            currentFace model.flip

        isAccept =
            face == "ACCEPT"
    in
    div [ class "action-zone" ]
        [ p [ class "submit-hint" ]
            [ text
                (if ready then
                    "ボタンが ACCEPT に変わった瞬間だけ受理できます。"

                 else
                    "チェックリストを全部そろえると Accept できます。"
                )
            ]
        , div [ class "action-buttons" ]
            [ button [ type_ "button", class "secondary-action", onClick Restart ] [ text "Reset" ]
            , button
                [ type_ "button"
                , classList
                    [ ( "primary-action moving-action", True )
                    , ( "ready", ready )
                    , ( "face-accept", ready && isAccept )
                    , ( "face-deny", ready && not isAccept )
                    ]
                , disabled (not ready)
                , onClick Submit
                , style "transform" (buttonTransform model)
                , on "mouseenter" (Decode.succeed ButtonDodged)
                ]
                [ text
                    (if ready then
                        face

                     else
                        "Accept"
                    )
                ]
            ]
        ]


field : String -> List (Html Msg) -> Html Msg
field labelText children =
    label [ class "field" ]
        (span [] [ text labelText ] :: children)


checkRow : String -> String -> Bool -> (Bool -> Msg) -> Html Msg
checkRow inputId copy current toMsg =
    label [ class "check-row", for inputId ]
        [ input [ id inputId, type_ "checkbox", checked current, onCheck toMsg ] []
        , span [] [ text copy ]
        ]


viewResult : Bool -> Model -> Html Msg
viewResult won model =
    div [ classList [ ( "result-card", True ), ( "won", won ) ] ]
        [ h2 []
            [ text
                (if won then
                    "ACCEPTED"

                 else
                    "REJECTED"
                )
            ]
        , p []
            [ text
                (if won then
                    "受理印が押されました。フォームはあなたに負けました。"

                 else
                    "時間切れです。フォームは勝ち誇っています。"
                )
            ]
        , p []
            [ text
                ("残り "
                    ++ String.fromInt model.secondsLeft
                    ++ " 秒 / ボタン逃走 "
                    ++ String.fromInt model.dodges
                    ++ " 回 / 誤爆 "
                    ++ String.fromInt model.misclicks
                    ++ " 回"
                )
            ]
        , button [ type_ "button", class "primary-action", onClick Start ] [ text "もう一度" ]
        ]


buttonTransform : Model -> String
buttonTransform model =
    case modBy 5 (model.elapsed + model.dodges) of
        0 ->
            "translate(0, 0)"

        1 ->
            "translate(-24px, -8px)"

        2 ->
            "translate(30px, 8px)"

        3 ->
            "translate(-12px, 24px)"

        _ ->
            "translate(18px, -18px)"


screenLabel : Screen -> String
screenLabel screen =
    case screen of
        Ready ->
            "READY"

        Playing ->
            "PLAYING"

        Won ->
            "ACCEPTED"

        Lost ->
            "TIMEOUT"
