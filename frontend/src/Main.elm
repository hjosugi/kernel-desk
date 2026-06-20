module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (Html, button, code, dd, div, dl, dt, h1, h2, h3, header, input, label, li, main_, option, p, section, select, span, text, textarea, ul)
import Html.Attributes exposing (attribute, class, classList, disabled, placeholder, rows, style, title, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Url.Builder


type Loadable value
    = Idle
    | Loading
    | Loaded value
    | Failed String


type alias GitChange =
    { code : String
    , path : String
    }


type alias RepoSnapshot =
    { root : String
    , isGitRepo : Bool
    , branch : String
    , remote : String
    , headSummary : String
    , headAuthor : String
    , headDate : String
    , changes : List GitChange
    }


type alias Lesson =
    { id : String
    , title : String
    , path : String
    , area : String
    , goal : String
    , questions : List String
    }


type alias SourceFile =
    { path : String
    , content : String
    , lineCount : Int
    , truncated : Bool
    }


type ProgressStatus
    = NotStarted
    | Reading
    | Understood


type alias Progress =
    { path : String
    , status : ProgressStatus
    , note : String
    , updatedAt : String
    }


type NoticeKind
    = Positive
    | Attention


type alias Notice =
    { kind : NoticeKind
    , message : String
    }


type alias ProgressSummary =
    { total : Int
    , reading : Int
    , understood : Int
    }


type ApiPayload value
    = ApiOk value
    | ApiError String


type alias Model =
    { repo : Loadable RepoSnapshot
    , lessons : Loadable (List Lesson)
    , selectedLesson : Maybe Lesson
    , filePath : String
    , source : Loadable SourceFile
    , progress : Dict String Progress
    , noteDraft : String
    , statusDraft : ProgressStatus
    , saving : Bool
    , notice : Maybe Notice
    }


type Msg
    = RepoReceived (Result Http.Error (ApiPayload RepoSnapshot))
    | LessonsReceived (Result Http.Error (List Lesson))
    | ProgressReceived (Result Http.Error (ApiPayload (List Progress)))
    | SelectLesson Lesson
    | FilePathChanged String
    | LoadFile
    | SourceReceived String (Result Http.Error (ApiPayload SourceFile))
    | NoteChanged String
    | StatusChanged String
    | SaveProgress
    | ProgressSaved String (Result Http.Error (ApiPayload Progress))
    | RefreshRepo
    | DismissNotice


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { repo = Loading
      , lessons = Loading
      , selectedLesson = Nothing
      , filePath = ""
      , source = Idle
      , progress = Dict.empty
      , noteDraft = ""
      , statusDraft = NotStarted
      , saving = False
      , notice = Nothing
      }
    , Cmd.batch
        [ fetchRepo
        , fetchLessons
        , fetchProgress
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RepoReceived result ->
            case result of
                Ok (ApiOk repo) ->
                    ( { model | repo = Loaded repo }, Cmd.none )

                Ok (ApiError message) ->
                    ( { model | repo = Failed message }, Cmd.none )

                Err error ->
                    ( { model | repo = Failed (httpErrorToString error) }, Cmd.none )

        LessonsReceived result ->
            case result of
                Ok lessons ->
                    case List.head lessons of
                        Just lesson ->
                            let
                                ( noteDraft, statusDraft ) =
                                    draftsFor lesson.path model.progress
                            in
                            ( { model
                                | lessons = Loaded lessons
                                , selectedLesson = Just lesson
                                , filePath = lesson.path
                                , source = Loading
                                , noteDraft = noteDraft
                                , statusDraft = statusDraft
                              }
                            , fetchSource lesson.path
                            )

                        Nothing ->
                            ( { model | lessons = Loaded [] }, Cmd.none )

                Err error ->
                    ( { model | lessons = Failed (httpErrorToString error) }, Cmd.none )

        ProgressReceived result ->
            case result of
                Ok (ApiOk items) ->
                    let
                        progress =
                            Dict.fromList (List.map (\item -> ( item.path, item )) items)

                        ( noteDraft, statusDraft ) =
                            draftsFor model.filePath progress
                    in
                    ( { model
                        | progress = progress
                        , noteDraft = noteDraft
                        , statusDraft = statusDraft
                      }
                    , Cmd.none
                    )

                Ok (ApiError message) ->
                    ( { model | notice = Just (attentionNotice message) }, Cmd.none )

                Err error ->
                    ( { model | notice = Just (attentionNotice (httpErrorToString error)) }, Cmd.none )

        SelectLesson lesson ->
            let
                ( noteDraft, statusDraft ) =
                    draftsFor lesson.path model.progress
            in
            ( { model
                | selectedLesson = Just lesson
                , filePath = lesson.path
                , source = Loading
                , noteDraft = noteDraft
                , statusDraft = statusDraft
                , notice = Nothing
              }
            , fetchSource lesson.path
            )

        FilePathChanged path ->
            ( { model | filePath = path }, Cmd.none )

        LoadFile ->
            let
                path =
                    String.trim model.filePath
            in
            if String.isEmpty path then
                ( { model | notice = Just (attentionNotice "相対パスを入力してください。") }, Cmd.none )

            else
                let
                    ( noteDraft, statusDraft ) =
                        draftsFor path model.progress
                in
                ( { model
                    | selectedLesson = Nothing
                    , filePath = path
                    , source = Loading
                    , noteDraft = noteDraft
                    , statusDraft = statusDraft
                    , notice = Nothing
                  }
                , fetchSource path
                )

        SourceReceived requestedPath result ->
            if requestedPath /= model.filePath then
                ( model, Cmd.none )

            else
                case result of
                    Ok (ApiOk source) ->
                        ( { model | source = Loaded source }, Cmd.none )

                    Ok (ApiError message) ->
                        ( { model | source = Failed message }, Cmd.none )

                    Err error ->
                        ( { model | source = Failed (httpErrorToString error) }, Cmd.none )

        NoteChanged note ->
            ( { model | noteDraft = note }, Cmd.none )

        StatusChanged rawStatus ->
            ( { model | statusDraft = statusFromString rawStatus }, Cmd.none )

        SaveProgress ->
            let
                path =
                    String.trim model.filePath
            in
            if String.isEmpty path then
                ( { model | notice = Just (attentionNotice "保存対象のファイルを開いてください。") }, Cmd.none )

            else
                ( { model | saving = True, notice = Nothing }
                , saveProgress path model.statusDraft model.noteDraft
                )

        ProgressSaved _ result ->
            case result of
                Ok (ApiOk item) ->
                    ( { model
                        | progress = Dict.insert item.path item model.progress
                        , saving = False
                        , notice = Just (successNotice ("保存しました: " ++ item.path))
                      }
                    , Cmd.none
                    )

                Ok (ApiError message) ->
                    ( { model | saving = False, notice = Just (attentionNotice message) }, Cmd.none )

                Err error ->
                    ( { model | saving = False, notice = Just (attentionNotice (httpErrorToString error)) }, Cmd.none )

        RefreshRepo ->
            ( { model | repo = Loading }, fetchRepo )

        DismissNotice ->
            ( { model | notice = Nothing }, Cmd.none )


fetchRepo : Cmd Msg
fetchRepo =
    Http.get
        { url = "/api/repo"
        , expect = Http.expectJson RepoReceived (apiPayloadDecoder repoDecoder)
        }


fetchLessons : Cmd Msg
fetchLessons =
    Http.get
        { url = "/api/learning-path"
        , expect = Http.expectJson LessonsReceived (Decode.list lessonDecoder)
        }


fetchProgress : Cmd Msg
fetchProgress =
    Http.get
        { url = "/api/progress"
        , expect = Http.expectJson ProgressReceived (apiPayloadDecoder (Decode.list progressDecoder))
        }


fetchSource : String -> Cmd Msg
fetchSource path =
    Http.get
        { url =
            Url.Builder.absolute
                [ "api", "file" ]
                [ Url.Builder.string "path" path ]
        , expect = Http.expectJson (SourceReceived path) (apiPayloadDecoder sourceDecoder)
        }


saveProgress : String -> ProgressStatus -> String -> Cmd Msg
saveProgress path status note =
    Http.post
        { url = "/api/progress"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "path", Encode.string path )
                    , ( "status", Encode.string (statusToString status) )
                    , ( "note", Encode.string note )
                    ]
                )
        , expect = Http.expectJson (ProgressSaved path) (apiPayloadDecoder progressDecoder)
        }


