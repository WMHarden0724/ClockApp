//
//  StopwatchIntents.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(iOS)
import ActivityKit
#endif
import AppIntents
import Foundation


// Compiled into the app, the widget extension and the Watch app. The widget extension only
// describes these intents for its buttons; the system performs them in the app.


nonisolated enum StopwatchCommand: Sendable {
	case start, stop, toggle, lap, reset
}


#if os(iOS)
/// Live Activity intents run in the app's process, even when the tap comes from the
/// Lock Screen, Dynamic Island or Control Center, so they reach the real stopwatch.
typealias InAppIntent = LiveActivityIntent
#else
typealias InAppIntent = AppIntent
#endif


private func run(_ command: StopwatchCommand) async -> String {
	#if WIDGET_EXTENSION
	return ""
	#else
	return TimerStore.shared.perform(command)
	#endif
}


struct StartStopwatchIntent: InAppIntent {
	static let title: LocalizedStringResource = "Start Stopwatch"
	static let description = IntentDescription("Starts the stopwatch, or picks up where it was stopped.")

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.start))")
	}
}


struct StopStopwatchIntent: InAppIntent {
	static let title: LocalizedStringResource = "Stop Stopwatch"
	static let description = IntentDescription("Stops the stopwatch without clearing it.")

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.stop))")
	}
}


struct ToggleStopwatchIntent: InAppIntent {
	static let title: LocalizedStringResource = "Start or Stop Stopwatch"
	static let description = IntentDescription("Starts the stopwatch if it's stopped, and stops it if it's running. Handy on the Action Button.")

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.toggle))")
	}
}


struct LapStopwatchIntent: InAppIntent {
	static let title: LocalizedStringResource = "Record Lap"
	static let description = IntentDescription("Records a lap on the running stopwatch.")

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.lap))")
	}
}


struct ResetStopwatchIntent: InAppIntent {
	static let title: LocalizedStringResource = "Reset Stopwatch"
	static let description = IntentDescription("Clears the stopwatch and saves the run to History.")

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.reset))")
	}
}


// MARK: - Control Center

#if os(iOS)
/// Whether the stopwatch is running, shared with the widget extension through the App Group
/// so the Control Center toggle can show it.
nonisolated enum StopwatchControlState {
	static let appGroup = "group.com.southerncode.ClockIt"
	static let controlKind = "com.southerncode.ClockIt.stopwatch.toggle"
	private static let runningKey = "stopwatchIsRunning"

	static var isRunning: Bool {
		get { UserDefaults(suiteName: appGroup)?.bool(forKey: runningKey) ?? false }
		set { UserDefaults(suiteName: appGroup)?.set(newValue, forKey: runningKey) }
	}
}


/// The Control Center toggle's action: on starts the stopwatch, off stops it.
struct SetStopwatchRunningIntent: SetValueIntent, LiveActivityIntent {
	static let title: LocalizedStringResource = "Set Stopwatch Running"
	static let isDiscoverable = false

	@Parameter(title: "Running") var value: Bool

	func perform() async throws -> some IntentResult {
		_ = await run(value ? .start : .stop)
		return .result()
	}
}
#endif


// MARK: - Live Activity

#if os(iOS)
/// The stopwatch on the Lock Screen and in the Dynamic Island.
nonisolated struct StopwatchActivityAttributes: ActivityAttributes {
	struct ContentState: Codable, Hashable {
		var isRunning: Bool
		/// When the run would have begun had it never stopped; counting up from here shows the total.
		var runStart: Date
		/// The same for the current lap.
		var lapStart: Date
		/// Frozen totals, shown while stopped.
		var elapsed: TimeInterval
		var currentLap: TimeInterval
		var lapCount: Int
	}
}
#endif
