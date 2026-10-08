# 開発の手順

最終更新: 2026-10-09

手元で動かし、変更を加えるための手順です。ブランチ、コミット、プルリクエストの約束は [CONTRIBUTING.md](../../CONTRIBUTING.md) にあります。設計は[設計の全体像](architecture.md)を見てください。

## 1. セットアップ

必要なものは Xcode 27 以降(Swift 6.4)、XcodeGen、SwiftLint、SwiftFormat です。入れ方は [README](../../README.md) にあります。

```sh
git clone https://github.com/TaiyoYamada/todo.git
cd todo
make bootstrap        # project.yml から Todo.xcodeproj を生成する
open Todo.xcodeproj
```

`Todo.xcodeproj` は生成物で、コミットしません。次のときに `make bootstrap` をやり直します。

- `App/`、`Extensions/`、`UITests/` にファイルを足した、または消した
- `project.yml` や `Configs/*.xcconfig` を変えた

`Packages/` の中にファイルを足すだけなら、やり直しは要りません。

`App/Info.plist`、`Extensions/*/Info.plist`、各 `.entitlements` は、XcodeGen が `project.yml` の内容で書き出します。直すときは、ファイルではなく `project.yml` を直します。

シミュレータ向けのビルドに、開発者登録は要りません。実機に入れるには、Family Controls と App Group の権限を持つ署名が要ります(未検証)。

## 2. コマンド

一覧は `make help` で出ます。

| コマンド | すること |
|---|---|
| `make bootstrap` | `Todo.xcodeproj` を生成する |
| `make build` | アプリを iOS シミュレータ向けにビルドする |
| `make test-domain` | `Domain` のテストを macOS 上で実行する。シミュレータを使わないので速い |
| `make test-app` | スキームに入っているテストをシミュレータで実行する(`DatabaseClientTests`、`AppFeatureTests`、`TodoUITests`) |
| `make test-ui` | UI テストだけを実行する |
| `make test` | `test-domain` のあとに `test-app` |
| `make lint` | SwiftLint と SwiftFormat で検査する(ファイルは変えない) |
| `make format` | SwiftFormat で整形する(ファイルを書き換える) |
| `make clean` | ビルドの成果物とテスト結果を消す |

変数で対象を切り替えられます。

```sh
make build SCHEME=Todo-Prod
make test-app DESTINATION='platform=iOS Simulator,name=iPhone 17'
```

既定のシミュレータは `iPhone 17` です。手元にないときは `xcrun simctl list devices available` で確かめて、`DESTINATION` を上書きします。

注意点:

- `make lint` は、2026-10-09 時点で違反を報告して失敗します(行の長さ、画像のアクセシビリティ、`Date()` の直接呼び出しなど)。未解消です。
- CI は手動実行だけで、まだ一度も実行していません。手元の `make test` が品質の確認になります。

## 3. スキーム

| | `Todo-Dev` | `Todo-Prod` |
|---|---|---|
| 設定ファイル | `Configs/Dev.xcconfig` | `Configs/Prod.xcconfig` |
| 端末に入る名前 | Lockcast Dev | Lockcast |
| 識別子 | `com.taiyoyamada.todo.dev` | `com.taiyoyamada.todo` |
| 拡張機能の識別子 | 上に `.widgets`、`.shield-monitor`、`.shield-configuration` を付けたもの | 同じ |
| App Group の識別子 | `group.com.taiyoyamada.todo.dev` | `group.com.taiyoyamada.todo` |
| コンパイル条件 `DEV` | あり | なし |
| 起動引数 `-sampleData` | 使える | 無視される |
| スキームに入っているテスト | あり | なし |
| 保存データ | 別(別のアプリとして入るため) | 別 |

版(`MARKETING_VERSION`、`CURRENT_PROJECT_VERSION`)、対応 OS、Swift の版は `Configs/Base.xcconfig` で共通です。

**ロックが本物か模擬かは、スキームでは決まりません。** ビルド先で決まります。シミュレータは模擬、実機は本物(未検証)です。実機に入れた `Todo-Dev` は本物のスクリーンタイム API を呼びます。

`DEV` はアプリ本体のターゲットにだけ付きます。`Packages/` の中では `#if DEV` は使えません。

## 4. 見本データ

`Todo-Dev` で、起動引数 `-sampleData <状態>` を付けると、保存データの代わりにメモリ上の見本データで動きます。

| 状態 | 場面 |
|---|---|
| `locked` | 今日の分(大学院入試 45 分、TOEIC 20 分)が残っていて、ロックされている |
| `countdown` | 大学院入試は終えた。TOEIC のロックが 2 時間 14 分後に来る |
| `free` | 今日の分をすべて終え、今日が締切のタスクも完了した |
| `fresh` | 何も登録していない。初回設定から始まる |

`fresh` 以外には、過去 13 日ぶんの記録、未完了のタスク 2 件、完了済みのタスク 3 件(見積もりの学習に使われる)、2 日前のパス 1 回が入ります。`free` では、未完了のタスクのうち 1 件も完了済みになります。

