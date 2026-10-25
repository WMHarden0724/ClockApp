//
//  AlarmScheduler.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

#if os(iOS)
import ActivityKit
import AlarmKit
import AppIntents
import UserNotifications
#endif
import SwiftUI


#if os(iOS)
/// Bridges `AppAlarm` to real system alarms. Only the device chosen to ring
/// (Settings › Ring on This Device, on by default for iPhone) schedules anything.
///
/// On iOS 26 that's AlarmKit, which rings through silent mode and shows the Live Activity.
/// Earlier, alarms and the mission nag are time-sensitive notifications and timers end
/// with `TimerNotifications`.
enum AlarmScheduler {
	static var isRingingDevice: Bool { AppSettings.shared.ringsOnThisDevice }

	static var usesAlarmKit: Bool {
		if #available(iOS 26, *) { true } else { false }
	}

	static func requestAuthorizationIfNeeded() async -> Bool {
		if #available(iOS 26, *) { return await AlarmKitScheduler.requestAuthorizationIfNeeded() }
		return await NotificationAlarms.requestAuthorizationIfNeeded()
	}

	/// Cancels any existing system alarm for this id, then reschedules it if it's active.
	/// `notBefore` holds alarms back while they're paused.
	static func sync(_ alarm: AppAlarm, isActive: Bool, notBefore: Date?) async {
		if #available(iOS 26, *) {
			await AlarmKitScheduler.sync(alarm, isActive: isActive, notBefore: notBefore)
		} else {
			NotificationAlarms.cancel(alarm.id)
			guard isRingingDevice, isActive, await requestAuthorizationIfNeeded() else { return }
			NotificationAlarms.schedule(alarm, notBefore: notBefore)
		}
	}

	static func cancel(_ id: UUID) {
		if #available(iOS 26, *) { AlarmKitScheduler.cancel(id) } else { NotificationAlarms.cancel(id) }
	}

	/// Rings again in a minute unless the wake-up mission gets done first. Stopping it reopens the mission.
	static func scheduleMissionNag(_ mission: ClockStore.ActiveMission, sound: TimerSound) async {
		if #available(iOS 26, *) {
			await AlarmKitScheduler.scheduleMissionNag(mission, sound: sound)
		} else {
			guard isRingingDevice, await requestAuthorizationIfNeeded() else { return }
			NotificationAlarms.scheduleMissionNag(mission, sound: sound)
		}
	}

	/// Starts a countdown that rings like an alarm and shows a Live Activity. Returns false if not allowed.
	/// Before iOS 26 there's nothing to start: `TimerNotifications` posts the end.
	static func startTimer(_ timer: AppTimer) async -> Bool {
		if #available(iOS 26, *) { return await AlarmKitScheduler.startTimer(timer) }
		return true
	}

	static func pause(_ id: UUID) {
		if #available(iOS 26, *) { AlarmKitScheduler.pause(id) }
	}

	static func resume(_ id: UUID) {
		if #available(iOS 26, *) { AlarmKitScheduler.resume(id) }
	}

	/// Ids AlarmKit currently has scheduled, or nil if we can't know (not authorized, or no AlarmKit).
	static func scheduledIDs() -> Set<UUID>? {
		if #available(iOS 26, *) { return AlarmKitScheduler.scheduledIDs() }
		return nil
	}
}


@available(iOS 26, *)
private enum AlarmKitScheduler {
	private static var manager: AlarmManager { .shared }

	private static var isRingingDevice: Bool { AlarmScheduler.isRingingDevice }

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