apiPayloadDecoder : Decoder value -> Decoder (ApiPayload value)
apiPayloadDecoder decoder =
    Decode.oneOf
        [ Decode.map ApiOk decoder
        , Decode.map ApiError (Decode.field "error" Decode.string)
        ]


repoDecoder : Decoder RepoSnapshot
repoDecoder =
    Decode.map8 RepoSnapshot
        (Decode.field "root" Decode.string)
        (Decode.field "isGitRepo" Decode.bool)
        (Decode.field "branch" Decode.string)
        (Decode.field "remote" Decode.string)
        (Decode.field "headSummary" Decode.string)
        (Decode.field "headAuthor" Decode.string)
        (Decode.field "headDate" Decode.string)
        (Decode.field "changes" (Decode.list gitChangeDecoder))


gitChangeDecoder : Decoder GitChange
gitChangeDecoder =
    Decode.map2 GitChange
        (Decode.field "code" Decode.string)
        (Decode.field "path" Decode.string)


lessonDecoder : Decoder Lesson
lessonDecoder =
    Decode.map6 Lesson
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "path" Decode.string)
        (Decode.field "area" Decode.string)
        (Decode.field "goal" Decode.string)
        (Decode.field "questions" (Decode.list Decode.string))


sourceDecoder : Decoder SourceFile
sourceDecoder =
    Decode.map4 SourceFile
        (Decode.field "path" Decode.string)
        (Decode.field "content" Decode.string)
        (Decode.field "lineCount" Decode.int)
        (Decode.field "truncated" Decode.bool)


