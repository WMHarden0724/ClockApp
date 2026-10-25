//
//  BedtimeReminder.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation
import UserNotifications


/// Bedtime for your next alarm and your sleep goal (Settings › Alarms).
enum Bedtime {
	static func date(forAlarmAt alarm: Date) -> Date {
		alarm.addingTimeInterval(-TimeInterval(AppSettings.shared.sleepGoalMinutes * 60))
	}

	/// "7 h 40 m" of sleep if you go to bed at `now`.
	static func sleepText(until alarm: Date, from now: Date = Date()) -> String {
		let minutes = max(0, Int(alarm.timeIntervalSince(now) / 60))
		return "\(minutes / 60) h \(minutes % 60) m"
	}
}


#if os(iOS)
/// A "time to wind down" notification 15 minutes before bedtime for the next alarm.
/// Only the ringing device posts it, so you don't get one from every device.
enum BedtimeReminder {
	private static let id = "bedtime.reminder"
	private static let windDown: TimeInterval = 15 * 60

	static func update(nextAlarm: Date?) {
		let center = UNUserNotificationCenter.current()
		center.removePendingNotificationRequests(withIdentifiers: [id])
		guard AppSettings.shared.bedtimeReminder, AlarmScheduler.isRingingDevice, let nextAlarm else { return }

		let bedtime = Bedtime.date(forAlarmAt: nextAlarm)
		let remindAt = bedtime.addingTimeInterval(-windDown)
		guard remindAt > Date() else { return }

		center.delegate = NotificationPresenter.shared
		center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
		let content = UNMutableNotificationContent()
		content.title = "Time to wind down"
		content.body = "Bed by \(bedtime.timeText) for \(AppSettings.shared.sleepGoalMinutes / 60) h of sleep before your \(nextAlarm.timeText) alarm."
		content.sound = .default
		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remindAt.timeIntervalSinceNow, repeats: false)
		center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
	}
}
#endif
