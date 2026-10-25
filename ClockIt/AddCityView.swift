//
//  AddCityView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


struct AddCityView: View {
	@Environment(\.dismiss) private var dismiss
	let existingIdentifiers: Set<String>
	let onAdd: (WorldClockCity) -> Void

	@State private var searchText = ""

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

	private var results: [Candidate] {
		if searchText.isEmpty { return Self.popular }
		return Self.all.filter {
			$0.name.localizedCaseInsensitiveContains(searchText) || $0.region.localizedCaseInsensitiveContains(searchText)
		}
	}

	var body: some View {
		NavigationStack {
			TimelineView(.everyMinute) { context in
				List {
					Section(searchText.isEmpty ? "Popular" : "Results") {
						ForEach(results) { candidate in
							row(for: candidate, at: context.date)
						}
					}
				}
			}
			.overlay {
				if results.isEmpty {
					ContentUnavailableView.search(text: searchText)
				}
			}
			.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or region")
			.navigationTitle("Add City")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
			}
		}
	}

	private func row(for candidate: Candidate, at date: Date) -> some View {
		let isAdded = existingIdentifiers.contains(candidate.id)
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
		.disabled(isAdded)
	}
}
