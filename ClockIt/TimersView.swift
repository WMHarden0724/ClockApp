//
//  TimersView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


struct TimersView: View {
	@Environment(TimerStore.self) private var store

	@State private var category: TimerCategory = .general
	@State private var hours = 0
	@State private var minutes = 5
	@State private var seconds = 0
	@State private var label = ""
	@State private var notes = ""
	@State private var childAge = 5
	@State private var colorName = ClockItPalette.defaultName
	@State private var focused: FocusTarget?

	private struct FocusTarget: Identifiable {
		let id: UUID
	}

	private var duration: TimeInterval {
		TimeInterval(hours * 3600 + minutes * 60 + seconds)
	}

	var body: some View {
		@Bindable var store = store

		NavigationStack {
			ScrollView {
				VStack(spacing: 16) {
					ForEach(store.timers) { timer in
						TimerCard(
							timer: timer,
							onPause: { store.pause(id: timer.id) },
							onResume: { store.resume(id: timer.id) },
							onCancel: { store.cancel(id: timer.id) }
						)
						.contentShape(.rect(cornerRadius: Theme.cornerRadius))
						.onTapGesture { focused = FocusTarget(id: timer.id) }
						.transition(.scale(scale: 0.9).combined(with: .opacity))
					}

					categoryPicker
					composer
					quickStart
				}
				.padding(16)
				.animation(.smooth, value: store.timers.map(\.id))
				.animation(.smooth, value: category)
			}
			.dismissKeyboardOnScroll()
			.background(AuroraBackground())
			.navigationTitle("Timers")
			.localTimeSubtitle()
			.settingsButton(section: .timers)
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
				if newValue == .timeOut {
					setDuration(TimeInterval(childAge * 60))
				}
			}
			.onChange(of: childAge) { _, age in
				setDuration(TimeInterval(age * 60))
			}
		}
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
			if !category.suggestions.isEmpty {
				suggestions(tint: color)
			}

			if category == .timeOut {
				timeOutAge(tint: color)
			}

			if AppSettings.shared.timerStyle == .analog {
				AnalogTimerPicker(
					duration: Binding(get: { duration }, set: { setDuration($0) }),
					color: color
				)
			} else {
				HStack(spacing: 0) {
					wheel("hr", selection: $hours, range: 0..<24)
					wheel("min", selection: $minutes, range: 0..<60)
					wheel("sec", selection: $seconds, range: 0..<60)
				}
				.frame(height: 150)
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

			swatches

			Button {
				store.start(duration: duration, label: label, notes: notes, category: category, colorName: colorName)
				label = ""
				notes = ""
			} label: {
				Label("Start \(duration > 0 ? duration.timerText : "")", systemImage: "play.fill")
					.font(.headline)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 6)
			}
			.glassProminentButton()
			.tint(color)
			.disabled(duration == 0)
			.sensoryFeedback(.start, trigger: store.timers.count) { old, new in new > old }
		}
		.glassCard()
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

	// MARK: Quick start

	private var quickStart: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Quick Start")
				.font(.headline)
				.padding(.leading, 4)

			ScrollView(.horizontal) {
				GlassGroup(spacing: 8) {
					HStack(spacing: 8) {
						ForEach(store.quickStarts) { preset in
							Button {
								store.start(duration: preset.duration, label: preset.label, category: preset.kind, colorName: preset.colorName)
							} label: {
								HStack(spacing: 10) {
									if preset.kind != .general {
										Image(systemName: preset.kind.symbol)
											.font(.body.weight(.semibold))
											.foregroundStyle(ClockItPalette.color(named: preset.colorName))
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
								}
								.padding(.horizontal, 16)
								.padding(.vertical, 12)
							}
							.buttonStyle(.plain)
							.softGlass(.regular.tint(ClockItPalette.color(named: preset.colorName).opacity(0.25)).interactive(), in: .capsule)
						}
					}
					.padding(.horizontal, 4)
				}
			}
			.scrollIndicators(.hidden)
		}
	}
}


#Preview {
	TimersView()
		.environment(TimerStore.preview)
}
