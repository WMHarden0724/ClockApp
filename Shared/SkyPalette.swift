//
//  SkyPalette.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


/// Soft sky colors for any hour of the day, blended between keyframes.
enum SkyPalette {
	struct Sky {
		let top: Color
		let bottom: Color
		let prefersLightText: Bool
	}

	private struct Stop {
		let hour: Double
		let top: Color
		let bottom: Color
	}

	private static let night = (top: Color(red: 0.01, green: 0.01, blue: 0.03), bottom: Color(red: 0.05, green: 0.05, blue: 0.10))

	private static let stops: [Stop] = [
		Stop(hour: 0, top: night.top, bottom: night.bottom),
		Stop(hour: 5, top: night.top, bottom: night.bottom),
		Stop(hour: 6.5, top: Color(red: 0.62, green: 0.58, blue: 0.88), bottom: Color(red: 1.00, green: 0.74, blue: 0.68)),
		Stop(hour: 8.5, top: Color(red: 0.56, green: 0.76, blue: 0.98), bottom: Color(red: 0.86, green: 0.91, blue: 1.00)),
		Stop(hour: 12, top: Color(red: 0.47, green: 0.73, blue: 0.98), bottom: Color(red: 0.78, green: 0.90, blue: 1.00)),
		Stop(hour: 16.5, top: Color(red: 0.52, green: 0.72, blue: 0.96), bottom: Color(red: 0.88, green: 0.88, blue: 0.98)),
		Stop(hour: 18.5, top: Color(red: 0.56, green: 0.46, blue: 0.82), bottom: Color(red: 1.00, green: 0.68, blue: 0.64)),
		Stop(hour: 20, top: Color(red: 0.12, green: 0.10, blue: 0.28), bottom: Color(red: 0.32, green: 0.21, blue: 0.42)),
		Stop(hour: 21.5, top: night.top, bottom: night.bottom),
		Stop(hour: 24, top: night.top, bottom: night.bottom)
	]

	/// `hour` is fractional local time, 0..<24.
	static func sky(atHour hour: Double) -> Sky {
		let h = min(max(hour, 0), 24)
		let upperIndex = stops.firstIndex { $0.hour > h } ?? stops.count - 1
		let lower = stops[max(upperIndex - 1, 0)]
		let upper = stops[upperIndex]
		let span = upper.hour - lower.hour
		let fraction = span > 0 ? (h - lower.hour) / span : 0
		return Sky(
			top: lower.top.blend(with: upper.top, by: fraction),
			bottom: lower.bottom.blend(with: upper.bottom, by: fraction),
			prefersLightText: h < 6 || h >= 19
		)
	}

	/// Colors around a full day, for angular gradients that start at midnight.
	static let dayRing: [Color] = stride(from: 0.0, through: 24.0, by: 1.0).map { hour in
		let sky = sky(atHour: hour)
		return sky.top.blend(with: sky.bottom, by: 0.5)
	}

	static func isDaytime(hour: Double) -> Bool {
		hour >= 6.5 && hour < 18.5
	}
}
