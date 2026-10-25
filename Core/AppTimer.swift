//
//  AppTimer.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import Foundation

struct AppTimer: Identifiable, Codable, Equatable {
	let id: UUID
	var label: String
	var duration: TimeInterval
	var remaining: TimeInterval // time left while paused
	var endDate: Date? // set while running
	var colorName: String // "lilac", "peach", etc. See ClockItPalette.
	var soundName: String
	var createdAt: Date
	var category: TimerCategory? // nil for timers saved before categories existed
	var notes: String?
	var originDevice: String? // SyncHub.deviceID of the device that started it

	var isRunning: Bool { endDate != nil }

	var kind: TimerCategory { category ?? .general }

	var displayLabel: String {
		if label.isEmpty { return kind.title }
		return kind == .timeOut ? "Time-out · \(label)" : label
	}

	func remaining(at date: Date) -> TimeInterval {
		guard let endDate else { return remaining }
		return max(0, endDate.timeIntervalSince(date))
	}

	/// Fraction elapsed, 0...1.
	func progress(at date: Date) -> Double {
		guard duration > 0 else { return 0 }
		return 1.0 - (remaining(at: date) / duration)
	}

	static let sample = AppTimer(
		id: UUID(),
		label: "Pasta",
		duration: 600,
		remaining: 420,
		endDate: Date().addingTimeInterval(420),
		colorName: "peach",
		soundName: "default",
		createdAt: Date(),
		category: .food,
		notes: "Stir at 5 minutes, save a cup of pasta water"
	)
}


/// A recently used timer, offered again as a one-tap quick start.
struct TimerPreset: Codable, Hashable, Identifiable {
	var duration: TimeInterval
	var label: String
	var colorName: String
	var category: TimerCategory?

	var kind: TimerCategory { category ?? .general }

	var id: String { "\(duration)|\(label)|\(colorName)|\(kind.rawValue)" }

	static let defaults: [TimerPreset] = [1, 3, 5, 10, 15, 30].map {
		TimerPreset(duration: TimeInterval($0 * 60), label: "", colorName: ClockItPalette.defaultName, category: nil)
	}
}


struct StopwatchState: Codable, Equatable {
	var startDate: Date? // set while running
	var accumulated: TimeInterval = 0 // time banked before the current run
	var laps: [TimeInterval] = [] // completed lap durations, oldest first

	var isRunning: Bool { startDate != nil }

	func elapsed(at date: Date) -> TimeInterval {
		accumulated + (startDate.map { date.timeIntervalSince($0) } ?? 0)
	}

	func currentLap(at date: Date) -> TimeInterval {
		elapsed(at: date) - laps.reduce(0, +)
	}

	/// Plain-text summary for sharing.
	func summary(at date: Date) -> String {
		var lines = ["Stopwatch · \(elapsed(at: date).stopwatchText)"]
		for (index, lap) in laps.enumerated() {
			lines.append("Lap \(index + 1)   \(lap.stopwatchText)")
		}
		return lines.joined(separator: "\n")
	}
}


/// A finished stopwatch run, saved to history on reset.
struct StopwatchSession: Codable, Identifiable {
	let id: UUID
	let date: Date
	let total: TimeInterval
	let laps: [TimeInterval]
}


/// A run cleared by Reset, held so the reset can be undone.
struct StopwatchReset: Equatable {
	let id: UUID
	let state: StopwatchState
	let sessionID: UUID
}


/// Best / worst / average over a set of laps. Best and worst need at least two laps to mean anything.
struct LapStats {
	let laps: [TimeInterval]

	var best: TimeInterval? { laps.count > 1 ? laps.min() : nil }
	var worst: TimeInterval? { laps.count > 1 ? laps.max() : nil }
	var average: TimeInterval? { laps.isEmpty ? nil : laps.reduce(0, +) / Double(laps.count) }

	/// 0 for the best lap, 1 for the worst.
	func slowness(of lap: TimeInterval) -> Double {
		guard let best, let worst, worst > best else { return 0 }
		return (lap - best) / (worst - best)
	}
}


extension TimeInterval {
	/// "4:05" or "1:02:03", rounding up so a timer never shows 0:00 while still running.
	var timerText: String {
		let total = Int(self.rounded(.up))
		let h = total / 3600, m = (total / 60) % 60, s = total % 60
		return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
	}

	/// "01:23.45" or "1:01:23.45".
	var stopwatchText: String {
		let centis = Int((self * 100).rounded(.down))
		let h = centis / 360_000, m = (centis / 6000) % 60, s = (centis / 100) % 60, c = centis % 100
		return h > 0 ? String(format: "%d:%02d:%02d.%02d", h, m, s, c) : String(format: "%02d:%02d.%02d", m, s, c)
	}

	/// ("01:23", ".45") so the hundredths can be styled separately.
	var stopwatchParts: (main: String, fraction: String) {
		let text = stopwatchText
		guard let dot = text.lastIndex(of: ".") else { return (text, "") }
		return (String(text[..<dot]), String(text[dot...]))
	}

	/// "+0.42" or "−1.10".
	var lapDeltaText: String {
		let sign = self < 0 ? "−" : "+"
		return sign + String(format: "%.2f", abs(self))
	}

	/// Compact axis label: "24s" or "1:05".
	var shortLapText: String {
		let total = Int(self.rounded())
		return total < 60 ? "\(total)s" : String(format: "%d:%02d", total / 60, total % 60)
	}

	/// "25 min", "1 hr 30 min", "45 sec".
	var durationLabel: String {
		Duration.seconds(self).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
	}
}
