//
//  AlarmEditorView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


struct AlarmEditorView: View {
	@Environment(\.dismiss) private var dismiss
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
	@State private var volumeRamp = false

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
			_volumeRamp = State(initialValue: alarm.volumeRamp)
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
			soundName: "default",
			volumeRamp: volumeRamp,
			missionType: nil
		)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 16) {
					dialCard
					detailsCard
					scheduleCard
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
						onSave(draft)
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
		Double(hour) + Double(minute) / 60
	}

	private var dialCard: some View {
		VStack(spacing: 12) {
			TimeDial(hour: $hour, minute: $minute)
				.frame(maxWidth: 320)

			HStack {
				nudgeButton(systemImage: "minus", minutes: -1)
				Spacer()
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
				Spacer()
				nudgeButton(systemImage: "plus", minutes: 1)
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

	private var optionsCard: some View {
		Stepper(value: $snoozeMinutes, in: 1...30) {
			HStack {
				Label("Snooze", systemImage: "zzz")
				Spacer()
				Text("\(snoozeMinutes) min")
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
		}
		.glassCard()
	}
}


#Preview {
	AlarmEditorView(alarm: nil) { _ in }
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