progressDecoder : Decoder Progress
progressDecoder =
    Decode.map4 Progress
        (Decode.field "path" Decode.string)
        (Decode.field "status" (Decode.map statusFromString Decode.string))
        (Decode.field "note" Decode.string)
        (Decode.field "updatedAt" Decode.string)


view : Model -> Html Msg
view model =
    div [ class "app-shell" ]
        [ viewHeader
        , div [ class "workspace" ]
            [ div [ class "sidebar" ]
                [ viewRepoCard model
                , viewLearningPath model
                ]
            , main_ [ class "content-column" ]
                [ viewNotice model.notice
                , viewPathToolbar model
                , viewSelectedLesson model.selectedLesson
                , viewSource model.source
                , viewNotes model
                ]
            ]
        ]


viewHeader : Html Msg
viewHeader =
    header [ class "topbar" ]
        [ div [ class "brand" ]
            [ h1 [] [ text "KernelDesk" ]
            , p [] [ text "Local Git management and Linux kernel code learning" ]
            ]
        , div [ class "topbar-note mono" ] [ text "Elm + Gleam + Node.js FFI" ]
        ]


viewNotice : Maybe Notice -> Html Msg
viewNotice maybeNotice =
    case maybeNotice of
        Nothing ->
            text ""

        Just notice ->
            div
                [ classList
                    [ ( "notice", True )
                    , ( "is-positive", notice.kind == Positive )
                    ]
                , attribute "role"
                    (if notice.kind == Positive then
                        "status"

                     else
                        "alert"
                    )
                ]
                [ span [] [ text notice.message ]
                , button [ type_ "button", onClick DismissNotice, title "閉じる" ] [ text "Close" ]
                ]


viewRepoCard : Model -> Html Msg
viewRepoCard model =
    section [ class "card" ]
        [ div [ class "card-header" ]
            [ h2 [] [ text "Local repository" ]
            , button [ class "small-button", type_ "button", onClick RefreshRepo ] [ text "Refresh" ]
            ]
        , case model.repo of
            Idle ->
                div [ class "empty-state" ] [ text "Repository is not loaded." ]

            Loading ->
                div [ class "loading-state" ] [ text "Git情報を読み込み中です。" ]

            Failed message ->
                div [ class "error-state" ] [ text message ]

            Loaded repo ->
                viewRepoSnapshot repo
        ]


