//
//  TimerControls.swift
//  ClockItWidgets
//
//  Created by Wesley Harden on 10/25/26.
//

import AppIntents
import SwiftUI
import WidgetKit


/// Starts one of your saved timers from Control Center, the Lock Screen or the Action Button.
/// Long-press it in Control Center to choose which.
@available(iOS 18, *)
struct StartTimerControl: ControlWidget {
	var body: some ControlWidgetConfiguration {
		AppIntentControlConfiguration(kind: SavedTimerShelf.startControlKind, intent: SelectSavedTimerIntent.self) { configuration in
			let timer = configuration.timer ?? .fiveMinutes
			ControlWidgetButton(action: StartSavedTimerIntent(timer: timer)) {
				Label(timer.name, systemImage: timer.symbol)
			}
			.tint(ClockItPalette.accent)
		}
		.displayName("Start Timer")
		.description("Starts one of your saved timers.")
		.promptsForUserConfiguration()
	}
}
