# Yoyu(仮称)— 開発ガイド

後回しにしてきた大事なことを、スマホが止まる前に終わらせる iPhone アプリ。
仕様は `docs/product/spec.md`、決定の経緯は `docs/product/decision-log.md` にある。作業の前に仕様を読むこと。

## 進め方の約束

- **実装は、オーナーの明確な開始の合図を待つ。** 相談中に、推測でコードやファイルを作らない。「この進め方がいい」という合意と、「今から始めて」という指示は別物。
- 仕様にないことを足すときは、`docs/product/decision-log.md` に「Claude が決めたこと」として残す。
- できていないこと、確かめていないことは、そのとおり書く。未検証のコードには、その旨を文書に残す。
- 取り返しのつかない操作(強制プッシュ、履歴の書き換え、リポジトリ設定の変更、`main` へのマージ、課金や申請)は、オーナーの指示なしに行わない。

## Git

- Git-flow。`main` は公開済みの状態、`develop` は統合先。作業は `feature/<内容>` で行い、PR は `develop` に出す。
- マージはマージコミットで行う(squash しない)。細かい履歴を残すため。
- コミットは小さく刻む。1コミット1つの意図。
- コミットメッセージは `<type>: <日本語の説明>`。type は feat, fix, docs, style, refactor, perf, test, build, ci, chore。
  - 例: `feat: 目標の追加画面を実装`、`test: 着手リミットの計算のテストを追加`
- 署名や Co-Authored-By の行は付けない。

## コマンド

```sh
make bootstrap     # project.yml から Todo.xcodeproj を生成(XcodeGen)
make build         # Todo-Dev をシミュレータ向けにビルド
make test-domain   # 純粋なロジックのテスト(macOS 上で高速)
make test          # ユニットテスト + UI テスト
make lint          # SwiftLint + SwiftFormat の検査
make format        # SwiftFormat で整形
```

`Todo.xcodeproj` は生成物でコミットしない。ファイルを足したら `make bootstrap` をやり直す。
開発が一段落するまで、CI は手動実行のみ。テストも毎回は回さなくてよい(節目で回す)。

## 構成

```
App/                  アプリ本体(薄い。起動と依存の組み立てだけ)
Extensions/           ウィジェット、Live Activity、スクリーンタイムの拡張機能
Packages/TodoKit/     ほぼすべてのコード(ローカルの Swift パッケージ)
Configs/              ビルド設定(xcconfig)。Dev と Prod を分ける
docs/                 仕様、設計、調査
```

`Packages/TodoKit` のモジュール:

| モジュール | 役割 | 依存してよいもの |
|---|---|---|
| `Domain` | 純粋なロジックと型。ロックの判定、余裕の計算 | Foundation のみ |
| `DesignSystem` | 色、文字、部品、演出 | SwiftUI |
| `*Client` | 外の世界との境界(DB、ロック、通知、Live Activity) | Domain、Dependencies |
| `*Feature` | 画面ごとの Reducer と View | 上のすべて、TCA |

設計の詳細は `docs/engineering/architecture.md`。

## 設計の原則

- アーキテクチャは TCA。状態の変更は Reducer に集め、View は状態を描くだけにする。
- 外の世界(時刻、DB、スクリーンタイム、通知)には必ず依存(`@Dependency`)を通して触る。Reducer の中で `Date()` を直接呼ばない。
- 判定や計算は `Domain` に置き、テストを書く。ロックの判定を間違えると、外れない、または掛からないという一番困る不具合になる。
- 単一責任、重複の排除、不要な抽象化をしない(YAGNI)。迷ったら単純なほうを選ぶ。
- 永続化は SQLiteData。拡張機能は DB を開かず、App Group に置いた小さな写し(スナップショット)を読む。
- 外部ライブラリは、信頼できるものに絞る。足すときは `docs/engineering/adr/` に理由を残す。

## コードの書き方

- Swift 6 の言語モード。警告を残さない。
- 文言は String Catalog(`.xcstrings`)に置き、コードに直書きしない。日本語と英語の両方を必ず入れる。
- 文言は平易に。罪悪感や不安をあおる表現、医療的な表現(「依存症を治す」など)は使わない。
- コメントは「なぜ」を書く。「何をしているか」はコードで分かるようにする。
- アクセシビリティ(VoiceOver のラベル、Dynamic Type、視差効果を減らす設定)に対応する。

## スキーム

| スキーム | 用途 | 違い |
|---|---|---|
| `Todo-Dev` | ローカル開発 | 別アプリとして入る(名前と識別子が違う)。ロックは模擬、見本データを投入できる |
| `Todo-Prod` | 本番 | 本物のスクリーンタイム API を使う |

## 未検証のもの

スクリーンタイム API による実際のロックは、実機と有料の開発者登録が必要で、シミュレータでは確かめられない。該当コードを変えたら `docs/product/spec.md` の「未検証の部分」を更新する。