viewRepoSnapshot : RepoSnapshot -> Html Msg
viewRepoSnapshot repo =
    if repo.isGitRepo then
        div [ class "card-body" ]
            [ dl [ class "repo-grid" ]
                [ dt [] [ text "Root" ]
                , dd [ class "mono" ] [ text repo.root ]
                , dt [] [ text "Branch" ]
                , dd [ class "mono" ] [ text (emptyAs "detached" repo.branch) ]
                , dt [] [ text "Remote" ]
                , dd [ class "mono" ] [ text (emptyAs "not configured" repo.remote) ]
                , dt [] [ text "HEAD" ]
                , dd [] [ text (emptyAs "unknown" repo.headSummary) ]
                , dt [] [ text "Author" ]
                , dd [] [ text (emptyAs "unknown" repo.headAuthor) ]
                , dt [] [ text "Date" ]
                , dd [] [ text (emptyAs "unknown" repo.headDate) ]
                , dt [] [ text "Changes" ]
                , dd [] [ text (String.fromInt (List.length repo.changes)) ]
                ]
            , viewChanges repo.changes
            ]

    else
        div [ class "card-body" ]
            [ div [ class "warning-state" ]
                [ p [] [ text "指定先はGitリポジトリではありません。ソース閲覧は利用できます。" ]
                , p [ class "mono" ] [ text repo.root ]
                ]
            ]


viewChanges : List GitChange -> Html Msg
viewChanges changes =
    if List.isEmpty changes then
        p [] [ text "Working tree is clean." ]

    else
        ul [ class "change-list" ]
            (changes
                |> List.take 10
                |> List.map
                    (\change ->
                        li [ class "change-item" ]
                            [ span [ class "change-code" ] [ text change.code ]
                            , span [ class "mono" ] [ text change.path ]
                            ]
                    )
            )


viewLearningPath : Model -> Html Msg
viewLearningPath model =
    section [ class "card" ]
        [ div [ class "card-header" ] [ h2 [] [ text "Linux learning path" ] ]
        , case model.lessons of
            Idle ->
                div [ class "empty-state" ] [ text "No learning path." ]

            Loading ->
                div [ class "loading-state" ] [ text "学習ルートを読み込み中です。" ]

            Failed message ->
                div [ class "error-state" ] [ text message ]

            Loaded lessons ->
                let
                    summary =
                        progressSummary lessons model.progress
                in
                div [ class "card-body" ]
                    [ viewProgressSummary summary
                    , ul [ class "lesson-list" ]
                        (List.map (viewLessonButton model) lessons)
                    ]
        ]


viewLessonButton : Model -> Lesson -> Html Msg
viewLessonButton model lesson =
    let
        isSelected =
            case model.selectedLesson of
                Just selectedLesson ->
                    selectedLesson.id == lesson.id

                Nothing ->
                    False

        status =
            Dict.get lesson.path model.progress
                |> Maybe.map .status
                |> Maybe.withDefault NotStarted
    in
    li []
        [ button
            [ classList
                [ ( "lesson-button", True )
                , ( "is-selected", isSelected )
                ]
            , type_ "button"
            , onClick (SelectLesson lesson)
            ]
            [ div [ class "lesson-title-row" ]
                [ span [ class "lesson-title" ] [ text lesson.title ]
                , viewStatusPill True status
                ]
            , span [ class "lesson-area" ] [ text lesson.area ]
            , span [ class "lesson-path" ] [ text lesson.path ]
            ]
        ]


viewPathToolbar : Model -> Html Msg
viewPathToolbar model =
    section [ class "card" ]
        [ div [ class "path-toolbar" ]
            [ input
                [ class "text-input mono"
                , type_ "text"
                , value model.filePath
                , placeholder "例: init/main.c"
                , attribute "aria-label" "Repository relative path"
                , onInput FilePathChanged
                ]
                []
            , button
                [ class "primary-button"
                , type_ "button"
                , onClick LoadFile
                , disabled (String.isEmpty (String.trim model.filePath))
                ]
                [ text "Open file" ]
            ]
        ]


