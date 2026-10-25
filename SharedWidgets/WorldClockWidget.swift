//
//  WorldClockWidget.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
import WidgetKit


/// Your World Clock cities, each under its own sky.
struct WorldClockWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: WidgetShelf.worldClockKind, provider: WorldClockProvider()) { entry in
			WorldClockWidgetView(entry: entry)
		}
		.configurationDisplayName("World Clock")
		.description("The time in your World Clock cities.")
		.supportedFamilies(Self.families)
	}

	private static var families: [WidgetFamily] {
		#if os(watchOS)
		[.accessoryCircular, .accessoryRectangular, .accessoryInline]
		#else
		[.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
		#endif
	}
}


nonisolated struct WorldClockEntry: TimelineEntry {
	let date: Date
	let snapshot: WidgetSnapshot
}


nonisolated struct WorldClockProvider: TimelineProvider {
	func placeholder(in context: Context) -> WorldClockEntry {
		WorldClockEntry(date: .now, snapshot: .preview)
	}

	func getSnapshot(in context: Context, completion: @escaping (WorldClockEntry) -> Void) {
		completion(WorldClockEntry(date: .now, snapshot: context.isPreview ? .preview : WidgetShelf.read()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<WorldClockEntry>) -> Void) {
		let snapshot = WidgetShelf.read()
		// Text's live clock styles only show your own time zone, so lay out a minute at a time.
		let minute = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
		let entries = (0..<120).map { WorldClockEntry(date: minute.addingTimeInterval(Double($0) * 60), snapshot: snapshot) }
		completion(Timeline(entries: entries, policy: .atEnd))
	}
}


struct WorldClockWidgetView: View {
	@Environment(\.widgetFamily) private var family
	let entry: WorldClockEntry

	private var cities: [WidgetSnapshot.City] { entry.snapshot.cities }
	private var uses24Hour: Bool? { entry.snapshot.uses24Hour }

	private var isHomeScreenSmall: Bool {
		#if os(watchOS)
		false
		#else
		family == .systemSmall
		#endif
	}

	var body: some View {
		content
			.containerBackground(for: .widget) { background }
	}

	@ViewBuilder
	private var background: some View {
		if isHomeScreenSmall, let city = cities.first {
			SkyPalette.sky(at: entry.date, in: city.timeZone).gradient
		} else {
			SkyPalette.sky(at: entry.date).gradient.opacity(0.35)
		}
	}

	@ViewBuilder
	private var content: some View {
		switch family {
		case .accessoryInline: inline
		case .accessoryCircular: circular
		case .accessoryRectangular: rectangular
		case .systemMedium: medium
		default: small
		}
	}

	// MARK: Home Screen

	@ViewBuilder
	private var small: some View {
		if let city = cities.first {
			let sky = SkyPalette.sky(at: entry.date, in: city.timeZone)
			VStack(alignment: .leading, spacing: 2) {
				Label("World Clock", systemImage: "globe")
					.font(.caption.weight(.semibold))
					.opacity(0.8)
				Spacer(minLength: 0)
				Text(city.displayName)
					.font(.headline)
					.lineLimit(1)
				Text(WidgetFormat.time(entry.date, uses24Hour: uses24Hour, in: city.timeZone))
					.font(WidgetFormat.clockFont(34))
					.lineLimit(1)
					.minimumScaleFactor(0.6)
				Text(detail(for: city))
					.font(.caption)
					.opacity(0.8)
					.lineLimit(1)
			}
			.foregroundStyle(sky.textColor)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		} else {
			empty
		}
	}

	@ViewBuilder
	private var medium: some View {
		if cities.isEmpty {
			empty
		} else {
			HStack(spacing: 8) {
				ForEach(cities.prefix(4)) { city in
					CityTile(city: city, date: entry.date, uses24Hour: uses24Hour)
				}
			}
		}
	}

	private var empty: some View {
		VStack(spacing: 6) {
			Image(systemName: "globe")
				.font(.title2)
				.foregroundStyle(ClockItPalette.accent)
			Text("Add a city in ClockIt")
				.font(.subheadline.weight(.medium))
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	// MARK: Lock Screen and watch face

	@ViewBuilder
	private var circular: some View {
		ZStack {
			AccessoryWidgetBackground()
			if let city = cities.first {
				VStack(spacing: 0) {
					Text(city.displayName.prefix(3).uppercased())
						.font(.caption2.weight(.semibold))
						.widgetAccentable()
					Text(WidgetFormat.compactTime(entry.date, uses24Hour: uses24Hour, in: city.timeZone))
						.font(.system(.body, design: .rounded).weight(.semibold))
						.minimumScaleFactor(0.5)
						.lineLimit(1)
				}
				.padding(4)
			} else {
				Image(systemName: "globe")
			}
		}
	}

	@ViewBuilder
	private var rectangular: some View {
		if cities.isEmpty {
			Label("No cities yet", systemImage: "globe")
				.frame(maxWidth: .infinity, alignment: .leading)
		} else {
			VStack(alignment: .leading, spacing: 1) {
				ForEach(cities.prefix(3)) { city in
					HStack {
						Text(city.displayName)
							.lineLimit(1)
						Spacer(minLength: 4)
						Text(WidgetFormat.time(entry.date, uses24Hour: uses24Hour, in: city.timeZone))
							.monospacedDigit()
							.widgetAccentable()
					}
					.font(.system(.body, design: .rounded).weight(.medium))
				}
			}
		}
	}

	private var inline: some View {
		Label {
			if let city = cities.first {
				Text("\(city.displayName) \(WidgetFormat.time(entry.date, uses24Hour: uses24Hour, in: city.timeZone))")
			} else {
				Text("World Clock")
			}
		} icon: {
			Image(systemName: "globe")
		}
	}

	private func detail(for city: WidgetSnapshot.City) -> String {
		let offset = WidgetFormat.offset(of: city.timeZone, at: entry.date)
		let parts = [city.person == nil ? nil : city.name, WidgetFormat.dayShift(in: city.timeZone, at: entry.date), offset]
		return parts.compactMap { $0 }.joined(separator: " · ")
	}
}


/// One city under its own sky, for the medium widget.
private struct CityTile: View {
	let city: WidgetSnapshot.City
	let date: Date
	let uses24Hour: Bool?

	var body: some View {
		let sky = SkyPalette.sky(at: date, in: city.timeZone)
		VStack(alignment: .leading, spacing: 2) {
			Text(city.displayName)
				.font(.caption.weight(.semibold))
				.lineLimit(1)
			if city.person != nil {
				Text(city.name)
					.font(.caption2)
					.opacity(0.8)
					.lineLimit(1)
			}
			Spacer(minLength: 0)
			Text(WidgetFormat.compactTime(date, uses24Hour: uses24Hour, in: city.timeZone))
				.font(WidgetFormat.clockFont(24))
				.lineLimit(1)
				.minimumScaleFactor(0.6)
			Text(WidgetFormat.dayShift(in: city.timeZone, at: date) ?? WidgetFormat.offset(of: city.timeZone, at: date))
				.font(.caption2)
				.opacity(0.8)
				.lineLimit(1)
		}
		.foregroundStyle(sky.textColor)
		.padding(10)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		.background(sky.gradient, in: .rect(cornerRadius: 14))
	}
}


#if os(iOS)
#Preview(as: .systemSmall) {
	WorldClockWidget()
} timeline: {
	WorldClockEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
	WorldClockWidget()
} timeline: {
	WorldClockEntry(date: .now, snapshot: .preview)
}
#endif
