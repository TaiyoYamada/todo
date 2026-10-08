import Foundation
import GRDB

// このファイルは GRDB だけを import する(理由は Schema.swift の冒頭を参照)。

/// 読み取りの結果を、関係する表が変わるたびに流し直す。
func observe<Value: Equatable & Sendable>(
    in database: any DatabaseReader,
    _ fetch: @escaping @Sendable (Database) throws -> Value
) -> AsyncStream<Value> {
    let observation = ValueObservation.tracking(fetch).removeDuplicates()
    return AsyncStream { continuation in
        let task = Task {
            do {
                for try await value in observation.values(in: database) {
                    continuation.yield(value)
                }
            } catch {
                // 読み取りに失敗したら流れを閉じる。購読側は最後に受け取った値を使い続ける。
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
