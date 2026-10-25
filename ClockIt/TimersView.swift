//
//  TimersView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


struct TimersView: View {
	/// Keyboard shortcuts only work while this is the selected tab.
	var isSelected = true

	@Environment(TimerStore.self) private var store

	@State private var category: TimerCategory = .general
	@State private var mode: ComposerMode = .single
	@State private var setBy: SetBy = .length
	@State private var hours = 0
	@State private var minutes = 5
	@State private var seconds = 0
	@State private var endsAt = TimersView.defaultEndTime()
	@State private var steps: [TimerStep] = SequenceTemplate.all[2].steps
	@State private var rounds = 1
	@State private var label = ""
	@State private var notes = ""
	@State private var childAge = 5
	@State private var colorName = ClockItPalette.defaultName
	@State private var sound: TimerSound = AppSettings.shared.timerSound(for: .general)
	@State private var focused: FocusTarget?
	@State private var showingHistory = false
	@State private var confirmingCancelAll = false

	private struct FocusTarget: Identifiable {
		let id: UUID
	}

	enum ComposerMode: String, CaseIterable {
		case single = "Timer"
		case sequence = "Sequence"
	}

	enum SetBy: String, CaseIterable {
		case length = "Length"
		case endsAt = "Ends At"
	}

	private var duration: TimeInterval {
		TimeInterval(hours * 3600 + minutes * 60 + seconds)
	}

	/// The sequence as it will run: every round, and no empty steps.
	private var expandedSteps: [TimerStep] {
		TimerStep.expand(steps.filter { $0.duration > 0 }, rounds: rounds)
	}

	/// What Start will run, worked out at the moment you press it.
	private func startDuration(at now: Date = Date()) -> TimeInterval {
		switch mode {
		case .sequence:
			return expandedSteps.reduce(0) { $0 + $1.duration }
		case .single:
			return setBy == .endsAt ? Self.interval(until: endsAt, from: now) : duration
		}
	}

	/// The timer the composer describes, for saving. Ends At timers aren't saved since the time of day matters.
	private var composedPreset: TimerPreset? {
		guard !(mode == .single && setBy == .endsAt), startDuration() > 0 else { return nil }
		return TimerPreset(
			duration: startDuration(),
			label: label,
			colorName: colorName,
			category: category,
			soundName: sound.rawValue,
			steps: mode == .sequence ? expandedSteps : nil
		)
	}

	/// Saved timers first, then recents: the ones ⌘1–9 start on the Mac.
	private var numberedPresets: [TimerPreset] {
		var seen = Set<String>()
		return (store.saved + store.quickStarts).filter { seen.insert($0.id).inserted }.prefix(9).map { $0 }
	}

