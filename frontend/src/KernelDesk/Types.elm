module KernelDesk.Types exposing (..)

import Dict exposing (Dict)
import Http


type Loadable value
    = Idle
    | Loading
    | Loaded value
    | Failed String


type alias Flags =
    { demoMode : Bool
    }


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
    , demoMode : Bool
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
