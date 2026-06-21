# KernelDesk

Elm + Gleamで作る、ローカルGitリポジトリとLinuxカーネルコードの学習ダッシュボードです。

## MVPでできること

- 指定したローカルGitリポジトリのbranch、remote、最新commit、変更ファイルを確認
- Linuxカーネルの学習ルートから主要ファイルを開く
- 任意のリポジトリ相対パスを指定してソースを読む
- ファイルごとに`Not started / Reading / Understood`を保存
- ファイルごとに学習メモを保存
- 進捗をローカルJSONファイルへ永続化
- GitHub tokenや外部データベースなしで利用

## 構成

```text
Browser
  |
  | JSON API
  v
Elm frontend
  |
  v
Gleam router (JavaScript target)
  |
  v
Small Node.js FFI layer
  |- local git commands
  |- source file access
  `- progress.json
```

Gleamはルーティング、入力検証、学習ルート、JSONレスポンス生成を担当します。Node.js FFIは、ローカルファイル、HTTP server、`git`コマンドとの境界に限定しています。

## 必要なもの

- Node.js 20以上。Node.js 22推奨
- npm
- Git
- Gleam 1.17.x

Elm compilerは`npm install`でプロジェクト内へ導入されます。GleamはJavaScript targetとNode.js runtimeを使うため、Erlangは不要です。

`mise`を利用する場合は、同梱の`mise.toml`からNode.jsとGleamを導入できます。

```bash
mise install
```

Nixを利用する場合は、同梱の`flake.nix`からNode.js、npm、Gleam、Elmを含む開発シェルに入れます。

```bash
nix develop
```

Nix shell内ではElm compilerもPATHから使えるため、現在の構成では`npm install`なしでフロントエンドをbuildできます。npm経由でElmを入れたい場合やNixを使わない場合は、従来どおり`npm install`を実行してください。

### VS Code + Elm

VS Codeで開発する場合は、推奨拡張としてElm language server、Nix IDE、direnvを提示しています。Nixを使う場合は、リポジトリ直下で一度だけdirenvを許可すると、VS Codeが`flake.nix`のElm toolingを拾いやすくなります。

```bash
direnv allow
code kernel-desk.code-workspace
```

`flake.nix`にはElm compilerに加えて、`elm-format`、`elm-test`、`elm-language-server`を入れています。これにより、VS Code上の診断、補完、formatをnpm global installなしで揃えられます。

Elm Language Serverが`KernelDesk.*`モジュールを解決できず赤線を出す場合は、VS Codeでリポジトリrootをそのまま開く代わりに、同梱のworkspaceを開いてください。`frontend`が独立したworkspace folderになり、`frontend/elm.json`をrootとして認識しやすくなります。

```bash
code kernel-desk.code-workspace
```

それでも残る場合は、VS Codeで`Elm: Restart Elm Language Server`または`Developer: Reload Window`を実行してください。

リポジトリrootにもeditor向けの`elm.json`を置いています。これはrootを直接開いたVS Code/Elm Language Serverが`frontend/src`を解決するためのものです。実際のフロントエンドbuildは引き続き`frontend/elm.json`を使います。

syntax highlightがElmにならない場合は、推奨拡張を入れたあとで`Developer: Reload Window`を実行してください。同梱workspaceでは`*.elm`をElmとして関連付け、`elm`、`elm-format`、`elm-test`のPATHをElm LSへ明示しています。右下の言語モードが`Elm`以外なら、`Change Language Mode`から`Elm`を選んでください。

VS Codeからよく使う操作は`Tasks: Run Task`で呼べます。Nixを使う場合は、`direnv allow`後にworkspaceを開くとタスクも同じtoolingを使いやすくなります。

- `elm: build debug`
- `elm: build optimized`
- `backend: check`
- `app: dev server`

通常の操作は次の流れです。

1. `elm: build debug`でElmの型とbuildを確認
2. `backend: check`でGleam backendを確認
3. `app: dev server`で`http://127.0.0.1:4000`を起動
4. GitHub Pages向けの静的demoは`main`へpushするとActionsで自動deploy

このアプリはHTTP APIを使うため、Elmの入口には`Browser.sandbox`や`Browser.document`ではなく`Browser.element`を使っています。`sandbox`は`Cmd`なしの小さな状態管理、`document`はページタイトルなどドキュメント全体も管理したい場合に向いています。

## すぐに試す

