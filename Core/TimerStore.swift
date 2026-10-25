//
//  TimerStore.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(iOS)
import ActivityKit
import AlarmKit
#endif
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
	/// The run Reset just cleared, kept for a few seconds so it can be brought back.
	private(set) var lastReset: StopwatchReset?
	var errorMessage: String?

	@ObservationIgnored private let fileURL: URL
	@ObservationIgnored private let live: Bool
	@ObservationIgnored private var pendingIDs: Set<UUID> = []
	@ObservationIgnored private var updatesTask: Task<Void, Never>?

	private struct Snapshot: Codable {
		var timers: [AppTimer]
		var recents: [TimerPreset]
		var stopwatch: StopwatchState
		var history: [StopwatchSession]? // optional so files saved before history existed still load
	}

	/// What the stopwatch channel shares: the live stopwatch and its saved runs.
	private struct StopwatchSync: Codable {
		var stopwatch: StopwatchState
		var history: [StopwatchSession]
	}

	/// The app's store. Siri, Shortcuts, Control Center and Live Activity buttons act on it too.
	static let shared = TimerStore()

	/// `live` stores sync with your other devices and follow AlarmKit; previews don't.
	init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "ClockIt-timers.json"), live: Bool = true) {
		self.fileURL = fileURL
		self.live = live
		if let data = try? Data(contentsOf: fileURL),
		   let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
			timers = snapshot.timers
			recents = snapshot.recents
			stopwatch = snapshot.stopwatch
			history = snapshot.history ?? []
		}
		if live {
			SyncHub.shared.register(.timers, apply: { [weak self] in self?.applyRemote($0) }, seed: { [weak self] in self?.encodedTimers() })
			SyncHub.shared.register(.stopwatch, apply: { [weak self] in self?.applyRemoteStopwatch($0) }, seed: { [weak self] in self?.encodedStopwatch() })
		}
		#if os(iOS)
		if live {
			StopwatchActivity.update(for: stopwatch)
			updatesTask = Task { [weak self] in
				for await alarms in AlarmManager.shared.alarmUpdates {
					self?.reconcile(with: alarms)
				}
			}
		}
		#endif
	}

	static var preview: TimerStore {
		TimerStore(fileURL: URL.temporaryDirectory.appending(path: "ClockIt-timers-preview-\(UUID()).json"), live: false)
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
			notes: notes.isEmpty ? nil : notes,
			originDevice: SyncHub.shared.deviceID
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

	#if os(iOS)
	/// Adopts changes made outside the app: Live Activity buttons, the alert's Stop/Repeat, or finished timers.
	private func reconcile(with alarms: [Alarm]) {
		// Only the ringing device's AlarmKit state is authoritative.
		guard AlarmScheduler.isRingingDevice else { return }
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
	#endif

	// MARK: Stopwatch

	func startStopwatch() {
		guard !stopwatch.isRunning else { return }
		stopwatch.startDate = Date()
		lastReset = nil // a new run replaces the one you could have brought back
		persistStopwatch()
	}

	func stopStopwatch() {
		guard let start = stopwatch.startDate else { return }
		stopwatch.accumulated += Date().timeIntervalSince(start)
		stopwatch.startDate = nil
		persistStopwatch()
	}

	func lap() {
		guard stopwatch.isRunning else { return }
		stopwatch.laps.append(stopwatch.currentLap(at: Date()))
		persistStopwatch()
	}

	/// Clears the stopwatch, saving the run to history first. The unfinished last lap is kept so laps add up to the total.
	func resetStopwatch() {
		let now = Date()
		let total = stopwatch.elapsed(at: now)
		guard total > 0 else { return }
		var laps = stopwatch.laps
		let finalLap = stopwatch.currentLap(at: now)
		if !laps.isEmpty, finalLap > 0.01 { laps.append(finalLap) }
		let session = StopwatchSession(id: UUID(), date: now, total: total, laps: laps)
		history.insert(session, at: 0)
		history = Array(history.prefix(100))
		lastReset = StopwatchReset(id: UUID(), state: stopwatch, sessionID: session.id)
		stopwatch = StopwatchState()
		persistStopwatch()
	}

	/// Brings back the run Reset just cleared, and takes it back out of history.
	func undoReset() {
		guard let lastReset else { return }
		history.removeAll { $0.id == lastReset.sessionID }
		stopwatch = lastReset.state
		self.lastReset = nil
		persistStopwatch()
	}

	/// Lets the undo offer lapse, unless a newer reset has replaced it.
	func dismissUndo(_ id: UUID) {
		if lastReset?.id == id { lastReset = nil }
	}

	/// Runs a command from Siri, Shortcuts, Control Center or the Live Activity, and says what happened.
	@discardableResult
	func perform(_ command: StopwatchCommand) -> String {
		switch command {
		case .start:
			guard !stopwatch.isRunning else { return "The stopwatch is already running." }
			startStopwatch()
			return "Stopwatch started."
		case .stop:
			guard stopwatch.isRunning else { return "The stopwatch isn't running." }
			stopStopwatch()
			return "Stopped at \(stopwatch.accumulated.stopwatchText)."
		case .toggle:
			return perform(stopwatch.isRunning ? .stop : .start)
		case .lap:
			guard stopwatch.isRunning else { return "Start the stopwatch to record laps." }
			lap()
			return "Lap \(stopwatch.laps.count): \(stopwatch.laps.last?.stopwatchText ?? "")."
		case .reset:
			let total = stopwatch.elapsed(at: Date())
			guard total > 0 else { return "The stopwatch is already at zero." }
			resetStopwatch()
			return "Saved a \(total.stopwatchText) run to History."
		}
	}

	func deleteSessions(at offsets: IndexSet) {
		history.remove(atOffsets: offsets)
		persistStopwatch()
	}

	func clearHistory() {
		history.removeAll()
		persistStopwatch()
	}

	// MARK: Persistence

	/// Saves locally and shares the timers with your other devices.
	private func persist() {
		writeToDisk()
		if live, let data = encodedTimers() {
			SyncHub.shared.publish(.timers, payload: data)
		}
	}

	/// Saves locally, shares the stopwatch with your other devices, and refreshes its Live Activity.
	private func persistStopwatch() {
		writeToDisk()
		if live, let data = encodedStopwatch() {
			SyncHub.shared.publish(.stopwatch, payload: data)
		}
		stopwatchDidChange()
	}

	private func stopwatchDidChange() {
		#if os(iOS)
		if live { StopwatchActivity.update(for: stopwatch) }
		#endif
	}

	private func writeToDisk() {
		do {
			try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			let data = try JSONEncoder().encode(Snapshot(timers: timers, recents: recents, stopwatch: stopwatch, history: history))
			try data.write(to: fileURL, options: .atomic)
		} catch {
			print("Failed to save ClockIt timers: \(error)")
		}
		#if os(macOS)
		MacTimerAlerts.update(for: timers)
		#endif
	}

	private func encodedTimers() -> Data? {
		try? JSONEncoder().encode(timers)
	}

	private func encodedStopwatch() -> Data? {
		try? JSONEncoder().encode(StopwatchSync(stopwatch: stopwatch, history: history))
	}

	// MARK: Sync

	/// Takes another device's timers. The ringing device starts, pauses, resumes or cancels
	/// the matching AlarmKit timers so they ring here.
	private func applyRemote(_ data: Data) {
		guard let incoming = try? JSONDecoder().decode([AppTimer].self, from: data) else { return }
		let previous = Dictionary(timers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		timers = incoming
		writeToDisk()

		let now = Date()
		for timer in incoming {
			guard let old = previous[timer.id] else {
				schedule(remote: timer, at: now)
				continue
			}
			if old.isRunning && !timer.isRunning {
				AlarmScheduler.pause(timer.id)
			} else if !old.isRunning && timer.isRunning {
				AlarmScheduler.resume(timer.id)
			}
		}
		let current = Set(incoming.map(\.id))
		for id in previous.keys where !current.contains(id) {
			AlarmScheduler.cancel(id)
		}
	}

	/// Takes the stopwatch and its history from another device, e.g. a lap recorded on the Watch.
	private func applyRemoteStopwatch(_ data: Data) {
		guard let incoming = try? JSONDecoder().decode(StopwatchSync.self, from: data) else { return }
		stopwatch = incoming.stopwatch
		history = incoming.history
		lastReset = nil
		writeToDisk()
		stopwatchDidChange()
	}

	/// Re-creates every timer's system countdown, e.g. after Ring on This Device changes.
	func rescheduleAll() {
		let now = Date()
		for timer in timers {
			AlarmScheduler.cancel(timer.id)
			schedule(remote: timer, at: now)
		}
	}

	/// A timer started on another device: schedule what's left of it, paused if it's paused there.
	private func schedule(remote timer: AppTimer, at now: Date) {
		var timer = timer
		timer.remaining = timer.remaining(at: now)
		guard timer.remaining > 0 else { return }
		let isPaused = !timer.isRunning
		pendingIDs.insert(timer.id)
		Task {
			_ = await AlarmScheduler.startTimer(timer)
			if isPaused { AlarmScheduler.pause(timer.id) }
			pendingIDs.remove(timer.id)
		}
	}
}
