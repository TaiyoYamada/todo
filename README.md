# Lockcast(仮称)

時間がゲームやショート動画に流れてしまう人のための、iPhone 用の ToDo アプリです。
長期の目標(1日の量)と、締切のあるタスクを登録します。終わっていない間は、選んだアプリをロックします。
ホーム画面の主役は ToDo の一覧ではなく、**次のロックまでの余裕**と、今日の**ロック予報**です。
ロックされてから動くのではなく、ロックされる前に片づけることを狙っています。

名前は仮のものです。商標の調査は済んでいません([公開前の確認事項](docs/engineering/release-checklist.md))。

## 現在の状態

最終更新: 2026-10-09

**実際のロックはまだ確かめられていません。** 実機と有料の開発者登録が要るためです。シミュレータではロックが模擬に置き換わり、「予報だけ」のアプリとして動きます。

| 区分 | 内容 |
|---|---|
| 実装済み | 初回設定、今日(余裕、ロック予報、これからの7日、今日の分、締切)、集中の計測、予定(目標とタスクの追加と編集、1行からの締切と所要時間の読み取り)、タスク完了時の実績入力、見積もりの自動補正、振り返り、設定、パス、ロックの前の通知、ウィジェット、コントロールセンターのボタン、集中の Live Activity |
| コードはあるが実機で未検証 | スクリーンタイム API によるロック、ロック開始時刻の予約、予約の時刻にロックを掛け直す拡張機能、ロック画面の文言を決める拡張機能、ロックするアプリを選ぶ画面 |
| まだない | ロック画面のボタンの動き、目標の保管、抜け道への対策、課金。アプリアイコンは仮のもの |
| テスト | `Domain` と `DatabaseClient` にはある。Reducer のテストは置き場だけ、UI テストは起動確認の1本だけ |

シミュレータでは、ロックの状態は計算され画面に出ますが、ほかのアプリは実際には止まりません。
詳しくは[仕様](docs/product/spec.md)の「実装の状況」と[設計](docs/engineering/architecture.md)の「分かっている制限」にあります。

## 必要なもの

| 必要なもの | バージョン | 入れ方 |
|---|---|---|
| Xcode | 27 以降(Swift 6.4) | App Store または Apple Developer |
| iOS シミュレータ | iOS 26 以上 | Xcode に同梱 |
| XcodeGen | 最新 | `brew install xcodegen` |
| SwiftLint、SwiftFormat | 最新 | `brew install swiftlint swiftformat` |
| xcbeautify(任意) | 最新 | `brew install xcbeautify` |

## 始め方

```sh
git clone https://github.com/TaiyoYamada/todo.git
cd todo
make bootstrap        # project.yml から Todo.xcodeproj を生成する
open Todo.xcodeproj   # スキーム Todo-Dev を選んで実行する
```

`Todo.xcodeproj` は生成物で、コミットしません。ファイルを足したり消したりしたら `make bootstrap` をやり直します。

シミュレータ向けのビルドに、開発者登録は要りません。実機に入れるには、Family Controls と App Group の権限を持つ署名が要ります。

### スキーム

| スキーム | 用途 | 端末に入る名前 | 識別子 |
|---|---|---|---|
| `Todo-Dev` | ローカル開発。見本データを使える。テストはこちらで回す | Lockcast Dev | `com.taiyoyamada.todo.dev` |
| `Todo-Prod` | 公開用 | Lockcast | `com.taiyoyamada.todo` |

### 見本データで起動する

`Todo-Dev` でだけ、起動引数 `-sampleData <状態>` が使えます。保存データには触れず、メモリ上の見本データで動きます。

| 状態 | 再現する場面 |
|---|---|
| `locked` | 今日の分が残っていて、ロックされている |
| `countdown` | ロックはまだだが、約2時間後に次のロックが来る |
| `free` | 今日の分をすべて終えて、自由 |
| `fresh` | 何も登録していない。初回設定から始まる |

Xcode では、スキームの編集画面で Run > Arguments に `-sampleData locked` を足します。コマンドラインでは次のとおりです。

```sh
make build
xcrun simctl install booted DerivedData/Build/Products/Debug-Dev-iphonesimulator/Todo.app
xcrun simctl launch booted com.taiyoyamada.todo.dev -sampleData locked
```

### よく使うコマンド

```sh
make test-domain   # 純粋なロジックのテスト(macOS 上で速い)
make test          # すべてのテスト(test-domain のあとにシミュレータでのテスト)
make lint          # SwiftLint と SwiftFormat の検査
make format        # SwiftFormat で整形
make help          # 一覧
```

## リポジトリの構成

```
App/                  アプリ本体。起動と、見本データの起動引数の読み取りだけ
Extensions/           ウィジェットと Live Activity、スクリーンタイムの拡張機能(入口だけ)
Packages/Domain/      純粋なロジックと型。ロックの判定、余裕の計算、見積もりの補正
Packages/TodoKit/     画面、保存、ロックや通知との境界、ウィジェットの見た目、部品
UITests/              UI テスト
Configs/              ビルド設定(xcconfig)。Dev と Prod を分ける
docs/                 仕様、設計、調査
project.yml           XcodeGen の設定
Makefile              開発用のコマンド
```

## 文書

| 文書 | 内容 |
|---|---|
| [docs/README.md](docs/README.md) | 文書の目次 |
| [docs/product/spec.md](docs/product/spec.md) | 仕様。アプリの振る舞いと、実装の状況 |
| [docs/product/decision-log.md](docs/product/decision-log.md) | 決定の記録と、その理由 |
| [docs/engineering/architecture.md](docs/engineering/architecture.md) | 設計の全体像 |
| [docs/engineering/development.md](docs/engineering/development.md) | 開発の手順 |
| [docs/engineering/release-checklist.md](docs/engineering/release-checklist.md) | 公開前の確認事項 |
| [docs/engineering/adr/](docs/engineering/adr/README.md) | 技術的な決定の記録 |
| [docs/research/](docs/research/README.md) | 市場、競合、事業モデル、リスクの調査 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | ブランチ、コミット、プルリクエストの約束 |

## ライセンス

このリポジトリは公開されていますが、オープンソースではありません。
[LICENSE](LICENSE) のとおり、閲覧のほかの利用(複製、改変、再配布)は許諾していません。外部からのプルリクエストも受け付けていません。
不具合の報告や提案は [Issue](https://github.com/TaiyoYamada/todo/issues/new/choose) からお願いします。
