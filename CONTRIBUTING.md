# 開発の進め方

このリポジトリでの開発の約束ごとをまとめています。

## 外部からのコントリビューションについて

**現在、外部からのプルリクエストは受け付けていません。**

このリポジトリは公開されていますが、オープンソースではありません。[LICENSE](LICENSE) のとおり、複製、改変、再配布は許諾していないため、いただいたコードを取り込むことができません。

不具合の報告や機能の提案は歓迎します。[Issue](https://github.com/TaiyoYamada/todo/issues/new/choose) からお知らせください。

以下は、リポジトリの持ち主が開発するときの手順です。

## 開発環境

| 必要なもの | バージョン | 入れ方 |
|---|---|---|
| Xcode | 27 以降(Swift 6.4) | App Store または Apple Developer |
| XcodeGen | 最新 | `brew install xcodegen` |
| SwiftLint | 最新 | `brew install swiftlint` |
| SwiftFormat | 最新 | `brew install swiftformat` |
| xcbeautify(任意) | 最新 | `brew install xcbeautify` |

xcbeautify は入っていれば `xcodebuild` の出力を読みやすくします。なくても動きます。

## セットアップ

```sh
git clone https://github.com/TaiyoYamada/todo.git
cd todo
make bootstrap   # project.yml から Todo.xcodeproj を生成する
open Todo.xcodeproj
```

`Todo.xcodeproj` は XcodeGen が作る生成物で、コミットしません。ファイルを足したり消したりしたら、`make bootstrap` をやり直してください。

## ブランチ

Git-flow で運用します。

| ブランチ | 役割 | 分岐元 | マージ先 |
|---|---|---|---|
| `main` | 公開済みの状態 | — | — |
| `develop` | 次の公開に向けた統合先 | — | — |
| `feature/<内容>` | 機能の追加や修正 | `develop` | `develop` |
| `release/<バージョン>` | 公開前の仕上げ | `develop` | `main` と `develop` |
| `hotfix/<内容>` | 公開済みの版の緊急修正 | `main` | `main` と `develop` |

- `main` と `develop` には直接プッシュしません。必ずプルリクエストを通します。
- ブランチ名は英小文字とハイフンで書きます。例: `feature/add-goal-screen`
- 強制プッシュと履歴の書き換えはしません。

## コミット

コミットは小さく刻みます。1つのコミットには1つの意図だけを入れます。

メッセージは次の形で書きます。

```
<type>: <日本語の説明>
```

| type | 使うとき | 例 |
|---|---|---|
| `feat` | 機能を足す | `feat: 目標の追加画面を実装` |
| `fix` | 不具合を直す | `fix: 期限が過去の目標を保存できてしまう問題を修正` |
| `docs` | 文書だけを変える | `docs: 開発の進め方にテストの方針を追記` |
| `style` | 動きを変えない整形 | `style: SwiftFormat の整形を適用` |
| `refactor` | 動きを変えない作り直し | `refactor: 余裕の計算を Domain に移動` |
| `perf` | 速さや消費を改善する | `perf: 目標一覧の再描画を減らす` |
| `test` | テストを足す、直す | `test: 着手リミットの計算のテストを追加` |
| `build` | ビルドの仕組みや依存を変える | `build: SQLiteData を依存に追加` |
| `ci` | CI の設定を変える | `ci: プルリクエストで CI が走るように変更` |
| `chore` | 上のどれでもない雑務 | `chore: .gitignore に xcresult を追加` |

- 説明は「何をしたか」を1行で書きます。理由が要るときは、空行を挟んで本文に書きます。
- 署名や `Co-Authored-By` の行は付けません。

## プルリクエストの流れ

1. `develop` から作業ブランチを切る。

   ```sh
   git fetch origin
   git checkout -b feature/<内容> origin/develop
   ```

2. 小さなコミットを重ねる。
3. プッシュする前に、手元で検査とテストを通す。

   ```sh
   make format
   make lint
   make test
   ```

4. `develop` に向けてプルリクエストを作る。タイトルはコミットと同じ形(`<type>: <日本語の説明>`)にし、本文はテンプレートに沿って書く。
5. **マージコミットでマージする。** squash と rebase は使いません。細かい履歴を残すためです。

   ```sh
   gh pr merge --merge --delete-branch
   ```

### CI について

開発が一段落するまで、CI は自動では走りません。必要なときに GitHub の Actions 画面から手動で実行します。それまでは、手元の `make lint` と `make test` が品質の確認になります。

## コードスタイル

整形は SwiftFormat、検査は SwiftLint に任せます。人が目で揃えることはしません。

| 道具 | 設定 | 役割 |
|---|---|---|
| SwiftFormat | [.swiftformat](.swiftformat) | インデント、折り返し、import の並び、末尾のカンマなどを自動で直す |
| SwiftLint | [.swiftlint.yml](.swiftlint.yml) | 自動では直せない問題(強制アンラップ、長すぎる関数など)を見つける |
| EditorConfig | [.editorconfig](.editorconfig) | 文字コード、改行、インデント幅をエディタに伝える |

主な決まり:

- インデントは空白4つ。1行は 120 文字まで。
- 複数行のコレクションには末尾のカンマを付ける。
- import はアルファベット順。`@testable import` は最後に置く。
- Swift 6 の言語モードで書き、警告を残さない。
- 時刻や ID は `Date()` や `UUID()` で直接作らず、`@Dependency` から受け取る(SwiftLint が検査します)。

SwiftLint の警告をやむを得ず止めるときは、範囲をいちばん狭くし、理由を添えます。

```swift
// swiftlint:disable:next force_unwrapping - 定数の URL なので必ず成功する
let url = URL(string: "https://example.com")!
```

## コマンド

よく使う操作は `make` にまとめています。一覧は `make help` で見られます。

| コマンド | すること |
|---|---|
| `make bootstrap` | `project.yml` から `Todo.xcodeproj` を生成する |
| `make build` | `Todo-Dev` を iOS シミュレータ向けにビルドする |
| `make test` | すべてのテストを実行する(`test-domain` のあとに `test-app`) |
| `make test-domain` | 純粋なロジックのテストを macOS 上で実行する(速い) |
| `make test-app` | ユニットテストと UI テストをシミュレータで実行する |
| `make test-ui` | UI テストだけをシミュレータで実行する |
| `make lint` | SwiftLint と SwiftFormat で検査する(ファイルは変えない) |
| `make format` | SwiftFormat で整形する(ファイルを書き換える) |
| `make format-check` | 整形が必要なファイルがないか確かめる |
| `make clean` | ビルドの成果物とテスト結果を消す |

スキームやシミュレータは変数で切り替えられます。

```sh
make build SCHEME=Todo-Prod
make test DESTINATION='platform=iOS Simulator,name=iPhone 17'
```

使えるシミュレータは `xcrun simctl list devices available` で確かめられます。既定の `DESTINATION` に書いたシミュレータが手元にないときは、上のように上書きしてください。

## テスト

| 対象 | 種類 | 求めること |
|---|---|---|
| `Domain` の判定や計算 | ユニットテスト | 変更には必ずテストを付ける。境界の値(ちょうど期限、0件、日付の変わり目)を含める |
| Reducer | ユニットテスト(TCA の `TestStore`) | アクションごとに、状態の変化と副作用を確かめる。依存は差し替え、時刻や ID を固定する |
| 重要な操作の流れ | UI テスト | 目標の追加から完了までなど、壊れると使えなくなる流れに絞る |

- 不具合を直すときは、先にその不具合を再現するテストを書きます。
- テストは実際の時刻、ネットワーク、端末の状態に頼らないようにします。
- UI テストは遅く、壊れやすいので、数を絞ります。細かい分岐は Reducer のテストで確かめます。
- `make test-domain` はシミュレータを使わず速いので、こまめに回します。`make test` は、プルリクエストを出す前などの節目で回します。
