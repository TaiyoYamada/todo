import Foundation
import Testing
@testable import Domain

@Suite("1日と1週間の区切り")
struct DayClockTests {
    let clock = DayClock(calendar: tokyo, dayStartHour: 4)

    @Test("朝4時より前は、前の日に含まれる")
    func beforeDayStartBelongsToPreviousDay() {
        #expect(clock.dayStart(containing: date(9, 3, 59)) == date(8, 4))
        #expect(clock.dayStart(containing: date(9, 4, 0)) == date(9, 4))
        #expect(clock.dayStart(containing: date(9, 23, 0)) == date(9, 4))
    }

    @Test("1日の区間は、次の日の開始で終わる")
    func dayInterval() {
        let day = clock.day(containing: date(9, 14))
        #expect(day.start == date(9, 4))
        #expect(day.end == date(10, 4))
    }

    @Test("深夜1時は、前日の曜日として数える")
    func weekdayAfterMidnight() {
        // 10/10(土)の深夜1時は、10/9(金)の1日に含まれる。
        let dayStart = clock.dayStart(containing: date(10, 1))
        #expect(clock.weekday(ofDayStarting: dayStart) == .friday)
    }

    @Test("1日の開始より前の時刻は、翌日の暦の日付になる")
    func timeOfDay() {
        let dayStart = date(9, 4)
        #expect(clock.time(minutesFromMidnight: 20 * 60, inDayStarting: dayStart) == date(9, 20))
        #expect(clock.time(minutesFromMidnight: 60, inDayStarting: dayStart) == date(10, 1))
        #expect(clock.time(minutesFromMidnight: 4 * 60, inDayStarting: dayStart) == date(9, 4))
    }

    @Test("週は月曜の朝4時に始まる")
    func week() {
        let week = clock.week(containing: date(9, 14))
        #expect(week.start == date(5, 4))
        #expect(week.end == date(12, 4))
        // 月曜の深夜3時は、まだ前の週。
        #expect(clock.week(containing: date(12, 3)).start == date(5, 4))
        #expect(clock.week(containing: date(12, 4)).start == date(12, 4))
    }

    @Test("1日の開始が0時でも成り立つ")
    func midnightStart() {
        let clock = DayClock(calendar: tokyo, dayStartHour: 0)
        #expect(clock.dayStart(containing: date(9, 0, 30)) == date(9, 0))
        #expect(clock.day(containing: date(9, 23, 59)).end == date(10, 0))
    }

    @Test("夏時間の切り替え日でも、1日は決めた時刻に始まる")
    func daylightSavingTime() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let clock = DayClock(calendar: newYork, dayStartHour: 4)
        func at(_ month: Int, _ day: Int, _ hour: Int) -> Date {
            newYork.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
        }

        // 2026-03-08 は時計が1時間進む日(23 時間しかない)。
        #expect(clock.dayStart(containing: at(3, 8, 12)) == at(3, 8, 4))
        #expect(clock.time(minutesFromMidnight: 21 * 60, inDayStarting: at(3, 8, 4)) == at(3, 8, 21))
        #expect(clock.dayStart(after: at(3, 7, 4)) == at(3, 8, 4))
        #expect(clock.dayStart(after: at(3, 8, 4)) == at(3, 9, 4))

        // 2026-11-01 は時計が1時間戻る日(25 時間ある)。
        #expect(clock.dayStart(containing: at(11, 1, 12)) == at(11, 1, 4))
        #expect(clock.time(minutesFromMidnight: 21 * 60, inDayStarting: at(11, 1, 4)) == at(11, 1, 21))
        #expect(clock.weekday(ofDayStarting: at(11, 1, 4)) == .sunday)
        #expect(clock.week(containing: at(11, 1, 12)).start == at(10, 26, 4))
    }
}
