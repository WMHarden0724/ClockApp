//
//  StopwatchShortcuts.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import AppIntents


/// Siri phrases and Shortcuts actions for the stopwatch. "Start or Stop" is the one to put on the Action Button.
struct ClockItShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
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
