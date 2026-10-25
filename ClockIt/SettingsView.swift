//
//  SettingsView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Observation
import SwiftUI


/// One Settings page per tab, picked with the segmented control at the top.
enum SettingsSection: String, CaseIterable, Identifiable {
	case general, alarms, worldClock, stopwatch, timers

	var id: String { rawValue }

	var title: String {
		switch self {
		case .general: "General"
		case .alarms: "Alarms"
		case .worldClock: "World Clock"
		case .stopwatch: "Stopwatch"
		case .timers: "Timers"
		}
	}

	var symbol: String {
		switch self {
		case .general: "gearshape"
		case .alarms: "alarm"
		case .worldClock: "globe"
		case .stopwatch: "stopwatch"
		case .timers: "timer"
		}
	}
}


struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(ClockStore.self) private var store
	@Environment(TimerStore.self) private var timerStore
	@Bindable private var settings = AppSettings.shared
	@State private var section: SettingsSection
	@State private var showingWelcome = false

	init(section: SettingsSection = .general) {
		_section = State(initialValue: section)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					Picker("Section", selection: $section.animation(.snappy)) {
						ForEach(SettingsSection.allCases) { section in
							Image(systemName: section.symbol)
								.accessibilityLabel(section.title)
								.tag(section)
						}
					}
					.pickerStyle(.segmented)

					Text(section.title)
						.font(.title2.weight(.bold))
						.padding(.leading, 4)
						.contentTransition(.opacity)

					Group {
						switch section {
						case .general: timeFormatCard
						case .alarms: alarmsCard
						case .worldClock: worldClockCard
						case .stopwatch: stopwatchCard
						case .timers: timerStyleCard
						}
					}
					.transition(.opacity.combined(with: .move(edge: .bottom)))
				}
				.padding(16)
			}
			.sensoryFeedback(.selection, trigger: section)
			.background(AuroraBackground())
			.navigationTitle("Settings")
			.inlineNavigationTitle()
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

	private var alarmsCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Stepper(value: $settings.defaultSnoozeMinutes, in: 1...30) {
				HStack {
					Label("Default Snooze", systemImage: "zzz")
					Spacer()
					Text("\(settings.defaultSnoozeMinutes) min")
						.monospacedDigit()
						.foregroundStyle(.secondary)
				}
			}

			Text("Used for new alarms. You can still change snooze on each alarm.")
				.font(.footnote)
				.foregroundStyle(.secondary)

			Divider()

			Stepper(value: $settings.sleepGoalMinutes, in: 240...720, step: 15) {
				HStack {
					Label("Sleep Goal", systemImage: "bed.double")
					Spacer()
					Text("\(settings.sleepGoalMinutes / 60) h \(settings.sleepGoalMinutes % 60 == 0 ? "" : "\(settings.sleepGoalMinutes % 60) m")")
						.monospacedDigit()
						.foregroundStyle(.secondary)
				}
			}

			Toggle(isOn: $settings.bedtimeReminder) {
				Label("Bedtime Reminder", systemImage: "moon.zzz")
			}
			.tint(Theme.accent)
			.onChange(of: settings.bedtimeReminder) { store.refreshReminders() }
			.onChange(of: settings.sleepGoalMinutes) { store.refreshReminders() }

			Text("Shows when to go to bed for your next alarm. The reminder comes 15 minutes before bedtime.")
				.font(.footnote)
				.foregroundStyle(.secondary)

			if AppSettings.canRing {
				Divider()

				Toggle(isOn: $settings.ringsOnThisDevice) {
					Label("Ring on This Device", systemImage: "bell.badge")
				}
				.tint(Theme.accent)
				.onChange(of: settings.ringsOnThisDevice) {
					store.resyncAlarms()
					timerStore.rescheduleAll()
				}

				Text("Alarms and timers sync to all your devices but ring only where this is on. It's on for iPhone and off for iPad unless you change it.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.glassCard()
	}

	private var stopwatchCard: some View {
		VStack(alignment: .leading, spacing: 14) {
			Picker(selection: $settings.stopwatchDialStyle.animation(.snappy)) {
				ForEach(AppSettings.StopwatchDialStyle.allCases) { style in
					Text(style.title).tag(style)
				}
			} label: {
				Label("Dial", systemImage: "dot.radiowaves.left.and.right")
			}
			.pickerStyle(.segmented)
			Text(settings.stopwatchDialStyle == .radar
				 ? "A radar scope: the beam sweeps once a minute and each lap lights up as a blip."
				 : "A chronograph with a sweeping hand, a minutes sub-dial and a pace ring.")
				.font(.footnote)
				.foregroundStyle(.secondary)

			Divider()

			Toggle(isOn: $settings.stopwatchKeepsScreenAwake) {
				Label("Keep Screen Awake", systemImage: "sun.max")
			}
			Text("Stops the screen from dimming while the stopwatch is running.")
				.font(.footnote)
				.foregroundStyle(.secondary)

			Divider()

			Toggle(isOn: $settings.stopwatchShowsPaceRing) {
				Label("Pace Ring", systemImage: "circle.dashed")
			}
			Text("The outer ring compares your current lap to your best one. Chronograph only.")
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
		.tint(Theme.accent)
		.glassCard()
	}

	private var worldClockCard: some View {
		VStack(spacing: 16) {
			myCityCard
			#if os(iOS)
			daylightSavingCard
			#endif
		}
	}

	#if os(iOS)
	private var daylightSavingCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Toggle(isOn: $settings.daylightSavingAlerts) {
				Label("Daylight Saving Alerts", systemImage: "clock.arrow.2.circlepath")
			}
			.tint(Theme.accent)
			.onChange(of: settings.daylightSavingAlerts) { store.refreshReminders() }

			Text("A heads-up three days before your clocks or a World Clock city's change, with what the time difference becomes.")
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
		.glassCard()
	}
	#endif

	private var myCityCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("My City", systemImage: "location.fill")
				.font(.headline)

			HStack {
				Text(LocalTime.currentCity)
					.font(.title3.weight(.semibold))
				Spacer()
				if settings.homeCityName != nil {
					Button("Reset") {
						withAnimation(.snappy) { settings.clearHomeCity() }
					}
					.glassButton()
				}
			}

			Text(settings.homeCityName == nil
				 ? "Search for your city in World Clock › + and choose Set as My City."
				 : "Shown beside your local time while you're in its time zone. Elsewhere, ClockIt names your time zone's city.")
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
		.glassCard()
	}

	private var timerStyleCard: some View {
		VStack(spacing: 16) {
			timerAlertsCard
			timerStyleGrid
		}
	}

	private var timerAlertsCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Picker(selection: $settings.timerHeadsUp) {
				ForEach(AppSettings.TimerHeadsUp.allCases) { option in
					Text(option.title).tag(option)
				}
			} label: {
				Label("Heads-Up", systemImage: "bell.badge")
			}
			Text("A gentle notification before a timer ends, so you can stir the pasta or flip the steak.")
				.font(.footnote)
				.foregroundStyle(.secondary)

			#if os(macOS)
			Divider()

			Toggle(isOn: $settings.showsMenuBarTimer) {
				Label("Show in Menu Bar", systemImage: "menubar.rectangle")
			}
			.tint(Theme.accent)
			Text("Shows the next timer's time left in the menu bar, with your saved timers a click away.")
				.font(.footnote)
				.foregroundStyle(.secondary)
			#endif
		}
		.glassCard()
		.onChange(of: settings.timerHeadsUp) {
			timerStore.refreshNotifications()
		}
	}

	private var timerStyleGrid: some View {
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
					.softGlass(isSelected ? .regular.tint(Theme.accent.opacity(0.15)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 20))
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

			Divider()

			Button {
				showingWelcome = true
			} label: {
				Label("Show Welcome Again", systemImage: "sparkles")
			}
			.glassButton()
		}
		.glassCard()
		.fullScreenOrSheet(isPresented: $showingWelcome) {
			WelcomeView()
		}
	}
}


extension View {
	/// Adds a gear button to the navigation bar that opens Settings.
	func settingsButton(section: SettingsSection = .general) -> some View {
		modifier(SettingsButton(section: section))
	}
}


private struct SettingsButton: ViewModifier {
	let section: SettingsSection
	@State private var showingSettings = false

	func body(content: Content) -> some View {
		content
			.toolbar {
				ToolbarItem(placement: .barTrailing) {
					Button {
						showingSettings = true
					} label: {
						Image(systemName: "gearshape")
					}
					.accessibilityLabel("Settings")
				}
			}
			.sheet(isPresented: $showingSettings) {
				SettingsView(section: section)
			}
	}
}
