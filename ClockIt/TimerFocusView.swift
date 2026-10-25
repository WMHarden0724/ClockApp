//
//  TimerFocusView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// A single timer, full screen, drawn large in the chosen style. Tap the graphic to pause or resume.
struct TimerFocusView: View {
	let timerID: UUID

	@Environment(TimerStore.self) private var store
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		if let timer = store.timers.first(where: { $0.id == timerID }) {
			content(for: timer)
		} else {
			// Cancelled or finished elsewhere (Live Activity, alert).
			Color.clear.onAppear { dismiss() }
		}
	}

	private func content(for timer: AppTimer) -> some View {
		let color = ClockItPalette.color(named: timer.colorName)
		let style = AppSettings.shared.timerStyle

		return TimelineView(.animation(minimumInterval: style.isAnimated ? 1.0 / 30 : 1.0 / 10, paused: !timer.isRunning)) { context in
			let totalRemaining = timer.remaining(at: context.date)
			let isDone = timer.isRunning && totalRemaining <= 0
			let step = isDone ? nil : timer.stepStatus(at: context.date)
			let remaining = step?.remaining ?? totalRemaining
			let elapsed = step?.progress ?? timer.progress(at: context.date)

			VStack(spacing: 24) {
				HStack {
					Label(timer.displayLabel, systemImage: timer.kind.symbol)
						.font(.headline)
						.foregroundStyle(color)
					Spacer()
					Button {
						dismiss()
					} label: {
						Image(systemName: "chevron.down")
							.font(.body.weight(.semibold))
							.frame(width: 44, height: 44)
					}
					.buttonStyle(.plain)
					.softGlass(.regular.interactive(), in: .circle)
					.accessibilityLabel("Close")
				}

				Spacer(minLength: 0)

				graphic(style: style, timer: timer, remaining: remaining, elapsed: elapsed, isDone: isDone, color: color, phase: context.date.timeIntervalSinceReferenceDate)
					.contentShape(Rectangle())
					.onTapGesture {
						guard !isDone else { return }
						timer.isRunning ? store.pause(id: timer.id) : store.resume(id: timer.id)
					}
					.accessibilityAddTraits(.isButton)
					.accessibilityLabel(timer.isRunning ? "Pause" : "Resume")

				VStack(spacing: 6) {
					if let step {
						Text(step.step.label.isEmpty ? "Step \(step.index + 1) of \(step.count)" : "\(step.step.label) · \(step.index + 1) of \(step.count)")
							.font(.title2.weight(.semibold))
							.foregroundStyle(color)
							.contentTransition(.opacity)
					}

					Text(isDone ? timer.kind.doneText : remaining.timerText)
						.font(Theme.clockFont(80, weight: .thin))
						.monospacedDigit()
						.lineLimit(1)
						.minimumScaleFactor(0.5)
						.contentTransition(.numericText(countsDown: true))

					Group {
						if isDone {
							Text("Finished")
						} else if let next = step?.next {
							Text("Next: \(next.label.isEmpty ? "Step" : next.label) \(next.duration.timerText) · \(totalRemaining.timerText) left")
						} else if let end = timer.endDate {
							Text("Ends \(end.timeText)")
						} else {
							Text("Paused")
						}
					}
					.font(.title3)
					.foregroundStyle(.secondary)

					if let notes = timer.notes, !notes.isEmpty {
						Label(notes, systemImage: "note.text")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
							.padding(.top, 8)
					}
				}

				Spacer(minLength: 0)

				GlassGroup(spacing: 8) {
					HStack(spacing: 8) {
						pillButton("+1 min", systemImage: "plus", color: color) {
							store.addTime(60, to: timer.id)
						}
						if isDone {
							pillButton("Repeat", systemImage: "repeat", color: color) {
								store.restart(id: timer.id)
								dismiss()
							}
						}
					}
				}

				controls(timer: timer, isDone: isDone, color: color)
			}
			.padding(24)
		}
		.background {
			ZStack {
				AuroraBackground()
				LinearGradient(colors: [color.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
					.ignoresSafeArea()
			}
		}
		.sensoryFeedback(.impact(weight: .medium), trigger: timer.isRunning)
	}

	private func graphic(style: TimerStyle, timer: AppTimer, remaining: TimeInterval, elapsed: Double, isDone: Bool, color: Color, phase: Double) -> some View {
		let card = TimerGraphic.cardSize(for: style)
		let scale = min(280 / card.width, 300 / card.height)

		return TimerGraphic(
			style: style,
			remaining: remaining,
			elapsed: elapsed,
			color: color,
			symbol: timer.kind.symbol,
			isRunning: timer.isRunning,
			isDone: isDone,
			phase: phase,
			large: true
		)
		.frame(width: card.width * scale, height: card.height * scale)
	}

	private func pillButton(_ title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Label(title, systemImage: systemImage)
				.font(.headline)
				.foregroundStyle(color)
				.padding(.horizontal, 18)
				.padding(.vertical, 12)
		}
		.buttonStyle(.plain)
		.softGlass(.regular.interactive(), in: .capsule)
	}

	private func controls(timer: AppTimer, isDone: Bool, color: Color) -> some View {
		GlassGroup(spacing: 40) {
			HStack {
				Button {
					store.cancel(id: timer.id)
					dismiss()
				} label: {
					Text(isDone ? "Stop" : "Cancel")
						.font(.headline)
						.foregroundStyle(color)
						.frame(width: 84, height: 84)
				}
				.buttonStyle(.plain)
				.softGlass(.regular.interactive(), in: .circle)

				Spacer()

				if !isDone {
					Button {
						timer.isRunning ? store.pause(id: timer.id) : store.resume(id: timer.id)
					} label: {
						Text(timer.isRunning ? "Pause" : "Resume")
							.font(.headline)
							.foregroundStyle(.white)
							.frame(width: 84, height: 84)
							.contentTransition(.interpolate)
					}
					.buttonStyle(.plain)
					.softGlass(.regular.tint(color).interactive(), in: .circle)
				}
			}
			.padding(.horizontal, 16)
		}
	}
}