- 付け方: Xcode のスキームの編集画面で、Run > Arguments に `-sampleData locked` を足す。コマンドラインからの起動は [README](../../README.md) を参照。
- 何時に起動しても同じ場面になるよう、時刻は起動した時点から計算する。そのため、見本データでは1日の開始時刻が設定の範囲(0〜8 時)を外れることがある。
- 目標名とタスク名は、端末の言語が日本語なら日本語、それ以外は英語になる。
- 変更はメモリ上だけで、起動し直すと元に戻る。
- 知らない名前を渡すと、見本データは使われず、ふつうの保存データで起動する。
- 定義は `Packages/TodoKit/Sources/AppFeature/Support/SampleData.swift`。UI テストも同じものを使う。
- 同じ見本データで、主要な画面の Xcode プレビューを用意してある(`Support/Previews.swift`)。画面の見た目だけを直すときは、こちらのほうが速い。

模擬のロックの切り替わりは、ログで見られます。

```sh
xcrun simctl spawn booted log stream --level info --predicate 'subsystem == "com.taiyoyamada.todo"'
```

## 5. 文言を足す

文言はコードに直書きしません。使う場所に合わせて、次のカタログに置きます。

| 使う場所 | カタログ |
|---|---|
| アプリの画面、通知 | `Packages/TodoKit/Sources/AppFeature/Resources/Localizable.xcstrings` |
| ウィジェット、Live Activity | `Packages/TodoKit/Sources/WidgetUI/Resources/Localizable.xcstrings` |
| ロック画面(シールド) | `Extensions/ShieldConfiguration/Localizable.xcstrings` |

手順は同じです。

1. Xcode でカタログを開き、キーを足す。
2. 英語と日本語の**両方**を入れる。片方だけでは足したことにならない。
3. 一度ビルドする。Xcode がキーからシンボルを生成する。
4. コードから、生成されたシンボルで参照する。

キーの付け方:

- `<画面>.<まとまり>.<役割>` の形で、ドットで区切る。英小文字で始め、語をつなぐときはキャメルケースにする。
- 画面をまたいで使うものは `common.` で始める。
- 英語の文そのものをキーにしない。

キーとシンボルの対応:

| キー | 英語の値 | コードでの書き方 |
|---|---|---|
| `today.slack.label` | Free until next lock | `Text(.todaySlackLabel)` |
| `goal.lock.atTime.footer` | Your apps lock at this time… | `Text(.goalLockAtTimeFooter)` |
| `today.cta.startFocus` | Start “%@” | `Text(.todayCtaStartFocus(goal.title))` |
| `today.pass.button` | Hold to use a pass (%lld left this week) | `Text(.todayPassButton(status.passesRemaining))` |
| `insights.passes.value` | %1$lld of %2$lld | `Text(.insightsPassesValue(used, limit))` |
| `common.today` | Today | `String(localized: .commonToday)` |

規則は、ドットを取り除き、2つめ以降の区切りの先頭を大文字にする、です。`%@` は文字列の引数、`%lld` は整数の引数になります。語順が言語で変わる文は、`%1$@` のように番号を付けます。

文言の書き方:

- 平易に書く。罪悪感や不安をあおる表現、医療的な表現(「依存症を治す」など)は使わない。
- 時間の長さ、時刻、日付、曜日は文言に埋め込まず、`DurationText`、`TimeText` などの書式に任せ、引数で渡す。
- カタログの JSON を直接書くときは、`"extractionState": "manual"` を付ける。

ロック画面の拡張機能だけ、いまはシンボルではなくキーの文字列で参照しています(`String(localized: "shield.button")`)。打ち間違いがコンパイル時に分からないので、足すときはキーをよく確かめます。

## 6. データベースの移行を足す

表の形を変えるときは、`Packages/TodoKit/Sources/DatabaseClient/Schema.swift` の `migrator` に、新しい移行を**末尾に**足します。

```swift
migrator.registerMigration("v2: タスクにメモの列を足す") { db in
    try #sql(
        """
        ALTER TABLE "tasks" ADD COLUMN "note" TEXT
        """
    )
    .execute(db)
}
```

決まり:

- **一度配布した移行は書き換えない。** 名前も中身も変えない。直したいときは、次の移行を足す。TestFlight での配布も「配布」に含める。
- まだ一度も配布していないので、いまの `v1` は公開までなら直せる。直したら、手元のシミュレータからアプリを消して入れ直す(古い形の DB が残るため)。迷ったら、直さずに新しい移行を足す。
- 移行は SQL の文字列で書く。行の型(`@Table`)を移行の中で使わない。型はあとで変わるが、移行は変わってはいけないため。
- 既存の行がある前提で書く。`NOT NULL` の列を足すときは `DEFAULT` を付ける。

移行と合わせて直すもの:

| 場所 | 内容 |
|---|---|
| `Schema.swift` の行の型 | `@Table` の構造体に項目を足す |
| `Schema.swift` の変換 | `Domain` の型との相互変換 |
| `Packages/Domain` の型 | `Codable` で写し(`snapshot.json`)にも入る。項目を足すときは、古い写しを読めるかを考える |
| `Schema.swift` の `live` | 新しい操作が要るなら足す |
| `InMemory.swift` | メモリ上の実装にも同じ操作を足す |
| `LiveDatabaseClientTests` | 読み書きのテストを足す |
| [設計](architecture.md) 5 | 表の説明を直す |

設定(`Preferences`)に項目を足すだけなら、移行は要りません。JSON で1列に入っているためです。`Preferences` の `init(from:)` に、欠けていたら初期値を使う1行を足します。

## 7. 画面(機能)を足す

画面はすべて `Packages/TodoKit/Sources/AppFeature/` にあります。

1. フォルダを作り、`<名前>Feature.swift`(Reducer)と `<名前>View.swift`(View)を置く。
2. Reducer を書く。
   - `@Reducer struct`、`@ObservableState struct State: Equatable`。
   - 保存データやロックの状態を見るなら、`State` に `@SharedReader(.board) var board` を置く。
   - 保存するときは `@Dependency(\.database)` の操作を呼ぶ。`Board` は書き換えない。
   - 時刻は `@Dependency(\.date.now)`、ID は `@Dependency(\.uuid)`、待ちは `@Dependency(\.continuousClock)` から受け取る。`Date()` や `UUID()` を直接呼ばない。
   - ロックは `@Dependency(\.shield)`、通知は `@Dependency(\.notifications)`、Live Activity は `@Dependency(\.liveActivity)` を通す。
   - 判定や計算は Reducer に書かず、`Domain` に置いてテストする。
3. View を書く。`StoreOf<…>` を受け取り、状態を描いて、操作をアクションとして送るだけにする。
4. 開き方をつなぐ。

シートや全画面として開く場合:

| 直す場所 | 内容 |
|---|---|
| `Support/Board.swift` の `Route` | 開く依頼を表す case を足す |
| 開く側の Reducer | `.send(.delegate(.<新しい Route>))` を返す |
| `App/AppFeature.swift` の `Destination` | 画面の case を足す |
| `App/AppFeature.swift` の `open(_:_:)` | `Route` から `Destination` の状態を作る |
| `App/AppView.swift` | `.sheet(item:)` か `.fullScreenCover(item:)` を足す |

閉じるときは、子の Reducer が `@Dependency(\.dismiss)` を呼びます。

タブとして足す場合は、`AppFeature` の `Tab` と `State` に足し、`Scope` でつなぎ、`AppView` の `tabs` に `Tab` を足します。

5. 文言をカタログに足す(5 を参照)。
6. Reducer のテストを `Packages/TodoKit/Tests/AppFeatureTests` に足す。`TestStore` で、アクションごとの状態の変化と副作用を確かめる。
7. `Support/Previews.swift` に、その画面のプレビューを足す。
8. 見た目を変えたら、VoiceOver、Dynamic Type、「視差効果を減らす」で確かめる。

外部ライブラリを足すときは、先に [ADR](adr/README.md) を書きます。

## 8. シミュレータで確かめられないこと

次のものは、実機と有料の開発者登録(Family Controls の権限)がないと確かめられません。該当のコードを変えたら、[仕様](../product/spec.md)の「未検証の部分」を更新します。

| 確かめられないこと | 理由 |
|---|---|
| ほかのアプリが実際にロックされること | スクリーンタイム API はシミュレータで動かない。模擬の実装はログを出すだけ |
| スクリーンタイムの許可の画面 | 模擬の実装は、許可を求めると必ず成功を返す |
| ロックするアプリの選択 | シミュレータでは OS の選択画面を出さず、説明だけを出す。模擬の実装は 6 件を選んだことにする |
| アプリを閉じている間の、時刻どおりのロック開始 | DeviceActivity の予約と、監視の拡張機能(`Extensions/ShieldMonitor`)が要る。シミュレータ向けのビルドでは、拡張機能は何もしない |
| ロック画面(シールド)の見た目とボタン | ロックされたアプリを開いたときに OS が出す画面。シミュレータではロックされないので出ない |
| 実機向けの署名 | Family Controls の権限には、有料の開発者登録が要る。まだ一度も試していない |

実機で確かめる項目の一覧は[公開前の確認事項](release-checklist.md)にあります。

シミュレータで試せるのは、次のものです。

- ロックの**判定**と、それを見せる画面。時刻が絡む動きは、見本データと `Domain` のテストで確かめる
- ロックの前の通知(通知の許可は、初回設定を終えた直後に求められる)
- ウィジェット(ホーム画面とロック画面)。写しは模擬の実装でも書き出す
- 集中の Live Activity

ウィジェットと通知は、ロックの状態が変わったときにしか更新されません。目標を足した直後に内容が変わらないのは、いまの作りの制限です([設計](architecture.md) 8)。
