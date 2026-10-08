# リスク

調査日: 2026-10-09

## 結論（重い順）

1. **ロック開始の確実性が Apple の API に依存し、その API は不安定だと多数の開発者が報告している。** 「締め切りの○時間前に必ずロックされる」が売りのアプリで、ロックが始まらない日があると商品価値がなくなる。
2. **Family Controls の配布エンタイトルメントは承認待ちが読めない。** 数日で通った報告と、2か月近く応答がない報告の両方がある。公開日を決める前に申請する。
3. **「完了」を自己申告で押せば解除できる。** 設定アプリから Screen Time の許可を切る抜け道も知られている。すり抜けは競合レビューでも主要な不満。
4. **対象に高校生（18歳未満）が含まれる。** ファミリー共有の子どもアカウントで、本人による認可が通るかどうかは確認できていない。
5. **ロックされた瞬間に消される。** サブスク全般でも年額の1年後継続は3割弱。ブロッカーに固有の継続率データは公開されていない。

## 一覧

| # | リスク | 深刻度 | 起きやすさ | 対策の方向 |
|---|---|---|---|---|
| 1 | スケジュールどおりにロックが始まらない・解除されない | 高 | 高 | 多重化と自己修復、実機での長期検証 |
| 2 | 配布エンタイトルメントの承認遅延 | 高 | 中 | 最初に申請。拡張機能ごとに申請 |
| 3 | 自己申告・設定変更・削除によるすり抜け | 中 | 高 | 正直な利用者向けと割り切り、抜け道に手間を足す |
| 4 | 未成年の端末で動かない | 高 | 不明 | 子どもアカウントの実機で検証 |
| 5 | 審査での却下（2.5.1、4.10、4.3、1.4.1） | 中 | 中 | 申請文・審査メモ・説明文の一致、表現の調整 |
| 6 | 継続率の低さ | 高 | 高 | ロック前に行動させる設計、緊急パス |
| 7 | 見積もりの甘さで締め切りに間に合わない | 高 | 高 | 余裕係数、実績からの補正（critique-and-ideas.md） |
| 8 | Apple の方針変更・標準機能化 | 高 | 低〜中 | 回避不能。依存していることを前提に計画 |
| 9 | 必要なアプリまでロックして実害が出る | 中 | 中 | 既定で除外するアプリ、緊急パス |
| 10 | 名称の衝突 | 中 | 高 | 改名（critique-and-ideas.md） |

深刻度と起きやすさは調査結果からの判断で、数値的な根拠はない。

## 1. 技術的な不安定さ

開発者フォーラムの報告（いずれも当事者の投稿で、Apple の公式見解ではない）:

