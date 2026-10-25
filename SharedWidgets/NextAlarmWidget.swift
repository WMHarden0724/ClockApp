//
//  NextAlarmWidget.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
import WidgetKit


/// The next alarm, on the Home Screen, Lock Screen and watch face.
struct NextAlarmWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: WidgetShelf.nextAlarmKind, provider: NextAlarmProvider()) { entry in
			NextAlarmWidgetView(entry: entry)
		}
		.configurationDisplayName("Next Alarm")
		.description("When your next alarm rings, and the ones after it.")
		.supportedFamilies(Self.families)
	}

	private static var families: [WidgetFamily] {
		#if os(watchOS)
		[.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
		#else
		[.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
		#endif
	}
}


nonisolated struct NextAlarmEntry: TimelineEntry {
	let date: Date
	let snapshot: WidgetSnapshot

	var upcoming: [WidgetSnapshot.Alarm] { snapshot.alarms(after: date) }
	var next: WidgetSnapshot.Alarm? { upcoming.first }
	var isPaused: Bool { (snapshot.alarmsPausedUntil ?? .distantPast) > date }
}


nonisolated struct NextAlarmProvider: TimelineProvider {
	func placeholder(in context: Context) -> NextAlarmEntry {
		NextAlarmEntry(date: .now, snapshot: .preview)
	}

	func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
		completion(NextAlarmEntry(date: .now, snapshot: context.isPreview ? .preview : WidgetShelf.read()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
		let snapshot = WidgetShelf.read()
		let now = Date()
		// A new entry as each alarm rings and when a pause ends, so the widget moves on by itself.
		var changes = [now] + snapshot.alarms(after: now).map(\.date)
		if let pausedUntil = snapshot.alarmsPausedUntil, pausedUntil > now { changes.append(pausedUntil) }
		let entries = Set(changes).sorted().map { NextAlarmEntry(date: $0, snapshot: snapshot) }
		completion(Timeline(entries: entries, policy: .atEnd))
	}
}


struct NextAlarmWidgetView: View {
	@Environment(\.widgetFamily) private var family
	let entry: NextAlarmEntry

	private var uses24Hour: Bool? { entry.snapshot.uses24Hour }
	private var sky: SkyPalette.Sky { SkyPalette.sky(at: entry.next?.date ?? entry.date) }

	var body: some View {
		content
			.containerBackground(for: .widget) { sky.gradient }
	}

	@ViewBuilder
	private var content: some View {
		switch family {
		case .accessoryInline: inline
		case .accessoryCircular: circular
		case .accessoryRectangular: rectangular
		#if os(watchOS)
		case .accessoryCorner: corner
		#endif
		case .systemMedium: medium
		default: small
		}
	}

	// MARK: Home Screen

	private var small: some View {
		NextAlarmSummary(entry: entry, uses24Hour: uses24Hour)
			.foregroundStyle(sky.textColor)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
	}

	private var medium: some View {
		HStack(alignment: .top, spacing: 16) {
			NextAlarmSummary(entry: entry, uses24Hour: uses24Hour)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

			VStack(alignment: .leading, spacing: 8) {
				Text("Later")
					.font(.caption.weight(.semibold))
					.opacity(0.75)
				let later = entry.upcoming.dropFirst().prefix(3)
				if later.isEmpty {
					Text("Nothing else set")
						.font(.subheadline)
						.opacity(0.75)
				}
				ForEach(Array(later)) { alarm in
					VStack(alignment: .leading, spacing: 0) {
						Text(WidgetFormat.time(alarm.date, uses24Hour: uses24Hour))
							.font(.headline.weight(.medium))
						Text("\(WidgetFormat.day(of: alarm.date, from: entry.date)) · \(alarm.label)")
							.font(.caption)
							.opacity(0.8)
							.lineLimit(1)
					}
				}
				Spacer(minLength: 0)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.foregroundStyle(sky.textColor)
	}

	// MARK: Lock Screen and watch face

	private var circular: some View {
		ZStack {
			AccessoryWidgetBackground()
			VStack(spacing: 0) {
				Image(systemName: entry.isPaused ? "moon.zzz.fill" : "alarm.fill")
					.font(.caption)
				Text(entry.next.map { WidgetFormat.compactTime($0.date, uses24Hour: uses24Hour) } ?? "--")
					.font(.system(.body, design: .rounded).weight(.semibold))
					.minimumScaleFactor(0.5)
					.lineLimit(1)
			}
			.padding(4)
		}
		.widgetAccentable()
	}

	private var rectangular: some View {
		VStack(alignment: .leading, spacing: 0) {
			Label(entry.next?.label ?? "Alarms", systemImage: "alarm.fill")
				.font(.headline)
				.widgetAccentable()
				.lineLimit(1)
			if let next = entry.next {
				Text(WidgetFormat.time(next.date, uses24Hour: uses24Hour))
					.font(.system(.title2, design: .rounded).weight(.medium))
					.lineLimit(1)
					.minimumScaleFactor(0.7)
				Text(entry.isPaused ? "Paused" : WidgetFormat.day(of: next.date, from: entry.date))
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				Text(entry.isPaused ? "Paused" : "No alarms set")
					.font(.body)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var inline: some View {
		Label {
			if let next = entry.next {
				Text("\(WidgetFormat.time(next.date, uses24Hour: uses24Hour)) \(next.label)")
			} else {
				Text("No alarms")
			}
		} icon: {
			Image(systemName: "alarm.fill")
		}
	}

	#if os(watchOS)
	private var corner: some View {
		Image(systemName: "alarm.fill")
			.font(.title3)
			.widgetAccentable()
			.widgetLabel {
				Text(entry.next.map { WidgetFormat.time($0.date, uses24Hour: uses24Hour) } ?? "No alarms")
			}
	}
	#endif
}


/// Next alarm's time, label and how far off it is.
private struct NextAlarmSummary: View {
	let entry: NextAlarmEntry
	let uses24Hour: Bool?

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Label(entry.isPaused ? "Paused" : "Next Alarm", systemImage: entry.isPaused ? "moon.zzz.fill" : "alarm.fill")
				.font(.caption.weight(.semibold))
				.opacity(0.8)

			Spacer(minLength: 0)

			if let next = entry.next {
				Text(WidgetFormat.time(next.date, uses24Hour: uses24Hour))
					.font(WidgetFormat.clockFont(34))
					.lineLimit(1)
					.minimumScaleFactor(0.6)
				Text(next.label)
					.font(.subheadline.weight(.semibold))
					.lineLimit(1)
				Text("\(WidgetFormat.day(of: next.date, from: entry.date)) · in \(next.date, style: .relative)")
					.font(.caption)
					.opacity(0.8)
					.lineLimit(1)
			} else {
				Text("No alarms")
					.font(.title3.weight(.medium))
				Text(entry.isPaused ? "Alarms are paused" : "Set one in ClockIt")
					.font(.caption)
					.opacity(0.8)
			}
		}
	}
}


#if os(iOS)
#Preview(as: .systemSmall) {
	NextAlarmWidget()
} timeline: {
	NextAlarmEntry(date: .now, snapshot: .preview)
	NextAlarmEntry(date: .now, snapshot: WidgetSnapshot())
}

#Preview(as: .systemMedium) {
	NextAlarmWidget()
} timeline: {
	NextAlarmEntry(date: .now, snapshot: .preview)
}
#endif
