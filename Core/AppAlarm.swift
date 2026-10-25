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
	var missionType: MissionType?
	/// Occurrences before this are skipped ("Skip Next").
	var skipUntil: Date? = nil
	/// Ring at this time in another time zone, wherever you are.
	var timeZoneIdentifier: String? = nil
	/// Ring at sunrise (plus or minus an offset) instead of a fixed time.
	var sunrise: SunriseOption? = nil
	/// Alarms in the same group switch on and off together.
	var group: String? = nil
	/// Made with a quick-alarm button; removed once it has rung.
	var isQuick: Bool? = nil

	/// What you have to do before the alarm lets you go.
	enum MissionType: String, Codable, CaseIterable, Identifiable {
		case none, math, shake

		var id: String { rawValue }

		var title: String {
			switch self {
			case .none: "None"
			case .math: "Solve Math"
			case .shake: "Shake Phone"
			}
		}

		var symbol: String {
			switch self {
			case .none: "checkmark"
			case .math: "function"
			case .shake: "iphone.radiowaves.left.and.right"
			}
		}
	}

	struct SunriseOption: Codable, Equatable, Hashable {
		/// Minutes after sunrise; negative for before.
		var offsetMinutes: Int
		var latitude: Double
		var longitude: Double
		var placeName: String
	}
}


extension AppAlarm {
	var displayLabel: String {
		label.isEmpty ? "Alarm" : label
	}

	var timeZone: TimeZone? {
		timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
	}

	/// The time it rings, in its own time zone. Sunrise alarms show their next ring.
	var timeText: String {
		if sunrise != nil, let next = nextFireDate() {
			return next.timeText
		}
		let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
		return date.timeText
	}

	var mission: MissionType { missionType ?? .none }

	var sound: TimerSound { TimerSound(rawValue: soundName) ?? .standard }

	/// Rings once and is done: no repeat days, or a specific date.
	var isOneTime: Bool { repeatDays.isEmpty || specificDate != nil }

	var isSkipping: Bool { (skipUntil ?? .distantPast) > Date() }

	/// Repeating weekly in local time is the only pattern AlarmKit can repeat by itself;
	/// everything else is scheduled one ring at a time.
	func needsFixedSchedule(notBefore: Date?) -> Bool {
		specificDate != nil || timeZone != nil || sunrise != nil || isSkipping || notBefore != nil
	}

	var scheduleText: String {
		var parts: [String] = []
		if let sunrise {
			let offset = sunrise.offsetMinutes
			parts.append(offset == 0 ? "Sunrise" : offset > 0 ? "\(offset) min after sunrise" : "\(-offset) min before sunrise")
		}
		if let timeZone, timeZone != .current {
			parts.append("\(Self.cityName(of: timeZone)) time")
		}
		if let specificDate {
			parts.append(specificDate.formatted(date: .abbreviated, time: .omitted))
		} else {
			switch repeatDays {
			case []: parts.append("Once")
			case Set(1...7): parts.append("Every day")
			case Set(2...6): parts.append("Weekdays")
			case [1, 7]: parts.append("Weekends")
			default:
				let days = Calendar.current.shortWeekdaySymbols
				parts.append(repeatDays.sorted().map { days[$0 - 1] }.joined(separator: ", "))
			}
		}
		return parts.joined(separator: " · ")
	}

	/// "London" from "Europe/London".
	static func cityName(of timeZone: TimeZone) -> String {
		timeZone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? timeZone.identifier
	}

	/// The next moment this alarm will ring, or nil if it never will again.
	/// `notBefore` is when paused alarms come back (Pause All Alarms).
	func nextFireDate(after date: Date = Date(), notBefore: Date? = nil) -> Date? {
		let start = [date, skipUntil, notBefore].compactMap { $0 }.max() ?? date
		var calendar = Calendar.current
		if let timeZone { calendar.timeZone = timeZone }

		if let sunrise {
			return nextSunrise(after: start, sunrise: sunrise, calendar: calendar)
		}
		if let specificDate {
			var comps = calendar.dateComponents([.year, .month, .day], from: specificDate)
			comps.hour = hour
			comps.minute = minute
			guard let fire = calendar.date(from: comps), fire > start else { return nil }
			return fire
		}
		let time = DateComponents(hour: hour, minute: minute, second: 0)
		if repeatDays.isEmpty {
			return calendar.nextDate(after: start, matching: time, matchingPolicy: .nextTime)
		}
		return repeatDays.compactMap { weekday in
			var comps = time
			comps.weekday = weekday
			return calendar.nextDate(after: start, matching: comps, matchingPolicy: .nextTime)
		}.min()
	}

	private func nextSunrise(after start: Date, sunrise: SunriseOption, calendar: Calendar) -> Date? {
		let firstDay = specificDate.map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: start)
		for offset in 0..<(specificDate == nil ? 9 : 1) {
			guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
			if !repeatDays.isEmpty, !repeatDays.contains(calendar.component(.weekday, from: day)) { continue }
			guard let rise = SunTimes.sunrise(on: day, latitude: sunrise.latitude, longitude: sunrise.longitude, calendar: calendar) else { continue }
			let fire = rise.addingTimeInterval(TimeInterval(sunrise.offsetMinutes * 60))
			let rounded = Date(timeIntervalSinceReferenceDate: (fire.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
			if rounded > start { return rounded }
		}
		return nil
	}
}


/// Sunrise from the sunrise equation (accurate to a minute or two away from the poles).
enum SunTimes {
	static func sunrise(on day: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> Date? {
		guard let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) else { return nil }
		let radians = Double.pi / 180
		let julianDay = noon.timeIntervalSince1970 / 86400 + 2_440_587.5
		let n = (julianDay - 2_451_545.0 + 0.0008).rounded()
		let meanSolarNoon = n - longitude / 360
		let anomaly = (357.5291 + 0.98560028 * meanSolarNoon).truncatingRemainder(dividingBy: 360)
		let center = 1.9148 * sin(anomaly * radians) + 0.02 * sin(2 * anomaly * radians) + 0.0003 * sin(3 * anomaly * radians)
		let eclipticLongitude = (anomaly + center + 180 + 102.9372).truncatingRemainder(dividingBy: 360)
		let transit = 2_451_545.0 + meanSolarNoon + 0.0053 * sin(anomaly * radians) - 0.0069 * sin(2 * eclipticLongitude * radians)
		let declination = asin(sin(eclipticLongitude * radians) * sin(23.4397 * radians))
		let cosHourAngle = (sin(-0.833 * radians) - sin(latitude * radians) * sin(declination)) / (cos(latitude * radians) * cos(declination))
		guard (-1...1).contains(cosHourAngle) else { return nil } // polar day or night
		let rise = transit - acos(cosHourAngle) / radians / 360
		return Date(timeIntervalSince1970: (rise - 2_440_587.5) * 86400)
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