	/// Cancels any existing system alarm for this id, then reschedules it if it's active.
	/// `notBefore` holds alarms back while they're paused.
	static func sync(_ alarm: AppAlarm, isActive: Bool, notBefore: Date?) async {
		cancel(alarm.id)
		guard isRingingDevice, isActive, let schedule = schedule(for: alarm, notBefore: notBefore) else { return }
		guard await requestAuthorizationIfNeeded() else { return }

		let snooze = AlarmButton(text: "Snooze", textColor: ClockItPalette.accent, systemImageName: "zzz")
		let alert = alertPresentation(title: "\(alarm.displayLabel)", secondaryButton: snooze)
		let attributes = AlarmAttributes<ClockItAlarmMetadata>(
			presentation: AlarmPresentation(alert: alert),
			metadata: ClockItAlarmMetadata(kind: .alarm, label: alarm.displayLabel, uses24Hour: AppSettings.shared.uses24Hour),
			tintColor: ClockItPalette.accent
		)
		// Stop runs in the app: it books the next ring, or opens the wake-up mission.
		let stopIntent: any LiveActivityIntent = alarm.mission == .none
			? AlarmStoppedIntent(alarmID: alarm.id)
			: WakeMissionIntent(alarmID: alarm.id)
		let configuration = AlarmManager.AlarmConfiguration(
			countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(alarm.snoozeMinutes * 60)),
			schedule: schedule,
			attributes: attributes,
			stopIntent: stopIntent,
			sound: alarm.sound.fileName.map { .named($0) } ?? .default
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

	/// Rings again in a minute unless the wake-up mission gets done first. Stopping it reopens the mission.
	static func scheduleMissionNag(_ mission: ClockStore.ActiveMission, sound: TimerSound) async {
		guard isRingingDevice, await requestAuthorizationIfNeeded() else { return }
		let presentation = AlarmPresentation(
			alert: alertPresentation(title: "Finish your wake-up mission"),
			countdown: AlarmPresentation.Countdown(title: "Finish your mission to stop the alarm")
		)
		let attributes = AlarmAttributes<ClockItAlarmMetadata>(
			presentation: presentation,
			metadata: ClockItAlarmMetadata(kind: .alarm, label: mission.label, uses24Hour: AppSettings.shared.uses24Hour),
			tintColor: ClockItPalette.accent
		)
		let configuration = AlarmManager.AlarmConfiguration(
			countdownDuration: Alarm.CountdownDuration(preAlert: 60, postAlert: nil),
			attributes: attributes,
			stopIntent: WakeMissionIntent(alarmID: mission.alarmID),
			sound: sound.fileName.map { .named($0) } ?? .default
		)
		_ = try? await manager.schedule(id: mission.nagID, configuration: configuration)
	}

	// MARK: Timers

	/// Starts a countdown that rings like an alarm and shows a Live Activity. Returns false if not allowed.
	static func startTimer(_ timer: AppTimer) async -> Bool {
		// Another device does the ringing; the timer still syncs there.
		guard isRingingDevice else { return true }
		guard await requestAuthorizationIfNeeded() else { return false }

		let color = ClockItPalette.color(named: timer.colorName)
		let presentation = AlarmPresentation(
			alert: alertPresentation(
				title: "\(timer.displayLabel)",
				secondaryButton: AlarmButton(text: "Repeat", textColor: color, systemImageName: "repeat")
			),
			countdown: AlarmPresentation.Countdown(
				title: "\(timer.displayLabel)",
				pauseButton: AlarmButton(text: "Pause", textColor: color, systemImageName: "pause.fill")
			),
			paused: AlarmPresentation.Paused(
				title: "Paused",
				resumeButton: AlarmButton(text: "Resume", textColor: color, systemImageName: "play.fill")
			)
		)
		let attributes = AlarmAttributes<ClockItAlarmMetadata>(
			presentation: presentation,
			metadata: ClockItAlarmMetadata(kind: .timer, label: timer.displayLabel, colorName: timer.colorName, symbolName: timer.kind.symbol, uses24Hour: AppSettings.shared.uses24Hour),
			tintColor: color
		)
		let configuration = AlarmManager.AlarmConfiguration(
			countdownDuration: Alarm.CountdownDuration(preAlert: timer.remaining, postAlert: timer.duration),
			attributes: attributes,
			sound: timer.sound.fileName.map { .named($0) } ?? .default
		)

		do {
			_ = try await manager.schedule(id: timer.id, configuration: configuration)
			return true
		} catch {
			print("Failed to start timer \(timer.id): \(error)")
			return false
		}
	}

	static func pause(_ id: UUID) {
		try? manager.pause(id: id)
	}

	static func resume(_ id: UUID) {
		try? manager.resume(id: id)
	}

	/// Ids AlarmKit currently has scheduled, or nil if we can't know (not authorized).
	static func scheduledIDs() -> Set<UUID>? {
		guard isRingingDevice, manager.authorizationState == .authorized, let alarms = try? manager.alarms else { return nil }
		return Set(alarms.map(\.id))
	}

	/// iOS 26.1 dropped the alert's Stop button; 26.0 still needs one.
	private static func alertPresentation(title: LocalizedStringResource, secondaryButton: AlarmButton? = nil) -> AlarmPresentation.Alert {
		let behavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = secondaryButton == nil ? nil : .countdown
		if #available(iOS 26.1, *) {
			return AlarmPresentation.Alert(title: title, secondaryButton: secondaryButton, secondaryButtonBehavior: behavior)
		}
		let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
		return AlarmPresentation.Alert(title: title, stopButton: stop, secondaryButton: secondaryButton, secondaryButtonBehavior: behavior)
	}