| 症状 | 報告されている環境 | 出典 |
|---|---|---|
| `intervalDidStart` が呼ばれず、予定時刻にシールドがかからない | iOS 16〜18 | [thread 736682](https://developer.apple.com/forums/thread/736682)、[757722](https://developer.apple.com/forums/thread/757722)、[746416](https://developer.apple.com/forums/thread/746416) |
| 監視中のアクティビティを再登録しても `intervalDidStart` が来ない。先に `stopMonitoring` が必要 | iOS 18 beta 2 | [thread 758309](https://developer.apple.com/forums/thread/758309) |
| DeviceActivityMonitor 拡張が数日で止まる、同じイベントが2回届く、認可が勝手に外れる | iOS 18.5 ほか | [thread 786854](https://developer.apple.com/forums/thread/786854) |
| 閾値イベントが発火しない、または作成直後に発火する | iOS 26 beta 以降 | [thread 819997](https://developer.apple.com/forums/thread/819997) |
| 利用0分なのに閾値到達が届き、早すぎるロックになる（約半分の日で発生との報告） | iOS 26.2 | [thread 811305](https://developer.apple.com/forums/thread/811305) |
| 解除できず、砂時計のシールドが残る | iOS 17 | [thread 742622](https://developer.apple.com/forums/thread/742622) |
| アプリを消したあともブロックが残る | — | [Opal コミュニティ](https://community.opal.so/t/opal-continues-to-make-my-phone-unusable-after-deleting-the-app/1127) |

one sec も公式ヘルプに「Screen Time API には多くのバグがある」と書いている（[出典](https://tutorials.one-sec.app/en/articles/3036354)）。Opal は2026年半ば、新しく入れたアプリが再起動までブロックされない不具合を出し、7月15日の更新で直したとされる（[unstar.app](https://unstar.app/blog/opal-forest-freedom-one-sec-jomo-screen-time-apps-ranked-2026)。二次情報）。資金のある先行企業でも踏んでいる問題だと見るべき。

仕様上の制約:

| 制約 | 内容 | 出典 |
|---|---|---|
| スケジュールの最短間隔 | 15分。これより短いとエラー | [DeviceActivitySchedule](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule)、[thread 729841](https://developer.apple.com/forums/thread/729841) |
| シールドできる数 | アプリトークン50個を超えると何もシールドされないという報告（iOS 17.2 時点）。多数を対象にするならカテゴリ指定が必要 | [thread 733361](https://developer.apple.com/forums/thread/733361) |
| 拡張機能のメモリと寿命 | 監視用の拡張は別プロセスで、メモリが限られ、状態を保持できない | [開発コンサルタントの解説](https://drobinin.com/consulting/screen-time-family-controls/building-with-screen-time-and-family-controls/) |
| 利用時間の数値 | `DeviceActivityReport` の中身はアプリから読めない | 同上 |
| Live Activity の表示時間 | 連続表示は約8時間まで、という制限があるとされる。今回は公式文書の本文で確認できなかった（未確認） | [ActivityKit ドキュメント](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) |

このアプリへの影響:

- 「締め切り − 所要時間」は任意の時刻になる。15分刻みに丸める必要があり、タスクを編集するたびにスケジュールを張り直すことになる。張り直しは、上の表で不具合報告が多い操作にあたる。
- ロックが始まらない失敗は、利用者から見ると「何も起きない」ので気づかれにくく、締め切りを落としたあとで不信につながる。
- 「次のロックまで」を Live Activity で常時出す案は、表示時間の上限に当たる可能性が高い。ウィジェットを主にして、Live Activity はロック直前の数時間だけにするのが現実的（上限の正確な値は要確認）。

対策の方向:

- ロックの状態を「現在時刻とタスク一覧から毎回計算し直せる値」として持ち、アプリ起動時、ウィジェット更新時、シールド表示時など、機会があるたびに照合して直す。
- 毎日のノルマは「既定でロック、完了で解除」とし、日付が変わるときの再ロックだけをスケジュールに頼る。
- 開発機ではなく普段使いの実機で、数週間の連続動作を確認してから公開する。シミュレーターでは DeviceActivity のイベントが発火しないと見る開発者の投稿がある（[Device Activity タグ](https://developer.apple.com/forums/tags/device-activity)。スレッドは特定していない）。

## 2. 配布エンタイトルメント

Family Controls を使うアプリを App Store に出すには、Apple の個別承認が要る。開発用の権限は Xcode で既定で使えるが、配布用は申請制（[開発コンサルタントの解説](https://drobinin.com/consulting/screen-time-family-controls/building-with-screen-time-and-family-controls/)）。

| 報告 | 出典 |
|---|---|
| Apple の担当者は「所要期間は示していない」と回答 | [thread 820811](https://developer.apple.com/forums/thread/820811) |
| 数日〜24時間で承認された例、約3週間かかった例 | 同種スレッド内の報告（[thread 812332](https://developer.apple.com/forums/thread/812332)、[824969](https://developer.apple.com/forums/thread/824969)。どの投稿かは特定していない） |
| 2週間応答なし | [thread 824665](https://developer.apple.com/forums/thread/824665)、[826427](https://developer.apple.com/forums/thread/826427) |
| 4週間応答なし | [thread 826625](https://developer.apple.com/forums/thread/826625) |
| 2か月近く応答なし | [thread 827666](https://developer.apple.com/forums/thread/827666) |
| 本体は承認済みでも、拡張機能のバンドル ID は別に申請が必要で、そちらが止まる | [thread 824193](https://developer.apple.com/forums/thread/824193)、[825312](https://developer.apple.com/forums/thread/825312) |

投稿の多くは2026年のもので、遅延が現在進行形であることを示す。ただしフォーラムには困った人が書き込むため、典型的な所要日数は分からない。

申請文について、同じ解説は「監視」「従業員の追跡」のように読める表現が拒否されやすく、「本人が自分を管理する」用途であることを明確に書くべきだとしている（第三者の見解）。

対策: 本体と拡張機能（監視、シールド表示、シールド操作）のバンドル ID を先に確定し、開発の初期に全部申請する。

## 3. すり抜け

| 抜け道 | 状況 | 出典 |
|---|---|---|
| やっていないのに「完了」を押す | このアプリの設計そのもの。競合は写真の AI 判定（Locky、Habit Doom）、提出物の AI 採点（Proc）、バーコード読み取り（TaskLock）で対抗している | competitors.md |
| 設定 → スクリーンタイム → アクセスを許可したアプリ、で許可を切る | 本人の Face ID やパスコードで切れるという報告。iOS 26.4 でスクリーンタイム・パスコードで守れるようになったとする記事があるが、開発者フォーラムの報告と食い違う（未確認） | [thread 727291](https://developer.apple.com/forums/thread/727291)、[Opal コミュニティ](https://community.opalapp.com/t/how-do-we-prevent-turning-off-screen-time-access-in-settings-solved-on-ios-26-4/488/50)、[AppBlock](https://appblock.app/how-to-block-screen-time-on-ios-26-4-and-newer/) |
| アプリを削除する | 「ブロッカーを消せばロックも消える」とする競合ブログがある（検証データなし）。Blockin は削除による解除を防ぐ機能をうたう | [Habit Doom](https://habitdoom.com/blog/doomscrolling-apps-no-bypass-2026)、[Blockin](https://apps.apple.com/jp/app/id1659162950) |
| ブラウザ版、別の端末、ゲーム機、PC | Screen Time API が効くのはその iPhone だけ。家庭用ゲーム機や PC のゲームは対象外 | — |
| 端末の時刻を変える | 影響は未確認 | — |

比較サイトの集計では、ブロッカー5本の星1〜3レビューのうち「すり抜けられる」が 19% で2番目に多い不満だった（[unstar.app](https://unstar.app/blog/opal-forest-freedom-one-sec-jomo-screen-time-apps-ranked-2026)。同サイト独自の集計）。

本人が自分の端末の管理者である以上、完全には防げない。「抜けようと思えば抜けられるが、手間がかかる」水準を狙い、説明文で「絶対に解除できない」とは書かない。書くと 2.3.1（実際にない機能の宣伝）に触れるうえ、レビューで反証される。

## 4. 未成年の利用者

- 対象の中心に高校生がいる（market-and-demand.md）。保護者がファミリー共有で管理している端末は珍しくない。
- 開発者フォーラムでは、`.child` の認可は「iCloud ファミリーの子どもアカウントでサインインし、MDM に入っていない端末でのみ可能」という担当者回答が引用されている（[Family Controls タグ](https://developer.apple.com/forums/tags/family-controls)、関連 [thread 771478](https://developer.apple.com/forums/thread/771478)。回答の原スレッドは特定していない）。
- 子どもアカウントの端末で、本人が `.individual` で認可できるのか、保護者の承認が要るのかは、今回の調査で確認できなかった（未確認）。
- iOS 26.4 以降は、許可の選択肢が「全データへのアクセス」か「許可しない」の2択になり、以前の許可形態が取れないという開発者報告がある（[thread 820283](https://developer.apple.com/forums/thread/820283)）。

対策: 13〜17歳の子どもアカウントでサインインした実機で、認可からロックまでを通しで試す。通らない場合、対象を大学生以上に切り替えるか、保護者承認の導線を用意するかを決める。これは設計の前提を変えるので、早い段階で確認する。

## 5. App Store 審査

| 条項 | 内容 | このアプリでの論点 | 出典 |
|---|---|---|---|
| 2.5.1 | API は意図された用途で使う | Screen Time API でアプリを「隠す」実装が却下され、異議も通らなかった報告がある。シールド表示は標準的な用途だが、審査メモで用途を明記する | [ガイドライン](https://developer.apple.com/app-store/review/guidelines/)、[thread 776058](https://developer.apple.com/forums/thread/776058)、[749466](https://developer.apple.com/forums/thread/749466) |
| 2.5.1（自動判定） | 「エンタイトルメントなしで Screen Time API を使っている」という自動メッセージが、権限を入れたビルドにも出た報告 | 提出前に署名済みビルドの権限を確認する | [thread 822078](https://developer.apple.com/forums/thread/822078) |
| 4.10 | Screen Time API などの組み込み機能を収益化してはならない | ロックそのものを課金の境目にしない（business-model.md） | [ガイドライン](https://developer.apple.com/app-store/review/guidelines/) |
| 4.3(b) | 既に広く出回っているものと区別がつかないアプリは不可 | 同種のアプリが大量にある。予報 UI と締め切り逆算を前面に出して違いを示す | 同上 |
| 2.3.7 / 5.2.1 / 4.1(c) | 他社のアプリ名や商標をメタデータに入れない。他の開発者の製品名を無断で使わない | キーワードに「Opal」などを入れない。名称の衝突にも関係する | 同上 |
| 1.4.1 | 医療アプリは厳しく審査。診断・治療に使えるものは精度の根拠が必要 | 下の「表現」を参照 | 同上 |
| 3.1.2(a) | 自動更新サブスクは継続的な価値が条件 | 更新が止まるなら買い切りが無難 | 同上 |
| 5.1.1 | 収集するデータと用途を明示 | 端末内完結にすれば説明が単純になる。申請文で「端末内のみ」と書いて実際は送信していると悪質と見なされる、という指摘がある | 同上、[解説](https://drobinin.com/consulting/screen-time-family-controls/building-with-screen-time-and-family-controls/) |

過去の経緯として、Apple は iOS 12 で標準の Screen Time を出した時期に、他社のスクリーンタイム系アプリを相次いで却下・削除した（[TechCrunch, 2018-12](https://techcrunch.com/2018/12/05/apple-puts-third-party-screen-time-apps-on-notice/)、[9to5Mac, 2019-04](https://9to5mac.com/2019/04/28/apple-releases-official-statement-responding-to-parental-control-app-rejection-controversy)）。現在の Screen Time API はその後に用意された正規の経路だが、このカテゴリが Apple の判断ひとつで動くことは変わらない。

### 表現（医療・依存）

- 「依存症を治す」「ADHD に効く」のように診断・治療と読める表現は 1.4.1 の対象になりうる。健康系アプリが、医療用語を外し免責を足しても 1.4.1 を指摘され続けたという報告がある（[thread 807508](https://developer.apple.com/forums/thread/807508)）。
- 一方、日本の App Store では「スマホ依存対策」をアプリ名に入れたものが複数公開されている（[Blockin](https://apps.apple.com/jp/app/id1659162950)、[one sec](https://apps.apple.com/jp/app/id1532875441)、[集中](https://apps.apple.com/jp/app/id1387759250) など）。この表現自体で却下された事例は見つけられなかった。
- スクリーンタイム系アプリが健康表現を理由に却下された事例も見つけられなかった（未確認）。
- 推奨: 「使いすぎ」「先延ばし」「習慣」で語り、「依存症」「治療」「改善効果○%」は使わない。効果を数字で言うなら出典が要る。
- 「ドパガキ」は医学用語ではなく、他人に向けると揶揄になる俗語（[ニコニコ大百科](https://dic.nicovideo.jp/a/%E3%83%89%E3%83%91%E3%82%AC%E3%82%AD)）。既に2本がメタデータに使って公開されているので審査上は通る見込みだが、英語版や広報では使いどころを選ぶ。

国内の広告表示規制（景品表示法など）との関係は今回調べていない。

## 6. 継続率

- 年額プランの1年後継続は、フリーミアムで 28%、課金必須で 27%（[RevenueCat 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)）。全カテゴリの値で、ブロッカー固有の値ではない。
- ブロッカーの継続率・削除率の公開データは見つけられなかった（未確認）。
- 構造上、このアプリは「利用者が最も使いたい瞬間に邪魔をする」。削除の動機はロック発動時に最大になる。
- Opal の不満の最多は課金まわり（24%）、次がすり抜け（19%）という集計がある（[unstar.app](https://unstar.app/blog/opal-forest-freedom-one-sec-jomo-screen-time-apps-ranked-2026)）。

「ロック予報」はこの問題への答えになりうる。ロックされる前に動けば、邪魔された体験にならない。逆に、予報を見ても動かない利用者にとっては、他のブロッカーと同じ理由で消される。

## 7. プラットフォーム依存

- iOS 26 は2026年6月7日時点で全 iPhone の 79%、過去4年の機種では 86%（[MacRumors](https://macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/)）。iOS 26 以降に限定することによる取りこぼしは2割程度。学生の端末構成は未確認。
- 競合の新規参入にも iOS 26.0 以降を要件にするものが出ている（Finiti、TaskWarden、TakeTime。competitors.md）。
- iOS 27 は Screen Time を刷新したが、保護者が子どもを管理する機能が中心と報じられている（[AppleInsider](https://appleinsider.com/articles/26/06/08/revamped-parental-controls-are-coming-to-iphone-mac-and-more)）。大人が自分を縛る機能を Apple が標準で強化すれば、カテゴリごと影響を受ける。
- Android は対象外。日本全体では Android が 54.1%（[MMD研究所調査](https://selectra.jp/telecom/news/iphone-share-202608)）。

## 8. 実害の可能性

- 連絡、地図、決済、学校の連絡アプリまでロックすると、生活上の支障が出る。DrillLock は「電話など緊急時に必要なアプリはブロック対象外」と明記している（[App Store](https://apps.apple.com/jp/app/id6759181330)）。
- 対策: ロック対象は利用者が選んだ娯楽アプリに限り、初期設定でカテゴリ全体を選ばせない。緊急パスは回数を使い切っても、時間をかければ解除できる経路を残す。

## 9. 模倣

2026年の参入数（competitors.md）が示すとおり、この種のアプリは短期間で作れる。締め切り逆算ロックが受けると分かれば、Opal、スタロック、TodoLock などが追加するのに大きな障壁はない。機能で守れる期間は短いと見て、名前の浸透、取り込みの手軽さ、見積もり補正のデータなど、時間がかかるものを先に積む。
