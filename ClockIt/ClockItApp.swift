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
	@Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
				.environment(store)
				.tint(Theme.accent)
        }
		.onChange(of: scenePhase) { _, phase in
			if phase == .active {
				store.reconcileFiredAlarms()
			}
		}
    }
}


struct ContentView: View {
	var body: some View {
		TabView {
			Tab("Alarms", systemImage: "alarm") {
				AlarmsView()
			}

			Tab("World Clock", systemImage: "globe") {
				WorldClockView()
			}
		}
	}
}


#Preview {
	ContentView()
		.environment(ClockStore.preview)
}
