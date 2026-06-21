# Form Panic Bureau

Elmだけで作る、理不尽フォーム突破ブラウザゲームです。

60秒以内にフォームの不備を全部つぶして、逃げる`Accept`ボタンを押せたら勝ちです。昔からある「わざと使いづらいフォーム」系のパロディを、軽く遊べる1画面ゲームにしています。

## 使い方

このrepoのtoolchainはNixに統一しています。

```bash
nix develop
npm run build
npm start
```

ブラウザで開きます。

```text
http://127.0.0.1:4000
```

ビルド結果は`dist/`に出ます。`dist/index.html`を直接開いても遊べます。

## コマンド

```bash
npm run build
npm run check
npm run dev
npm start
```

Nix appとしても呼べます。

```bash
nix run .#build
nix run .#check
nix run .#dev
```

## VS Code

```bash
direnv allow
code form-panic-bureau.code-workspace
```

推奨拡張はElm Language Server、Nix IDE、direnvです。workspace内のtaskは`nix develop --command ...`経由で動きます。

## デプロイ

`main`へpushするとGitHub Pages workflowが`dist/`を公開します。

```text
https://hjosugi.github.io/form-panic-bureau/
```
