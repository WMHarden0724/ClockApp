//
//  SettingsView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Observation
import SwiftUI


/// App-wide preferences. Views that format times through it update as soon as a setting changes.
@Observable
final class AppSettings {
	static let shared = AppSettings()

	enum TimeFormat: String, CaseIterable, Identifiable {
		case system, twelveHour, twentyFourHour

		var id: String { rawValue }

		var title: String {
			switch self {
			case .system: "System"
			case .twelveHour: "12-Hour"
			case .twentyFourHour: "24-Hour"
			}
		}
	}

	private static let timeFormatKey = "timeFormat"
	private static let timerStyleKey = "timerStyle"

	var timeFormat: TimeFormat {
		didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: Self.timeFormatKey) }
	}

	var timerStyle: TimerStyle {
		didSet { UserDefaults.standard.set(timerStyle.rawValue, forKey: Self.timerStyleKey) }
	}

	/// nil follows the system setting.
	var uses24Hour: Bool? {
		switch timeFormat {
		case .system: nil
		case .twelveHour: false
		case .twentyFourHour: true
		}
	}

	var is24Hour: Bool { ClockFormat.is24Hour(uses24Hour) }

	private init() {
		timeFormat = UserDefaults.standard.string(forKey: Self.timeFormatKey).flatMap(TimeFormat.init) ?? .system
		timerStyle = UserDefaults.standard.string(forKey: Self.timerStyleKey).flatMap(TimerStyle.init) ?? .ring
	}
}


extension Date {
	/// This time in the user's chosen 12/24-hour format.
	var timeText: String {
		ClockFormat.time(self, uses24Hour: AppSettings.shared.uses24Hour)
	}

	func timeText(in timeZone: TimeZone) -> String {
		ClockFormat.time(self, uses24Hour: AppSettings.shared.uses24Hour, timeZone: timeZone)
	}

	var dateTimeText: String {
		ClockFormat.dateTime(self, uses24Hour: AppSettings.shared.uses24Hour)
	}
}


struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(ClockStore.self) private var store
	@Bindable private var settings = AppSettings.shared

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 16) {
					timeFormatCard
					timerStyleCard
				}
				.padding(16)
			}
			.background(AuroraBackground())
			.navigationTitle("Settings")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
			.onChange(of: settings.timeFormat) {
				// Reschedule so alarm Live Activities pick up the new format.
				store.resyncAlarms()
			}
			.sensoryFeedback(.selection, trigger: settings.timeFormat)
			.sensoryFeedback(.selection, trigger: settings.timerStyle)
		}
	}

	private var timerStyleCard: some View {
		VStack(alignment: .leading, spacing: 14) {
			Label("Timer Style", systemImage: "timer")
				.font(.headline)

			LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
				ForEach(TimerStyle.allCases) { style in
					let isSelected = settings.timerStyle == style

					Button {
						withAnimation(.snappy) { settings.timerStyle = style }
					} label: {
						VStack(spacing: 10) {
							TimerStylePreview(style: style, color: Theme.accent)
							VStack(spacing: 2) {
								Text(style.title)
									.font(.subheadline.weight(.semibold))
								Text(style.caption)
									.font(.caption2)
									.foregroundStyle(.secondary)
							}
						}
						.frame(maxWidth: .infinity)
						.padding(.vertical, 16)
						.overlay {
							RoundedRectangle(cornerRadius: 20)
								.strokeBorder(Theme.accent, lineWidth: isSelected ? 2.5 : 0)
						}
					}
					.buttonStyle(.plain)
					.glassEffect(isSelected ? .regular.tint(Theme.accent.opacity(0.15)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 20))
					.accessibilityAddTraits(isSelected ? .isSelected : [])
				}
			}
		}
		.glassCard()
	}

	private var timeFormatCard: some View {
		VStack(alignment: .leading, spacing: 14) {
			Label("Time Format", systemImage: "clock")
				.font(.headline)

			Picker("Time Format", selection: $settings.timeFormat.animation(.snappy)) {
				ForEach(AppSettings.TimeFormat.allCases) { format in
					Text(format.title).tag(format)
				}
			}
			.pickerStyle(.segmented)

			HStack {
				Text("Preview")
					.foregroundStyle(.secondary)
				Spacer()
				TimelineView(.everyMinute) { context in
					Text(context.date.timeText)
						.font(Theme.clockFont(28))
						.monospacedDigit()
						.contentTransition(.numericText())
				}
			}

			Text("Applies to alarms, world clocks, timers, the stopwatch history and the Lock Screen.")
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
		.glassCard()
	}
}


extension View {
	/// Adds a gear button to the navigation bar that opens Settings.
	func settingsButton() -> some View {
		modifier(SettingsButton())
	}
}


private struct SettingsButton: ViewModifier {
	@State private var showingSettings = false

	func body(content: Content) -> some View {
		content
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						showingSettings = true
					} label: {
						Image(systemName: "gearshape")
					}
					.accessibilityLabel("Settings")
				}
			}
			.sheet(isPresented: $showingSettings) {
				SettingsView()
			}
	}
}
