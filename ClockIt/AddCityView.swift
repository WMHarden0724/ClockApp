//
//  AddCityView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import MapKit
import SwiftUI


struct AddCityView: View {
	@Environment(\.dismiss) private var dismiss
	let existingCities: [WorldClockCity]
	let onAdd: (WorldClockCity) -> Void

	@State private var searchText = ""
	@State private var citySearch = CitySearch()
	@State private var resolving: MKLocalSearchCompletion?
	@State private var sameZonePlace: CitySearch.Place?
	@State private var lookupFailed = false

	private struct Candidate: Identifiable {
		let id: String // time zone identifier
		let name: String
		let region: String
	}

	private static let popular: [Candidate] = [
		("New York", "America/New_York"),
		("London", "Europe/London"),
		("Paris", "Europe/Paris"),
		("Tokyo", "Asia/Tokyo"),
		("Sydney", "Australia/Sydney"),
		("Los Angeles", "America/Los_Angeles"),
		("Chicago", "America/Chicago"),
		("Dubai", "Asia/Dubai"),
		("Singapore", "Asia/Singapore"),
		("Berlin", "Europe/Berlin")
	].map { Candidate(id: $0.1, name: $0.0, region: region(for: $0.1)) }

	/// Every city-level time zone the system knows, e.g. "America/Argentina/Buenos_Aires".
	private static let all: [Candidate] = TimeZone.knownTimeZoneIdentifiers
		.compactMap { identifier -> Candidate? in
			let parts = identifier.split(separator: "/")
			guard parts.count >= 2, parts[0] != "Etc", let last = parts.last else { return nil }
			return Candidate(id: identifier, name: String(last).replacing("_", with: " "), region: region(for: identifier))
		}
		.sorted { $0.name < $1.name }

	private static func region(for identifier: String) -> String {
		identifier.split(separator: "/").dropLast().joined(separator: " · ").replacing("_", with: " ")
	}

	private var zoneResults: [Candidate] {
		if searchText.isEmpty { return Self.popular }
		return Self.all.filter {
			$0.name.localizedCaseInsensitiveContains(searchText) || $0.region.localizedCaseInsensitiveContains(searchText)
		}
	}

	var body: some View {
		NavigationStack {
			TimelineView(.everyMinute) { context in
				List {
					if !searchText.isEmpty && !citySearch.results.isEmpty {
						Section("Places") {
							ForEach(citySearch.results, id: \.self) { completion in
								placeRow(completion)
							}
						}
					}

					if !zoneResults.isEmpty {
						Section(searchText.isEmpty ? "Popular" : "Time Zones") {
							ForEach(zoneResults) { candidate in
								zoneRow(for: candidate, at: context.date)
							}
						}
					}
				}
			}
			.overlay {
				if !searchText.isEmpty && zoneResults.isEmpty && citySearch.results.isEmpty {
					ContentUnavailableView.search(text: searchText)
				}
			}
			.searchable(text: $searchText, placement: .drawer, prompt: "Any city, e.g. Brunswick, GA")
			.onChange(of: searchText) { _, text in
				citySearch.query = text
			}
			.navigationTitle("Add City")
			.inlineNavigationTitle()
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
			}
			.confirmationDialog(
				"\(sameZonePlace?.name ?? "This city") is in your time zone",
				isPresented: Binding(get: { sameZonePlace != nil }, set: { if !$0 { sameZonePlace = nil } }),
				titleVisibility: .visible,
				presenting: sameZonePlace
			) { place in
				Button("Set as My City") {
					AppSettings.shared.setHomeCity(name: place.name, timeZone: place.timeZone)
					dismiss()
				}
				Button("Set as My City and Add Clock") {
					AppSettings.shared.setHomeCity(name: place.name, timeZone: place.timeZone)
					add(place)
				}
				Button("Add Clock Only") {
					add(place)
				}
			} message: { place in
				Text("Show \(place.name) beside your local time instead of \(LocalTime.currentCity)?")
			}
			.alert("Couldn't Find That Place's Time Zone", isPresented: $lookupFailed) {
				Button("OK", role: .cancel) {}
			} message: {
				Text("Check your connection and try again, or pick a time zone below.")
			}
		}
	}

	// MARK: Places (MapKit)

	private func placeRow(_ completion: MKLocalSearchCompletion) -> some View {
		Button {
			Task { await pick(completion) }
		} label: {
			HStack {
				Image(systemName: "mappin.circle.fill")
					.font(.title3)
					.foregroundStyle(Theme.accent)

				VStack(alignment: .leading, spacing: 2) {
					Text(completion.title)
						.foregroundStyle(.primary)
					if !completion.subtitle.isEmpty {
						Text(completion.subtitle)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}

				Spacer()

				if resolving == completion {
					ProgressView()
				}
			}
		}
		.tint(.primary)
		.disabled(resolving != nil)
	}

	private func pick(_ completion: MKLocalSearchCompletion) async {
		resolving = completion
		defer { resolving = nil }

		guard let place = await citySearch.resolve(completion) else {
			lookupFailed = true
			return
		}
		if place.timeZone.sharesClock(with: .current) {
			sameZonePlace = place
		} else {
			add(place)
		}
	}

	private func add(_ place: CitySearch.Place) {
		onAdd(WorldClockCity(id: UUID(), name: place.name, timeZoneIdentifier: place.timeZone.identifier, nickname: nil, order: 0))
		dismiss()
	}

	// MARK: Time zones

	private func zoneRow(for candidate: Candidate, at date: Date) -> some View {
		let isAdded = existingCities.contains { $0.timeZoneIdentifier == candidate.id && $0.name == candidate.name }
		let city = WorldClockCity(id: UUID(), name: candidate.name, timeZoneIdentifier: candidate.id, nickname: nil, order: 0)

		return Button {
			onAdd(city)
			dismiss()
		} label: {
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text(candidate.name)
						.foregroundStyle(.primary)
					Text(candidate.region)
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Spacer()

				if isAdded {
					Image(systemName: "checkmark.circle.fill")
						.foregroundStyle(Theme.accent)
				} else {
					Text(city.timeText(at: date))
						.font(Theme.clockFont(17, weight: .medium))
						.monospacedDigit()
						.foregroundStyle(.secondary)
				}
			}
		}
		.tint(.primary)
		.disabled(isAdded)
	}
}