viewSelectedLesson : Maybe Lesson -> Html Msg
viewSelectedLesson maybeLesson =
    case maybeLesson of
        Nothing ->
            text ""

        Just lesson ->
            section [ class "card" ]
                [ div [ class "card-header" ]
                    [ h2 [] [ text lesson.title ]
                    , span [ class "area-chip" ] [ text lesson.area ]
                    ]
                , div [ class "card-body" ]
                    [ div [ class "lesson-focus" ]
                        [ span [ class "section-kicker" ] [ text "Focus" ]
                        , p [] [ text lesson.goal ]
                        ]
                    , div [ class "question-panel" ]
                        [ span [ class "section-kicker" ] [ text "Questions" ]
                        , ul [ class "question-list" ]
                            (List.map (\question -> li [] [ text question ]) lesson.questions)
                        ]
                    ]
                ]


viewSource : Loadable SourceFile -> Html Msg
viewSource sourceState =
    section [ class "card" ]
        [ case sourceState of
            Idle ->
                div [ class "empty-state" ] [ text "左の学習ルートまたは相対パスからファイルを開いてください。" ]

            Loading ->
                div [ class "loading-state" ] [ text "ソースを読み込み中です。" ]

            Failed message ->
                div [ class "error-state" ] [ text message ]

            Loaded source ->
                div []
                    [ div [ class "card-header" ]
                        [ div [ class "source-heading" ]
                            [ span [ class "section-kicker" ] [ text "Source" ]
                            , h3 [ class "mono" ] [ text source.path ]
                            ]
                        , div [ class "source-meta" ]
                            [ span [] [ text (String.fromInt source.lineCount ++ " lines") ]
                            , if source.truncated then
                                span [ class "warning-chip" ] [ text "Preview truncated" ]

                              else
                                text ""
                            ]
                        ]
                    , div [ class "code-scroll" ]
                        [ div [ class "code-block" ]
                            (source.content
                                |> String.lines
                                |> List.indexedMap viewCodeLine
                            )
                        ]
                    ]
        ]


viewCodeLine : Int -> String -> Html Msg
viewCodeLine index line =
    div [ class "code-line" ]
        [ span [ class "line-number" ] [ text (String.fromInt (index + 1)) ]
        , code [ class "line-text" ] [ text line ]
        ]


viewNotes : Model -> Html Msg
viewNotes model =
    section [ class "card" ]
        [ div [ class "card-header" ]
            [ h2 [] [ text "Learning note" ]
            , viewCurrentProgressMeta model
            ]
        , div [ class "card-body" ]
            [ div [ class "notes-grid" ]
                [ div [ class "field-group" ]
                    [ label [ class "field-label" ] [ text "Status" ]
                    , viewStatusPill False model.statusDraft
                    , select
                        [ class "select-input"
                        , value (statusToString model.statusDraft)
                        , onInput StatusChanged
                        , disabled (String.isEmpty (String.trim model.filePath))
                        ]
                        [ option [ value "not_started" ] [ text "Not started" ]
                        , option [ value "reading" ] [ text "Reading" ]
                        , option [ value "understood" ] [ text "Understood" ]
                        ]
                    ]
                , div [ class "field-group" ]
                    [ label [ class "field-label" ] [ text "Note" ]
                    , textarea
                        [ class "note-input"
                        , rows 8
                        , value model.noteDraft
                        , placeholder "関数の責務、呼び出し関係、疑問点を記録します。"
                        , onInput NoteChanged
                        , disabled (String.isEmpty (String.trim model.filePath))
                        ]
                        []
                    ]
                ]
            , div [ class "note-actions" ]
                [ button
                    [ class "primary-button"
                    , type_ "button"
                    , onClick SaveProgress
                    , disabled (model.saving || String.isEmpty (String.trim model.filePath))
                    ]
                    [ text
                        (if model.saving then
                            "Saving..."

                         else
                            "Save locally"
                        )
                    ]
                ]
            ]
        ]


