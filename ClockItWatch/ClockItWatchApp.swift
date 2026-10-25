//
//  ClockItWatchApp.swift
//  ClockItWatch
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


@main
struct ClockItWatchApp: App {
	@State private var store = ClockStore()
	@State private var timerStore = TimerStore.shared

	init() {
		// Changes made here go straight to the iPhone, which does the ringing.
		SyncHub.shared.start()
	}

	var body: some Scene {
		WindowGroup {
			WatchRootView()
				.environment(store)
				.environment(timerStore)
				.tint(ClockItPalette.accent)
		}
	}
}


/// Four pages you scroll through with the Digital Crown.
struct WatchRootView: View {
	var body: some View {
		TabView {
			WatchTimersView()
			WatchStopwatchView()
			WatchAlarmsView()
			WatchWorldClockView()
		}
		.tabViewStyle(.verticalPage)
	}
}
