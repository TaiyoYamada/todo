# 文書の目次

Lockcast(仮称)の文書の一覧です。アプリの概要と始め方は、リポジトリの [README](../README.md) にあります。

迷ったら、[仕様](product/spec.md) → [設計の全体像](engineering/architecture.md) → [開発の手順](engineering/development.md) の順に読みます。

## 製品

| 文書 | 内容 |
|---|---|
| [product/spec.md](product/spec.md) | 仕様。ロックの規則、余裕の表示、画面、実装の状況、未検証の部分 |
| [product/decision-log.md](product/decision-log.md) | 仕様に関する決定と理由の記録。区切りごとの見直し(壁打ち)も含む |

## 開発

| 文書 | 内容 |
|---|---|
| [engineering/architecture.md](engineering/architecture.md) | 設計の全体像。モジュール、データの流れ、ロックのモデル、画面の移動、保存の形、分かっている制限 |
| [engineering/development.md](engineering/development.md) | 開発の手順。セットアップ、コマンド、スキーム、見本データ、文言、移行、画面の足し方 |
| [engineering/release-checklist.md](engineering/release-checklist.md) | 公開前の確認事項。開発者登録、権限の申請、実機検証、商標、プライバシー、審査、料金、画像 |

## 技術的な決定の記録(ADR)

| 文書 | 内容 |
|---|---|
| [engineering/adr/README.md](engineering/adr/README.md) | 一覧、書き方、ひな形 |
| [engineering/adr/0001-tca.md](engineering/adr/0001-tca.md) | アーキテクチャに TCA を使う |
| [engineering/adr/0002-sqlitedata.md](engineering/adr/0002-sqlitedata.md) | 永続化に SQLiteData を使い、監視は GRDB を直接使う |
| [engineering/adr/0003-xcodegen-and-local-packages.md](engineering/adr/0003-xcodegen-and-local-packages.md) | XcodeGen と、2つのローカルパッケージで構成する |
| [engineering/adr/0004-shared-board-state.md](engineering/adr/0004-shared-board-state.md) | 全画面が1つの Board を共有し、書くのは AppFeature だけにする |
| [engineering/adr/0005-screen-time-boundary.md](engineering/adr/0005-screen-time-boundary.md) | スクリーンタイム API を境界の向こうに置き、拡張機能には写しを渡す |
| [engineering/adr/0006-string-catalog-symbols.md](engineering/adr/0006-string-catalog-symbols.md) | 文言は String Catalog に置き、生成されたシンボルで参照する |
| [engineering/adr/0007-estimate-calibration.md](engineering/adr/0007-estimate-calibration.md) | 着手リミットを、本人の実績から自動で前倒しする |

## 調査

2026-10-09 時点の調査です。当時の仮称(Yoyu)のまま書かれています。

| 文書 | 内容 |
|---|---|
| [research/README.md](research/README.md) | 調査の要約と読み方 |
| [research/competitors.md](research/competitors.md) | 競合アプリの一覧、価格、評価件数、新規性の検証 |
| [research/market-and-demand.md](research/market-and-demand.md) | 需要の根拠、既存アプリの規模、日本での到達可能規模 |
| [research/business-model.md](research/business-model.md) | 競合の課金、推奨する価格と無料範囲、収支の目安 |
| [research/risks.md](research/risks.md) | 技術、審査、権限の承認、すり抜け、未成年、継続率、表現のリスク |
| [research/critique-and-ideas.md](research/critique-and-ideas.md) | 差別化の評価、設計上の弱点、強化案、名称の検討 |

## リポジトリの直下にある文書

| 文書 | 内容 |
|---|---|
| [../README.md](../README.md) | アプリの概要、現在の状態、始め方 |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | ブランチ、コミット、プルリクエスト、コードスタイル、テストの約束 |
| [../CLAUDE.md](../CLAUDE.md) | Claude Code 向けの開発ガイド。進め方の約束と設計の原則 |
| [../LICENSE](../LICENSE) | ライセンス(公開しているが、オープンソースではない) |

## 文書を書くときの約束

- 日本語で、平易に書く。結論を先に書く。
- コードについて書くことは、コードを読んで確かめる。まだ作っていないものは「未実装」「予定」、動かして確かめていないものは「未検証」と書く。
- 仕様を変えたら [product/spec.md](product/spec.md) を直し、理由を [product/decision-log.md](product/decision-log.md) に足す。
- 技術的な決定は ADR に書く。
- 相対リンクを書いたら、リンク先があることを確かめる。
