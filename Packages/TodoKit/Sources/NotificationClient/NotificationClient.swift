import Dependencies
import DependenciesMacros
import Foundation
import UserNotifications

/// ロックの前触れとして出す通知。
public struct LockNotification: Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var fireAt: Date

    public init(id: String, title: String, body: String, fireAt: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.fireAt = fireAt
    }
}

/// 端末の通知の窓口。
@DependencyClient
public struct NotificationClient: Sendable {
    /// 通知の許可を求める。許可されたら true。
    public var requestAuthorization: @Sendable () async -> Bool = { false }
    /// 予約済みの通知をすべて捨てて、渡したものに置き換える。
    public var replaceAll: @Sendable (_ notifications: [LockNotification]) async -> Void
}

extension NotificationClient: DependencyKey {
    public static let liveValue = NotificationClient(
        requestAuthorization: {
            (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        },
        replaceAll: { notifications in
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            let now = Date()
            for notification in notifications where notification.fireAt > now {
                let content = UNMutableNotificationContent()
                content.title = notification.title
                content.body = notification.body
                content.sound = .default
                let parts = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: notification.fireAt
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                // 許可がないときなどは失敗する。通知は補助なので、失敗しても先へ進む。
                try? await center.add(
                    UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger)
                )
            }
        }
    )

    /// 通知は補助的なもの。テストとプレビューでは何もしない実装にして、各テストが差し替えなくて済むようにする。
    public static let testValue = NotificationClient(requestAuthorization: { false }, replaceAll: { _ in })
    public static let previewValue = testValue
}

extension DependencyValues {
    public var notifications: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
