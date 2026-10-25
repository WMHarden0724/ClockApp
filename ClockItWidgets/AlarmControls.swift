//
//  AlarmControls.swift
//  ClockItWidgets
//
//  Created by Wesley Harden on 10/25/26.
//

import AppIntents
import SwiftUI
import WidgetKit


/// Switches one alarm on or off from Control Center or the Lock Screen, lit while it's on.
/// Long-press it in Control Center to choose which.
@available(iOS 18, *)
struct AlarmToggleControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		AppIntentControlConfiguration(kind: AlarmShelf.toggleControlKind, provider: Provider()) { state in
			ControlWidgetToggle(isOn: state.isOn, action: SetAlarmEnabledIntent(alarm: state.alarm)) {
				Text(state.alarm?.name ?? "Alarm")
			} valueLabel: { isOn in
				Label(state.alarm.map { "\($0.timeText)" } ?? (isOn ? "On" : "Off"), systemImage: isOn ? "alarm.fill" : "alarm")
			}
			.tint(ClockItPalette.accent)
		}
		.displayName("Alarm")
		.description("Turns one of your alarms on or off.")
		.promptsForUserConfiguration()
	}

	struct State {
		let alarm: AlarmEntity?
		let isOn: Bool
	}

	/// Reads what the app last shared through the App Group.
	struct Provider: AppIntentControlValueProvider {
		func previewValue(configuration: SelectAlarmIntent) -> State {
			State(alarm: configuration.alarm, isOn: true)
		}

		func currentValue(configuration: SelectAlarmIntent) async throws -> State {
			let alarm = configuration.alarm.flatMap { chosen in AlarmShelf.read().first { $0.id == chosen.id } }
			return State(alarm: alarm.map(AlarmEntity.init) ?? configuration.alarm, isOn: alarm?.isEnabled ?? false)
		}
	}
}
