import ConcurrencyExtras
import Domain
import Foundation

extension DatabaseClient {
    /// メモリ上だけで動く実装。プレビューと、DB を使わないテストで使う。
    public static func inMemory(_ initial: World = World()) -> DatabaseClient {
        let store = InMemoryStore(initial)
        return DatabaseClient(
            observeWorld: { store.stream() },
            saveGoal: { goal in
                store.update { world in
                    if let index = world.goals.firstIndex(where: { $0.id == goal.id }) {
                        world.goals[index] = goal
                    } else {
                        world.goals.append(goal)
                    }
                }
            },
            deleteGoal: { id in
                store.update { world in
                    world.goals.removeAll { $0.id == id }
                    world.sessions.removeAll { $0.goalID == id }
                    if world.activeFocus?.goalID == id { world.activeFocus = nil }
                }
            },
            saveTask: { task in
                store.update { world in
                    if let index = world.tasks.firstIndex(where: { $0.id == task.id }) {
                        world.tasks[index] = task
                    } else {
                        world.tasks.append(task)
                    }
                }
            },
            deleteTask: { id in store.update { $0.tasks.removeAll { $0.id == id } } },
            addSession: { session in store.update { $0.sessions.append(session) } },
            setActiveFocus: { focus in store.update { $0.activeFocus = focus } },
            addPassUse: { passUse in store.update { $0.passUses.append(passUse) } },
            savePreferences: { preferences in store.update { $0.preferences = preferences } },
            replaceAll: { world in store.update { $0 = world } }
        )
    }
}

/// 値と、その購読者を持つ。変更のたびに全員へ流す。
private final class InMemoryStore: Sendable {
    private struct Storage {
        var world: World
        var continuations: [UUID: AsyncStream<World>.Continuation] = [:]
    }

    private let storage: LockIsolated<Storage>

    init(_ world: World) {
        storage = LockIsolated(Storage(world: world))
    }

    func stream() -> AsyncStream<World> {
        AsyncStream { continuation in
            let id = UUID()
            storage.withValue { storage in
                storage.continuations[id] = continuation
                continuation.yield(storage.world)
            }
            continuation.onTermination = { [storage] _ in
                storage.withValue { $0.continuations[id] = nil }
            }
        }
    }

    func update(_ mutate: @Sendable (inout World) -> Void) {
        storage.withValue { storage in
            mutate(&storage.world)
            for continuation in storage.continuations.values {
                continuation.yield(storage.world)
            }
        }
    }
}
