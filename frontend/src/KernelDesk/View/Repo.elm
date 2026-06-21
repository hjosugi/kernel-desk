module KernelDesk.View.Repo exposing (viewRepoCard)

import Html exposing (Html, button, dd, div, dl, dt, h2, li, p, section, span, text, ul)
import Html.Attributes exposing (class, type_)
import Html.Events exposing (onClick)
import KernelDesk.Types exposing (GitChange, Loadable(..), Model, Msg(..), RepoSnapshot)


viewRepoCard : Model -> Html Msg
viewRepoCard model =
    if model.demoMode then
        section [ class "card" ]
            [ div [ class "card-header" ]
                [ h2 [] [ text "Static demo" ] ]
            , div [ class "card-body" ]
                [ div [ class "warning-state" ]
                    [ p [] [ text "GitHub Pages版は静的demoです。ブラウザからローカルGit repositoryやgitコマンドにはアクセスできません。" ]
                    , p [] [ text "本物のrepositoryを見るには、ローカルserverを起動してKERNEL_REPO_PATHへGit repositoryを指定してください。" ]
                    , p [ class "mono" ] [ text "KERNEL_REPO_PATH=$HOME/src/linux npm start" ]
                    ]
                ]
            ]

    else
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


viewRepoSnapshot : RepoSnapshot -> Html msg
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


viewChanges : List GitChange -> Html msg
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


emptyAs : String -> String -> String
emptyAs fallback value_ =
    if String.isEmpty value_ then
        fallback

    else
        value_
