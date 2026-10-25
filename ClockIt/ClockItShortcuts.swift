//
//  ClockItShortcuts.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import AppIntents


/// Siri phrases and Shortcuts actions for timers and the stopwatch. (The system allows ten.)
/// "Start or Stop" is the one to put on the Action Button.
struct ClockItShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: StartSavedTimerIntent(),
			phrases: [
				"Start my \(\.$timer) timer in \(.applicationName)",
				"Start \(\.$timer) in \(.applicationName)"
			],
			shortTitle: "Start Saved Timer",
			systemImageName: "bookmark.fill"
		)
		AppShortcut(
			intent: StartTimerIntent(),
			phrases: [
				"Start a timer in \(.applicationName)",
				"Set a \(.applicationName) timer"
			],
			shortTitle: "Start Timer",
			systemImageName: "timer"
		)
		AppShortcut(
			intent: CheckTimersIntent(),
			phrases: [
				"How long is left on my \(.applicationName) timer",
				"Check my \(.applicationName) timers"
			],
			shortTitle: "Check Timers",
			systemImageName: "hourglass"
		)
		AppShortcut(
			intent: PauseAllTimersIntent(),
			phrases: ["Pause my \(.applicationName) timers"],
			shortTitle: "Pause All Timers",
			systemImageName: "pause.fill"
		)
		AppShortcut(
			intent: CancelAllTimersIntent(),
			phrases: ["Cancel my \(.applicationName) timers"],
			shortTitle: "Cancel All Timers",
			systemImageName: "xmark"
		)
		AppShortcut(
			intent: ToggleStopwatchIntent(),
			phrases: [
				"Start or stop the \(.applicationName) stopwatch",
				"Toggle the \(.applicationName) stopwatch"
			],
			shortTitle: "Start or Stop",
			systemImageName: "stopwatch"
		)
		AppShortcut(
			intent: StartStopwatchIntent(),
			phrases: [
				"Start the stopwatch in \(.applicationName)",
				"Start the \(.applicationName) stopwatch"
			],
			shortTitle: "Start Stopwatch",
			systemImageName: "play.fill"
		)
		AppShortcut(
			intent: StopStopwatchIntent(),
			phrases: [
				"Stop the stopwatch in \(.applicationName)",
				"Stop the \(.applicationName) stopwatch"
			],
			shortTitle: "Stop Stopwatch",
			systemImageName: "stop.fill"
		)
		AppShortcut(
			intent: LapStopwatchIntent(),
			phrases: [
				"Record a lap in \(.applicationName)",
				"\(.applicationName) lap"
			],
			shortTitle: "Record Lap",
			systemImageName: "flag.fill"
		)
		AppShortcut(
			intent: ResetStopwatchIntent(),
			phrases: [
				"Reset the stopwatch in \(.applicationName)",
				"Reset the \(.applicationName) stopwatch"
			],
			shortTitle: "Reset Stopwatch",
			systemImageName: "arrow.counterclockwise"
		)
	}
}


/// Tells Siri the saved timers' names changed, so "Start my Pasta timer" keeps working.
enum ClockItShortcutsUpdater {
	static func update() {
		ClockItShortcuts.updateAppShortcutParameters()
	}
}
