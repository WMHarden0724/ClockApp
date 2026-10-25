//
//  AppAlarm.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import Foundation



struct AppAlarm: Identifiable, Codable, Equatable {
	let id: UUID
	var label: String
	var hour: Int
	var minute: Int
	var isEnabled: Bool
	var repeatDays: Set<Int> // 1 = Sunday ... 7 = Saturday, empty = one-time
	var specificDate: Date? // for one-time future date alarms
	var snoozeMinutes: Int
	var soundName: String
	var volumeRamp: Bool
	var missionType: MissionType?

	enum MissionType: String, Codable {
		case none, math, shake, qrCode, photo
	}
}


extension AppAlarm {
	var displayLabel: String {
		label.isEmpty ? "Alarm" : label
	}

	var timeText: String {
		let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
		return date.timeText
	}

	var scheduleText: String {
		if let specificDate {
			return specificDate.formatted(date: .abbreviated, time: .omitted)
		}
		switch repeatDays {
		case []: return "Once"
		case Set(1...7): return "Every day"
		case Set(2...6): return "Weekdays"
		case [1, 7]: return "Weekends"
		default:
			let days = Calendar.current.shortWeekdaySymbols
			return repeatDays.sorted().map { days[$0 - 1] }.joined(separator: ", ")
		}
	}

	/// The next moment this alarm will ring, or nil if it never will again.
	func nextFireDate(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
		if let specificDate {
			var comps = calendar.dateComponents([.year, .month, .day], from: specificDate)
			comps.hour = hour
			comps.minute = minute
			guard let fire = calendar.date(from: comps), fire > date else { return nil }
			return fire
		}
		let time = DateComponents(hour: hour, minute: minute, second: 0)
		if repeatDays.isEmpty {
			return calendar.nextDate(after: date, matching: time, matchingPolicy: .nextTime)
		}
		return repeatDays.compactMap { weekday in
			var comps = time
			comps.weekday = weekday
			return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
		}.min()
	}
}


extension Date {
	/// "7h 32m", "2d 4h", or "12m" until this date.
	func countdownText(from now: Date = Date()) -> String {
		let minutes = max(0, Int((timeIntervalSince(now) / 60).rounded(.up)))
		let days = minutes / 1440
		let hours = (minutes % 1440) / 60
		let mins = minutes % 60
		if days > 0 { return "\(days)d \(hours)h" }
		if hours > 0 { return "\(hours)h \(mins)m" }
		return "\(mins)m"
	}

	/// "Today, 7:00 AM", "Tomorrow, 7:00 AM", or "Friday, 7:00 AM".
	var relativeDayAndTime: String {
		let calendar = Calendar.current
		let time = self.timeText
		if calendar.isDateInToday(self) { return "Today, \(time)" }
		if calendar.isDateInTomorrow(self) { return "Tomorrow, \(time)" }
		if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: self).day, days < 7 {
			return "\(formatted(.dateTime.weekday(.wide))), \(time)"
		}
		return dateTimeText
	}
}
