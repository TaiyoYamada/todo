# 競合アプリ調査

調査日: 2026-10-09

## 結論

1. **「長期目標の1日ノルマを終えるまでロック（クイズなし）」は新規性がない。** 日本では [TodoLock](https://apps.apple.com/jp/app/id6760632571) と [あとスマ](https://apps.apple.com/jp/app/id6782053907)、海外では [Unrot](https://apps.apple.com/us/app/id6746537171)（米国評価 約5.7万件）をはじめ、2026年だけで十数本が同じ仕組みで出ている。
2. **「締め切り − 所要時間 の時点から自動でロック」は、今回の調査範囲では見つからなかった。** ただし隣接機能は既にある。[Proc](https://apps.apple.com/us/app/id6775617660) は締め切りから逆算した日割りノルマでロックし、[Structured × one sec 連携](https://tutorials.one-sec.app/en/articles/3035010) は「未完了タスクの時間枠の間ブロック」を無料で提供している。差は「開始時刻をアプリが自動で決めるか」だけで、既存アプリが追加するのは難しくない。
3. **「ロックまでの残り余裕」を主画面にしたアプリは見つからなかった。** 近いのは [Finiti](https://apps.apple.com/app/id6761764736) のロック画面カウントダウン（締め切りまでの日数）と、ブロック中の残り時間を出す Live Activity（[CoLock](https://apps.apple.com/jp/app/id6754523922) など）で、どちらも「ロックが始まるまで」ではない。
4. **「ドパガキ」という訴求は日本で先に使われている。** [あとスマ](https://apps.apple.com/jp/app/id6782053907) はアプリ名に「ドパガキ対策」を入れ、[ドパロック](https://apps.apple.com/jp/app/id6774131105) は説明文を「ドパガキ、卒業。」で始めている（いずれも2026年6〜7月公開）。
5. **緊急パス（15分）も既出。** [TaskLock（Ali Firat Celik）](https://apps.apple.com/us/app/id6792368867) は「1日1回・15分の Emergency Pass」、Finiti は「1日10分の緊急一時停止」を備える。

見つからなかったことは「存在しない」ことの証明ではない。検索は App Store の日米ストアと英語・日本語のウェブに限り、Android、中国・韓国ストア、未公開の開発中アプリは見ていない。

## 調査方法と数字の読み方

- 評価件数・公開日・対応OSは、Apple の iTunes Lookup API（例: `https://itunes.apple.com/lookup?id=1497465230&country=us`）で 2026-10-09 に取得した値。
- 機能の説明は各社の App Store 掲載文に基づく。**開発者の宣伝文であり、実機での動作は未確認。**
- ダウンロード数は公開されていないアプリが大半で、評価件数を規模の目安として使った。評価件数からダウンロード数への換算は行っていない。
- 価格は App Store の「App内課金」欄の表示。同名で複数価格が並ぶ場合があり、どれが通常価格かは未確認。

## 新規性の検証（3つの主張ごと）

| 主張 | 判定 | 最も近い既存例 | 既存例との差 |
|---|---|---|---|
| (a) 締め切り前、所要時間ぶん手前から自動ロック | 見つからず | [Proc](https://theprocapp.com/)（締め切りまでの日数で課題を日割りし、日次目標を満たすまでロック）、[Structured × one sec](https://tutorials.one-sec.app/en/articles/3035010)（未完了タスクの時間枠中にブロック）、[TaskWarden](https://apps.apple.com/app/id6759471039)（期限超過でブロック）、[Finiti](https://apps.apple.com/app/id6761764736)（締め切り日まで毎日1・2・5時間の固定枠でブロック） | ロック開始時刻を「締め切り − 見積もり」で自動計算する点だけが残る |
| (b) 「ロックまでの残り時間」を主画面・ウィジェット・Live Activity に出す | 見つからず | [Finiti](https://apps.apple.com/app/id6761764736)（ロック画面に1日1点のカウントダウン）、[AppBlock](https://appblock.app/?p=336)（ウィジェットでスケジュール確認・残り時間表示。詳細は未確認）、[CoLock](https://apps.apple.com/jp/app/id6754523922)（制限中の残り時間を Live Activity 表示） | 既存はブロック中の残り時間か締め切りまでの日数。ロック開始までの猶予を主役にした例は確認できなかった |
| (c) 長期目標の1日ノルマでゲート（クイズなし） | **既に多数ある** | [TodoLock](https://apps.apple.com/jp/app/id6760632571)、[あとスマ](https://apps.apple.com/jp/app/id6782053907)、[Unrot](https://apps.apple.com/us/app/id6746537171)、[Habit Doom](https://apps.apple.com/us/app/id6757255783)、[Daybound](https://apps.apple.com/app/id6751446752)、[TaskLock](https://apps.apple.com/us/app/id6792368867)、[GoalLock](https://apps.apple.com/us/app/id6744908131)、[Locky](https://apps.apple.com/us/app/id6759135387) | 差別化要素にならない |

補足として、ユーザー側の要望は実在する。Opal のフォーラムには「課題にどれだけかかるか分からないので明日までブロックしたい」という要望があり（[出典](https://community.opalapp.com/t/manually-block-an-app-until-tomorrow/10754)）、ADHD向けプランナー Yoodoo には「タスク完了まで自動でアプリをブロックしてほしい」という要望が検討中になっている（[出典](https://yoodooapp.featurebase.app/p/automatic-app-blocking-until-task-is-done)）。

締め切りと見積もり時間から予定を自動で組むプランナー（例: [Motion](https://www.usemotion.com/blog/best-time-blocking-apps)）は存在するが、アプリのブロックは行わない。

## 最も近い競合（締め切り・タスク連動型）

| アプリ | 仕組み | 価格 | 評価件数 | 公開 | 備考 |
|---|---|---|---|---|---|
| [Proc: Procrastination Blocker](https://apps.apple.com/us/app/id6775617660) | 課題を締め切りまでの日数に分割し、日次の進捗目標に届くまでロック。進捗は提出物を AI が採点。Canvas から課題を取り込む。先に進めると翌日の余裕が貯まる | 月 $5.99 / 年 $49.99、3日無料。全機能が課金必須（[出典](https://theprocapp.com/)） | 米 6 | 2026-07 | 「締め切りを知っているブロッカー」として最も近い。日割り方式で、直前まで放置させない設計 |
| [Finiti: Deadline App Blocker](https://apps.apple.com/app/id6761764736) | 目標と締め切り日を決め、毎日の固定枠（1・2・5時間）でブロック。ロック画面に日数カウントダウン。1日10分の緊急一時停止 | 月 $5.99 / 年 $19.99（7日無料） | 米 1 | 2026-04 | iOS 26.0 以降。「Deadline App Blocker」という名称を先に使っている |
| [TaskWarden](https://apps.apple.com/app/id6759471039) | リマインダーが期限超過になるとブロック。写真による完了証明、Live Activity | 月 $3.99 / 年 $29.99。オンボーディング後は課金必須 | 米 4 | 2026-05 | iOS 26.0 以降。締め切り「後」のロック |
| [Structured](https://apps.apple.com/us/app/id1499198946) × [one sec](https://apps.apple.com/us/app/one-sec-screen-time-focus/id1532875441) | Structured の未完了タスクの時間枠の間、one sec がアプリを開けなくする。完了にすると解除（[出典](https://tutorials.one-sec.app/en/articles/3035010)） | 連携は無料（[出典](https://one-sec.app/integrations/structured/)） | Structured 米 167,213 / one sec 米 23,666 | 既存 | 既存の大手2本の組み合わせ。ユーザーがタスクを直前に置けば、挙動は (a) とほぼ同じになる |
| [TaskLock: To-Do App Blocker](https://apps.apple.com/us/app/id6792368867) | 「Locking」にした ToDo や日課が終わるまでブロック。日課に開始時刻を付けられる（例: 21時から歯磨きまでロック）。1日1回15分の Emergency Pass | 無料枠はロック付き ToDo 1件と日課1件。Premium の価格は未確認 | 米 0 | 2026-08 | 緊急パスの仕様がこちらの案とほぼ同じ |
| [TaskLock: To Do & Block Apps](https://apps.apple.com/jp/app/id6760604253) | タスクまたはカレンダー予定を選び、終わるまでブロック。Apple カレンダー同期 | 未確認 | 米 14 / 日 1 | 2026-04 | 29言語対応、日本語あり |
| [TodoLock](https://apps.apple.com/jp/app/id6760632571) | 今日のタスクが残っている間ロックし、全完了で解除。繰り返しタスク、リマインダー連携、ウィジェット | Pro あり（価格未確認） | 日 0 | 2026-04 | **日本語。「今日のノルマが終わるまでロック」をそのまま実装済み** |
| [Daybound](https://apps.apple.com/app/id6751446752) | タスク完了までロック。写真で完了証明。「タイマーなし」を明言 | 月 $5.99 / 年 $35.99 | 米 9 | 2026-01 | ADHD向けの訴求 |
| [GoalLock](https://apps.apple.com/us/app/id6744908131) | その日のタスクの達成率が自分で決めた閾値（例: 70%）を超えると解除 | 未確認 | 米 10 | 2025-05 | |
| [Locky](https://apps.apple.com/us/app/id6759135387) | 現実のタスクを終え、写真を AI が確認すると当日は解除 | 未確認 | 米 1 | 2026-03 | |
| [Stratum](https://apps.apple.com/us/app/id6761681343) | 学習タイマー、アプリブロック、締め切りプランナー。Pro に「締め切りから学習セッションを提案」 | サブスク（価格未確認） | 米 0 | 2026-06 | 締め切りとブロックを同居させているが、連動の詳細は未確認 |
| [Bloko](https://apps.apple.com/us/app/bloko-app-blocker-focus-time/id6648773531) | ToDo 完了までブロック | 未確認 | 米 5 | 2024-09 | |

## 「稼いで解除」型（習慣・集中時間で解除権を得る）

| アプリ | 仕組み | 価格 | 評価件数 | 公開 |
|---|---|---|---|---|
| [Unrot](https://apps.apple.com/us/app/id6746537171) | 現実の習慣（タイマーまたは写真で確認）でコインを得て、ロックしたアプリを開く | 課金必須。App内課金は $9.99〜$69.99 の範囲で複数 | 米 56,846 / 日 97 | 2025-06 |
| [あとスマ](https://apps.apple.com/jp/app/id6782053907) | 集中タイマーで「カギ」を貯め、カギでロックを解除。初期設定は1時間集中で最大20分 | 月 ¥1,980 / 年 ¥7,980（年 ¥3,980 の表示もあり） | 日 16 | 2026-07 |
| [Habit Doom](https://apps.apple.com/us/app/id6757255783) | 習慣を記録すると利用時間が貯まる。写真の端末内 AI 検証あり | 月 $4.99 / 年 $19.99 / 買い切り $29.99（[自社ブログ](https://habitdoom.com/blog/task-based-app-blocker-iphone-2026)） | 米 21 | 2026-02 |
| [BePresent](https://apps.apple.com/us/app/id1644737181) | ブロックセッション、連続記録、ポイントで現実の特典 | 月 $3.99〜$14.99 / 年 $24.99〜$59.99 の複数表示 | 米 66,500 / 日 30 | 2022-09 |
| [Earned](https://apps.apple.com/us/app/id6781796831) | 未確認 | 未確認 | 米 0 | 2026-06 |

## クイズ・学習で解除する型

| アプリ | 仕組み | 価格 | 評価件数 | 公開 |
|---|---|---|---|---|
| [StudyJunkie](https://apps.apple.com/jp/app/studyjunkie/id6758565892) | ロックしたアプリを開く前に数学・英単語などのクイズ。日本語対応 | 無料（App内課金の表示なし） | 日 4 | 2026-03 |
| [ScrollToll](https://apps.apple.com/us/app/id6757320347) | 1問正解で5分解除し、自動で再ロック。MCAT など試験対策 | 無料開始、上位機能は課金（価格未確認） | 米 735 | 2026-02 |
| [Study Guard](https://apps.apple.com/us/app/id6744607430) | 自作フラッシュカードに正解して解除 | 無料トライアル後は課金必須 | 米 376 | 2025-04 |
| [Recess](https://apps.apple.com/us/app/id6777757202) | ノートや PDF から AI がカードを生成。試験日が近づくと出題量を増やす「exam ramp」 | Pro サブスク（価格未確認） | 米 23 | 2026-08 |
| [TakeTime](https://apps.apple.com/us/app/id6757314402) | 制限に達すると短い学習問題。SAT、AP、LeetCode | 未確認 | 米 20 | 2026-02 |
| [Study Lock](https://apps.apple.com/us/app/id6758857561) | 教材から AI がクイズを生成し、正解で利用時間を得る | 未確認 | 米 8 | 2026-02 |
| [Not Rot](https://apps.apple.com/us/app/id6794893428) | クイズでトークンを得て解除 | 未確認 | 米 7 | 2026-08 |
| [DrillLock](https://apps.apple.com/jp/app/id6759181330) | 時間指定ロック。開くには計算問題を解く。解除は10分・1日3回まで | 無料 + PRO（価格未確認） | 日 6 | 2026-02 |

依頼にあった「Exam Master」「Do Unlock」は、同名のブロッカーを App Store 検索で特定できなかった（未確認）。

## 汎用ブロッカー（規模の大きい既存勢）

### 海外

| アプリ | 仕組み | 価格 | 評価件数（米 / 日） | 順位など |
|---|---|---|---|---|
| [Opal](https://apps.apple.com/us/app/opal-screen-time-control/id1497465230) | スケジュール・タイマーでブロック、集中スコア、ランキング | 月 $19.99 / 年 $99.99、学生向け週額あり。無料枠あり | 89,384 / 3,285 | 米・仕事効率化 無料76位 |
| [one sec](https://apps.apple.com/us/app/one-sec-screen-time-focus/id1532875441) | 開く前に数秒の間を挟む（ブロックではなく遅延） | 月 $6.99 / 年 $19.99 / 買い切り $99.99 | 23,666 / 7,621 | 30言語対応 |
| [ScreenZen](https://apps.apple.com/us/app/id1541027222) | 開く前の待ち時間、回数制限など | 無料。任意のチップ $5〜$40（[出典](https://www.whistleout.com/CellPhones/Apps/screenzen-app-review)） | 51,200 / 584 | |
| [Brick](https://apps.apple.com/us/app/id6448794069) | 物理タグに iPhone をかざして解除 | 本体 約$59、アプリ無料（[出典](https://getbrick.com/products/brick)） | 56,551 / — | |
| [Lock In](https://apps.apple.com/us/app/id6746586837) | 仕組みは未確認 | 未確認 | 27,409 / — | 2025-06 公開 |
| [Refocus](https://apps.apple.com/us/app/id1645639057) | 未確認 | 未確認 | 11,551 / — | |
| [ClearSpace](https://apps.apple.com/us/app/id1572515807) | ブロックと利用制限 | 未確認 | 8,895 / — | |
| [AppBlock](https://apps.apple.com/us/app/id1515753232) | スケジュール、場所、Wi-Fi でブロック | 未確認 | 6,771 / 2,100 | |

### 日本

| アプリ | 仕組み | 価格 | 評価件数（日） | 順位など |
|---|---|---|---|---|
| [スタロック](https://apps.apple.com/jp/app/id6504188981) | すぐロック、予約ロック、解除に手間をかける「約束」機能 | 月 ¥590 / 年 ¥4,900（割引表示 ¥3,500・¥2,390）/ 買い切り ¥9,900 | 8,406 | 仕事効率化 無料96位 |
| [Blockin](https://apps.apple.com/jp/app/id1659162950) | 時間帯・上限ブロック、解除不能モード、収集要素 | 月 ¥1,650 / 年 ¥6,600 / 買い切り ¥13,000 | 19,456 | ヘルスケア 無料66位 |
| [スマホをやめれば魚が育つ](https://apps.apple.com/jp/app/id1669133971) | 未確認（スクリーンタイム連動の育成系） | 未確認 | 16,181 | |
| [Zentime](https://apps.apple.com/jp/app/id6748847369) | ロックによるスマホ制限 | 未確認 | 1,505 | 2025-11 公開 |
| [ドパロック](https://apps.apple.com/jp/app/id6774131105) | 時間指定ロック、強制ブロックモード、取り戻した時間の記録 | 月 ¥400 / 年 ¥2,480 / 買い切り ¥3,980 | 12 | 2026-06 公開。「ドパガキ」訴求 |
| [CoLock](https://apps.apple.com/jp/app/id6754523922) | 友人と制限状況を共有、ランキング、Live Activity | Pro あり（価格未確認） | 9 | 2025-11 公開 |

### 参考: ブロックしない学習アプリ（日本の学生の定番）

| アプリ | 内容 | 評価件数（日） |
|---|---|---|
| [Studyplus](https://apps.apple.com/jp/app/id505410049) | 勉強記録と集中タイマー | 339,050 |
| [集中](https://apps.apple.com/jp/app/id1387759250) | 作業タイマーと記録。掲載文は「スマホ使用制限いらず」をうたい、ブロック機能の記載はない | 133,117 |

日本の学生向けでは、ブロックしない記録・タイマー系のほうが評価件数で1〜2桁大きい。ブロックそのものより「続く仕組み」に需要が寄っている可能性がある（解釈であり未検証）。

## 名称「Yoyu」の衝突（詳細は critique-and-ideas.md）

日本の App Store に既に3本ある: [Yoyu 出発判断タイマー](https://apps.apple.com/jp/app/id6778750422)（仕事効率化、2026-06）、[YOYU](https://apps.apple.com/jp/app/id6794309370)（家計簿、2026-08）、[ヨユウ](https://apps.apple.com/jp/app/id6763001725)（セルフケア、2026-06）。

## この調査から言えること

- 2026年に入ってからの新規参入が非常に多く、その大半は評価件数が0〜20件にとどまる。機能を作ることより、見つけてもらうことのほうが難しい市場になっている。
- 規模を持つのは、汎用ブロッカー（Opal、ScreenZen、BePresent、Brick）と「稼いで解除」の Unrot。タスク・締め切り連動型で評価1,000件を超えた専業アプリは確認できなかった。
- 新規性が残るのは (a) の自動計算と (b) の予報 UI の組み合わせ。(c) を売りにすると既存勢と区別がつかない。
