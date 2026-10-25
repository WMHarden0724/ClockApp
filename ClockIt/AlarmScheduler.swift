//
//  AlarmScheduler.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import AlarmKit
import SwiftUI


nonisolated struct ClockItAlarmMetadata: AlarmMetadata {}


/// Bridges `AppAlarm` to real system alarms via AlarmKit.
enum AlarmScheduler {
	private static var manager: AlarmManager { .shared }

	static func requestAuthorizationIfNeeded() async -> Bool {
		switch manager.authorizationState {
		case .authorized:
			return true
		case .denied:
			return false
		case .notDetermined:
			return (try? await manager.requestAuthorization()) == .authorized
		@unknown default:
			return false
		}
	}

	/// Cancels any existing system alarm for this id, then reschedules it if it's enabled.
	static func sync(_ alarm: AppAlarm) async {
		cancel(alarm.id)
		guard alarm.isEnabled, let schedule = schedule(for: alarm) else { return }
		guard await requestAuthorizationIfNeeded() else { return }

		let snooze = AlarmButton(text: "Snooze", textColor: Theme.accent, systemImageName: "zzz")
		let alert = AlarmPresentation.Alert(
			title: "\(alarm.displayLabel)",
			secondaryButton: snooze,
			secondaryButtonBehavior: .countdown
		)
		let attributes = AlarmAttributes<ClockItAlarmMetadata>(
			presentation: AlarmPresentation(alert: alert),
			tintColor: Theme.accent
		)
		let configuration = AlarmManager.AlarmConfiguration(
			countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(alarm.snoozeMinutes * 60)),
			schedule: schedule,
			attributes: attributes
		)

		do {
			_ = try await manager.schedule(id: alarm.id, configuration: configuration)
		} catch {
			print("Failed to schedule alarm \(alarm.id): \(error)")
		}
	}

	static func cancel(_ id: UUID) {
		try? manager.cancel(id: id)
	}

	/// Ids AlarmKit currently has scheduled, or nil if we can't know (not authorized).
	static func scheduledIDs() -> Set<UUID>? {
		guard manager.authorizationState == .authorized, let alarms = try? manager.alarms else { return nil }
		return Set(alarms.map(\.id))
	}

	private static func schedule(for alarm: AppAlarm) -> Alarm.Schedule? {
		if alarm.specificDate != nil {
			return alarm.nextFireDate().map { .fixed($0) }
		}
		let weekdays = alarm.repeatDays.sorted().compactMap { weekdayMap[$0] }
		return .relative(Alarm.Schedule.Relative(
			time: .init(hour: alarm.hour, minute: alarm.minute),
			repeats: weekdays.isEmpty ? .never : .weekly(weekdays)
		))
	}

	private static let weekdayMap: [Int: Locale.Weekday] = [
		1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday, 5: .thursday, 6: .friday, 7: .saturday
	]
}
