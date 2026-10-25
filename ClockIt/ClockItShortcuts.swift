//
//  ClockItShortcuts.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import AppIntents


/// Siri phrases for alarms, timers and the stopwatch. The system allows ten, so the rest
/// (pause or cancel all timers, start / stop / reset the stopwatch, pause all alarms) are
/// actions in the Shortcuts app without a phrase. "Start or Stop" suits the Action Button.
struct ClockItShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: SetAlarmIntent(),
			phrases: [
				"Set an alarm in \(.applicationName)",
				"Wake me up with \(.applicationName)"
			],
			shortTitle: "Set Alarm",
			systemImageName: "alarm"
		)
		AppShortcut(
			intent: NextAlarmIntent(),
			phrases: [
				"When's my next \(.applicationName) alarm",
				"What time is my \(.applicationName) alarm"
			],
			shortTitle: "Next Alarm",
			systemImageName: "alarm.waves.left.and.right"
		)
		AppShortcut(
			intent: TurnOffAlarmIntent(),
			phrases: ["Turn off my \(\.$alarm) alarm in \(.applicationName)"],
			shortTitle: "Turn Off Alarm",
			systemImageName: "alarm"
		)
		AppShortcut(
			intent: TurnOnAlarmIntent(),
			phrases: ["Turn on my \(\.$alarm) alarm in \(.applicationName)"],
			shortTitle: "Turn On Alarm",
			systemImageName: "alarm.fill"
		)
		AppShortcut(
			intent: SkipNextAlarmIntent(),
			phrases: ["Skip my next \(\.$alarm) alarm in \(.applicationName)"],
			shortTitle: "Skip Next Alarm",
			systemImageName: "forward.end"
		)
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
			intent: ToggleStopwatchIntent(),
			phrases: [
				"Start or stop the \(.applicationName) stopwatch",
				"Toggle the \(.applicationName) stopwatch"
			],
			shortTitle: "Start or Stop",
			systemImageName: "stopwatch"
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
	}
}


/// Tells Siri the saved timers' names changed, so "Start my Pasta timer" keeps working.
enum ClockItShortcutsUpdater {
	static func update() {
		ClockItShortcuts.updateAppShortcutParameters()
	}
}
