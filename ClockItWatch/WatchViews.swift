//
//  WatchViews.swift
//  ClockItWatch
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


// MARK: - Timers

struct WatchTimersView: View {
	@Environment(TimerStore.self) private var store

	var body: some View {
		NavigationStack {
			List {
				if !store.timers.isEmpty {
					Section {
						ForEach(store.timers) { timer in
							NavigationLink {
								WatchTimerDetail(timerID: timer.id)
							} label: {
								WatchTimerRow(timer: timer)
							}
						}
					}
				}

				Section("Start") {
					ForEach(store.quickStarts) { preset in
						Button {
							store.start(duration: preset.duration, label: preset.label, category: preset.kind, colorName: preset.colorName)
						} label: {
							HStack(spacing: 10) {
								Image(systemName: preset.kind.symbol)
									.foregroundStyle(ClockItPalette.color(named: preset.colorName))
									.frame(width: 22)
								VStack(alignment: .leading, spacing: 0) {
									Text(preset.duration.durationLabel)
										.font(.system(.body, design: .rounded).weight(.semibold))
									if !preset.label.isEmpty {
										Text(preset.label)
											.font(.caption2)
											.foregroundStyle(.secondary)
									}
								}
							}
						}
					}
				}
			}
			.navigationTitle("Timers")
		}
	}
}


struct WatchTimerRow: View {
	let timer: AppTimer

	var body: some View {
		let color = ClockItPalette.color(named: timer.colorName)

		TimelineView(.animation(minimumInterval: 1, paused: !timer.isRunning)) { context in
			let remaining = timer.remaining(at: context.date)
			let isDone = timer.isRunning && remaining <= 0

			HStack(spacing: 10) {
				WatchRing(fraction: 1 - timer.progress(at: context.date), color: color, symbol: timer.kind.symbol, lineWidth: 4)
					.frame(width: 34, height: 34)
				VStack(alignment: .leading, spacing: 0) {
					Text(isDone ? timer.kind.doneText : remaining.timerText)
						.font(.system(.title3, design: .rounded).weight(.medium))
						.monospacedDigit()
					Text(timer.isRunning ? timer.displayLabel : "\(timer.displayLabel) · Paused")
						.font(.caption2)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}
		}
	}
}


struct WatchTimerDetail: View {
	let timerID: UUID

	@Environment(TimerStore.self) private var store
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		if let timer = store.timers.first(where: { $0.id == timerID }) {
			let color = ClockItPalette.color(named: timer.colorName)

			TimelineView(.animation(minimumInterval: 1.0 / 4, paused: !timer.isRunning)) { context in
				let remaining = timer.remaining(at: context.date)
				let isDone = timer.isRunning && remaining <= 0

				VStack(spacing: 8) {
					ZStack {
						WatchRing(fraction: 1 - timer.progress(at: context.date), color: color, symbol: nil, lineWidth: 9)
						VStack(spacing: 0) {
							Text(isDone ? timer.kind.doneText : remaining.timerText)
								.font(.system(size: 30, weight: .light, design: .rounded))
								.monospacedDigit()
								.minimumScaleFactor(0.6)
							Label(timer.displayLabel, systemImage: timer.kind.symbol)
								.font(.caption2)
								.foregroundStyle(color)
								.lineLimit(1)
						}
						.padding(.horizontal, 14)
					}

					HStack {
						Button(role: .destructive) {
							store.cancel(id: timer.id)
							dismiss()
						} label: {
							Image(systemName: isDone ? "stop.fill" : "xmark")
						}

						if !isDone {
							Button {
								timer.isRunning ? store.pause(id: timer.id) : store.resume(id: timer.id)
							} label: {
								Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
							}
							.tint(color)
						}
					}
				}
			}
			.navigationTitle(timer.kind.title)
		} else {
			Text("Timer ended")
				.foregroundStyle(.secondary)
		}
	}
}


/// A progress ring sized for the wrist.
struct WatchRing: View {
	let fraction: Double
	let color: Color
	let symbol: String?
	let lineWidth: CGFloat

	var body: some View {
		ZStack {
			Circle()
				.stroke(color.opacity(0.25), lineWidth: lineWidth)
			Circle()
				.trim(from: 0, to: max(0.001, min(fraction, 1)))
				.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				.rotationEffect(.degrees(-90))
			if let symbol {
				Image(systemName: symbol)
					.font(.system(size: lineWidth * 3, weight: .semibold))
					.foregroundStyle(color)
			}
		}
	}
}


// MARK: - Stopwatch

/// The same stopwatch as your iPhone: start, stop or lap from either and the other follows.
struct WatchStopwatchView: View {
	@Environment(TimerStore.self) private var store

	private let startColor = ClockItPalette.color(named: "mint")
	private let stopColor = ClockItPalette.color(named: "rose")
	private let lapColor = ClockItPalette.color(named: "peach")

