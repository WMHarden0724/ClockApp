//
//  TimerCard.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// A running timer, drawn in the user's chosen style (Settings › Timer Style).
struct TimerCard: View {
	let timer: AppTimer
	let onPause: () -> Void
	let onResume: () -> Void
	let onCancel: () -> Void
	var onAddMinute: () -> Void = {}
	var onRepeat: () -> Void = {}

	var body: some View {
		let color = ClockItPalette.color(named: timer.colorName)
		let style = AppSettings.shared.timerStyle

		TimelineView(.animation(minimumInterval: style.isAnimated ? 1.0 / 30 : 1.0 / 10, paused: !timer.isRunning)) { context in
			let totalRemaining = timer.remaining(at: context.date)
			let isDone = timer.isRunning && totalRemaining <= 0
			// A sequence shows its current step; the whole run is in the subtitle.
			let step = isDone ? nil : timer.stepStatus(at: context.date)
			let remaining = step?.remaining ?? totalRemaining
			let elapsed = step?.progress ?? timer.progress(at: context.date)

			HStack(alignment: .top, spacing: 16) {
				visual(style: style, remaining: remaining, elapsed: elapsed, isDone: isDone, color: color, phase: context.date.timeIntervalSinceReferenceDate)

				VStack(alignment: .leading, spacing: 2) {
					Text(isDone ? timer.kind.doneText : remaining.timerText)
						.font(Theme.clockFont(38))
						.monospacedDigit()
						.contentTransition(.numericText(countsDown: true))

					if let step {
						Text("\(step.step.label.isEmpty ? "Step \(step.index + 1)" : step.step.label) · \(step.index + 1) of \(step.count)")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(color)
							.contentTransition(.opacity)
					}

					Group {
						if isDone {
							Text(timer.displayLabel)
						} else if let end = timer.endDate {
							Text("\(timer.displayLabel) · Ends \(end.timeText)")
						} else {
							Text("\(timer.displayLabel) · Paused")
						}
					}
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.lineLimit(2)

					if let next = step?.next {
						Text("Next: \(next.label.isEmpty ? "Step" : next.label) \(next.duration.timerText)")
							.font(.footnote)
							.foregroundStyle(.secondary)
					}

					if let notes = timer.notes, !notes.isEmpty {
						Label(notes, systemImage: "note.text")
							.font(.footnote)
							.foregroundStyle(.secondary)
							.lineLimit(3)
							.padding(.top, 6)
					}

					extraButtons(isDone: isDone, color: color)
						.padding(.top, 10)
				}

				Spacer(minLength: 0)

				controls(isDone: isDone, color: color)
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background {
				if style == .liquid {
					LiquidFill(level: isDone ? 0 : 1 - elapsed, color: color, phase: context.date.timeIntervalSinceReferenceDate * 1.5)
						.clipShape(.rect(cornerRadius: Theme.cornerRadius))
				}
			}
			.softGlass(.regular.tint(color.opacity(0.12)), in: .rect(cornerRadius: Theme.cornerRadius))
		}
		.sensoryFeedback(.impact(weight: .light), trigger: timer.isRunning)
	}

	@ViewBuilder
	private func visual(style: TimerStyle, remaining: TimeInterval, elapsed: Double, isDone: Bool, color: Color, phase: Double) -> some View {
		if style == .liquid {
			// The whole card is the liquid, so just show the category here.
			Image(systemName: isDone ? "bell.and.waves.left.and.right.fill" : timer.kind.symbol)
				.font(.system(size: 20, weight: .semibold))
				.foregroundStyle(color)
				.symbolEffect(.wiggle, options: .repeat(.continuous), isActive: isDone)
				.frame(width: 52, height: 52)
				.softGlass(.regular, in: .circle)
		} else {
			let size = TimerGraphic.cardSize(for: style)
			TimerGraphic(
				style: style,
				remaining: remaining,
				elapsed: elapsed,
				color: color,
				symbol: timer.kind.symbol,
				isRunning: timer.isRunning,
				isDone: isDone,
				phase: phase
			)
			.frame(width: size.width, height: size.height)
		}
	}

	/// +1 min always; Repeat once it's done.
	private func extraButtons(isDone: Bool, color: Color) -> some View {
		GlassGroup(spacing: 6) {
			HStack(spacing: 6) {
				capsuleButton("+1 min", systemImage: "plus", color: color, action: onAddMinute)
				if isDone {
					capsuleButton("Repeat", systemImage: "repeat", color: color, action: onRepeat)
				}
			}
		}
	}

	private func capsuleButton(_ title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Label(title, systemImage: systemImage)
				.font(.caption.weight(.semibold))
				.foregroundStyle(color)
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
		}
		.buttonStyle(.plain)
		.softGlass(.regular.interactive(), in: .capsule)
	}

	private func controls(isDone: Bool, color: Color) -> some View {
		GlassGroup(spacing: 8) {
			VStack(spacing: 8) {
				if !isDone {
					Button(action: timer.isRunning ? onPause : onResume) {
						Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
							.font(.body.weight(.bold))
							.foregroundStyle(.white)
							.frame(width: 44, height: 44)
					}
					.buttonStyle(.plain)
					.softGlass(.regular.tint(color).interactive(), in: .circle)
					.accessibilityLabel(timer.isRunning ? "Pause" : "Resume")
				}

				Button(action: onCancel) {
					Image(systemName: isDone ? "stop.fill" : "xmark")
						.font(.body.weight(.bold))
						.foregroundStyle(color)
						.frame(width: 44, height: 44)
				}
				.buttonStyle(.plain)
				.softGlass(.regular.interactive(), in: .circle)
				.accessibilityLabel(isDone ? "Stop" : "Cancel")
			}
		}
	}
}


#Preview {
	VStack(spacing: 16) {
		TimerCard(timer: .sample, onPause: {}, onResume: {}, onCancel: {})
	}
	.padding()
	.background(AuroraBackground())
}
