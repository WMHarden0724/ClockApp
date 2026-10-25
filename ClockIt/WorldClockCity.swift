//
//  WorldClockCity.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import Foundation

struct WorldClockCity: Identifiable, Codable, Hashable {
	let id: UUID
	var name: String
	var timeZoneIdentifier: String
	var nickname: String?
	var order: Int

	var timeZone: TimeZone {
		TimeZone(identifier: timeZoneIdentifier) ?? .current
	}

	var displayName: String {
		if let nickname, !nickname.isEmpty { return nickname }
		return name
	}

	func timeText(at date: Date) -> String {
		var style = Date.FormatStyle(date: .omitted, time: .shortened)
		style.timeZone = timeZone
		return date.formatted(style)
	}

	/// Fractional hour of the day in this city, 0..<24.
	func localHour(at date: Date) -> Double {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone
		let comps = calendar.dateComponents([.hour, .minute], from: date)
		return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
	}

	func isDaytime(at date: Date = Date()) -> Bool {
		// Rough approximation by clock hour. Can be improved with sunrise/sunset later.
		SkyPalette.isDaytime(hour: localHour(at: date))
	}

	/// Calendar-day difference between this city and the user's own time zone.
	func dayOffset(at date: Date) -> Int {
		var cityCalendar = Calendar(identifier: .gregorian)
		cityCalendar.timeZone = timeZone
		var localCalendar = Calendar(identifier: .gregorian)
		localCalendar.timeZone = .current
		var utc = Calendar(identifier: .gregorian)
		utc.timeZone = .gmt

		let cityDay = cityCalendar.dateComponents([.year, .month, .day], from: date)
		let localDay = localCalendar.dateComponents([.year, .month, .day], from: date)
		guard let city = utc.date(from: cityDay), let local = utc.date(from: localDay) else { return 0 }
		return utc.dateComponents([.day], from: local, to: city).day ?? 0
	}

	func relativeDayText(at date: Date) -> String {
		let diff = dayOffset(at: date)
		switch diff {
		case 1: return "Tomorrow"
		case -1: return "Yesterday"
		case 0: return "Today"
		default: return diff > 0 ? "+\(diff) days" : "\(diff) days"
		}
	}

	/// "+9h", "−3h 30m", or "Same time".
	func hourOffsetText(at date: Date) -> String {
		let seconds = timeZone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
		if seconds == 0 { return "Same time" }
		return LocalTime.offsetText(minutes: Double(seconds / 60))
	}

	static let sampleCities: [WorldClockCity] = [
		WorldClockCity(id: UUID(), name: "New York", timeZoneIdentifier: "America/New_York", nickname: nil, order: 0),
		WorldClockCity(id: UUID(), name: "London", timeZoneIdentifier: "Europe/London", nickname: nil, order: 1),
		WorldClockCity(id: UUID(), name: "Tokyo", timeZoneIdentifier: "Asia/Tokyo", nickname: nil, order: 2),
		WorldClockCity(id: UUID(), name: "Sydney", timeZoneIdentifier: "Australia/Sydney", nickname: "Family", order: 3),
		WorldClockCity(id: UUID(), name: "Los Angeles", timeZoneIdentifier: "America/Los_Angeles", nickname: nil, order: 4)
	]
}
