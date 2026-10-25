//
//  TimersWidget.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
import WidgetKit


/// Running timers counting down, on the Home Screen, Lock Screen and watch face.
struct TimersWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: WidgetShelf.timersKind, provider: TimersProvider()) { entry in
			TimersWidgetView(entry: entry)
		}
		.configurationDisplayName("Timers")
		.description("Your running timers, counting down.")
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


nonisolated struct TimersEntry: TimelineEntry {
	let date: Date
	let snapshot: WidgetSnapshot

	var timers: [WidgetSnapshot.Timer] { snapshot.timers(at: date) }
}


nonisolated struct TimersProvider: TimelineProvider {
	func placeholder(in context: Context) -> TimersEntry {
		TimersEntry(date: .now, snapshot: .preview)
	}

	func getSnapshot(in context: Context, completion: @escaping (TimersEntry) -> Void) {
		completion(TimersEntry(date: .now, snapshot: context.isPreview ? .preview : WidgetShelf.read()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<TimersEntry>) -> Void) {
		let snapshot = WidgetShelf.read()
		let now = Date()
		// Countdowns tick on their own; a new entry only as each timer finishes.
		let ends = snapshot.timers.compactMap(\.endDate).filter { $0 > now }
		let entries = Set([now] + ends).sorted().map { TimersEntry(date: $0, snapshot: snapshot) }
		completion(Timeline(entries: entries, policy: .never))
	}
}


struct TimersWidgetView: View {
	@Environment(\.widgetFamily) private var family
	let entry: TimersEntry

	private var first: WidgetSnapshot.Timer? { entry.timers.first }
	private var tint: Color { first.map { ClockItPalette.color(named: $0.colorName) } ?? ClockItPalette.accent }

	var body: some View {
		content
			.containerBackground(for: .widget) {
				LinearGradient(colors: [tint.opacity(0.32), tint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
			}
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

	@ViewBuilder
	private var small: some View {
		if let timer = first {
			VStack(alignment: .leading, spacing: 4) {
				HStack {
					TimerBadge(timer: timer, size: 30)
					Spacer()
					if entry.timers.count > 1 {
						Text("+\(entry.timers.count - 1)")
							.font(.caption.weight(.semibold))
							.foregroundStyle(.secondary)
					}
				}
				Spacer(minLength: 0)
				TimerCountdown(timer: timer)
					.font(WidgetFormat.clockFont(34))
				Text(timer.endDate == nil ? "\(timer.label) · Paused" : timer.label)
					.font(.subheadline.weight(.semibold))
					.lineLimit(1)
				TimerProgress(timer: timer)
					.tint(ClockItPalette.color(named: timer.colorName))
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		} else {
			empty
		}
	}

	@ViewBuilder
	private var medium: some View {
		if entry.timers.isEmpty {
			empty
		} else {
			VStack(spacing: 10) {
				ForEach(entry.timers.prefix(3)) { timer in
					HStack(spacing: 10) {
						TimerBadge(timer: timer, size: 28)
						VStack(alignment: .leading, spacing: 3) {
							Text(timer.endDate == nil ? "\(timer.label) · Paused" : timer.label)
								.font(.subheadline.weight(.semibold))
								.lineLimit(1)
							TimerProgress(timer: timer)
								.tint(ClockItPalette.color(named: timer.colorName))
						}
						TimerCountdown(timer: timer)
							.font(.system(.title3, design: .rounded).weight(.medium))
							.frame(width: 84, alignment: .trailing)
					}
				}
				Spacer(minLength: 0)
			}
		}
	}

	private var empty: some View {
		VStack(spacing: 6) {
			Image(systemName: "timer")
				.font(.title2)
				.foregroundStyle(ClockItPalette.accent)
			Text("No timers running")
				.font(.subheadline.weight(.medium))
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	// MARK: Lock Screen and watch face

	@ViewBuilder
	private var circular: some View {
		if let timer = first {
			TimerRing(timer: timer) {
				Image(systemName: timer.symbol)
			}
			.widgetAccentable()
		} else {
			ZStack {
				AccessoryWidgetBackground()
				Image(systemName: "timer")
			}
		}
	}

	private var rectangular: some View {
		VStack(alignment: .leading, spacing: 2) {
			Label(first?.label ?? "Timers", systemImage: first?.symbol ?? "timer")
				.font(.headline)
				.lineLimit(1)
				.widgetAccentable()
			if let timer = first {
				TimerCountdown(timer: timer)
					.font(.system(.title2, design: .rounded).weight(.medium))
				TimerProgress(timer: timer)
			} else {
				Text("None running")
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var inline: some View {
		Label {
			if let timer = first {
				TimerCountdown(timer: timer)
			} else {
				Text("No timers")
			}
		} icon: {
			Image(systemName: "timer")
		}
	}

	#if os(watchOS)
	@ViewBuilder
	private var corner: some View {
		if let timer = first {
			Image(systemName: timer.symbol)
				.font(.title3)
				.widgetAccentable()
				.widgetLabel {
					TimerCountdown(timer: timer)
				}
		} else {
			Image(systemName: "timer")
				.font(.title3)
				.widgetLabel("No timers")
		}
	}
	#endif
}


/// The category symbol in the timer's color.
private struct TimerBadge: View {
	let timer: WidgetSnapshot.Timer
	let size: CGFloat

	var body: some View {
		Image(systemName: timer.symbol)
			.font(.system(size: size * 0.45, weight: .semibold))
			.foregroundStyle(.white)
			.frame(width: size, height: size)
			.background(ClockItPalette.color(named: timer.colorName), in: .circle)
	}
}


/// Ticks down while running; the time left while paused.
private struct TimerCountdown: View {
	let timer: WidgetSnapshot.Timer

	var body: some View {
		Group {
			if let start = timer.startDate, let end = timer.endDate {
				Text(timerInterval: start...end, countsDown: true)
			} else {
				Text(WidgetFormat.remaining(timer.remaining))
			}
		}
		.monospacedDigit()
		.lineLimit(1)
		.minimumScaleFactor(0.6)
	}
}


/// A bar that drains as the timer runs.
private struct TimerProgress: View {
	let timer: WidgetSnapshot.Timer

	var body: some View {
		if let start = timer.startDate, let end = timer.endDate {
			ProgressView(timerInterval: start...end, countsDown: true) {
				EmptyView()
			} currentValueLabel: {
				EmptyView()
			}
		} else {
			ProgressView(value: timer.remaining, total: max(timer.duration, 1))
		}
	}
}


/// A ring that drains as the timer runs, around `label`.
private struct TimerRing<Label: View>: View {
	let timer: WidgetSnapshot.Timer
	@ViewBuilder let label: Label

	var body: some View {
		Group {
			if let start = timer.startDate, let end = timer.endDate {
				ProgressView(timerInterval: start...end, countsDown: true) {
					EmptyView()
				} currentValueLabel: {
					label
				}
			} else {
				ProgressView(value: timer.remaining, total: max(timer.duration, 1)) {
					EmptyView()
				} currentValueLabel: {
					label
				}
			}
		}
		.progressViewStyle(.circular)
	}
}


#if os(iOS)
#Preview(as: .systemSmall) {
	TimersWidget()
} timeline: {
	TimersEntry(date: .now, snapshot: .preview)
	TimersEntry(date: .now, snapshot: WidgetSnapshot())
}

#Preview(as: .systemMedium) {
	TimersWidget()
} timeline: {
	TimersEntry(date: .now, snapshot: .preview)
}
#endif
