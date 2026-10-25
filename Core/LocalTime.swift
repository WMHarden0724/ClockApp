//
//  LocalTime.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation


enum LocalTime {
	/// "Local · 9:41 PM", plus the shift when the user has scrubbed away from now.
	static func label(for date: Date, offsetMinutes: Double = 0) -> String {
		let time = date.timeText
		guard offsetMinutes != 0 else { return "Local · \(time)" }
		return "Local · \(time) (\(offsetText(minutes: offsetMinutes)))"
	}

	/// The user's chosen city while they're in its time zone; otherwise the city their time zone
	/// is named for, e.g. "New York" for America/New_York.
	static var currentCity: String {
		let settings = AppSettings.shared
		if let name = settings.homeCityName,
		   let zone = settings.homeCityTimeZone.flatMap(TimeZone.init(identifier:)),
		   zone.sharesClock(with: .current) {
			return name
		}
		let identifier = TimeZone.current.identifier
		let parts = identifier.split(separator: "/")
		guard parts.count >= 2, let last = parts.last else {
			return TimeZone.current.localizedName(for: .generic, locale: .current) ?? identifier
		}
		return String(last).replacing("_", with: " ")
	}

	static func offsetText(minutes: Double) -> String {
		let total = Int(minutes)
		let sign = total >= 0 ? "+" : "−"
		let hours = abs(total) / 60
		let mins = abs(total) % 60
		if hours == 0 { return "\(sign)\(mins)m" }
		return mins == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h \(mins)m"
	}
}


extension TimeZone {
	/// True when both zones show the same time now and in six months, so aliases and DST rules line up.
	func sharesClock(with other: TimeZone, at date: Date = Date()) -> Bool {
		if identifier == other.identifier { return true }
		let later = date.addingTimeInterval(182 * 86_400)
		return secondsFromGMT(for: date) == other.secondsFromGMT(for: date)
			&& secondsFromGMT(for: later) == other.secondsFromGMT(for: later)
	}
}