viewProgressSummary : ProgressSummary -> Html msg
viewProgressSummary summary =
    let
        notStarted =
            max 0 (summary.total - summary.reading - summary.understood)
    in
    div [ class "progress-summary" ]
        [ div [ class "progress-summary-row" ]
            [ span [ class "section-kicker" ] [ text "Progress" ]
            , span [ class "progress-total" ]
                [ text (String.fromInt summary.understood ++ "/" ++ String.fromInt summary.total ++ " understood") ]
            ]
        , div [ class "progress-meter", attribute "aria-hidden" "true" ]
            [ span [ class "progress-fill", style "width" (progressPercent summary) ] [] ]
        , div [ class "progress-counts" ]
            [ span [] [ text (String.fromInt notStarted ++ " new") ]
            , span [] [ text (String.fromInt summary.reading ++ " reading") ]
            , span [] [ text (String.fromInt summary.understood ++ " done") ]
            ]
        ]


viewStatusPill : Bool -> ProgressStatus -> Html msg
viewStatusPill compact status =
    span
        [ classList
            [ ( "status-pill", True )
            , ( "is-compact", compact )
            , ( "is-reading", status == Reading )
            , ( "is-understood", status == Understood )
            ]
        , title (statusLabel status)
        ]
        [ text
            (if compact then
                compactStatusLabel status

             else
                statusLabel status
            )
        ]


viewCurrentProgressMeta : Model -> Html Msg
viewCurrentProgressMeta model =
    let
        path =
            String.trim model.filePath
    in
    case Dict.get path model.progress of
        Just item ->
            if String.isEmpty item.updatedAt then
                text ""

            else
                span [ class "note-meta" ] [ text ("Updated " ++ item.updatedAt) ]

        Nothing ->
            text ""


progressSummary : List Lesson -> Dict String Progress -> ProgressSummary
progressSummary lessons progress =
    List.foldl
        (\lesson summary ->
            case Dict.get lesson.path progress |> Maybe.map .status |> Maybe.withDefault NotStarted of
                Reading ->
                    { summary | reading = summary.reading + 1 }

                Understood ->
                    { summary | understood = summary.understood + 1 }

                NotStarted ->
                    summary
        )
        { total = List.length lessons, reading = 0, understood = 0 }
        lessons


progressPercent : ProgressSummary -> String
progressPercent summary =
    if summary.total == 0 then
        "0%"

    else
        String.fromInt (summary.understood * 100 // summary.total) ++ "%"


draftsFor : String -> Dict String Progress -> ( String, ProgressStatus )
draftsFor path progress =
    case Dict.get path progress of
        Just item ->
            ( item.note, item.status )

        Nothing ->
            ( "", NotStarted )


statusFromString : String -> ProgressStatus
statusFromString rawStatus =
    case rawStatus of
        "reading" ->
            Reading

        "understood" ->
            Understood

        _ ->
            NotStarted


statusToString : ProgressStatus -> String
statusToString status =
    case status of
        NotStarted ->
            "not_started"

        Reading ->
            "reading"

        Understood ->
            "understood"


statusLabel : ProgressStatus -> String
statusLabel status =
    case status of
        NotStarted ->
            "Not started"

        Reading ->
            "Reading"

        Understood ->
            "Understood"


compactStatusLabel : ProgressStatus -> String
compactStatusLabel status =
    case status of
        NotStarted ->
            "New"

        Reading ->
            "Reading"

        Understood ->
            "Done"


successNotice : String -> Notice
successNotice message =
    { kind = Positive, message = message }


attentionNotice : String -> Notice
attentionNotice message =
    { kind = Attention, message = message }


emptyAs : String -> String -> String
emptyAs fallback value_ =
    if String.isEmpty value_ then
        fallback

    else
        value_


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out."

        Http.NetworkError ->
            "Backendに接続できません。Gleam serverを確認してください。"

        Http.BadStatus statusCode ->
            "Backend returned HTTP " ++ String.fromInt statusCode ++ "."

        Http.BadBody details ->
            "Invalid response: " ++ details
