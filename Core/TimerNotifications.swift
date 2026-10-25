//
//  TimerNotifications.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(iOS) || os(macOS)
import Foundation
import UserNotifications


/// The gentle notifications around a timer: the cue at each step of a sequence, the heads-up
/// before the end (Settings › Timers), and on the Mac a backup for the end itself.
///
/// The real end-of-timer alert is AlarmKit's, on the ringing device. The Mac can't ring, and
/// the iPhone only hears about a Mac-started timer once its app runs, so the Mac posts its own.
enum TimerNotifications {
	private static let prefix = "timer."
	private static var scheduledIDs: [String] = []
	private static var requestedPermission = false

	static func update(for timers: [AppTimer]) {
		let center = UNUserNotificationCenter.current()
		center.delegate = NotificationPresenter.shared
		center.removePendingNotificationRequests(withIdentifiers: scheduledIDs)
		scheduledIDs = []

		#if os(macOS)
		let relevant = timers.filter { $0.originDevice == SyncHub.shared.deviceID }
		let postsEnd = true
		#else
		// Only the device that rings adds cues, so an iPhone and iPad don't both chime.
		let relevant = AlarmScheduler.isRingingDevice ? timers : []
		let postsEnd = false
		#endif

		let now = Date()
		var requests: [UNNotificationRequest] = []
		for timer in relevant {
			guard let end = timer.endDate, end > now else { continue }

			for start in timer.stepStarts where start.date > now {
				let content = UNMutableNotificationContent()
				content.title = "\(start.step.label.isEmpty ? "Next step" : start.step.label) · \(start.step.duration.timerText)"
				content.body = "\(timer.displayLabel) · step \(start.index + 1) of \(timer.steps?.count ?? 0)"
				content.sound = UNNotificationSound(named: UNNotificationSoundName(TimerSound.stepCueFileName))
				content.interruptionLevel = .timeSensitive
				requests.append(request("\(timer.id).step\(start.index)", content, at: start.date))
			}

			if let lead = AppSettings.shared.timerHeadsUp.lead(for: timer.duration), end.addingTimeInterval(-lead) > now {
				let content = UNMutableNotificationContent()
				content.title = timer.displayLabel
				content.body = "\(lead.durationLabel) left · ends \(end.timeText)"
				content.sound = .default
				requests.append(request("\(timer.id).headsUp", content, at: end.addingTimeInterval(-lead)))
			}

			if postsEnd {
				let content = UNMutableNotificationContent()
				content.title = timer.displayLabel
				content.body = timer.kind.doneText
				content.sound = timer.sound.fileName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
				content.interruptionLevel = .timeSensitive
				requests.append(request("\(timer.id).end", content, at: end))
			}
		}

		guard !requests.isEmpty else { return }
		if !requestedPermission {
			requestedPermission = true
			center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
		}
		for request in requests {
			center.add(request)
			scheduledIDs.append(request.identifier)
		}
	}

	private static func request(_ id: String, _ content: UNNotificationContent, at date: Date) -> UNNotificationRequest {
		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
		return UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger)
	}
}


/// Shows ClockIt's notifications even while it's open, so a workout on screen still chimes.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
	static let shared = NotificationPresenter()

	nonisolated func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification
	) async -> UNNotificationPresentationOptions {
		[.banner, .list, .sound]
	}
}
#endif
