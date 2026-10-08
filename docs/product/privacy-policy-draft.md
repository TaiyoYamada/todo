# プライバシーポリシー(下書き)

最終更新: 2026-10-09

公開のときに必要になる文書の下書きです。Claude が、2026-10-09 時点のコードの動きに基づいて書きました。**法的な確認は受けていません。** 公開の前に、オーナーが内容を確かめ、必要なら専門家に相談してください。

課金、解析、同期などを足したときは、この文書も直す必要があります。

## いまのコードが扱っているデータ

| データ | 保存する場所 | 端末の外に出るか |
|---|---|---|
| 目標、タスク、集中の記録、パスの記録、設定 | アプリの中のデータベース(SQLite) | 出ない |
| 上の一部の写し(ウィジェットとロックの判定用) | アプリと拡張機能が共有する領域 | 出ない |
| ロックするアプリの選択 | 同じ共有の領域 | 出ない。アプリ自身も、どのアプリが選ばれたかを知ることができない(Apple の仕組みによる) |
| 通知の予約 | 端末の通知の仕組み | 出ない |

- アカウントの登録はない
- 外部のサーバーとの通信はない
- 解析や広告の仕組みは入っていない
- 外部のライブラリは、状態の管理とデータベースのためのもので、通信は行わない

## 利用者向けの文面(案)

### 日本語

**集める情報**
Lockcast は、あなたの個人情報を集めません。アカウントの登録は不要です。

**端末の中に保存する情報**
あなたが入力した目標、タスク、集中の記録、設定は、あなたの iPhone の中にだけ保存されます。開発者を含め、ほかの誰にも送られません。

**スクリーンタイム**
アプリのロックには、Apple のスクリーンタイムを使います。ロックするアプリの選択は、あなたの iPhone の中にだけ保存されます。Lockcast は、あなたがどのアプリを選んだか、どのアプリをどれだけ使ったかを知ることができません。

**通知**
ロックの前触れを知らせるために、通知を使います。通知の内容は端末の中で作られ、外部には送られません。

**データを消す**
アプリを削除すると、保存されたデータはすべて消えます。

**お問い合わせ**
(連絡先を入れる)

### English

**Information we collect**
Lockcast does not collect personal information. No account is required.

**Information stored on your device**
The goals, tasks, focus history and settings you enter are stored only on your iPhone. They are not sent to the developer or anyone else.

**Screen Time**
Lockcast uses Apple's Screen Time to lock apps. Your selection of apps is stored only on your iPhone. Lockcast cannot see which apps you chose or how much you use them.

**Notifications**
Lockcast uses notifications to warn you before a lock. They are created on your device and are not sent anywhere.

**Deleting your data**
Deleting the app deletes all stored data.

**Contact**
(add contact)

## 公開の前に確かめること

- 上の表が、公開する版のコードと合っているか
- App Store Connect の「App のプライバシー」の回答(いまのコードなら「データの収集なし」)
- 連絡先の記載
- 公開用の URL(ポリシーを置く場所)