	private static func schedule(for alarm: AppAlarm, notBefore: Date?) -> Alarm.Schedule? {
		if alarm.needsFixedSchedule(notBefore: notBefore) {
			return alarm.nextFireDate(notBefore: notBefore).map { .fixed($0) }
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


/// Alarms as time-sensitive notifications, for iOS 17 through 25. They don't ring through
/// silent mode and the sound stops after 30 seconds, but they arrive on time.
private enum NotificationAlarms {
	private static var center: UNUserNotificationCenter { .current() }

	static func requestAuthorizationIfNeeded() async -> Bool {
		center.delegate = NotificationPresenter.shared
		switch await center.notificationSettings().authorizationStatus {
		case .authorized, .provisional, .ephemeral:
			return true
		case .notDetermined:
			return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
		default:
			return false
		}
	}

	static func schedule(_ alarm: AppAlarm, notBefore: Date?) {
		let content = content(
			title: alarm.displayLabel,
			body: alarm.mission == .none ? "Alarm" : "Tap to start your wake-up mission",
			sound: alarm.sound,
			alarmID: alarm.id,
			action: alarm.mission == .none ? .stopped : .mission
		)

		if alarm.needsFixedSchedule(notBefore: notBefore) || alarm.repeatDays.isEmpty {
			guard let date = alarm.nextFireDate(notBefore: notBefore) else { return }
			let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
			add(identifier(alarm.id), content, UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
			return
		}
		for weekday in alarm.repeatDays {
			let components = DateComponents(hour: alarm.hour, minute: alarm.minute, weekday: weekday)
			add(identifier(alarm.id, weekday: weekday), content, UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
		}
	}

	static func scheduleMissionNag(_ mission: ClockStore.ActiveMission, sound: TimerSound) {
		let content = content(
			title: "Finish your wake-up mission",
			body: mission.label,
			sound: sound,
			alarmID: mission.alarmID,
			action: .mission
		)
		add(identifier(mission.nagID), content, UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false))
	}

	static func cancel(_ id: UUID) {
		let ids = [identifier(id)] + (1...7).map { identifier(id, weekday: $0) }
		center.removePendingNotificationRequests(withIdentifiers: ids)
		center.removeDeliveredNotifications(withIdentifiers: ids)
	}

	private static func content(title: String, body: String, sound: TimerSound, alarmID: UUID, action: NotificationPresenter.AlarmTapAction) -> UNMutableNotificationContent {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = sound.fileName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
		content.interruptionLevel = .timeSensitive
		content.userInfo = NotificationPresenter.userInfo(alarmID: alarmID, action: action)
		return content
	}

	private static func add(_ identifier: String, _ content: UNNotificationContent, _ trigger: UNNotificationTrigger) {
		center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
	}

	private static func identifier(_ id: UUID, weekday: Int? = nil) -> String {
		weekday.map { "alarm.\(id).\($0)" } ?? "alarm.\(id)"
	}
}
#else
/// Mac, Apple Watch and Vision Pro can't ring AlarmKit alarms. Changes made there sync to the
/// iPhone, which schedules them.
enum AlarmScheduler {
	static let isRingingDevice = false

	static func sync(_ alarm: AppAlarm, isActive: Bool, notBefore: Date?) async {}
	static func scheduleMissionNag(_ mission: ClockStore.ActiveMission, sound: TimerSound) async {}
	static func cancel(_ id: UUID) {}
	static func startTimer(_ timer: AppTimer) async -> Bool { true }
	static func pause(_ id: UUID) {}
	static func resume(_ id: UUID) {}
	static func scheduledIDs() -> Set<UUID>? { nil }
}
#endif
