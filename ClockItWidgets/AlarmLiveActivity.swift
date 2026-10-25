//
//  AlarmLiveActivity.swift
//  ClockItWidgets
//
//  Created by Wesley Harden on 10/25/26.
//

import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit


@main
struct ClockItWidgetsBundle: WidgetBundle {
	var body: some Widget {
		StopwatchLiveActivity()
		if #available(iOS 26, *) {
			AlarmLiveActivity()
		}
		if #available(iOS 18, *) {
			StopwatchToggleControl()
			StopwatchLapControl()
			StartTimerControl()
			AlarmToggleControl()
		}
	}
}


/// Lock Screen and Dynamic Island UI for running timers and snoozed alarms.
@available(iOS 26, *)
struct AlarmLiveActivity: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: AlarmAttributes<ClockItAlarmMetadata>.self) { context in
			LockScreenView(attributes: context.attributes, state: context.state)
				.activityBackgroundTint(context.attributes.tint.opacity(0.22))
				.activitySystemActionForegroundColor(context.attributes.tint)
		} dynamicIsland: { context in
			let attributes = context.attributes
			let state = context.state

			return DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					ProgressRing(attributes: attributes, state: state, lineWidth: 5)
						.frame(width: 48, height: 48)
						.padding(.leading, 4)
				}
				DynamicIslandExpandedRegion(.trailing) {
					CountdownText(state: state)
						.font(.system(size: 36, weight: .light, design: .rounded))
						.foregroundStyle(attributes.tint)
						.frame(maxWidth: 140, alignment: .trailing)
						.padding(.trailing, 4)
				}
				DynamicIslandExpandedRegion(.bottom) {
					HStack {
						VStack(alignment: .leading, spacing: 2) {
							Text(attributes.label)
								.font(.headline)
							StatusText(attributes: attributes, state: state)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						Spacer()
						ControlButtons(attributes: attributes, state: state)
					}
					.padding(.horizontal, 4)
				}
			} compactLeading: {
				ProgressRing(attributes: attributes, state: state, lineWidth: 3)
					.frame(width: 22, height: 22)
			} compactTrailing: {
				CountdownText(state: state)
					.font(.system(.body, design: .rounded).weight(.medium))
					.foregroundStyle(attributes.tint)
					.frame(maxWidth: 64)
			} minimal: {
				ProgressRing(attributes: attributes, state: state, lineWidth: 3)
					.frame(width: 22, height: 22)
			}
			.keylineTint(attributes.tint)
		}
	}
}


@available(iOS 26, *)
extension AlarmAttributes where Metadata == ClockItAlarmMetadata {
	var isTimer: Bool { metadata?.kind == .timer }

	var tint: Color {
		guard isTimer, let metadata else { return tintColor }
		return ClockItPalette.color(named: metadata.colorName)
	}

	var label: String {
		if let label = metadata?.label, !label.isEmpty { return label }
		return isTimer ? "Timer" : "Alarm"
	}

	var symbol: String { isTimer ? (metadata?.symbolName ?? "timer") : "zzz" }
}


@available(iOS 26, *)
private struct LockScreenView: View {
	let attributes: AlarmAttributes<ClockItAlarmMetadata>
	let state: AlarmPresentationState

	var body: some View {
		HStack(spacing: 14) {
			ProgressRing(attributes: attributes, state: state, lineWidth: 6)
				.frame(width: 56, height: 56)

			VStack(alignment: .leading, spacing: 4) {
				Text(attributes.label)
					.font(.headline)
				StatusText(attributes: attributes, state: state)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 8)

			VStack(alignment: .trailing, spacing: 8) {
				CountdownText(state: state)
					.font(.system(size: 40, weight: .light, design: .rounded))
					.foregroundStyle(attributes.tint)
				ControlButtons(attributes: attributes, state: state)
			}
		}
		.padding(18)
	}
}


/// Live countdown while running, frozen remaining time while paused.
@available(iOS 26, *)
private struct CountdownText: View {
	let state: AlarmPresentationState

