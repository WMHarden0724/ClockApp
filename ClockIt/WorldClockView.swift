//
//  WorldClockView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


struct WorldClockView: View {
	@Environment(ClockStore.self) private var store
	@State private var showingAddCity = false
	@State private var offsetMinutes: Double = 0

	var body: some View {
		NavigationStack {
			TimelineView(.everyMinute) { context in
				let date = context.date.addingTimeInterval(offsetMinutes * 60)

				List {
					ForEach(store.cities) { city in
						WorldClockRow(city: city, date: date)
							.glassListRow()
					}
					.onMove(perform: store.moveCities)
					.onDelete(perform: store.deleteCities)
				}
				.listStyle(.plain)
				.scrollContentBackground(.hidden)
				.navigationSubtitle(
					Text("\(LocalTime.label(for: date, offsetMinutes: offsetMinutes)) · \(LocalTime.currentCity)")
				)
				.overlay {
					if store.cities.isEmpty {
						ContentUnavailableView(
							"No Cities",
							systemImage: "globe",
							description: Text("Add a city to see its time, day and sky at a glance.")
						)
					}
				}
			}
			.background(AuroraBackground())
			.safeAreaInset(edge: .bottom) {
				if !store.cities.isEmpty {
					TimeScrubber(offsetMinutes: $offsetMinutes)
						.padding(.horizontal, 16)
						.padding(.bottom, 8)
				}
			}
			.navigationTitle("World Clock")
			.settingsButton()
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						showingAddCity = true
					} label: {
						Image(systemName: "plus")
					}
				}
				ToolbarItem(placement: .topBarLeading) {
					EditButton()
				}
			}
			.sheet(isPresented: $showingAddCity) {
				AddCityView(existingIdentifiers: Set(store.cities.map(\.timeZoneIdentifier))) { city in
					store.addCity(city)
				}
			}
		}
	}
}


#Preview {
	WorldClockView()
		.environment(ClockStore.preview)
}
