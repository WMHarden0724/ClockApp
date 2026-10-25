//
//  TimerComposerParts.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import AVFoundation
import SwiftUI


// MARK: - Sequences

/// Builds a sequence: named steps, repeated for a number of rounds, or one of the ready-made ones.
struct SequenceEditor: View {
	@Binding var steps: [TimerStep]
	@Binding var rounds: Int
	let tint: Color
	var onTemplate: (SequenceTemplate) -> Void = { _ in }

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			ScrollView(.horizontal) {
				HStack(spacing: 8) {
					ForEach(SequenceTemplate.all) { template in
						Button {
							steps = template.steps.map { TimerStep(label: $0.label, duration: $0.duration) }
							rounds = template.rounds
							onTemplate(template)
						} label: {
							Label(template.name, systemImage: template.symbol)
								.font(.subheadline.weight(.semibold))
								.padding(.horizontal, 14)
								.padding(.vertical, 10)
						}
						.buttonStyle(.plain)
						.softGlass(.regular.interactive(), in: .capsule)
					}
				}
				.padding(.vertical, 2)
			}
			.scrollIndicators(.hidden)

			VStack(spacing: 8) {
				ForEach($steps) { $step in
					HStack(spacing: 8) {
						Text("\((steps.firstIndex { $0.id == step.id } ?? 0) + 1)")
							.font(.caption.weight(.bold))
							.foregroundStyle(.white)
							.frame(width: 22, height: 22)
							.background(tint, in: .circle)

						TextField("Step", text: $step.label, prompt: Text("Step name"))
							.textFieldStyle(.plain)

						StepDurationPicker(duration: $step.duration)

						if steps.count > 1 {
							Button {
								withAnimation(.snappy) { steps.removeAll { $0.id == step.id } }
							} label: {
								Image(systemName: "minus.circle.fill")
									.foregroundStyle(.secondary)
							}
							.buttonStyle(.plain)
							.accessibilityLabel("Remove step")
						}
					}
					.padding(.horizontal, 14)
					.padding(.vertical, 8)
					.softGlass(.regular, in: .capsule)
				}
			}

			HStack {
				Button {
					withAnimation(.snappy) { steps.append(TimerStep(label: "", duration: 60)) }
				} label: {
					Label("Add Step", systemImage: "plus")
						.font(.subheadline.weight(.semibold))
				}
				.glassButton()

				Spacer()

				Stepper(value: $rounds.animation(.snappy), in: 1...30) {
					Text(rounds == 1 ? "Once" : "\(rounds) rounds")
						.font(.subheadline.weight(.medium))
						.monospacedDigit()
						.contentTransition(.numericText())
				}
				.fixedSize()
			}

			let total = steps.reduce(0) { $0 + $1.duration } * Double(rounds)
			Text("\(steps.count * rounds) steps · \(total.durationLabel) in all")
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
	}
}


/// Minutes and seconds for one step, as two compact menus.
struct StepDurationPicker: View {
	@Binding var duration: TimeInterval

	var body: some View {
		let total = Int(duration)
		let minutes = Binding(
			get: { total / 60 },
			set: { duration = TimeInterval($0 * 60 + total % 60) }
		)
		let seconds = Binding(
			get: { total % 60 / 5 * 5 },
			set: { duration = TimeInterval(total / 60 * 60 + $0) }
		)

		HStack(spacing: 0) {
			Picker("Minutes", selection: minutes) {
				ForEach(0..<181, id: \.self) { Text("\($0) min").tag($0) }
			}
			Picker("Seconds", selection: seconds) {
				ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) sec").tag($0) }
			}
		}
		.pickerStyle(.menu)
		.labelsHidden()
		.fixedSize()
	}
}


struct SequenceTemplate: Identifiable {
	let name: String
	let symbol: String
	let category: TimerCategory
	let steps: [TimerStep]
	let rounds: Int

	var id: String { name }

	static let all: [SequenceTemplate] = [
		SequenceTemplate(name: "Pomodoro", symbol: "brain.head.profile", category: .focus,
						 steps: [.init(label: "Focus", duration: 25 * 60), .init(label: "Break", duration: 5 * 60)], rounds: 4),
		SequenceTemplate(name: "Tabata", symbol: "flame.fill", category: .workout,
						 steps: [.init(label: "Work", duration: 20), .init(label: "Rest", duration: 10)], rounds: 8),
		SequenceTemplate(name: "Intervals", symbol: "figure.run", category: .workout,
						 steps: [.init(label: "Work", duration: 40), .init(label: "Rest", duration: 20)], rounds: 6),
		SequenceTemplate(name: "Steak", symbol: "fork.knife", category: .food,
						 steps: [.init(label: "Sear", duration: 180), .init(label: "Flip", duration: 180), .init(label: "Rest", duration: 300)], rounds: 1),
		SequenceTemplate(name: "Laundry", symbol: "washer.fill", category: .laundry,
						 steps: [.init(label: "Wash", duration: 50 * 60), .init(label: "Dry", duration: 60 * 60)], rounds: 1)
	]
}


// MARK: - Sound

/// Pick the sound a timer rings with; each choice plays as you pick it.
struct TimerSoundPicker: View {
	@Binding var sound: TimerSound
	let tint: Color

	var body: some View {
		HStack {
			Label("Sound", systemImage: "speaker.wave.2.fill")
				.font(.subheadline.weight(.medium))
			Spacer()
			Menu {
				ForEach(TimerSound.allCases) { option in
					Button {
						sound = option
						SoundPreview.play(option)
					} label: {
						if option == sound {
							Label(option.title, systemImage: "checkmark")
						} else {
							Text(option.title)
						}
					}
				}
			} label: {
				HStack(spacing: 4) {
					Text(sound.title)
					Image(systemName: "chevron.up.chevron.down")
						.font(.caption2.weight(.semibold))
				}
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(tint)
			}
			.menuStyle(.button)
			.buttonStyle(.plain)
			.fixedSize()

			Button {
				SoundPreview.play(sound)
			} label: {
				Image(systemName: "play.circle.fill")
					.font(.title3)
					.foregroundStyle(tint)
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Play \(sound.title)")
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.softGlass(.regular, in: .capsule)
	}
}


/// Plays a timer sound once, for choosing between them.
enum SoundPreview {
	private static var player: AVAudioPlayer?

	static func play(_ sound: TimerSound) {
		guard let fileName = sound.fileName,
			  let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
			playSystemAlert()
			return
		}
		#if os(iOS) || os(visionOS)
		try? AVAudioSession.sharedInstance().setCategory(.ambient)
		#endif
		player = try? AVAudioPlayer(contentsOf: url)
		player?.play()
	}

	private static func playSystemAlert() {
		#if os(macOS)
		NSSound.beep()
		#elseif os(iOS)
		AudioServicesPlaySystemSound(1005)
		#endif
	}
}
