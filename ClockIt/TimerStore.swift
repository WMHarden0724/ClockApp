//
//  TimerStore.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import ActivityKit
import AlarmKit
import Foundation
import Observation
import SwiftUI


/// Owns running timers (backed by AlarmKit) and the stopwatch, and persists both.
@Observable
final class TimerStore {
	private(set) var timers: [AppTimer] = []
	private(set) var recents: [TimerPreset] = []
	private(set) var stopwatch = StopwatchState()
	private(set) var history: [StopwatchSession] = []
	var errorMessage: String?

	@ObservationIgnored private let fileURL: URL
	@ObservationIgnored private var pendingIDs: Set<UUID> = []
	@ObservationIgnored private var updatesTask: Task<Void, Never>?

	private struct Snapshot: Codable {
		var timers: [AppTimer]
		var recents: [TimerPreset]
		var stopwatch: StopwatchState
		var history: [StopwatchSession]? // optional so files saved before history existed still load
	}

	init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "ClockIt-timers.json"), observesAlarmKit: Bool = true) {
		self.fileURL = fileURL
		if let data = try? Data(contentsOf: fileURL),
		   let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
			timers = snapshot.timers
			recents = snapshot.recents
			stopwatch = snapshot.stopwatch
			history = snapshot.history ?? []
		}
		if observesAlarmKit {
			updatesTask = Task { [weak self] in
				for await alarms in AlarmManager.shared.alarmUpdates {
					self?.reconcile(with: alarms)
				}
			}
		}
	}

	static var preview: TimerStore {
		TimerStore(fileURL: URL.temporaryDirectory.appending(path: "ClockIt-timers-preview-\(UUID()).json"), observesAlarmKit: false)
	}

	var quickStarts: [TimerPreset] {
		var seen = Set<String>()
		return (recents + TimerPreset.defaults).filter { seen.insert($0.id).inserted }.prefix(8).map { $0 }
	}

	// MARK: Timers

	func start(duration: TimeInterval, label: String, notes: String = "", category: TimerCategory = .general, colorName: String) {
		guard duration > 0 else { return }
		let timer = AppTimer(
			id: UUID(),
			label: label,
			duration: duration,
			remaining: duration,
			endDate: Date().addingTimeInterval(duration),
			colorName: colorName,
			soundName: "default",
			createdAt: Date(),
			category: category,
			notes: notes.isEmpty ? nil : notes
		)
		timers.insert(timer, at: 0)
		remember(TimerPreset(duration: duration, label: label, colorName: colorName, category: category))
		persist()

		pendingIDs.insert(timer.id)
		Task {
			let scheduled = await AlarmScheduler.startTimer(timer)
			pendingIDs.remove(timer.id)
			if !scheduled {
				timers.removeAll { $0.id == timer.id }
				errorMessage = "Couldn't start the timer. Make sure ClockIt is allowed to ring alarms in Settings › ClockIt."
				persist()
			}
		}
	}

	func pause(id: UUID) {
		guard let index = timers.firstIndex(where: { $0.id == id }), timers[index].isRunning else { return }
		timers[index].remaining = timers[index].remaining(at: Date())
		timers[index].endDate = nil
		AlarmScheduler.pause(id)
		persist()
	}

	func resume(id: UUID) {
		guard let index = timers.firstIndex(where: { $0.id == id }), !timers[index].isRunning else { return }
		timers[index].endDate = Date().addingTimeInterval(timers[index].remaining)
		AlarmScheduler.resume(id)
		persist()
	}

	func cancel(id: UUID) {
		timers.removeAll { $0.id == id }
		AlarmScheduler.cancel(id)
		persist()
	}

	private func remember(_ preset: TimerPreset) {
		recents.removeAll { $0.id == preset.id }
		recents.insert(preset, at: 0)
		recents = Array(recents.prefix(6))
	}

	/// Adopts changes made outside the app: Live Activity buttons, the alert's Stop/Repeat, or finished timers.
	private func reconcile(with alarms: [Alarm]) {
		let alarmsByID = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		let states = Dictionary(
			Activity<AlarmAttributes<ClockItAlarmMetadata>>.activities.map { ($0.content.state.alarmID, $0.content.state) },
			uniquingKeysWith: { first, _ in first }
		)
		let now = Date()
		var changed = false

		for timer in timers where !pendingIDs.contains(timer.id) {
			guard let alarm = alarmsByID[timer.id], let index = timers.firstIndex(where: { $0.id == timer.id }) else {
				// Stopped from the alert or cancelled from the Live Activity.
				timers.removeAll { $0.id == timer.id }
				changed = true
				continue
			}

			if let state = states[timer.id] {
				switch state.mode {
				case .countdown(let countdown):
					timers[index].endDate = countdown.fireDate
				case .paused(let paused):
					timers[index].endDate = nil
					timers[index].remaining = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
				default:
					break
				}
				changed = true
			} else if alarm.state == .paused, timer.isRunning {
				timers[index].remaining = timer.remaining(at: now)
				timers[index].endDate = nil
				changed = true
			} else if alarm.state == .countdown, !timer.isRunning {
				timers[index].endDate = now.addingTimeInterval(timer.remaining)
				changed = true
			}
		}
		if changed { persist() }
	}

	// MARK: Stopwatch

	func startStopwatch() {
		guard !stopwatch.isRunning else { return }
		stopwatch.startDate = Date()
		persist()
	}

	func stopStopwatch() {
		guard let start = stopwatch.startDate else { return }
		stopwatch.accumulated += Date().timeIntervalSince(start)
		stopwatch.startDate = nil
		persist()
	}

	func lap() {
		guard stopwatch.isRunning else { return }
		stopwatch.laps.append(stopwatch.currentLap(at: Date()))
		persist()
	}

	/// Clears the stopwatch, saving the run to history first. The unfinished last lap is kept so laps add up to the total.
	func resetStopwatch() {
		let now = Date()
		let total = stopwatch.elapsed(at: now)
		if total > 0 {
			var laps = stopwatch.laps
			let finalLap = stopwatch.currentLap(at: now)
			if !laps.isEmpty, finalLap > 0.01 { laps.append(finalLap) }
			history.insert(StopwatchSession(id: UUID(), date: now, total: total, laps: laps), at: 0)
			history = Array(history.prefix(100))
		}
		stopwatch = StopwatchState()
		persist()
	}

	func deleteSessions(at offsets: IndexSet) {
		history.remove(atOffsets: offsets)
		persist()
	}

	func clearHistory() {
		history.removeAll()
		persist()
	}

	// MARK: Persistence

	private func persist() {
		do {
			try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			let data = try JSONEncoder().encode(Snapshot(timers: timers, recents: recents, stopwatch: stopwatch, history: history))
			try data.write(to: fileURL, options: .atomic)
		} catch {
			print("Failed to save ClockIt timers: \(error)")
		}
	}
}
