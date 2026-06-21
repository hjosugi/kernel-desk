module Main exposing (main)

import Browser
import Dict
import Http
import KernelDesk.Api as Api
import KernelDesk.Demo as Demo
import KernelDesk.Notice as Notice
import KernelDesk.Progress as Progress
import KernelDesk.Types as Types
import KernelDesk.Types exposing (ApiPayload(..), Flags, Loadable(..), Model, Msg(..), ProgressStatus(..))
import KernelDesk.View as View


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = View.view
        }


init : Flags -> ( Model, Cmd Msg )
init flags =
    if flags.demoMode then
        initDemo

    else
        initApi


initApi : ( Model, Cmd Msg )
initApi =
    ( baseModel False
    , Cmd.batch
        [ Api.fetchRepo
        , Api.fetchLessons
        , Api.fetchProgress
        ]
    )


initDemo : ( Model, Cmd Msg )
initDemo =
    let
        model =
            baseModel True
    in
    case List.head Demo.lessons of
        Just lesson ->
            ( { model
                | repo = Loaded Demo.repo
                , lessons = Loaded Demo.lessons
                , selectedLesson = Just lesson
                , filePath = lesson.path
                , source = Demo.source lesson.path
                , notice = Just (Notice.attention "GitHub Pages版は静的demoです。本物のGit repositoryはローカルserverで開いてください。")
              }
            , Cmd.none
            )

        Nothing ->
            ( { model
                | repo = Loaded Demo.repo
                , lessons = Loaded []
                , notice = Just (Notice.attention "Demo mode has no lessons.")
              }
            , Cmd.none
            )


