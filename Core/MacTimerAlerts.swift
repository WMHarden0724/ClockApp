//
//  MacTimerAlerts.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(macOS)
import Foundation
import UserNotifications


/// The iPhone rings for every timer, but it only hears about a Mac-started timer once its app runs.
/// So timers started on this Mac also post a notification here when they finish, as a backup.
enum MacTimerAlerts {
	private static var requestedPermission = false

	static func update(for timers: [AppTimer]) {
		let center = UNUserNotificationCenter.current()
		let mine = timers.filter { $0.originDevice == SyncHub.shared.deviceID && $0.isRunning }

		if !mine.isEmpty && !requestedPermission {
			requestedPermission = true
			center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
		}

		center.removeAllPendingNotificationRequests()
		for timer in mine {
			guard let end = timer.endDate, end > Date() else { continue }
			let content = UNMutableNotificationContent()
			content.title = timer.displayLabel
			content.body = timer.kind.doneText
			content.sound = .default
			let trigger = UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSinceNow, repeats: false)
			center.add(UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger))
		}
	}
}
#endif
