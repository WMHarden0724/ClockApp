//
//  ClockStore.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import Foundation
import Observation
import SwiftUI


/// Owns alarms and world clock cities, persists them to disk, and keeps AlarmKit in sync.
@Observable
final class ClockStore {
	private(set) var alarms: [AppAlarm] = []
	private(set) var cities: [WorldClockCity] = []
	/// While set, no alarm rings before this date (Pause All Alarms).
	private(set) var pausedUntil: Date?
	/// Groups switched off as a whole.
	private(set) var disabledGroups: Set<String> = []
	/// A mission-alarm you stopped but haven't finished the mission for yet.
	private(set) var activeMission: ActiveMission?

	@ObservationIgnored private let fileURL: URL
	@ObservationIgnored private let syncs: Bool
	@ObservationIgnored private var syncsInFlight = 0

	struct ActiveMission: Identifiable, Equatable {
		let alarmID: UUID
		let type: AppAlarm.MissionType
		let label: String
		/// The backup alarm that rings again if the mission isn't done in time.
		let nagID: UUID

		var id: UUID { alarmID }
	}

	private struct Snapshot: Codable {
		var alarms: [AppAlarm]
		var cities: [WorldClockCity]
		var pausedUntil: Date?
		var disabledGroups: Set<String>?
	}

	/// The app's store. Siri, Shortcuts, Control Center and alarm buttons act on it too.
	static let shared = ClockStore()

