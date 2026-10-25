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
	@State private var labeling: WorldClockCity?
	@State private var offsetMinutes: Double = 0

	var body: some View {
		NavigationStack {
			TimelineView(.everyMinute) { context in
				let date = context.date.addingTimeInterval(offsetMinutes * 60)

				Group {
					#if os(visionOS)
					ClockWallView(cities: store.cities, offsetMinutes: offsetMinutes) { city in
						store.deleteCity(id: city.id)
					}
					#elseif os(macOS)
					WorldClockMorphView(cities: store.cities, date: date, offsetMinutes: offsetMinutes, onLabel: { labeling = $0 }) { city in
						store.deleteCity(id: city.id)
					}
					#else
					List {
						ForEach(store.cities) { city in
							WorldClockRow(city: city, date: date)
								.glassListRow()
								.contextMenu {
									personButton(for: city)
								}
								.swipeActions(edge: .leading) {
									personButton(for: city)
										.tint(ClockItPalette.accent)
								}
						}
						.onMove(perform: store.moveCities)
						.onDelete(perform: store.deleteCities)
					}
					.listStyle(.plain)
					#endif
				}
				.scrollContentBackground(.hidden)
				.navigationSubtitleIfAvailable(
					Text("\(LocalTime.label(for: date, offsetMinutes: offsetMinutes)) · \(LocalTime.currentCity)")
				)
				.overlay {
					if store.cities.isEmpty && !Self.showsClockWall {
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
			.settingsButton(section: .worldClock)
			.toolbar {
				ToolbarItem(placement: .barTrailing) {
					Button {
						showingAddCity = true
					} label: {
						Image(systemName: "plus")
					}
				}
				#if os(iOS)
				ToolbarItem(placement: .barLeading) {
					EditButton()
				}
				#endif
			}
			.sheet(isPresented: $showingAddCity) {
				AddCityView(existingCities: store.cities) { city in
					store.addCity(city)
				}
			}
			.sheet(item: $labeling) { city in
				PersonLabelView(city: city) { person in
					store.setPerson(person, forCity: city.id)
				}
			}
		}
	}

	private func personButton(for city: WorldClockCity) -> some View {
		Button(city.person == nil ? "Label with a Person" : "Change Person", systemImage: "person.crop.circle") {
			labeling = city
		}
	}

	/// Vision Pro shows the government-office style clock wall, which always has your local clock.
	private static var showsClockWall: Bool {
		#if os(visionOS)
		true
		#else
		false
		#endif
	}
}


#Preview {
	WorldClockView()
		.environment(ClockStore.preview)
}
