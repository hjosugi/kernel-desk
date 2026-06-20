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
