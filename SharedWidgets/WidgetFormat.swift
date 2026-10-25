//
//  WidgetFormat.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
import WidgetKit


// Compiled into the iPhone widget extension and the Watch complications extension.


nonisolated enum WidgetFormat {
	/// "9:41 PM" or "21:41".
	static func time(_ date: Date, uses24Hour: Bool?, in timeZone: TimeZone = .autoupdatingCurrent) -> String {
		ClockFormat.time(date, uses24Hour: uses24Hour, timeZone: timeZone)
	}

	/// "9:41" with no AM/PM, for the smallest spots.
	static func compactTime(_ date: Date, uses24Hour: Bool?, in timeZone: TimeZone = .autoupdatingCurrent) -> String {
		let style = Date.FormatStyle(locale: ClockFormat.locale(uses24Hour: uses24Hour), timeZone: timeZone)
			.hour(.defaultDigits(amPM: .omitted))
			.minute()
		return date.formatted(style)
	}

	/// "Today", "Tomorrow", or the weekday for later this week.
	static func day(of date: Date, from now: Date) -> String {
		let calendar = Calendar.autoupdatingCurrent
		if calendar.isDate(date, inSameDayAs: now) { return "Today" }
		if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
			return "Tomorrow"
		}
		return date.formatted(.dateTime.weekday(.wide))
	}

	/// "Tomorrow" or "Yesterday" when a city's date differs from yours, else nil.
	static func dayShift(in timeZone: TimeZone, at date: Date) -> String? {
		var theirs = Calendar(identifier: .gregorian)
		theirs.timeZone = timeZone
		var ours = Calendar(identifier: .gregorian)
		ours.timeZone = .autoupdatingCurrent
		let a = theirs.dateComponents([.year, .month, .day], from: date)
		let b = ours.dateComponents([.year, .month, .day], from: date)
		guard a != b else { return nil }
		let later = (a.year!, a.month!, a.day!) > (b.year!, b.month!, b.day!)
		return later ? "Tomorrow" : "Yesterday"
	}

	/// "+5h", "−3h 30m", or "Same time" relative to your time zone.
	static func offset(of timeZone: TimeZone, at date: Date) -> String {
		let seconds = timeZone.secondsFromGMT(for: date) - TimeZone.autoupdatingCurrent.secondsFromGMT(for: date)
		guard seconds != 0 else { return "Same time" }
		let sign = seconds > 0 ? "+" : "−"
		let hours = abs(seconds) / 3600
		let minutes = abs(seconds) % 3600 / 60
		return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h \(minutes)m"
	}

	/// "4:05" or "1:04:05" for a paused timer.
	static func remaining(_ seconds: TimeInterval) -> String {
		let duration = Duration.seconds(max(0, seconds.rounded()))
		return duration.formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
	}

	/// Light, rounded numerals like the app's clocks.
	static func clockFont(_ size: CGFloat) -> Font {
		.system(size: size, weight: .light, design: .rounded)
	}
}


extension SkyPalette.Sky {
	var gradient: LinearGradient {
		LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
	}

	var textColor: Color {
		prefersLightText ? .white : Color.black.opacity(0.8)
	}
}


extension SkyPalette {
	/// The sky at a moment's local hour in a time zone.
	static func sky(at date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> Sky {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone
		let parts = calendar.dateComponents([.hour, .minute], from: date)
		return sky(atHour: Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60)
	}
}


nonisolated extension WidgetSnapshot {
	/// Sample content for the widget gallery and previews.
	static var preview: WidgetSnapshot {
		let now = Date()
		return WidgetSnapshot(
			alarms: [
				Alarm(id: "a", label: "Wake Up", date: now.addingTimeInterval(7 * 3600)),
				Alarm(id: "b", label: "Gym", date: now.addingTimeInterval(26 * 3600)),
				Alarm(id: "c", label: "Wake Up", date: now.addingTimeInterval(31 * 3600))
			],
			timers: [
				Timer(id: UUID(), label: "Pasta", colorName: "peach", symbol: "fork.knife", duration: 600, remaining: 600, endDate: now.addingTimeInterval(372)),
				Timer(id: UUID(), label: "Laundry", colorName: "sky", symbol: "washer", duration: 2700, remaining: 1500, endDate: nil)
			],
			cities: [
				City(id: UUID(), name: "London", person: "Mom", timeZoneIdentifier: "Europe/London"),
				City(id: UUID(), name: "Tokyo", timeZoneIdentifier: "Asia/Tokyo"),
				City(id: UUID(), name: "New York", timeZoneIdentifier: "America/New_York"),
				City(id: UUID(), name: "Sydney", timeZoneIdentifier: "Australia/Sydney")
			]
		)
	}
}
