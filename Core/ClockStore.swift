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

	@ObservationIgnored private let fileURL: URL
	@ObservationIgnored private let syncs: Bool
	@ObservationIgnored private var syncsInFlight = 0

	private struct Snapshot: Codable {
		var alarms: [AppAlarm]
		var cities: [WorldClockCity]
	}

	init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "ClockIt.json"), syncs: Bool = true) {
		self.fileURL = fileURL
		self.syncs = syncs
		if let data = try? Data(contentsOf: fileURL),
		   let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
			alarms = snapshot.alarms
			cities = snapshot.cities.sorted { $0.order < $1.order }
		} else {
			cities = WorldClockCity.sampleCities
		}
		if syncs {
			SyncHub.shared.register(.clock, apply: { [weak self] in self?.applyRemote($0) }, seed: { [weak self] in self?.encodedSnapshot() })
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
		alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
		persist()
		sync(alarm)
	}

	func setEnabled(_ isEnabled: Bool, for id: UUID) {
		guard var alarm = alarms.first(where: { $0.id == id }) else { return }
		alarm.isEnabled = isEnabled
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

	/// Reschedules every enabled alarm, e.g. after a setting that alarms carry with them changes.
	func resyncAlarms() {
		for alarm in alarms where alarm.isEnabled {
			sync(alarm)
		}
	}

	var nextAlarm: (alarm: AppAlarm, date: Date)? {
		alarms
			.filter(\.isEnabled)
			.compactMap { alarm in alarm.nextFireDate().map { (alarm, $0) } }
			.min { $0.1 < $1.1 }
	}

	/// One-time alarms that already rang are gone from AlarmKit; switch them off like the system Clock does.
	func reconcileFiredAlarms() {
		guard syncsInFlight == 0, let scheduled = AlarmScheduler.scheduledIDs() else { return }
		var changed = false
		for index in alarms.indices where alarms[index].isEnabled
			&& alarms[index].repeatDays.isEmpty
			&& !scheduled.contains(alarms[index].id) {
			alarms[index].isEnabled = false
			changed = true
		}
		if changed { persist() }
	}

	private func sync(_ alarm: AppAlarm) {
		syncsInFlight += 1
		Task {
			await AlarmScheduler.sync(alarm)
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
		try? JSONEncoder().encode(Snapshot(alarms: alarms, cities: cities))
	}

	// MARK: Sync

	/// Takes another device's alarms and cities. The ringing device then schedules what changed.
	private func applyRemote(_ data: Data) {
		guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
		let previous = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		alarms = snapshot.alarms.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
		cities = snapshot.cities.sorted { $0.order < $1.order }
		writeToDisk()

		for alarm in alarms where previous[alarm.id] != alarm {
			sync(alarm)
		}
		let current = Set(alarms.map(\.id))
		for id in previous.keys where !current.contains(id) {
			AlarmScheduler.cancel(id)
		}
	}
}
