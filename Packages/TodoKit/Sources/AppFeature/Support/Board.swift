import ComposableArchitecture
import Domain
import Foundation

/// 全画面が共有して読む、いまの状況。保存データと、そこから計算したロックの状態。
///
/// 書き込むのは `AppFeature` だけ。各画面は読むだけにして、状態の出どころを1か所にする。
struct Board: Equatable, Sendable {
    var world = World()
    var status = LockEngine(calendar: Calendar(identifier: .gregorian))
        .status(world: World(), now: Date(timeIntervalSinceReferenceDate: 0))
    /// 保存データを一度でも読み終えたか。読み終える前に初回設定を出してしまわないために使う。
    var isLoaded = false
}

extension SharedReaderKey where Self == InMemoryKey<Board>.Default {
    static var board: Self {
        Self[.inMemory("board"), default: Board()]
    }
}

/// 画面をまたぐ移動の依頼。子の画面はこれを親に伝えるだけで、開き方は知らない。
enum Route: Equatable, Sendable {
    case startFocus(Goal.ID)
    /// nil なら新しく作る。
    case editGoal(Goal.ID?)
    case editTask(TaskItem.ID?)
    case completeTask(TaskItem.ID)
    case openSettings
}
