//
//  StopwatchView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


struct StopwatchView: View {
	@Environment(TimerStore.self) private var store
	@State private var showingHistory = false

	private let startColor = ClockItPalette.color(named: "mint")
	private let stopColor = ClockItPalette.color(named: "rose")

	var body: some View {
		let stopwatch = store.stopwatch
		let hasTime = stopwatch.isRunning || stopwatch.accumulated > 0

		NavigationStack {
			ScrollView {
				VStack(spacing: 20) {
					TimelineView(.animation(paused: !stopwatch.isRunning)) { context in
						StopwatchDial(
							elapsed: stopwatch.elapsed(at: context.date),
							currentLap: stopwatch.currentLap(at: context.date),
							laps: stopwatch.laps
						)
					}
					.frame(maxWidth: 360)
					.padding(.top, 8)

					controls

					if stopwatch.laps.count >= 2 {
						LapStatsRow(laps: stopwatch.laps)
						LapChart(laps: stopwatch.laps)
					}

					if !stopwatch.laps.isEmpty {
						TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !stopwatch.isRunning)) { context in
							LapList(laps: stopwatch.laps, currentLap: stopwatch.currentLap(at: context.date))
						}
					}
				}
				.padding(16)
				.animation(.smooth, value: stopwatch.laps.count)
			}
			.background(AuroraBackground())
			.navigationTitle("Stopwatch")
			.localTimeSubtitle()
			.settingsButton()
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						showingHistory = true
					} label: {
						Image(systemName: "clock.arrow.circlepath")
					}
					.accessibilityLabel("History")
				}
				if hasTime && !stopwatch.isRunning {
					ToolbarItem(placement: .topBarTrailing) {
						ShareLink(item: stopwatch.summary(at: Date()))
					}
				}
			}
			.sheet(isPresented: $showingHistory) {
				StopwatchHistoryView()
			}
		}
	}

	private var controls: some View {
		let stopwatch = store.stopwatch
		let hasTime = stopwatch.isRunning || stopwatch.accumulated > 0
		let lapCount: Int = stopwatch.laps.count

		return GlassEffectContainer(spacing: 40) {
			HStack {
				roundButton(
					title: stopwatch.isRunning || !hasTime ? "Lap" : "Reset",
					tint: nil,
					action: {
						if stopwatch.isRunning { store.lap() } else { store.resetStopwatch() }
					}
				)
				.disabled(!hasTime)
				.opacity(hasTime ? 1 : 0.5)

				Spacer()

				roundButton(
					title: stopwatch.isRunning ? "Stop" : "Start",
					tint: stopwatch.isRunning ? stopColor : startColor,
					action: {
						if stopwatch.isRunning { store.stopStopwatch() } else { store.startStopwatch() }
					}
				)
			}
			.padding(.horizontal, 24)
		}
		.sensoryFeedback(.impact(weight: .medium), trigger: stopwatch.isRunning)
		.sensoryFeedback(.selection, trigger: lapCount)
	}

	private func roundButton(title: String, tint: Color?, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Text(title)
				.font(.headline)
				.foregroundStyle(tint == nil ? Color.primary : .white)
				.frame(width: 84, height: 84)
				.contentTransition(.interpolate)
		}
		.buttonStyle(.plain)
		.glassEffect(tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(), in: .circle)
	}
}


#Preview {
	StopwatchView()
		.environment(TimerStore.preview)
}
