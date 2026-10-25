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

	var body: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text(alarm.timeText)
					.font(Theme.clockFont(48))
					.monospacedDigit()

				Text("\(alarm.displayLabel) · \(alarm.scheduleText)")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			.opacity(isEnabled ? 1 : 0.45)

			Spacer()

			Toggle("Enabled", isOn: $isEnabled)
				.labelsHidden()
				.tint(Theme.accent)
		}
		.glassCard(tint: isEnabled ? Theme.accent.opacity(0.18) : nil)
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