baseModel : Bool -> Model
baseModel demoMode =
    { repo = Loading
    , lessons = Loading
    , selectedLesson = Nothing
    , filePath = ""
    , source = Idle
    , progress = Dict.empty
    , noteDraft = ""
    , statusDraft = NotStarted
    , saving = False
    , notice = Nothing
    , demoMode = demoMode
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RepoReceived result ->
            handleRepoReceived result model

        LessonsReceived result ->
            handleLessonsReceived result model

        ProgressReceived result ->
            handleProgressReceived result model

        SelectLesson lesson ->
            let
                ( noteDraft, statusDraft ) =
                    Progress.draftsFor lesson.path model.progress

                source =
                    if model.demoMode then
                        Demo.source lesson.path

                    else
                        Loading

                command =
                    if model.demoMode then
                        Cmd.none

                    else
                        Api.fetchSource lesson.path
            in
            ( { model
                | selectedLesson = Just lesson
                , filePath = lesson.path
                , source = source
                , noteDraft = noteDraft
                , statusDraft = statusDraft
                , notice = Nothing
              }
            , command
            )

        FilePathChanged path ->
            ( { model | filePath = path }, Cmd.none )

        LoadFile ->
            loadRequestedFile model

        SourceReceived requestedPath result ->
            handleSourceReceived requestedPath result model

        NoteChanged note ->
            ( { model | noteDraft = note }, Cmd.none )

        StatusChanged rawStatus ->
            ( { model | statusDraft = Progress.statusFromString rawStatus }, Cmd.none )

        SaveProgress ->
            saveCurrentProgress model

        ProgressSaved _ result ->
            handleProgressSaved result model

        RefreshRepo ->
            ( { model | repo = Loading }, Api.fetchRepo )

        DismissNotice ->
            ( { model | notice = Nothing }, Cmd.none )


handleRepoReceived : Result Http.Error (ApiPayload Types.RepoSnapshot) -> Model -> ( Model, Cmd Msg )
handleRepoReceived result model =
    case result of
        Ok (ApiOk repo) ->
            ( { model | repo = Loaded repo }, Cmd.none )

        Ok (ApiError message) ->
            ( { model | repo = Failed message }, Cmd.none )

        Err error ->
            ( { model | repo = Failed (Api.httpErrorToString error) }, Cmd.none )


handleLessonsReceived : Result Http.Error (List Types.Lesson) -> Model -> ( Model, Cmd Msg )
handleLessonsReceived result model =
    case result of
        Ok lessons ->
            case List.head lessons of
                Just lesson ->
                    let
                        ( noteDraft, statusDraft ) =
                            Progress.draftsFor lesson.path model.progress
                    in
                    ( { model
                        | lessons = Loaded lessons
                        , selectedLesson = Just lesson
                        , filePath = lesson.path
                        , source = Loading
                        , noteDraft = noteDraft
                        , statusDraft = statusDraft
                      }
                    , Api.fetchSource lesson.path
                    )

                Nothing ->
                    ( { model | lessons = Loaded [] }, Cmd.none )

        Err error ->
            ( { model | lessons = Failed (Api.httpErrorToString error) }, Cmd.none )


handleProgressReceived : Result Http.Error (ApiPayload (List Types.Progress)) -> Model -> ( Model, Cmd Msg )
handleProgressReceived result model =
    case result of
        Ok (ApiOk items) ->
            let
                progress =
                    Dict.fromList (List.map (\item -> ( item.path, item )) items)

                ( noteDraft, statusDraft ) =
                    Progress.draftsFor model.filePath progress
            in
            ( { model
                | progress = progress
                , noteDraft = noteDraft
                , statusDraft = statusDraft
              }
            , Cmd.none
            )

        Ok (ApiError message) ->
            ( { model | notice = Just (Notice.attention message) }, Cmd.none )

        Err error ->
            ( { model | notice = Just (Notice.attention (Api.httpErrorToString error)) }, Cmd.none )


loadRequestedFile : Model -> ( Model, Cmd Msg )
loadRequestedFile model =
    let
        path =
            String.trim model.filePath
    in
    if String.isEmpty path then
        ( { model | notice = Just (Notice.attention "相対パスを入力してください。") }, Cmd.none )

    else if model.demoMode then
        let
            ( noteDraft, statusDraft ) =
                Progress.draftsFor path model.progress
        in
        ( { model
            | selectedLesson = Nothing
            , filePath = path
            , source = Demo.source path
            , noteDraft = noteDraft
            , statusDraft = statusDraft
            , notice = Nothing
          }
        , Cmd.none
        )

    else
        let
            ( noteDraft, statusDraft ) =
                Progress.draftsFor path model.progress
        in
        ( { model
            | selectedLesson = Nothing
            , filePath = path
            , source = Loading
            , noteDraft = noteDraft
            , statusDraft = statusDraft
            , notice = Nothing
          }
        , Api.fetchSource path
        )


handleSourceReceived : String -> Result Http.Error (ApiPayload Types.SourceFile) -> Model -> ( Model, Cmd Msg )
handleSourceReceived requestedPath result model =
    if requestedPath /= model.filePath then
        ( model, Cmd.none )

    else
        case result of
            Ok (ApiOk source) ->
                ( { model | source = Loaded source }, Cmd.none )

            Ok (ApiError message) ->
                ( { model | source = Failed message }, Cmd.none )

            Err error ->
                ( { model | source = Failed (Api.httpErrorToString error) }, Cmd.none )


saveCurrentProgress : Model -> ( Model, Cmd Msg )
saveCurrentProgress model =
    let
        path =
            String.trim model.filePath
    in
    if String.isEmpty path then
        ( { model | notice = Just (Notice.attention "保存対象のファイルを開いてください。") }, Cmd.none )

    else if model.demoMode then
        let
            item =
                { path = path
                , status = model.statusDraft
                , note = model.noteDraft
                , updatedAt = "Demo session"
                }
        in
        ( { model
            | progress = Dict.insert path item model.progress
            , saving = False
            , notice = Just (Notice.success ("Demo note updated: " ++ path))
          }
        , Cmd.none
        )

    else
        ( { model | saving = True, notice = Nothing }
        , Api.saveProgress path model.statusDraft model.noteDraft
        )


handleProgressSaved : Result Http.Error (ApiPayload Types.Progress) -> Model -> ( Model, Cmd Msg )
handleProgressSaved result model =
    case result of
        Ok (ApiOk item) ->
            ( { model
                | progress = Dict.insert item.path item model.progress
                , saving = False
                , notice = Just (Notice.success ("保存しました: " ++ item.path))
              }
            , Cmd.none
            )

        Ok (ApiError message) ->
            ( { model | saving = False, notice = Just (Notice.attention message) }, Cmd.none )

        Err error ->
            ( { model | saving = False, notice = Just (Notice.attention (Api.httpErrorToString error)) }, Cmd.none )
