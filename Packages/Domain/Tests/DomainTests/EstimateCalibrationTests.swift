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
        let calibration = EstimateCalibration(tasks: [done(1, estimate: 60, actual: 60), done(2, estimate: 60, actual: 60)])
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
        let tasks = (1...3).map { done($0, estimate: 60, actual: 30) }
        #expect(EstimateCalibration(tasks: tasks).factor == 1.0)
    }

    @Test("3倍を上限にする")
    func upperBound() {
        let tasks = (1...3).map { done($0, estimate: 30, actual: 300) }
        #expect(EstimateCalibration(tasks: tasks).factor == 3.0)
    }

    @Test("直近の10件だけを見る")
    func window() {
        // 古い 5 件は 3 倍、新しい 10 件は見積もりどおり。
        let old = (1...5).map { done($0, estimate: 60, actual: 180, day: 1) }
        let recent = (6...15).map { done($0, estimate: 60, actual: 60, day: 8) }
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
        let tasks = (1...3).map { done($0, estimate: 60, actual: 120) }
        var world = World(tasks: tasks)
        #expect(world.estimateFactor == 2.0)

        world.preferences.buffer = .quarter
        #expect(world.estimateFactor == 1.25)
    }
}