	init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "ClockIt.json"), syncs: Bool = true) {
		self.fileURL = fileURL
		self.syncs = syncs
		if let data = try? Data(contentsOf: fileURL),
		   let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
			alarms = snapshot.alarms
			cities = snapshot.cities.sorted { $0.order < $1.order }
			pausedUntil = snapshot.pausedUntil
			disabledGroups = snapshot.disabledGroups ?? []
		} else {
			cities = WorldClockCity.sampleCities
		}
		if syncs {
			SyncHub.shared.register(.clock, apply: { [weak self] in self?.applyRemote($0) }, seed: { [weak self] in self?.encodedSnapshot() })
			shareAlarms()
		}
	}

	static var preview: ClockStore {
		ClockStore(fileURL: URL.temporaryDirectory.appending(path: "ClockIt-preview-\(UUID()).json"), syncs: false)
	}

	// MARK: Alarms

	func save(_ alarm: AppAlarm) {
		if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
			alarms[index] = alarm
		} else {
			alarms.append(alarm)
		}
		sortAlarms()
		persist()
		sync(alarm)
	}

	func setEnabled(_ isEnabled: Bool, for id: UUID) {
		guard var alarm = alarms.first(where: { $0.id == id }) else { return }
		alarm.isEnabled = isEnabled
		if !isEnabled { alarm.skipUntil = nil }
		save(alarm)
	}

	func deleteAlarm(id: UUID) {
		alarms.removeAll { $0.id == id }
		AlarmScheduler.cancel(id)
		persist()
	}

	func deleteAlarms(at offsets: IndexSet) {
		for id in offsets.map({ alarms[$0].id }) {
			deleteAlarm(id: id)
		}
	}

	/// A copy of an alarm, saved right after the original.
	@discardableResult
	func duplicate(id: UUID) -> AppAlarm? {
		guard var copy = alarms.first(where: { $0.id == id }) else { return nil }
		copy = AppAlarm(
			id: UUID(), label: copy.label, hour: copy.hour, minute: copy.minute, isEnabled: copy.isEnabled,
			repeatDays: copy.repeatDays, specificDate: copy.specificDate, snoozeMinutes: copy.snoozeMinutes,
			soundName: copy.soundName, missionType: copy.missionType, skipUntil: nil,
			timeZoneIdentifier: copy.timeZoneIdentifier, sunrise: copy.sunrise, group: copy.group, isQuick: nil
		)
		save(copy)
		return copy
	}

	/// Skips just the next ring of a repeating alarm.
	func skipNext(id: UUID) {
		guard var alarm = alarms.first(where: { $0.id == id }), let next = alarm.nextFireDate(notBefore: pausedUntil) else { return }
		alarm.skipUntil = next.addingTimeInterval(60)
		save(alarm)
	}

	func cancelSkip(id: UUID) {
		guard var alarm = alarms.first(where: { $0.id == id }) else { return }
		alarm.skipUntil = nil
		save(alarm)
	}

	/// A one-time alarm that removes itself after ringing: a nap, or "remind me in an hour".
	@discardableResult
	func addQuickAlarm(at date: Date, label: String) -> AppAlarm {
		let calendar = Calendar.current
		let minuteDate = calendar.date(bySetting: .second, value: 0, of: date) ?? date
		let parts = calendar.dateComponents([.hour, .minute], from: minuteDate)
		let alarm = AppAlarm(
			id: UUID(), label: label, hour: parts.hour ?? 0, minute: parts.minute ?? 0, isEnabled: true,
			repeatDays: [], specificDate: calendar.startOfDay(for: minuteDate),
			snoozeMinutes: AppSettings.shared.defaultSnoozeMinutes, soundName: TimerSound.standard.rawValue,
			missionType: nil, isQuick: true
		)
		save(alarm)
		return alarm
	}

	/// When you usually get up: your earliest repeating alarm, or 7:00.
	var usualWakeTime: (hour: Int, minute: Int) {
		let repeating = alarms.filter { $0.isEnabled && !$0.repeatDays.isEmpty && $0.sunrise == nil && $0.timeZone == nil }
		guard let first = repeating.min(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) else { return (7, 0) }
		return (first.hour, first.minute)
	}

	// MARK: Groups and pausing

	/// Group names in the order they first appear.
	var groups: [String] {
		var seen = Set<String>()
		return alarms.compactMap(\.group).filter { !$0.isEmpty && seen.insert($0).inserted }
	}

	func isGroupEnabled(_ group: String) -> Bool {
		!disabledGroups.contains(group)
	}

	func setGroupEnabled(_ isEnabled: Bool, group: String) {
		if isEnabled { disabledGroups.remove(group) } else { disabledGroups.insert(group) }
		persist()
		resyncAlarms()
	}

	/// No alarms ring until `date`; they come back on their own afterwards.
	func pauseAlarms(until date: Date) {
		pausedUntil = date
		persist()
		resyncAlarms()
	}

	func resumeAlarms() {
		pausedUntil = nil
		persist()
		resyncAlarms()
	}

	var isPaused: Bool { (pausedUntil ?? .distantPast) > Date() }

	/// Whether an alarm should be scheduled at all: switched on, and its group too.
	func isActive(_ alarm: AppAlarm) -> Bool {
		alarm.isEnabled && (alarm.group.map(isGroupEnabled) ?? true)
	}

	/// Reschedules every alarm, e.g. after a setting that alarms carry with them changes.
	func resyncAlarms() {
		for alarm in alarms {
			sync(alarm)
		}
	}

	var nextAlarm: (alarm: AppAlarm, date: Date)? {
		alarms
			.filter(isActive)
			.compactMap { alarm in alarm.nextFireDate(notBefore: activePause).map { (alarm, $0) } }
			.min { $0.1 < $1.1 }
	}

	private var activePause: Date? {
		isPaused ? pausedUntil : nil
	}

	/// Catches up after alarms rang while the app wasn't running: one-time alarms switch off
	/// (quick ones go away), and alarms scheduled one ring at a time get their next ring.
	func reconcileFiredAlarms() {
		guard syncsInFlight == 0, let scheduled = AlarmScheduler.scheduledIDs() else { return }
		let now = Date()
		var changed = false

		if let pausedUntil, pausedUntil <= now {
			self.pausedUntil = nil
			changed = true
		}
		for index in alarms.indices {
			if let skipUntil = alarms[index].skipUntil, skipUntil <= now {
				alarms[index].skipUntil = nil
				changed = true
			}
		}

		var toResync: [AppAlarm] = []
		for alarm in alarms where isActive(alarm) && !scheduled.contains(alarm.id) {
			if alarm.isOneTime {
				if alarm.isQuick == true {
					alarms.removeAll { $0.id == alarm.id }
				} else if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
					alarms[index].isEnabled = false
				}
				changed = true
			} else {
				toResync.append(alarm)
			}
		}
		if changed { persist() }
		for alarm in toResync { sync(alarm) }
	}

	/// The alarm was stopped. Called by its Stop button, in the app's process.
	func alarmDidStop(id: UUID) {
		guard let alarm = alarms.first(where: { $0.id == id }) else { return }
		if alarm.isQuick == true {
			deleteAlarm(id: id)
		} else if alarm.isOneTime {
			var finished = alarm
			finished.isEnabled = false
			save(finished)
		} else {
			// Book the next ring for alarms AlarmKit can't repeat by itself.
			var next = alarm
			if let skipUntil = next.skipUntil, skipUntil <= Date() { next.skipUntil = nil }
			save(next)
		}
	}

	// MARK: Missions

	/// Stop was pressed on an alarm with a mission: open the mission, and ring again in a minute unless it's done.
	func beginMission(alarmID: UUID) {
		guard let alarm = alarms.first(where: { $0.id == alarmID }), alarm.mission != .none else {
			alarmDidStop(id: alarmID)
			return
		}
		if let current = activeMission, current.alarmID == alarmID {
			AlarmScheduler.cancel(current.nagID)
		}
		let mission = ActiveMission(alarmID: alarmID, type: alarm.mission, label: alarm.displayLabel, nagID: UUID())
		activeMission = mission
		Task { await AlarmScheduler.scheduleMissionNag(mission, sound: alarm.sound) }
	}

	func completeMission() {
		guard let mission = activeMission else { return }
		AlarmScheduler.cancel(mission.nagID)
		activeMission = nil
		alarmDidStop(id: mission.alarmID)
	}

	// MARK: Commands

	/// Runs an alarm command from Siri, Shortcuts or Control Center, and says what happened.
	@discardableResult
	func perform(_ action: AlarmAction) -> String {
		switch action {
		case .set(let hour, let minute, let label):
			let now = Date()
			var parts = DateComponents()
			parts.hour = hour
			parts.minute = minute
			guard let date = Calendar.current.nextDate(after: now, matching: parts, matchingPolicy: .nextTime) else {
				return "I couldn't set that alarm."
			}
			let alarm = AppAlarm(
				id: UUID(), label: label, hour: hour, minute: minute, isEnabled: true, repeatDays: [],
				specificDate: Calendar.current.startOfDay(for: date), snoozeMinutes: AppSettings.shared.defaultSnoozeMinutes,
				soundName: TimerSound.standard.rawValue, missionType: nil
			)
			save(alarm)
			return "Alarm set for \(date.relativeDayAndTime)."
		case .next:
			if isPaused, let pausedUntil {
				return "Your alarms are paused until \(pausedUntil.formatted(date: .abbreviated, time: .omitted))."
			}
			guard let next = nextAlarm else { return "You don't have any alarms set." }
			return "\(next.alarm.displayLabel) rings \(next.date.relativeDayAndTime), in \(next.date.countdownText())."
		case .setEnabled(let id, let isEnabled):
			guard let alarm = alarms.first(where: { $0.id == id }) else { return "I couldn't find that alarm." }
			setEnabled(isEnabled, for: id)
			return "\(alarm.displayLabel) at \(alarm.timeText) is \(isEnabled ? "on" : "off")."
		case .skipNext(let id):
			guard let alarm = alarms.first(where: { $0.id == id }), let next = alarm.nextFireDate(notBefore: activePause) else {
				return "That alarm isn't going to ring."
			}
			skipNext(id: id)
			return "Skipping \(alarm.displayLabel) on \(next.relativeDayAndTime)."
		case .pause(let until):
			let day = Calendar.current.startOfDay(for: until)
			pauseAlarms(until: day)
			return "Alarms are paused until \(day.formatted(date: .complete, time: .omitted))."
		case .stopped(let id):
			alarmDidStop(id: id)
			return ""
		case .mission(let id):
			beginMission(alarmID: id)
			return ""
		}
	}

	private func sortAlarms() {
		alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
	}

	private func sync(_ alarm: AppAlarm) {
		syncsInFlight += 1
		let isActive = isActive(alarm)
		let notBefore = activePause
		Task {
			await AlarmScheduler.sync(alarm, isActive: isActive, notBefore: notBefore)
			syncsInFlight -= 1
		}
	}

	// MARK: Cities

	func addCity(_ city: WorldClockCity) {
		// Several cities can share a time zone (New York and Brunswick, GA), so match on both.
		guard !cities.contains(where: { $0.timeZoneIdentifier == city.timeZoneIdentifier && $0.name == city.name }) else { return }
		var city = city
		city.order = cities.count
		cities.append(city)
		persist()
	}

	func moveCities(from source: IndexSet, to destination: Int) {
		cities.move(fromOffsets: source, toOffset: destination)
		renumberCities()
	}

	func deleteCity(id: UUID) {
		cities.removeAll { $0.id == id }
		renumberCities()
	}

	func deleteCities(at offsets: IndexSet) {
		cities.remove(atOffsets: offsets)
		renumberCities()
	}

	private func renumberCities() {
		for index in cities.indices {
			cities[index].order = index
		}
		persist()
	}

	// MARK: Persistence

	/// Saves locally and shares the change with your other devices.
	private func persist() {
		writeToDisk()
		if syncs, let data = encodedSnapshot() {
			SyncHub.shared.publish(.clock, payload: data)
		}
		shareAlarms()
	}

	private func writeToDisk() {
		do {
			try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			if let data = encodedSnapshot() {
				try data.write(to: fileURL, options: .atomic)
			}
		} catch {
			print("Failed to save ClockIt data: \(error)")
		}
	}

	private func encodedSnapshot() -> Data? {
		try? JSONEncoder().encode(Snapshot(alarms: alarms, cities: cities, pausedUntil: pausedUntil, disabledGroups: disabledGroups))
	}

	/// Re-plans the bedtime reminder, e.g. after the sleep goal changes.
	func refreshReminders() {
		shareAlarms()
	}

	/// Alarms for Siri and the Control Center toggle, and the bedtime reminder for the next one.
	private func shareAlarms() {
		guard syncs else { return }
		AlarmShelf.write(alarms.map {
			AlarmSummary(id: $0.id, name: $0.displayLabel, timeText: $0.timeText, scheduleText: $0.scheduleText, isEnabled: isActive($0))
		})
		#if os(iOS)
		BedtimeReminder.update(nextAlarm: nextAlarm?.date)
		#endif
		#if !os(watchOS)
		ClockItShortcutsUpdater.update()
		#endif
	}

	// MARK: Sync

	/// Takes another device's alarms and cities. The ringing device then schedules what changed.
	private func applyRemote(_ data: Data) {
		guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
		let previous = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		let pauseOrGroupsChanged = snapshot.pausedUntil != pausedUntil || (snapshot.disabledGroups ?? []) != disabledGroups
		alarms = snapshot.alarms
		sortAlarms()
		cities = snapshot.cities.sorted { $0.order < $1.order }
		pausedUntil = snapshot.pausedUntil
		disabledGroups = snapshot.disabledGroups ?? []
		writeToDisk()
		shareAlarms()

		for alarm in alarms where pauseOrGroupsChanged || previous[alarm.id] != alarm {
			sync(alarm)
		}
		let current = Set(alarms.map(\.id))
		for id in previous.keys where !current.contains(id) {
			AlarmScheduler.cancel(id)
		}
	}
}
