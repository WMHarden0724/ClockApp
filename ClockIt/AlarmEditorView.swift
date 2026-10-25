//
//  AlarmEditorView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

#if os(iOS)
import CoreLocation
#endif
import SwiftUI


struct AlarmEditorView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(ClockStore.self) private var store
	let existing: AppAlarm?
	let onSave: (AppAlarm) -> Void
	let onDelete: (() -> Void)?

	@State private var hour = 7
	@State private var minute = 0
	@State private var label = ""
	@State private var isEnabled = true
	@State private var repeatDays: Set<Int> = []
	@State private var useSpecificDate = false
	@State private var specificDate = Date()
	@State private var snoozeMinutes = 9
	@State private var sound: TimerSound = .standard
	@State private var mission: AppAlarm.MissionType = .none
	@State private var group = ""
	@State private var timeZoneIdentifier: String?
	@State private var sunrise: AppAlarm.SunriseOption?
	@State private var locating = false
	@State private var locationError: String?

	init(alarm: AppAlarm?, onSave: @escaping (AppAlarm) -> Void, onDelete: (() -> Void)? = nil) {
		self.existing = alarm
		self.onSave = onSave
		self.onDelete = onDelete
		if let alarm {
			_hour = State(initialValue: alarm.hour)
			_minute = State(initialValue: alarm.minute)
			_label = State(initialValue: alarm.label)
			_isEnabled = State(initialValue: alarm.isEnabled)
			_repeatDays = State(initialValue: alarm.repeatDays)
			_useSpecificDate = State(initialValue: alarm.specificDate != nil)
			_specificDate = State(initialValue: alarm.specificDate ?? Date())
			_snoozeMinutes = State(initialValue: alarm.snoozeMinutes)
			_sound = State(initialValue: alarm.sound)
			_mission = State(initialValue: alarm.mission)
			_group = State(initialValue: alarm.group ?? "")
			_timeZoneIdentifier = State(initialValue: alarm.timeZoneIdentifier)
			_sunrise = State(initialValue: alarm.sunrise)
		} else {
			_snoozeMinutes = State(initialValue: AppSettings.shared.defaultSnoozeMinutes)
		}
	}

	private var draft: AppAlarm {
		AppAlarm(
			id: existing?.id ?? UUID(),
			label: label,
			hour: hour,
			minute: minute,
			isEnabled: isEnabled,
			repeatDays: useSpecificDate ? [] : repeatDays,
			specificDate: useSpecificDate ? specificDate : nil,
			snoozeMinutes: snoozeMinutes,
			soundName: sound.rawValue,
			missionType: mission == .none ? nil : mission,
			skipUntil: existing?.skipUntil,
			timeZoneIdentifier: sunrise == nil ? timeZoneIdentifier : nil,
			sunrise: sunrise,
			group: group.trimmingCharacters(in: .whitespaces).isEmpty ? nil : group.trimmingCharacters(in: .whitespaces),
			isQuick: existing?.isQuick
		)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 16) {
					if sunrise == nil {
						dialCard
					} else {
						sunriseCard
					}
					detailsCard
					scheduleCard
					ringCard
					optionsCard

					if let onDelete {
						Button("Delete Alarm", role: .destructive) {
							onDelete()
							dismiss()
						}
						.glassButton()
						.controlSize(.large)
						.padding(.top, 8)
					}
				}
				.padding(16)
			}
			.dismissKeyboardOnScroll()
			.background(AlarmSkyBackground(hour: alarmHour))
			.navigationTitle(existing == nil ? "New Alarm" : "Edit Alarm")
			.inlineNavigationTitle()
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						var alarm = draft
						// Sunrise alarms sort by today's sunrise.
						if sunrise != nil, let next = alarm.nextFireDate() {
							let parts = Calendar.current.dateComponents([.hour, .minute], from: next)
							alarm.hour = parts.hour ?? alarm.hour
							alarm.minute = parts.minute ?? alarm.minute
						}
						onSave(alarm)
						dismiss()
					}
				}
			}
		}
		// Glass and text flip to dark styling once the sky behind them goes dark.
		.environment(\.colorScheme, SkyPalette.sky(atHour: alarmHour).prefersLightText ? .dark : .light)
		.animation(.smooth(duration: 0.6), value: alarmHour)
	}

	private var alarmHour: Double {
		if sunrise != nil, let next = draft.nextFireDate() {
			let parts = Calendar.current.dateComponents([.hour, .minute], from: next)
			return Double(parts.hour ?? 6) + Double(parts.minute ?? 0) / 60
		}
		return Double(hour) + Double(minute) / 60
	}

	private var dialCard: some View {
		VStack(spacing: 12) {
			TimeDial(hour: $hour, minute: $minute)
				.frame(maxWidth: 320)

			HStack {
				nudgeButton(systemImage: "minus", minutes: -1)
				Spacer()
				ringsIn
				Spacer()
				nudgeButton(systemImage: "plus", minutes: 1)
			}

			if let zone = draft.timeZone, zone != .current, let next = draft.nextFireDate() {
				Text("\(next.timeText) here")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity)
		.glassCard()
	}

	private var ringsIn: some View {
		TimelineView(.everyMinute) { context in
			Group {
				if let next = draft.nextFireDate(after: context.date) {
					Text("Rings in \(next.countdownText(from: context.date))")
				} else {
					Text("That date has passed")
				}
			}
			.font(.subheadline.weight(.medium))
			.foregroundStyle(.secondary)
			.contentTransition(.numericText())
		}
	}

	private var sunriseCard: some View {
		VStack(spacing: 12) {
			Image(systemName: "sunrise.fill")
				.font(.system(size: 44))
				.symbolRenderingMode(.multicolor)

			if let next = draft.nextFireDate() {
				Text(next.timeText)
					.font(Theme.clockFont(56))
					.monospacedDigit()
				Text(next.relativeDayAndTime)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			} else {
				Text("No sunrise soon here")
					.font(.title3)
			}

			if let sunrise {
				Stepper(value: Binding(
					get: { sunrise.offsetMinutes },
					set: { self.sunrise?.offsetMinutes = $0 }
				), in: -120...120, step: 5) {
					Text(sunrise.offsetMinutes == 0 ? "At sunrise"
						 : sunrise.offsetMinutes > 0 ? "\(sunrise.offsetMinutes) min after sunrise"
						 : "\(-sunrise.offsetMinutes) min before sunrise")
						.monospacedDigit()
				}
				Text("Moves with the seasons · \(sunrise.placeName)")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity)
		.glassCard()
	}

	private func nudgeButton(systemImage: String, minutes: Int) -> some View {
		Button {
			let total = ((hour * 60 + minute + minutes) % 1440 + 1440) % 1440
			hour = total / 60
			minute = total % 60
		} label: {
			Image(systemName: systemImage)
				.font(.body.weight(.semibold))
				.frame(width: 32, height: 32)
		}
		.glassButton()
		.buttonBorderShape(.circle)
		.accessibilityLabel(minutes > 0 ? "One minute later" : "One minute earlier")
	}

	private var detailsCard: some View {
		VStack(spacing: 14) {
			TextField("Label", text: $label, prompt: Text("Alarm"))
				.font(.title3)
			Divider()
			HStack {
				Label("Group", systemImage: "square.stack")
				TextField("Group", text: $group, prompt: Text("None"))
					.multilineTextAlignment(.trailing)
				if !store.groups.isEmpty {
					Menu {
						ForEach(store.groups, id: \.self) { name in
							Button(name) { group = name }
						}
						Button("None") { group = "" }
					} label: {
						Image(systemName: "chevron.up.chevron.down")
					}
					.menuStyle(.button)
					.buttonStyle(.plain)
					.fixedSize()
				}
			}
			Divider()
			Toggle("Enabled", isOn: $isEnabled)
		}
		.tint(Theme.accent)
		.glassCard()
	}

	private var scheduleCard: some View {
		VStack(alignment: .leading, spacing: 14) {
			Picker("Schedule", selection: $useSpecificDate.animation(.smooth)) {
				Text("Repeat").tag(false)
				Text("On a Date").tag(true)
			}
			.pickerStyle(.segmented)

			if useSpecificDate {
				DatePicker("Date", selection: $specificDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
					.datePickerStyle(.graphical)
					.tint(Theme.accent)
			} else {
				RepeatDaysPicker(selected: $repeatDays)
				Text(repeatDays.isEmpty ? "Rings once" : draft.scheduleText)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity)
			}
		}
		.glassCard()
	}

	/// When it rings: a time here or in another city, or with the sunrise.
	private var ringCard: some View {
		VStack(alignment: .leading, spacing: 14) {
			if sunrise == nil {
				Picker(selection: $timeZoneIdentifier) {
					Text("Here").tag(String?.none)
					ForEach(store.cities.filter { $0.timeZoneIdentifier != TimeZone.current.identifier }) { city in
						Text(city.displayName).tag(Optional(city.timeZoneIdentifier))
					}
				} label: {
					Label("Time In", systemImage: "globe")
				}
				Text("Rings at this time in that city, wherever you are. Handy for calls.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			#if os(iOS)
			if sunrise == nil { Divider() }
			Toggle(isOn: Binding(
				get: { sunrise != nil },
				set: { $0 ? locateForSunrise() : (sunrise = nil) }
			)) {
				Label(locating ? "Finding your location…" : "Ring at Sunrise", systemImage: "sunrise")
			}
			.disabled(locating)
			if let locationError {
				Text(locationError)
					.font(.footnote)
					.foregroundStyle(.red)
			}
			#else
			if sunrise != nil {
				Label("Rings at sunrise. Set up on iPhone.", systemImage: "sunrise")
			}
			#endif
		}
		.tint(Theme.accent)
		.glassCard()
	}

	private var optionsCard: some View {
		VStack(alignment: .leading, spacing: 14) {
			Stepper(value: $snoozeMinutes, in: 1...30) {
				HStack {
					Label("Snooze", systemImage: "zzz")
					Spacer()
					Text("\(snoozeMinutes) min")
						.monospacedDigit()
						.foregroundStyle(.secondary)
				}
			}

			Divider()

			TimerSoundPicker(sound: $sound, tint: Theme.accent)

			Divider()

			VStack(alignment: .leading, spacing: 8) {
				Label("Wake-Up Mission", systemImage: "figure.walk.motion")
				Picker("Wake-Up Mission", selection: $mission) {
					ForEach(AppAlarm.MissionType.allCases) { option in
						Text(option.title).tag(option)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
				Text(mission == .none
					 ? "Stop turns the alarm off right away."
					 : "Stop opens ClockIt, and the alarm rings again every minute until you \(mission == .math ? "solve three problems" : "shake your phone 30 times"). Works on iPhone.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.glassCard()
	}

	#if os(iOS)
	/// Sunrise alarms need to know where you are; ask once, when you turn it on.
	private func locateForSunrise() {
		locating = true
		locationError = nil
		Task {
			defer { locating = false }
			guard let location = await OneShotLocation.current() else {
				locationError = "ClockIt couldn't get your location. Allow it in Settings › ClockIt › Location."
				return
			}
			sunrise = AppAlarm.SunriseOption(
				offsetMinutes: 0,
				latitude: location.coordinate.latitude,
				longitude: location.coordinate.longitude,
				placeName: "Your location"
			)
			timeZoneIdentifier = nil
		}
	}
	#endif
}


#Preview {
	AlarmEditorView(alarm: nil) { _ in }
		.environment(ClockStore.preview)
}


/// The sky at the alarm's time: dawn pastels, midday blue, dusk, or a starry night. Follows the dial as you drag.
private struct AlarmSkyBackground: View {
	let hour: Double
	
	var body: some View {
		let sky = SkyPalette.sky(atHour: hour)
		let isDay = SkyPalette.isDaytime(hour: hour)
		let glow = isDay ? Color(red: 1.0, green: 0.86, blue: 0.55) : Color(red: 0.98, green: 0.96, blue: 0.88)
		
		ZStack {
			LinearGradient(colors: [sky.top, sky.bottom], startPoint: .top, endPoint: .bottom)
			
			// Soft sun or moon glow in the upper corner.
			RadialGradient(
				colors: [glow.opacity(isDay ? 0.55 : 0.18), .clear],
				center: UnitPoint(x: 0.85, y: 0.08),
				startRadius: 0,
				endRadius: 320
			)
			
			StarField(seed: "alarm-sky", count: 90)
				.opacity(sky.prefersLightText ? 1 : 0)
		}
		.ignoresSafeArea()
	}
}


#if os(iOS)
/// One location fix, asking for permission the first time.
enum OneShotLocation {
	static func current() async -> CLLocation? {
		let session = CLServiceSession(authorization: .whenInUse)
		defer { session.invalidate() }
		do {
			for try await update in CLLocationUpdate.liveUpdates() {
				if let location = update.location { return location }
				if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }
			}
		} catch {
			return nil
		}
		return nil
	}
}
#endif