	var body: some View {
		let stopwatch = store.stopwatch
		let hasTime = stopwatch.isRunning || stopwatch.accumulated > 0

		NavigationStack {
			List {
				Section {
					VStack(spacing: 10) {
						TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !stopwatch.isRunning)) { context in
							VStack(spacing: 2) {
								Text(stopwatch.elapsed(at: context.date).stopwatchText)
									.font(.system(size: 34, weight: .light, design: .rounded))
									.monospacedDigit()
									.lineLimit(1)
									.minimumScaleFactor(0.6)
								if !stopwatch.laps.isEmpty {
									Text("Lap \(stopwatch.laps.count + 1)  \(stopwatch.currentLap(at: context.date).stopwatchText)")
										.font(.caption2.weight(.medium))
										.monospacedDigit()
										.foregroundStyle(lapColor)
								}
							}
						}

						HStack {
							Button {
								if stopwatch.isRunning { store.lap() } else { store.resetStopwatch() }
							} label: {
								Image(systemName: stopwatch.isRunning || !hasTime ? "flag.fill" : "arrow.counterclockwise")
							}
							.disabled(!hasTime)
							.accessibilityLabel(stopwatch.isRunning || !hasTime ? "Lap" : "Reset")

							Button {
								if stopwatch.isRunning { store.stopStopwatch() } else { store.startStopwatch() }
							} label: {
								Image(systemName: stopwatch.isRunning ? "stop.fill" : "play.fill")
							}
							.tint(stopwatch.isRunning ? stopColor : startColor)
							.accessibilityLabel(stopwatch.isRunning ? "Stop" : "Start")
						}
					}
					.listRowBackground(Color.clear)
				}

				if store.lastReset != nil {
					Button("Undo Reset", systemImage: "arrow.uturn.backward") {
						store.undoReset()
					}
					.task(id: store.lastReset?.id) {
						guard let id = store.lastReset?.id else { return }
						try? await Task.sleep(for: .seconds(6))
						store.dismissUndo(id)
					}
				}

				if !stopwatch.laps.isEmpty {
					let stats = LapStats(laps: stopwatch.laps)
					Section("Laps") {
						ForEach(Array(stopwatch.laps.enumerated().reversed()), id: \.offset) { index, lap in
							HStack {
								Text("Lap \(index + 1)")
									.font(.caption)
								Spacer()
								Text(lap.stopwatchText)
									.font(.system(.body, design: .rounded))
									.monospacedDigit()
									.foregroundStyle(lap == stats.best ? startColor : lap == stats.worst ? stopColor : .primary)
							}
						}
					}
				}
			}
			.navigationTitle("Stopwatch")
		}
		.sensoryFeedback(.impact(weight: .medium), trigger: stopwatch.isRunning)
		.sensoryFeedback(.selection, trigger: stopwatch.laps.count)
	}
}


// MARK: - Alarms

struct WatchAlarmsView: View {
	@Environment(ClockStore.self) private var store

	var body: some View {
		NavigationStack {
			List {
				if let next = store.nextAlarm {
					TimelineView(.everyMinute) { context in
						VStack(alignment: .leading, spacing: 2) {
							Text("Next alarm")
								.font(.caption2.weight(.semibold))
								.foregroundStyle(ClockItPalette.accent)
							Text("in \(next.date.countdownText(from: context.date))")
								.font(.system(.title3, design: .rounded).weight(.medium))
							Text(next.date.relativeDayAndTime)
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
					}
				}

				ForEach(store.alarms) { alarm in
					Toggle(isOn: Binding(
						get: { alarm.isEnabled },
						set: { store.setEnabled($0, for: alarm.id) }
					)) {
						VStack(alignment: .leading, spacing: 0) {
							Text(alarm.timeText)
								.font(.system(.title2, design: .rounded).weight(.light))
								.monospacedDigit()
							Text("\(alarm.displayLabel) · \(alarm.scheduleText)")
								.font(.caption2)
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}
					}
					.tint(ClockItPalette.accent)
				}
			}
			.overlay {
				if store.alarms.isEmpty {
					ContentUnavailableView("No Alarms", systemImage: "alarm", description: Text("Add alarms on your iPhone."))
				}
			}
			.navigationTitle("Alarms")
		}
	}
}


// MARK: - World Clock

struct WatchWorldClockView: View {
	@Environment(ClockStore.self) private var store

	var body: some View {
		NavigationStack {
			TimelineView(.everyMinute) { context in
				List {
					ForEach(store.cities) { city in
						let sky = SkyPalette.sky(atHour: city.localHour(at: context.date))
						let ink: Color = sky.prefersLightText ? .white : Color(red: 0.10, green: 0.13, blue: 0.27)

						VStack(alignment: .leading, spacing: 2) {
							HStack {
								Text(city.displayName)
									.font(.headline)
									.lineLimit(1)
								Spacer(minLength: 4)
								Text(city.hourOffsetText(at: context.date))
									.font(.caption2)
									.opacity(0.75)
							}
							Text(city.timeText(at: context.date))
								.font(.system(.title2, design: .rounded).weight(.light))
								.monospacedDigit()
							Text(city.relativeDayText(at: context.date))
								.font(.caption2)
								.opacity(0.75)
						}
						.foregroundStyle(ink)
						.listRowBackground(
							RoundedRectangle(cornerRadius: 14)
								.fill(LinearGradient(colors: [sky.top, sky.bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
						)
					}
				}
			}
			.navigationTitle("World Clock")
		}
	}
}


#Preview {
	WatchRootView()
		.environment(ClockStore.preview)
		.environment(TimerStore.preview)
}
