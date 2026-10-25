//
//  AlarmRow.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


struct AlarmRow: View {
	let alarm: AppAlarm
	@Binding var isEnabled: Bool
	/// Its group is switched off, so it won't ring even if it's on.
	var isGroupOff = false
	/// "⌘1" on the Mac.
	var shortcutHint: String?

	var body: some View {
		let isLive = isEnabled && !isGroupOff

		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					Text(alarm.timeText)
						.font(Theme.clockFont(48))
						.monospacedDigit()
					if alarm.sunrise != nil {
						Image(systemName: "sunrise.fill")
							.symbolRenderingMode(.multicolor)
					}
					if alarm.mission != .none {
						Image(systemName: alarm.mission.symbol)
							.foregroundStyle(.secondary)
							.accessibilityLabel(alarm.mission.title)
					}
				}

				Text("\(alarm.displayLabel) · \(alarm.scheduleText)")
					.font(.subheadline)
					.foregroundStyle(.secondary)

				if let zone = alarm.timeZone, zone != .current, let next = alarm.nextFireDate() {
					Label("\(next.timeText) here", systemImage: "globe")
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				if alarm.isSkipping, let next = alarm.nextFireDate() {
					Label("Skipping · next \(next.relativeDayAndTime)", systemImage: "forward.end.fill")
						.font(.caption.weight(.medium))
						.foregroundStyle(Theme.accent)
				} else if isGroupOff {
					Label("\(alarm.group ?? "Group") is off", systemImage: "square.stack")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.opacity(isLive ? 1 : 0.45)

			Spacer()

			#if os(macOS)
			if let shortcutHint {
				Text(shortcutHint)
					.font(.caption.weight(.medium))
					.foregroundStyle(.secondary)
			}
			#endif

			Toggle("Enabled", isOn: $isEnabled)
				.labelsHidden()
				.tint(Theme.accent)
		}
		.glassCard(tint: isLive ? Theme.accent.opacity(0.18) : nil)
		.animation(.smooth, value: isEnabled)
		.sensoryFeedback(.impact(weight: .light), trigger: isEnabled)
	}
}


/// Hero card at the top of the Alarms tab: when the next alarm rings.
struct NextAlarmCard: View {
	let next: (alarm: AppAlarm, date: Date)?

	var body: some View {
		TimelineView(.everyMinute) { context in
			VStack(alignment: .leading, spacing: 6) {
				Label("Next alarm", systemImage: "alarm.waves.left.and.right.fill")
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(Theme.accent)

				if let next {
					Text("in \(next.date.countdownText(from: context.date))")
						.font(Theme.clockFont(40, weight: .regular))
						.monospacedDigit()
						.contentTransition(.numericText())

					Text("\(next.date.relativeDayAndTime) · \(next.alarm.displayLabel)")
						.font(.subheadline)
						.foregroundStyle(.secondary)

					// Bedtime for your sleep goal, when the alarm is close enough for it to matter.
					if next.date.timeIntervalSince(context.date) < 20 * 3600 {
						let bedtime = Bedtime.date(forAlarmAt: next.date)
						Label(
							bedtime > context.date
								? "Bed by \(bedtime.timeText) for \(AppSettings.shared.sleepGoalMinutes / 60) h · \(Bedtime.sleepText(until: next.date, from: context.date)) if you sleep now"
								: "\(Bedtime.sleepText(until: next.date, from: context.date)) of sleep if you go to bed now",
							systemImage: "bed.double.fill"
						)
						.font(.footnote)
						.foregroundStyle(.secondary)
						.padding(.top, 2)
					}
				} else {
					Text("Nothing scheduled")
						.font(Theme.clockFont(28, weight: .regular))
					Text("Enjoy sleeping in.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}
			.glassCard(tint: Theme.accent.opacity(0.10))
		}
	}
}
