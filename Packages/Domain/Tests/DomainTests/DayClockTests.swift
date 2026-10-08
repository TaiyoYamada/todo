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
}