	var body: some View {
		@Bindable var store = store

		NavigationStack {
			ScrollView {
				VStack(spacing: 16) {
					if store.timers.count > 1 {
						allTimersBar
					}

					ForEach(store.timers) { timer in
						TimerCard(
							timer: timer,
							onPause: { store.pause(id: timer.id) },
							onResume: { store.resume(id: timer.id) },
							onCancel: { store.cancel(id: timer.id) },
							onAddMinute: { store.addTime(60, to: timer.id) },
							onRepeat: { store.restart(id: timer.id) }
						)
						.contentShape(.rect(cornerRadius: Theme.cornerRadius))
						.onTapGesture { focused = FocusTarget(id: timer.id) }
						.transition(.scale(scale: 0.9).combined(with: .opacity))
					}

					categoryPicker
					composer

					if !store.saved.isEmpty {
						presetRow(title: "Saved", presets: store.saved, isSavedRow: true)
					}
					presetRow(title: "Quick Start", presets: store.quickStarts.filter { !store.isSaved($0) }, isSavedRow: false)
				}
				.padding(16)
				.animation(.smooth, value: store.timers.map(\.id))
				.animation(.smooth, value: category)
				.animation(.smooth, value: mode)
				.animation(.smooth, value: store.saved)
			}
			.dismissKeyboardOnScroll()
			.background(AuroraBackground())
			.navigationTitle("Timers")
			.localTimeSubtitle()
			.settingsButton(section: .timers)
			.toolbar {
				ToolbarItem(placement: .barLeading) {
					Button {
						showingHistory = true
					} label: {
						Image(systemName: "clock.arrow.circlepath")
					}
					.accessibilityLabel("History")
				}
			}
			.sheet(isPresented: $showingHistory) {
				TimerHistoryView()
			}
			.fullScreenOrSheet(item: $focused) { target in
				TimerFocusView(timerID: target.id)
			}
			.alert("Timer Not Started", isPresented: Binding(
				get: { store.errorMessage != nil },
				set: { if !$0 { store.errorMessage = nil } }
			)) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(store.errorMessage ?? "")
			}
			.onChange(of: category) { _, newValue in
				colorName = newValue.colorName
				sound = AppSettings.shared.timerSound(for: newValue)
				if newValue == .timeOut {
					mode = .single
					setBy = .length
					setDuration(TimeInterval(childAge * 60))
				}
			}
			.onChange(of: childAge) { _, age in
				setDuration(TimeInterval(age * 60))
			}
			.onChange(of: sound) { _, newValue in
				AppSettings.shared.setTimerSound(newValue, for: category)
			}
		}
	}

	// MARK: All timers

	private var allTimersBar: some View {
		GlassGroup(spacing: 8) {
			HStack(spacing: 8) {
				if store.hasRunningTimers {
					barButton("Pause All", systemImage: "pause.fill") { store.pauseAll() }
						.keyboardShortcut(isSelected ? KeyboardShortcut("p", modifiers: [.command, .shift]) : nil)
						.help("Pause All (⇧⌘P)")
				} else {
					barButton("Resume All", systemImage: "play.fill") { store.resumeAll() }
						.keyboardShortcut(isSelected ? KeyboardShortcut("p", modifiers: [.command, .shift]) : nil)
						.help("Resume All (⇧⌘P)")
				}

				Spacer()

				barButton("Cancel All", systemImage: "xmark") { confirmingCancelAll = true }
					.confirmationDialog("Cancel all \(store.timers.count) timers?", isPresented: $confirmingCancelAll) {
						Button("Cancel All Timers", role: .destructive) { store.cancelAll() }
					}
			}
		}
	}

	private func barButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Label(title, systemImage: systemImage)
				.font(.subheadline.weight(.semibold))
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
		}
		.buttonStyle(.plain)
		.softGlass(.regular.interactive(), in: .capsule)
	}

	// MARK: Category

	private var categoryPicker: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("What's it for?")
				.font(.headline)
				.padding(.leading, 4)

			ScrollView(.horizontal) {
				GlassGroup(spacing: 8) {
					HStack(spacing: 8) {
						ForEach(TimerCategory.allCases) { option in
							let isSelected = option == category
							let color = ClockItPalette.color(named: option.colorName)

							Button {
								category = option
							} label: {
								Label(option.title, systemImage: option.symbol)
									.font(.subheadline.weight(.semibold))
									.foregroundStyle(isSelected ? .white : .primary)
									.padding(.horizontal, 14)
									.padding(.vertical, 10)
							}
							.buttonStyle(.plain)
							.softGlass(isSelected ? .regular.tint(color).interactive() : .regular.interactive(), in: .capsule)
							.accessibilityAddTraits(isSelected ? .isSelected : [])
						}
					}
					.padding(.horizontal, 4)
				}
			}
			.scrollIndicators(.hidden)
			.sensoryFeedback(.selection, trigger: category)
		}
	}

	// MARK: Composer

	private var composer: some View {
		let color = ClockItPalette.color(named: colorName)

		return VStack(spacing: 16) {
			if category != .timeOut {
				Picker("Kind", selection: $mode.animation(.snappy)) {
					ForEach(ComposerMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}

			switch mode {
			case .single:
				singleTimer(tint: color)
			case .sequence:
				SequenceEditor(steps: $steps, rounds: $rounds, tint: color) { template in
					category = template.category
					if label.isEmpty { label = template.name }
				}
			}

			TextField("Label", text: $label, prompt: Text(category.labelPrompt))
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
				.softGlass(.regular, in: .capsule)

			TextField("Notes", text: $notes, prompt: Text(category.notesPrompt), axis: .vertical)
				.lineLimit(1...4)
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
				.softGlass(.regular, in: .rect(cornerRadius: 20))

			TimerSoundPicker(sound: $sound, tint: color)

			swatches

			HStack(spacing: 10) {
				startButton(tint: color)

				Button {
					if let preset = composedPreset { store.save(preset) }
				} label: {
					Image(systemName: composedPreset.map(store.isSaved) == true ? "bookmark.fill" : "bookmark")
						.font(.headline)
						.padding(.vertical, 6)
				}
				.glassButton()
				.disabled(composedPreset == nil)
				.accessibilityLabel("Save Timer")
				.help("Save this timer")
			}
		}
		.glassCard()
	}

	@ViewBuilder
	private func singleTimer(tint: Color) -> some View {
		if category != .timeOut {
			Picker("Set by", selection: $setBy.animation(.snappy)) {
				ForEach(SetBy.allCases, id: \.self) { Text($0.rawValue).tag($0) }
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.frame(maxWidth: 260)
		}

		if setBy == .endsAt && category != .timeOut {
			VStack(spacing: 8) {
				DatePicker("Ends at", selection: $endsAt, displayedComponents: .hourAndMinute)
					.font(.headline)
				TimelineView(.everyMinute) { context in
					Text("Rings in \(Self.interval(until: endsAt, from: context.date).durationLabel)")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			.padding(.vertical, 8)
		} else {
			if !category.suggestions.isEmpty {
				suggestions(tint: tint)
			}

			if category == .timeOut {
				timeOutAge(tint: tint)
			}

			if AppSettings.shared.timerStyle == .analog {
				AnalogTimerPicker(
					duration: Binding(get: { duration }, set: { setDuration($0) }),
					color: tint
				)
			} else {
				HStack(spacing: 0) {
					wheel("hr", selection: $hours, range: 0..<24)
					wheel("min", selection: $minutes, range: 0..<60)
					wheel("sec", selection: $seconds, range: 0..<60)
				}
				.frame(height: 150)
			}
		}
	}

	private func startButton(tint: Color) -> some View {
		let length = startDuration()
		let title: String = switch (mode, setBy) {
		case (.sequence, _): "Start \(length > 0 ? length.timerText : "")"
		case (.single, .endsAt) where category != .timeOut: "Start · Ends \(endsAt.timeText)"
		default: "Start \(length > 0 ? length.timerText : "")"
		}

		return Button {
			let steps = mode == .sequence ? expandedSteps : nil
			let length = startDuration()
			store.start(duration: length, label: label, notes: notes, category: category, colorName: colorName, soundName: sound.rawValue, steps: steps)
			label = ""
			notes = ""
		} label: {
			HStack(spacing: 8) {
				Label(title, systemImage: "play.fill")
				#if os(macOS)
				if isSelected {
					Text("↩")
						.font(.caption.weight(.semibold))
						.opacity(0.6)
				}
				#endif
			}
			.font(.headline)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 6)
		}
		.glassProminentButton()
		.tint(tint)
		.disabled(length == 0)
		.keyboardShortcut(isSelected ? .defaultAction : nil)
		.sensoryFeedback(.start, trigger: store.timers.count) { old, new in new > old }
	}

	private func suggestions(tint: Color) -> some View {
		ScrollView(.horizontal) {
			HStack(spacing: 8) {
				ForEach(category.suggestions) { suggestion in
					let isSelected = suggestion.label == label && suggestion.duration == duration

					Button {
						label = suggestion.label
						setDuration(suggestion.duration)
					} label: {
						VStack(alignment: .leading, spacing: 2) {
							Text(suggestion.label)
								.font(.subheadline.weight(.semibold))
							Text(suggestion.duration.durationLabel)
								.font(.caption)
								.foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
						}
						.foregroundStyle(isSelected ? .white : .primary)
						.padding(.horizontal, 14)
						.padding(.vertical, 10)
					}
					.buttonStyle(.plain)
					.softGlass(isSelected ? .regular.tint(tint).interactive() : .regular.interactive(), in: .rect(cornerRadius: 18))
				}
			}
			.padding(.vertical, 2)
		}
		.scrollIndicators(.hidden)
		.sensoryFeedback(.selection, trigger: label)
	}

	private func timeOutAge(tint: Color) -> some View {
		HStack(spacing: 12) {
			Image(systemName: "figure.child")
				.font(.title2)
				.foregroundStyle(tint)
				.frame(width: 44, height: 44)
				.softGlass(.regular.tint(tint.opacity(0.2)), in: .circle)

			VStack(alignment: .leading, spacing: 2) {
				Text("\(childAge) years old")
					.font(.headline)
					.contentTransition(.numericText())
				Text("1 minute per year of age")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer()

			Stepper("Age", value: $childAge.animation(.snappy), in: 2...12)
				.labelsHidden()
		}
	}

	private var swatches: some View {
		HStack {
			ForEach(ClockItPalette.named, id: \.name) { swatch in
				Button {
					colorName = swatch.name
				} label: {
					Circle()
						.fill(swatch.color.gradient)
						.frame(width: 28, height: 28)
						.overlay {
							if swatch.name == colorName {
								Circle().strokeBorder(.white, lineWidth: 3)
							}
						}
						.padding(4)
				}
				.buttonStyle(.plain)
				.accessibilityLabel(swatch.name.capitalized)
				.accessibilityAddTraits(swatch.name == colorName ? .isSelected : [])

				if swatch.name != ClockItPalette.named.last?.name { Spacer(minLength: 0) }
			}
		}
		.sensoryFeedback(.selection, trigger: colorName)
	}

	private func wheel(_ unit: String, selection: Binding<Int>, range: Range<Int>) -> some View {
		Picker(unit, selection: selection) {
			ForEach(range, id: \.self) { value in
				Text("\(value)").font(Theme.clockFont(22, weight: .regular)).tag(value)
			}
		}
		.wheelPickerStyleIfAvailable()
		.overlay(alignment: .trailing) {
			Text(unit)
				.font(.subheadline.weight(.medium))
				.foregroundStyle(.secondary)
				.padding(.trailing, 12)
				.allowsHitTesting(false)
		}
	}

	private func setDuration(_ duration: TimeInterval) {
		let total = Int(duration)
		hours = total / 3600
		minutes = (total / 60) % 60
		seconds = total % 60
	}

	/// Seconds from `now` until the next time the clock reads `time`'s hour and minute.
	private static func interval(until time: Date, from now: Date) -> TimeInterval {
		let calendar = Calendar.current
		let parts = calendar.dateComponents([.hour, .minute], from: time)
		guard let next = calendar.nextDate(after: now, matching: parts, matchingPolicy: .nextTime) else { return 0 }
		return next.timeIntervalSince(now).rounded()
	}

	/// An hour from now, on the next five minutes.
	private static func defaultEndTime() -> Date {
		let inAnHour = Date().addingTimeInterval(3600)
		let minute = Calendar.current.component(.minute, from: inAnHour)
		return Calendar.current.date(byAdding: .minute, value: (5 - minute % 5) % 5, to: inAnHour) ?? inAnHour
	}

	// MARK: Saved and quick start

	private func presetRow(title: String, presets: [TimerPreset], isSavedRow: Bool) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Label(title, systemImage: isSavedRow ? "bookmark.fill" : "bolt.fill")
				.font(.headline)
				.padding(.leading, 4)

			ScrollView(.horizontal) {
				GlassGroup(spacing: 8) {
					HStack(spacing: 8) {
						ForEach(presets) { preset in
							presetChip(preset)
								.contextMenu {
									if isSavedRow {
										Button("Remove from Saved", systemImage: "bookmark.slash", role: .destructive) {
											store.unsave(preset)
										}
									} else {
										Button("Save", systemImage: "bookmark") {
											store.save(preset)
										}
									}
								}
						}
					}
					.padding(.horizontal, 4)
				}
			}
			.scrollIndicators(.hidden)
		}
	}

	private func presetChip(_ preset: TimerPreset) -> some View {
		let number = numberedPresets.firstIndex { $0.id == preset.id }.map { $0 + 1 }
		let color = ClockItPalette.color(named: preset.colorName)

		return Button {
			store.start(preset)
		} label: {
			HStack(spacing: 10) {
				if preset.isSequence {
					Image(systemName: "list.bullet")
						.font(.body.weight(.semibold))
						.foregroundStyle(color)
				} else if preset.kind != .general {
					Image(systemName: preset.kind.symbol)
						.font(.body.weight(.semibold))
						.foregroundStyle(color)
				}
				VStack(alignment: .leading, spacing: 2) {
					Text(preset.duration.durationLabel)
						.font(.subheadline.weight(.semibold))
					if !preset.label.isEmpty {
						Text(preset.label)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				#if os(macOS)
				if let number, isSelected {
					Text("⌘\(number)")
						.font(.caption2.weight(.medium))
						.foregroundStyle(.secondary)
				}
				#endif
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
		}
		.buttonStyle(.plain)
		.softGlass(.regular.tint(color.opacity(0.25)).interactive(), in: .capsule)
		.keyboardShortcut(isSelected ? number.map { KeyboardShortcut(KeyEquivalent(Character("\($0)")), modifiers: .command) } : nil)
	}
}


#Preview {
	TimersView()
		.environment(TimerStore.preview)
}