	var body: some View {
		Group {
			switch state.mode {
			case .countdown(let countdown):
				Text(timerInterval: min(countdown.startDate, countdown.fireDate)...countdown.fireDate, countsDown: true)
			case .paused(let paused):
				Text(formatted(paused.totalCountdownDuration - paused.previouslyElapsedDuration))
			case .alert:
				Text("0:00")
			@unknown default:
				Text("--:--")
			}
		}
		.monospacedDigit()
		.multilineTextAlignment(.trailing)
		.lineLimit(1)
		.minimumScaleFactor(0.6)
	}

	private func formatted(_ seconds: TimeInterval) -> String {
		let duration = Duration.seconds(max(0, seconds.rounded()))
		return duration.formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
	}
}


@available(iOS 26, *)
private struct StatusText: View {
	let attributes: AlarmAttributes<ClockItAlarmMetadata>
	let state: AlarmPresentationState

	var body: some View {
		switch state.mode {
		case .countdown(let countdown):
			let time = ClockFormat.time(countdown.fireDate, uses24Hour: attributes.metadata?.uses24Hour)
			Text(attributes.isTimer ? "Ends \(time)" : "Snoozed until \(time)")
		case .paused:
			Text("Paused")
		case .alert:
			Text("Ringing")
		@unknown default:
			EmptyView()
		}
	}
}


/// A soft ring that drains over the whole timer, with the timer or snooze glyph in the middle.
@available(iOS 26, *)
private struct ProgressRing: View {
	let attributes: AlarmAttributes<ClockItAlarmMetadata>
	let state: AlarmPresentationState
	let lineWidth: CGFloat

	var body: some View {
		ZStack {
			switch state.mode {
			case .countdown(let countdown):
				let start = countdown.fireDate.addingTimeInterval(-countdown.totalCountdownDuration)
				ProgressView(timerInterval: min(start, countdown.fireDate)...countdown.fireDate, countsDown: true) {
					EmptyView()
				} currentValueLabel: {
					EmptyView()
				}
				.progressViewStyle(.circular)
			case .paused(let paused):
				let total = max(paused.totalCountdownDuration, 1)
				ProgressView(value: (total - paused.previouslyElapsedDuration) / total)
					.progressViewStyle(.circular)
			default:
				ProgressView(value: 0)
					.progressViewStyle(.circular)
			}

			Image(systemName: attributes.symbol)
				.font(.system(size: lineWidth * 2.6, weight: .semibold))
				.foregroundStyle(attributes.tint)
		}
		.tint(attributes.tint)
	}
}


/// +1 minute, pause / resume and cancel, for timers only. Snoozed alarms are managed from the alert itself.
@available(iOS 26, *)
private struct ControlButtons: View {
	let attributes: AlarmAttributes<ClockItAlarmMetadata>
	let state: AlarmPresentationState

	var body: some View {
		if attributes.isTimer {
			HStack(spacing: 8) {
				switch state.mode {
				case .countdown:
					circleButton(intent: AddMinuteToTimerIntent(alarmID: state.alarmID), symbol: "goforward.plus", prominent: false)
					circleButton(intent: PauseAlarmIntent(alarmID: state.alarmID), symbol: "pause.fill", prominent: true)
				case .paused:
					circleButton(intent: ResumeAlarmIntent(alarmID: state.alarmID), symbol: "play.fill", prominent: true)
				default:
					EmptyView()
				}
				circleButton(intent: CancelAlarmIntent(alarmID: state.alarmID), symbol: "xmark", prominent: false)
			}
		}
	}

	private func circleButton(intent: some LiveActivityIntent, symbol: String, prominent: Bool) -> some View {
		Button(intent: intent) {
			Image(systemName: symbol)
				.font(.system(size: 14, weight: .bold))
				.foregroundStyle(prominent ? .white : attributes.tint)
				.frame(width: 34, height: 34)
				.background(prominent ? attributes.tint : attributes.tint.opacity(0.18), in: .circle)
		}
		.buttonStyle(.plain)
	}
}
