//
//  LapViews.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Charts
import SwiftUI


/// Mint for your fastest lap, rose for your slowest, blended in between.
enum LapColors {
	static let fast = ClockItPalette.color(named: "mint")
	static let slow = ClockItPalette.color(named: "rose")

	static func color(for lap: TimeInterval, in stats: LapStats) -> Color {
		guard stats.best != nil else { return Theme.accent }
		return fast.blend(with: slow, by: stats.slowness(of: lap))
	}
}


/// Best · Average · Worst chips.
struct LapStatsRow: View {
	let laps: [TimeInterval]

	var body: some View {
		let stats = LapStats(laps: laps)

		GlassGroup(spacing: 8) {
			HStack(spacing: 8) {
				chip("Best", value: stats.best, symbol: "hare.fill", tint: LapColors.fast)
				chip("Average", value: stats.average, symbol: "equal", tint: Theme.accent)
				chip("Worst", value: stats.worst, symbol: "tortoise.fill", tint: LapColors.slow)
			}
		}
	}

	private func chip(_ title: String, value: TimeInterval?, symbol: String, tint: Color) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Label(title, systemImage: symbol)
				.font(.caption.weight(.semibold))
				.foregroundStyle(tint)
			Text(value?.stopwatchText ?? "—")
				.font(Theme.clockFont(17, weight: .medium))
				.monospacedDigit()
				.lineLimit(1)
				.minimumScaleFactor(0.7)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(14)
		.softGlass(.regular.tint(tint.opacity(0.12)), in: .rect(cornerRadius: 20))
	}
}


/// One bar per lap, colored by pace, with a dashed line at the average.
struct LapChart: View {
	let laps: [TimeInterval]

	var body: some View {
		let stats = LapStats(laps: laps)

		VStack(alignment: .leading, spacing: 12) {
			Label("Lap Pace", systemImage: "chart.bar.fill")
				.font(.headline)

			Chart {
				ForEach(Array(laps.enumerated()), id: \.offset) { index, lap in
					BarMark(
						x: .value("Lap", index + 1),
						y: .value("Time", lap),
						width: .ratio(0.6)
					)
					.foregroundStyle(LapColors.color(for: lap, in: stats).gradient)
					.cornerRadius(6)
				}

				if let average = stats.average {
					RuleMark(y: .value("Average", average))
						.lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
						.foregroundStyle(.secondary)
						.annotation(position: .top, alignment: .trailing) {
							Text("avg \(average.shortLapText)")
								.font(.caption2.weight(.medium))
								.foregroundStyle(.secondary)
						}
				}
			}
			.chartXAxis {
				AxisMarks(values: .automatic(desiredCount: min(laps.count, 8))) { value in
					AxisValueLabel {
						if let lap = value.as(Int.self) { Text("\(lap)") }
					}
				}
			}
			.chartYAxis {
				AxisMarks(values: .automatic(desiredCount: 3)) { value in
					AxisGridLine().foregroundStyle(.primary.opacity(0.08))
					AxisValueLabel {
						if let seconds = value.as(Double.self) { Text(seconds.shortLapText) }
					}
				}
			}
			.frame(height: 150)
			.accessibilityLabel("Lap times chart")
		}
		.glassCard(padding: 16)
	}
}


/// Laps newest-first with a pace bar and the change from the previous lap.
/// Pass `currentLap` to show the lap in progress at the top.
struct LapList: View {
	let laps: [TimeInterval]
	var currentLap: TimeInterval?

	var body: some View {
		let stats = LapStats(laps: laps)
		let longest = max(laps.max() ?? 1, currentLap ?? 0)

		VStack(spacing: 0) {
			if let currentLap {
				row(number: laps.count + 1, time: currentLap, previous: laps.last, longest: longest, stats: stats, isCurrent: true)
				if !laps.isEmpty { Divider() }
			}

			ForEach(Array(laps.enumerated().reversed()), id: \.offset) { index, lap in
				row(number: index + 1, time: lap, previous: index > 0 ? laps[index - 1] : nil, longest: longest, stats: stats, isCurrent: false)
				if index > 0 { Divider() }
			}
		}
		.glassCard(padding: 16)
	}

	private func row(number: Int, time: TimeInterval, previous: TimeInterval?, longest: TimeInterval, stats: LapStats, isCurrent: Bool) -> some View {
		let isBest = !isCurrent && time == stats.best
		let isWorst = !isCurrent && time == stats.worst
		let color = isCurrent ? ClockItPalette.color(named: "peach") : LapColors.color(for: time, in: stats)

		return VStack(spacing: 8) {
			HStack(alignment: .firstTextBaseline) {
				Text("Lap \(number)")
					.font(.body.weight(isBest || isWorst ? .semibold : .regular))

				if isBest {
					badge("Best", color: LapColors.fast)
				} else if isWorst {
					badge("Worst", color: LapColors.slow)
				} else if isCurrent {
					badge("Now", color: color)
				}

				Spacer()

				if !isCurrent, let previous {
					let delta = time - previous
					Text(delta.lapDeltaText)
						.font(.caption.weight(.semibold))
						.monospacedDigit()
						.foregroundStyle(delta <= 0 ? LapColors.fast : LapColors.slow)
				}

				Text(time.stopwatchText)
					.font(Theme.clockFont(17, weight: .medium))
					.monospacedDigit()
					.frame(minWidth: 86, alignment: .trailing)
			}

			GeometryReader { geo in
				Capsule()
					.fill(color.gradient)
					.frame(width: max(4, geo.size.width * min(time / longest, 1)))
			}
			.frame(height: 4)
			.opacity(0.8)
		}
		.padding(.vertical, 10)
		.accessibilityElement(children: .combine)
	}

	private func badge(_ text: String, color: Color) -> some View {
		Text(text)
			.font(.caption2.weight(.bold))
			.textCase(.uppercase)
			.foregroundStyle(color)
			.padding(.horizontal, 6)
			.padding(.vertical, 2)
			.background(color.opacity(0.15), in: .capsule)
	}
}
