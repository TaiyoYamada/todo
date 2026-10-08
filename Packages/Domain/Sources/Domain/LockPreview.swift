import Foundation

/// 「これを片づけたら、次のロックはいつになるか」の見通し。
///
/// 片づける前と後の余裕を比べて見せることで、いま動く理由を具体的にする。
public struct LockPreview: Equatable, Sendable {
    /// 片づけたあとの、次のロックの時刻。もう予定がなければ nil。
    public var nextLockAt: Date?
    /// 片づけたあと、今日はもうロックの予定がないか。
    public var isFreeForToday: Bool
    /// 片づけると、ロックが外れる(または、ロックされずに済む)か。ほかに理由が残るなら false。
    public var unlocks: Bool
}

extension LockEngine {
    /// `source` をいま片づけたと仮定して、ロックの見通しを計算する。保存データは変えない。
    public func preview(resolving source: LockReason.Source, world: World, now: Date) -> LockPreview {
        var world = world
        switch source {
        case let .goal(id):
            guard let goal = world.goal(id: id) else { break }
            let remaining = progress(of: goal, world: world, now: now).remainingSeconds
            // 残りをちょうどやり終えた、という記録を仮に足す。
            world.activeFocus = nil
            world.sessions.append(
                FocusSession(id: UUID(), goalID: id, startedAt: now.addingTimeInterval(-1), seconds: remaining)
            )
        case let .task(id):
            guard let index = world.tasks.firstIndex(where: { $0.id == id }) else { break }
            world.tasks[index].completedAt = now
        }
        let after = status(world: world, now: now)
        switch after.phase {
        case .locked, .onPass:
            return LockPreview(nextLockAt: nil, isFreeForToday: false, unlocks: false)
        case let .free(nextLockAt):
            return LockPreview(nextLockAt: nextLockAt, isFreeForToday: after.isFreeForToday, unlocks: true)
        }
    }
}
