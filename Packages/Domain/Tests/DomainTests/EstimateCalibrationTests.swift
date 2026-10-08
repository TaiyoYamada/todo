import Foundation
import Testing
@testable import Domain

@Suite("見積もりの癖の学習")
struct EstimateCalibrationTests {
    private func done(_ id: Int, estimate: Int, actual: Int?, day: Int = 5) -> TaskItem {
        .fixture(id, estimateMinutes: estimate, actualMinutes: actual, completedAt: date(day, 12))
    }

    @Test("実績が3件に満たなければ、1.5倍を使う")
    func fallback() {
        let calibration = EstimateCalibration(tasks: [
            done(1, estimate: 60, actual: 60),
            done(2, estimate: 60, actual: 60),
        ])
        #expect(calibration.factor == 1.5)
        #expect(!calibration.isLearned)
    }

    @Test("実績の中央値を倍率にする")
    func median() {
        let calibration = EstimateCalibration(tasks: [
            done(1, estimate: 60, actual: 60),
            done(2, estimate: 60, actual: 120),
            // 1回だけ大きく外しても、中央値は動かない。
            done(3, estimate: 60, actual: 600),
        ])
        #expect(calibration.factor == 2.0)
        #expect(calibration.isLearned)
    }

    @Test("偶数件のときは、中央の2つの平均")
    func evenCount() {
        let calibration = EstimateCalibration(tasks: [
            done(1, estimate: 60, actual: 60),
            done(2, estimate: 60, actual: 90),
            done(3, estimate: 60, actual: 120),
            done(4, estimate: 60, actual: 150),
        ])
        #expect(calibration.factor == 1.75)
    }

    @Test("見積もりより早く終わる人でも、1倍より小さくはしない")
    func lowerBound() {
        let tasks = (1 ... 3).map { done($0, estimate: 60, actual: 30) }
        #expect(EstimateCalibration(tasks: tasks).factor == 1.0)
    }

    @Test("3倍を上限にする")
    func upperBound() {
        let tasks = (1 ... 3).map { done($0, estimate: 30, actual: 300) }
        #expect(EstimateCalibration(tasks: tasks).factor == 3.0)
    }

    @Test("直近の10件だけを見る")
    func window() {
        // 古い 5 件は 3 倍、新しい 10 件は見積もりどおり。
        let old = (1 ... 5).map { done($0, estimate: 60, actual: 180, day: 1) }
        let recent = (6 ... 15).map { done($0, estimate: 60, actual: 60, day: 8) }
        let calibration = EstimateCalibration(tasks: old + recent)
        #expect(calibration.factor == 1.0)
        #expect(calibration.sampleCount == 10)
    }

    @Test("実際の時間を答えていないタスクと、未完了のタスクは数えない")
    func ignoresIncomplete() {
        let calibration = EstimateCalibration(tasks: [
            done(1, estimate: 60, actual: nil),
            .fixture(2, estimateMinutes: 60, actualMinutes: 120),
        ])
        #expect(calibration.sampleCount == 0)
    }

    @Test("設定が自動なら学習した倍率を、固定ならその値を使う")
    func worldFactor() {
        let tasks = (1 ... 3).map { done($0, estimate: 60, actual: 120) }
        var world = World(tasks: tasks)
        #expect(world.estimateFactor == 2.0)

        world.preferences.buffer = .quarter
        #expect(world.estimateFactor == 1.25)
    }

    @Test("取りかかってからの時間は、5分刻みに丸める")
    func elapsedMinutes() {
        var task = TaskItem.fixture()
        #expect(task.elapsedMinutes(until: date(9, 14)) == nil)

        task.startedAt = date(9, 13)
        #expect(task.elapsedMinutes(until: date(9, 14, 2)) == 60)
        #expect(task.elapsedMinutes(until: date(9, 14, 13)) == 75)
        // すぐ終えても、最低 5 分として扱う。
        #expect(task.elapsedMinutes(until: date(9, 13, 1)) == 5)
        // 何日も前に始めたままでも、見積もり(2 時間)の 4 倍までしか出さない。
        #expect(task.elapsedMinutes(until: date(12, 13)) == 480)
    }

    @Test("見積もりどおりにしたタスクには、倍率を掛けない")
    func exactEstimate() {
        var task = TaskItem.fixture(dueAt: date(9, 23, 59), estimateMinutes: 120)
        #expect(task.startLimit(factor: 1.5) == date(9, 20, 59))

        task.usesExactEstimate = true
        #expect(task.startLimit(factor: 1.5) == date(9, 21, 59))
    }

    @Test("あとから足した項目がない古い JSON も読める")
    func decodesOlderJSON() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000100","title":"レポート","dueAt":800000000,\
        "estimateMinutes":60,"createdAt":799000000}
        """
        let task = try JSONDecoder().decode(TaskItem.self, from: Data(json.utf8))
        #expect(task.title == "レポート")
        #expect(!task.usesExactEstimate)
        #expect(task.startedAt == nil)
    }
}