実際のLinuxリポジトリをまだ用意していない場合は、同梱の教育用ソースを使えます。

```bash
unzip kernel-desk.zip
cd kernel-desk

npm install
npm run build
npm run verify:local
npm start
```

Nixを使う場合:

```bash
nix develop
npm run build
npm run verify:local
npm start
```

ブラウザで次を開きます。

```text
http://127.0.0.1:4000
```

`sample/linux-mini`はUI確認用のsynthetic sampleです。実際のLinuxカーネルコードではありません。

## 実際のLinuxソースを読む

別の場所へLinuxリポジトリをcloneします。

```bash
git clone --depth 1 https://github.com/torvalds/linux.git "$HOME/src/linux"
```

起動時に絶対パスを渡します。

```bash
KERNEL_REPO_PATH="$HOME/src/linux" npm start
```

毎回指定したくない場合は`.env`を作成します。

```bash
cp .env.example .env
```

`.env`:

```dotenv
KERNEL_REPO_PATH=/home/you/src/linux
PORT=4000
KERNEL_DESK_DATA=./data/progress.json
KERNEL_DESK_STATIC=./priv/static
```

環境変数は`.env`より優先されます。相対パスの設定値は`backend/`を基準に解決されます。

## 開発コマンド

Elmをdebug build:

```bash
npm run build:frontend:debug
```

Elmをoptimized build:

```bash
npm run build:frontend
```

Gleamをtype check:

```bash
npm run check:backend
```

Gleamをformat:

```bash
npm run format:backend
```

フロントエンドをdebug buildして起動:

```bash
npm run dev
```

Node.js FFIのローカル動作を検証:

```bash
npm run verify:local
```

最初の`gleam build`で`backend/manifest.toml`が生成されます。依存バージョンを固定するため、そのファイルはGitへcommitしてください。

## デプロイ

### GitHub Pages

このリポジトリにはGitHub Pages向けのworkflowを同梱しています。`main`へpushするか、Actionsタブから`Deploy static demo to GitHub Pages`を手動実行すると、`backend/priv/static`がPagesへ公開されます。

GitHub Pagesは静的ホスティングのため、公開版は`sample/linux-mini`を使うdemo modeで動きます。ローカルGitリポジトリの読み取り、任意ファイルの読み取り、進捗JSONへの永続保存は、ローカルのGleam/Node.js serverで起動した場合だけ利用できます。

初回だけGitHubのRepository SettingsでPagesのSourceを`GitHub Actions`にしてください。公開URLは通常、次の形式です。

```text
https://<user>.github.io/kernel-desk/
```

ローカルでもdemo modeを確認できます。

```text
http://127.0.0.1:4000/?demo=1
```

### 安い代替

静的demoだけならCloudflare Pagesも相性がよいです。実際のローカルGit学習用途では、ユーザーの手元のファイルシステムと`git`コマンドへアクセスする必要があるため、クラウドへ置くよりローカル起動を推奨します。

## API

```text
GET  /api/health
GET  /api/repo
GET  /api/learning-path
GET  /api/file?path=init/main.c
GET  /api/progress
POST /api/progress
```

`POST /api/progress`:

```json
{
  "path": "init/main.c",
  "status": "reading",
  "note": "Trace start_kernel() and list the initialization order."
}
```

## 学習の進め方

1. `init/main.c`でboot sequenceの入口を確認する
2. 関数名を検索し、呼び出し先をメモする
3. 1ファイルを理解し切ろうとせず、subsystemの責務を一文で書く
4. `Reading`から`Understood`へ変更する条件を自分で決める
5. scheduler、memory、VFS、networkの順で読む

## ディレクトリ

```text
kernel-desk/
├── backend/                 Gleam API + Node.js FFI
├── frontend/                Elm application
├── sample/linux-mini/       教育用synthetic source
├── scripts/                 起動・検証用Node.js scripts
├── docs/ROADMAP.md          次に実装する機能
├── .env.example
├── mise.toml
└── package.json
```

## セキュリティ上の前提

サーバーは初期状態で`127.0.0.1`だけにbindします。指定リポジトリ外へのpath traversalを拒否し、ソース表示量とrequest bodyに上限を設けています。インターネットへ公開する前に、認証、repository allowlist、CSRF対策、CORS制限、rate limitを追加してください。

## 次の実装候補

`docs/ROADMAP.md`に整理しています。最初はdirectory tree、`git grep`によるsymbol検索、file history、`git blame`の順がおすすめです。
