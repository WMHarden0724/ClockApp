//
//  StopwatchFocusView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// The stopwatch full screen, in digits big enough to read across a room. Tap the time to lap,
/// or to start when it's stopped.
struct StopwatchFocusView: View {
	@Environment(TimerStore.self) private var store
	@Environment(\.dismiss) private var dismiss

	private let lapColor = ClockItPalette.color(named: "peach")

	var body: some View {
		let stopwatch = store.stopwatch
		let tint = stopwatch.isRunning ? ClockItPalette.color(named: "mint") : lapColor

		VStack(spacing: 24) {
			HStack {
				Label("Stopwatch", systemImage: "stopwatch")
					.font(.headline)
					.foregroundStyle(tint)
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
				.keyboardShortcut(.cancelAction)
				.accessibilityLabel("Close")
			}

			Spacer(minLength: 0)

			TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !stopwatch.isRunning)) { context in
				readout(elapsed: stopwatch.elapsed(at: context.date), currentLap: stopwatch.currentLap(at: context.date), laps: stopwatch.laps)
			}
			.contentShape(Rectangle())
			.onTapGesture {
				if stopwatch.isRunning { store.lap() } else { store.startStopwatch() }
			}
			.accessibilityAddTraits(.isButton)
			.accessibilityHint(stopwatch.isRunning ? "Records a lap" : "Starts the stopwatch")

			Spacer(minLength: 0)

			StopwatchControls()
		}
		.padding(24)
		#if os(macOS)
		.frame(minWidth: 720, minHeight: 560)
		#endif
		.background {
			ZStack {
				AuroraBackground()
				LinearGradient(colors: [tint.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
					.ignoresSafeArea()
			}
			.animation(.smooth, value: stopwatch.isRunning)
		}
		.overlay(alignment: .bottom) {
			UndoResetToast()
				.padding(.bottom, 130)
		}
	}

	private func readout(elapsed: TimeInterval, currentLap: TimeInterval, laps: [TimeInterval]) -> some View {
		let parts = elapsed.stopwatchParts

		return VStack(spacing: 16) {
			HStack(alignment: .firstTextBaseline, spacing: 0) {
				Text(parts.main)
					.font(Theme.clockFont(160, weight: .thin))
				Text(parts.fraction)
					.font(Theme.clockFont(80, weight: .thin))
					.foregroundStyle(.secondary)
			}
			.monospacedDigit()
			.lineLimit(1)
			.minimumScaleFactor(0.3)

			if !laps.isEmpty {
				HStack(spacing: 20) {
					Text("Lap \(laps.count + 1)  \(currentLap.stopwatchText)")
						.foregroundStyle(lapColor)

					if let last = laps.last {
						let delta = laps.count > 1 ? last - laps[laps.count - 2] : nil
						HStack(spacing: 6) {
							Text("Last \(last.stopwatchText)")
								.foregroundStyle(.secondary)
							if let delta {
								Text(delta.lapDeltaText)
									.foregroundStyle(delta <= 0 ? LapColors.fast : LapColors.slow)
							}
						}
					}
				}
				.font(Theme.clockFont(28, weight: .regular))
				.monospacedDigit()
				.lineLimit(1)
				.minimumScaleFactor(0.5)
			}
		}
		.accessibilityElement(children: .combine)
	}
}


#Preview {
	StopwatchFocusView()
		.environment(TimerStore.preview)
}
