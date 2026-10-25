//
//  ClockItApp.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI
#if os(iOS)
import UserNotifications
#endif

@main
struct ClockItApp: App {
	@State private var store = ClockStore.shared
	@State private var timerStore = TimerStore.shared
	@State private var settings = AppSettings.shared
	@Environment(\.scenePhase) private var scenePhase

	init() {
		// The stores registered their sync channels while initializing above.
		SyncHub.shared.start()
		#if os(iOS)
		// Set early so tapping an alarm notification (before iOS 26) reaches us on launch.
		UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
		#endif
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
				// Rolls the bedtime and daylight saving notifications and the widgets forward.
				store.refreshReminders()
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
				.environment(store)
		} label: {
			MenuBarTimerLabel(store: timerStore, clockStore: store)
		}
		#endif
    }
}


struct ContentView: View {
	enum Section: Hashable {
		case alarms, worldClock, stopwatch, timers
	}

	@State private var selection: Section = .alarms
	@State private var showingWelcome = !AppSettings.shared.hasSeenWelcome
	@Environment(ClockStore.self) private var clockStore

	var body: some View {
		tabs
		.fullScreenOrSheet(isPresented: $showingWelcome) {
			WelcomeView()
		}
		#if os(iOS)
		.fullScreenCover(item: Binding(get: { clockStore.activeMission }, set: { _ in })) { mission in
			WakeMissionView(mission: mission)
		}
		#endif
	}

	@ViewBuilder
	private var tabs: some View {
		if #available(iOS 18, macOS 15, visionOS 2, *) {
			TabView(selection: $selection) {
				Tab("Alarms", systemImage: "alarm", value: .alarms) {
					AlarmsView(isSelected: selection == .alarms)
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
		} else {
			// Plain tabs everywhere before the adaptable sidebar.
			TabView(selection: $selection) {
				AlarmsView(isSelected: selection == .alarms)
					.tabItem { Label("Alarms", systemImage: "alarm") }
					.tag(Section.alarms)

				WorldClockView()
					.tabItem { Label("World Clock", systemImage: "globe") }
					.tag(Section.worldClock)

				StopwatchView(isSelected: selection == .stopwatch)
					.tabItem { Label("Stopwatch", systemImage: "stopwatch") }
					.tag(Section.stopwatch)

				TimersView(isSelected: selection == .timers)
					.tabItem { Label("Timers", systemImage: "timer") }
					.tag(Section.timers)
			}
		}
	}
}


#Preview {
	ContentView()
		.environment(ClockStore.preview)
		.environment(TimerStore.preview)
}
