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
	/// Timers you pinned, which stay put however many others you run.
	private(set) var saved: [TimerPreset] = []
	/// Finished and cancelled timers, newest first.
	private(set) var timerHistory: [TimerRecord] = []
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
		var saved: [TimerPreset]?
		var timerHistory: [TimerRecord]?
	}

	/// What the timer library channel shares: saved timers and timer history.
	private struct LibrarySync: Codable {
		var saved: [TimerPreset]
		var timerHistory: [TimerRecord]
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
			saved = snapshot.saved ?? []
			timerHistory = snapshot.timerHistory ?? []
		}
		if live {
			SyncHub.shared.register(.timers, apply: { [weak self] in self?.applyRemote($0) }, seed: { [weak self] in self?.encodedTimers() })
			SyncHub.shared.register(.stopwatch, apply: { [weak self] in self?.applyRemoteStopwatch($0) }, seed: { [weak self] in self?.encodedStopwatch() })
			SyncHub.shared.register(.timerLibrary, apply: { [weak self] in self?.applyRemoteLibrary($0) }, seed: { [weak self] in self?.encodedLibrary() })
			shareSaved()
		}
		#if os(iOS)
		if live {
			StopwatchActivity.update(for: stopwatch)
			if #available(iOS 26, *) {
				updatesTask = Task { [weak self] in
					for await alarms in AlarmManager.shared.alarmUpdates {
						self?.reconcile(with: alarms)
					}
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

	/// Starts a timer. With `steps`, it's a sequence and `duration` is ignored in favor of their total.
	func start(
		duration: TimeInterval,
		label: String,
		notes: String = "",
		category: TimerCategory = .general,
		colorName: String,
		soundName: String = TimerSound.standard.rawValue,
		steps: [TimerStep]? = nil
	) {
		let steps = steps.flatMap { $0.isEmpty ? nil : $0 }
		let duration = steps.map { $0.reduce(0) { $0 + $1.duration } } ?? duration
		guard duration > 0 else { return }
		let timer = AppTimer(
			id: UUID(),
			label: label,
			duration: duration,
			remaining: duration,
			endDate: Date().addingTimeInterval(duration),
			colorName: colorName,
			soundName: soundName,
			createdAt: Date(),
			category: category,
			notes: notes.isEmpty ? nil : notes,
			originDevice: SyncHub.shared.deviceID,
			steps: steps
		)
		timers.insert(timer, at: 0)
		remember(timer.preset)
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

	func start(_ preset: TimerPreset) {
		start(
			duration: preset.duration,
			label: preset.label,
			category: preset.kind,
			colorName: preset.colorName,
			soundName: preset.soundName ?? AppSettings.shared.timerSound(for: preset.kind).rawValue,
			steps: preset.steps
		)
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
		guard let timer = timers.first(where: { $0.id == id }) else { return }
		record(timer)
		timers.removeAll { $0.id == id }
		AlarmScheduler.cancel(id)
		persist()
	}

	/// Adds time to a timer. A finished one comes back to life with just the added time.
	/// In a sequence the time goes to the current step.
	func addTime(_ seconds: TimeInterval, to id: UUID) {
		guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
		let now = Date()
		var timer = timers[index]
		let remaining = timer.remaining(at: now)

		if timer.isRunning, remaining <= 0 {
			// Finished: start over with just the extra time, as a plain timer.
			timer.duration = seconds
			timer.steps = nil
			timer.remaining = seconds
			timer.endDate = now.addingTimeInterval(seconds)
		} else {
			if let status = timer.stepStatus(at: now) {
				timer.steps?[status.index].duration += seconds
			}
			timer.duration += seconds
			timer.remaining = remaining + seconds
			if timer.isRunning { timer.endDate = now.addingTimeInterval(remaining + seconds) }
		}
		timers[index] = timer
		persist()
		reschedule(timer)
	}

	/// Starts a timer over from the top, e.g. Repeat on a finished one.
	func restart(id: UUID) {
		guard let timer = timers.first(where: { $0.id == id }) else { return }
		cancel(id: id)
		start(
			duration: timer.duration,
			label: timer.label,
			notes: timer.notes ?? "",
			category: timer.kind,
			colorName: timer.colorName,
			soundName: timer.soundName,
			steps: timer.steps.map { TimerStep.expand($0, rounds: 1) }
		)
	}

	func pauseAll() {
		for timer in timers where timer.isRunning && timer.remaining(at: Date()) > 0 {
			pause(id: timer.id)
		}
	}

	func resumeAll() {
		for timer in timers where !timer.isRunning {
			resume(id: timer.id)
		}
	}

	func cancelAll() {
		for timer in timers {
			cancel(id: timer.id)
		}
	}

	/// Re-plans step cues and heads-ups, e.g. after the heads-up setting changes.
	func refreshNotifications() {
		#if os(iOS) || os(macOS)
		if live { TimerNotifications.update(for: timers) }
		#endif
	}

	var hasRunningTimers: Bool {
		timers.contains { $0.isRunning && $0.remaining(at: Date()) > 0 }
	}

	/// Cancels the AlarmKit countdown and schedules what's left, after the timer's length changed.
	private func reschedule(_ timer: AppTimer) {
		pendingIDs.insert(timer.id)
		AlarmScheduler.cancel(timer.id)
		Task {
			_ = await AlarmScheduler.startTimer(timer)
			if !timer.isRunning { AlarmScheduler.pause(timer.id) }
			pendingIDs.remove(timer.id)
		}
	}

	private func remember(_ preset: TimerPreset) {
		recents.removeAll { $0.id == preset.id }
		recents.insert(preset, at: 0)
		recents = Array(recents.prefix(6))
	}

	/// Runs a timer command from Siri, Shortcuts, Control Center or the Live Activity, and says what happened.
	@discardableResult
	func perform(_ action: TimerAction) -> String {
		switch action {
		case .start(let duration, let label):
			guard duration >= 1 else { return "That's too short for a timer." }
			start(
				duration: duration.rounded(),
				label: label,
				colorName: ClockItPalette.defaultName,
				soundName: AppSettings.shared.timerSound(for: .general).rawValue
			)
			return label.isEmpty ? "Started a \(duration.durationLabel) timer." : "Started \(label) for \(duration.durationLabel)."
		case .startSaved(let id):
			guard let preset = startSaved(id: id) else { return "I couldn't find that timer. It may have been removed." }
			return "Started \(preset.displayName)."
		case .status:
			let now = Date()
			guard !timers.isEmpty else { return "No timers are running." }
			return timers.map { timer in
				let remaining = timer.remaining(at: now)
				if timer.isRunning && remaining <= 0 { return "\(timer.displayLabel) is done." }
				let left = remaining.rounded(.up).durationLabel
				return timer.isRunning ? "\(timer.displayLabel): \(left) left." : "\(timer.displayLabel) is paused with \(left) left."
			}
			.joined(separator: " ")
		case .pauseAll:
			guard hasRunningTimers else { return "No timers are running." }
			pauseAll()
			return "Paused your timers."
		case .resumeAll:
			guard timers.contains(where: { !$0.isRunning }) else { return "No timers are paused." }
			resumeAll()
			return "Resumed your timers."
		case .cancelAll:
			guard !timers.isEmpty else { return "There are no timers to cancel." }
			let count = timers.count
			cancelAll()
			return count == 1 ? "Cancelled your timer." : "Cancelled \(count) timers."
		case .addTime(let seconds, let id):
			addTime(seconds, to: id)
			return "Added \(seconds.durationLabel)."
		}
	}

	// MARK: Saved timers and history

	func isSaved(_ preset: TimerPreset) -> Bool {
		saved.contains { $0.id == preset.id }
	}

	func save(_ preset: TimerPreset) {
		guard !isSaved(preset) else { return }
		saved.append(preset)
		persistLibrary()
	}

	func unsave(_ preset: TimerPreset) {
		saved.removeAll { $0.id == preset.id }
		persistLibrary()
	}

	func moveSaved(from source: IndexSet, to destination: Int) {
		saved.move(fromOffsets: source, toOffset: destination)
		persistLibrary()
	}

	func deleteTimerRecords(_ ids: Set<UUID>) {
		timerHistory.removeAll { ids.contains($0.id) }
		persistLibrary()
	}

	func clearTimerHistory() {
		timerHistory.removeAll()
		persistLibrary()
	}

	/// Starts a saved timer by id, or a plain one from a "duration:300" id (the Control Center default).
	@discardableResult
	func startSaved(id: String) -> TimerPreset? {
		if let preset = saved.first(where: { $0.id == id }) {
			start(preset)
			return preset
		}
		if id.hasPrefix("duration:"), let seconds = TimeInterval(id.dropFirst("duration:".count)) {
			let preset = TimerPreset(duration: seconds, label: "", colorName: ClockItPalette.defaultName, category: nil)
			start(preset)
			return preset
		}
		return nil
	}

	/// Keeps a timer that's going away in history. Called only where the removal happens,
	/// so each device's history arrives once, through sync.
	private func record(_ timer: AppTimer, at now: Date = Date()) {
		timerHistory.insert(TimerRecord(
			id: UUID(),
			preset: timer.preset,
			startedAt: timer.createdAt,
			endedAt: now,
			completed: timer.remaining(at: now) <= 0.5
		), at: 0)
		timerHistory = Array(timerHistory.prefix(200))
		persistLibrary()
	}

	#if os(iOS)
	/// Adopts changes made outside the app: Live Activity buttons, the alert's Stop/Repeat, or finished timers.
	@available(iOS 26, *)
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
				record(timer, at: now)
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

	/// Saves locally and shares saved timers and history with your other devices.
	private func persistLibrary() {
		writeToDisk()
		if live, let data = encodedLibrary() {
			SyncHub.shared.publish(.timerLibrary, payload: data)
		}
		shareSaved()
	}

	/// Saved timers for Siri's phrases and the Control Center button.
	private func shareSaved() {
		guard live else { return }
		SavedTimerShelf.write(saved.map {
			SavedTimerSummary(id: $0.id, name: $0.displayName, duration: $0.duration, symbol: $0.kind.symbol)
		})
		#if !os(watchOS)
		ClockItShortcutsUpdater.update()
		#endif
	}

	/// Running and paused timers, for the Home Screen widgets and Watch complications.
	private func shareWithWidgets() {
		let shared = timers.map {
			WidgetSnapshot.Timer(id: $0.id, label: $0.displayLabel, colorName: $0.colorName, symbol: $0.kind.symbol, duration: $0.duration, remaining: $0.remaining, endDate: $0.endDate)
		}
		WidgetShelf.update { $0.timers = shared }
	}

	private func writeToDisk() {
		do {
			try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			let snapshot = Snapshot(timers: timers, recents: recents, stopwatch: stopwatch, history: history, saved: saved, timerHistory: timerHistory)
			try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
		} catch {
			print("Failed to save ClockIt timers: \(error)")
		}
		if live { shareWithWidgets() }
		#if os(iOS) || os(macOS)
		if live { TimerNotifications.update(for: timers) }
		#endif
	}

	private func encodedTimers() -> Data? {
		try? JSONEncoder().encode(timers)
	}

	private func encodedLibrary() -> Data? {
		try? JSONEncoder().encode(LibrarySync(saved: saved, timerHistory: timerHistory))
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
			if old.duration != timer.duration || old.steps != timer.steps {
				// Time was added on another device.
				AlarmScheduler.cancel(timer.id)
				schedule(remote: timer, at: now)
			} else if old.isRunning && !timer.isRunning {
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

	private func applyRemoteLibrary(_ data: Data) {
		guard let incoming = try? JSONDecoder().decode(LibrarySync.self, from: data) else { return }
		saved = incoming.saved
		timerHistory = incoming.timerHistory
		writeToDisk()
		shareSaved()
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
