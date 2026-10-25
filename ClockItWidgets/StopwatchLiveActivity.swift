//
//  StopwatchLiveActivity.swift
//  ClockItWidgets
//
//  Created by Wesley Harden on 10/25/26.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit


private let runningTint = ClockItPalette.color(named: "mint")
private let stoppedTint = ClockItPalette.color(named: "peach")
private let stopTint = ClockItPalette.color(named: "rose")


/// Lock Screen and Dynamic Island UI for the stopwatch.
struct StopwatchLiveActivity: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: StopwatchActivityAttributes.self) { context in
			StopwatchLockScreenView(state: context.state)
				.activityBackgroundTint(stopwatchTint(for: context.state).opacity(0.22))
				.activitySystemActionForegroundColor(stopwatchTint(for: context.state))
		} dynamicIsland: { context in
			let state = context.state

			return DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					StopwatchGlyph(state: state, size: 44)
						.padding(.leading, 4)
				}
				DynamicIslandExpandedRegion(.trailing) {
					ElapsedText(state: state)
						.font(.system(size: 34, weight: .light, design: .rounded))
						.foregroundStyle(stopwatchTint(for: state))
						.frame(maxWidth: 160, alignment: .trailing)
						.padding(.trailing, 4)
				}
				DynamicIslandExpandedRegion(.bottom) {
					HStack {
						VStack(alignment: .leading, spacing: 2) {
							Text("Stopwatch")
								.font(.headline)
							LapStatusText(state: state)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						Spacer()
						StopwatchButtons(state: state)
					}
					.padding(.horizontal, 4)
				}
			} compactLeading: {
				Image(systemName: "stopwatch.fill")
					.foregroundStyle(stopwatchTint(for: state))
			} compactTrailing: {
				ElapsedText(state: state)
					.font(.system(.body, design: .rounded).weight(.medium))
					.foregroundStyle(stopwatchTint(for: state))
					.frame(maxWidth: 64)
			} minimal: {
				Image(systemName: "stopwatch.fill")
					.foregroundStyle(stopwatchTint(for: state))
			}
			.keylineTint(stopwatchTint(for: state))
		}
	}
}


private func stopwatchTint(for state: StopwatchActivityAttributes.ContentState) -> Color {
	state.isRunning ? runningTint : stoppedTint
}


private struct StopwatchLockScreenView: View {
	let state: StopwatchActivityAttributes.ContentState

	var body: some View {
		HStack(spacing: 14) {
			StopwatchGlyph(state: state, size: 52)

			VStack(alignment: .leading, spacing: 4) {
				Text("Stopwatch")
					.font(.headline)
				LapStatusText(state: state)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 8)

			VStack(alignment: .trailing, spacing: 8) {
				ElapsedText(state: state)
					.font(.system(size: 40, weight: .light, design: .rounded))
					.foregroundStyle(stopwatchTint(for: state))
				StopwatchButtons(state: state)
			}
		}
		.padding(18)
	}
}


/// Counts up live while running; the exact total, to the hundredth, while stopped.
private struct ElapsedText: View {
	let state: StopwatchActivityAttributes.ContentState

	var body: some View {
		Group {
			if state.isRunning {
				Text(timerInterval: state.runStart...Date.distantFuture, countsDown: false)
			} else {
				Text(precise(state.elapsed))
			}
		}
		.monospacedDigit()
		.multilineTextAlignment(.trailing)
		.lineLimit(1)
		.minimumScaleFactor(0.6)
	}
}


/// "Lap 3 · 0:42" with the lap counting live, or "Running" / "Stopped" before the first lap.
private struct LapStatusText: View {
	let state: StopwatchActivityAttributes.ContentState

	var body: some View {
		if state.lapCount == 0 {
			Text(state.isRunning ? "Running" : "Stopped")
		} else if state.isRunning {
			HStack(spacing: 4) {
				Text("Lap \(state.lapCount + 1) ·")
				Text(timerInterval: state.lapStart...Date.distantFuture, countsDown: false)
					.monospacedDigit()
			}
		} else {
			Text("Lap \(state.lapCount + 1) · \(precise(state.currentLap))")
				.monospacedDigit()
		}
	}
}


private func precise(_ seconds: TimeInterval) -> String {
	let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600
		? .hourMinuteSecond(padHourToLength: 1, fractionalSecondsLength: 2)
		: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)
	return Duration.seconds(max(0, seconds)).formatted(.time(pattern: pattern))
}


private struct StopwatchGlyph: View {
	let state: StopwatchActivityAttributes.ContentState
	let size: CGFloat

	var body: some View {
		Image(systemName: state.isRunning ? "stopwatch.fill" : "stopwatch")
			.font(.system(size: size * 0.5, weight: .semibold))
			.foregroundStyle(stopwatchTint(for: state))
			.frame(width: size, height: size)
			.background(stopwatchTint(for: state).opacity(0.18), in: .circle)
	}
}


/// Lap and Stop while running; Start and Reset while stopped.
private struct StopwatchButtons: View {
	let state: StopwatchActivityAttributes.ContentState

	var body: some View {
		HStack(spacing: 8) {
			if state.isRunning {
				circleButton(intent: LapStopwatchIntent(), symbol: "flag.fill", tint: runningTint, prominent: false)
				circleButton(intent: StopStopwatchIntent(), symbol: "stop.fill", tint: stopTint, prominent: true)
			} else {
				circleButton(intent: ResetStopwatchIntent(), symbol: "arrow.counterclockwise", tint: stoppedTint, prominent: false)
				circleButton(intent: StartStopwatchIntent(), symbol: "play.fill", tint: runningTint, prominent: true)
			}
		}
	}

	private func circleButton(intent: some LiveActivityIntent, symbol: String, tint: Color, prominent: Bool) -> some View {
		Button(intent: intent) {
			Image(systemName: symbol)
				.font(.system(size: 14, weight: .bold))
				.foregroundStyle(prominent ? .white : tint)
				.frame(width: 34, height: 34)
				.background(prominent ? tint : tint.opacity(0.18), in: .circle)
		}
		.buttonStyle(.plain)
	}
}


// MARK: - Control Center

/// Starts or stops the stopwatch from Control Center or the Lock Screen, lit while it's running.
struct StopwatchToggleControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		StaticControlConfiguration(kind: StopwatchControlState.controlKind, provider: Provider()) { isRunning in
			ControlWidgetToggle("Stopwatch", isOn: isRunning, action: SetStopwatchRunningIntent()) { isOn in
				Label(isOn ? "Running" : "Stopped", systemImage: isOn ? "stopwatch.fill" : "stopwatch")
			}
			.tint(runningTint)
		}
		.displayName("Stopwatch")
		.description("Starts the stopwatch, or stops it if it's running.")
	}

	/// Reads what the app last shared through the App Group.
	struct Provider: ControlValueProvider {
		var previewValue: Bool { false }

		func currentValue() async throws -> Bool {
			StopwatchControlState.isRunning
		}
	}
}


/// Records a lap on the running stopwatch.
struct StopwatchLapControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		StaticControlConfiguration(kind: "com.southerncode.ClockIt.stopwatch.lap") {
			ControlWidgetButton(action: LapStopwatchIntent()) {
				Label("Lap", systemImage: "flag.fill")
			}
		}
		.displayName("Stopwatch Lap")
		.description("Records a lap on the running stopwatch.")
	}
}
