//
//  ClockItApp.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI

@main
struct ClockItApp: App {
	@State private var store = ClockStore()
	@State private var timerStore = TimerStore.shared
	@State private var settings = AppSettings.shared
	@Environment(\.scenePhase) private var scenePhase

	init() {
		// The stores registered their sync channels while initializing above.
		SyncHub.shared.start()
	}

    var body: some Scene {
        WindowGroup {
            ContentView()
				.environment(store)
				.environment(timerStore)
				.tint(Theme.accent)
        }
		#if os(macOS)
		.defaultSize(width: 1100, height: 760)
		#elseif os(visionOS)
		.defaultSize(width: 1500, height: 820)
		#endif
		.onChange(of: scenePhase) { _, phase in
			if phase == .active {
				SyncHub.shared.refresh()
				store.reconcileFiredAlarms()
			}
		}

		#if os(macOS)
		Settings {
			SettingsView()
				.environment(store)
				.environment(timerStore)
				.tint(Theme.accent)
				.frame(width: 520, height: 620)
		}

		MenuBarExtra(isInserted: $settings.showsMenuBarTimer) {
			MenuBarTimerMenu()
				.environment(timerStore)
		} label: {
			MenuBarTimerLabel(store: timerStore)
		}
		#endif
    }
}


struct ContentView: View {
	enum Section: Hashable {
		case alarms, worldClock, stopwatch, timers
	}

	@State private var selection: Section = .alarms

	var body: some View {
		TabView(selection: $selection) {
			Tab("Alarms", systemImage: "alarm", value: .alarms) {
				AlarmsView()
			}

			Tab("World Clock", systemImage: "globe", value: .worldClock) {
				WorldClockView()
			}
			
			Tab("Stopwatch", systemImage: "stopwatch", value: .stopwatch) {
				// Every tab stays loaded in the sidebar, so the stopwatch's single-key
				// shortcuts would otherwise fire while you type in other tabs.
				StopwatchView(isSelected: selection == .stopwatch)
			}
			
			Tab("Timers", systemImage: "timer", value: .timers) {
				TimersView(isSelected: selection == .timers)
			}
		}
		// A sidebar on iPad, Mac and Vision Pro; tabs on iPhone.
		.tabViewStyle(.sidebarAdaptable)
	}
}


#Preview {
	ContentView()
		.environment(ClockStore.preview)
		.environment(TimerStore.preview)
}
