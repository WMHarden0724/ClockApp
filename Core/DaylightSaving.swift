//
//  DaylightSaving.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation
#if os(iOS)
import UserNotifications
#endif


/// A daylight saving change coming up, in your time zone or a World Clock city's,
/// and what it does to the gap between you.
struct ClockChange: Equatable {
	enum Whose: Equatable {
		case yours, theirs
	}

	let date: Date
	let whose: Whose
	/// The time zone whose clocks change, for naming the day as they'd see it.
	let timeZone: TimeZone
	/// How far the clocks move: positive springs forward, negative falls back.
	let shift: Int
	/// The city's offset from you, in seconds, before and after.
	let gapBefore: Int
	let gapAfter: Int

	/// The next change, yours or the city's, that alters the gap between you, within `window`.
	static func next(for city: WorldClockCity, from now: Date = Date(), within window: TimeInterval = 7 * 86_400) -> ClockChange? {
		let local = TimeZone.autoupdatingCurrent
		let candidates: [(Date, Whose, TimeZone)] = [
			local.nextDaylightSavingTimeTransition(after: now).map { ($0, .yours, local) },
			city.timeZone.nextDaylightSavingTimeTransition(after: now).map { ($0, .theirs, city.timeZone) }
		].compactMap { $0 }

		for (date, whose, zone) in candidates.sorted(by: { $0.0 < $1.0 }) where date.timeIntervalSince(now) <= window {
			// A day either side, so neighbors that change at their own 2 AM, an hour apart,
			// count as changing together.
			let gapBefore = gap(city.timeZone, local, at: date.addingTimeInterval(-86_400))
			let gapAfter = gap(city.timeZone, local, at: date.addingTimeInterval(86_400))
			// Both sides changing together leaves the gap alone; nothing to warn about.
			guard gapBefore != gapAfter else { continue }
			let shift = zone.secondsFromGMT(for: date.addingTimeInterval(1)) - zone.secondsFromGMT(for: date.addingTimeInterval(-1))
			return ClockChange(date: date, whose: whose, timeZone: zone, shift: shift, gapBefore: gapBefore, gapAfter: gapAfter)
		}
		return nil
	}

	/// Your own next change, within `window`.
	static func nextLocal(from now: Date = Date(), within window: TimeInterval) -> (date: Date, shift: Int)? {
		let local = TimeZone.autoupdatingCurrent
		guard let date = local.nextDaylightSavingTimeTransition(after: now), date.timeIntervalSince(now) <= window else { return nil }
		let shift = local.secondsFromGMT(for: date.addingTimeInterval(1)) - local.secondsFromGMT(for: date.addingTimeInterval(-1))
		return shift == 0 ? nil : (date, shift)
	}

	private static func gap(_ theirs: TimeZone, _ ours: TimeZone, at date: Date) -> Int {
		theirs.secondsFromGMT(for: date) - ours.secondsFromGMT(for: date)
	}

	// MARK: Wording

	/// "Clocks in London go back Sunday" or "Your clocks go forward tomorrow".
	func headline(cityName: String, from now: Date = Date()) -> String {
		let who = whose == .yours ? "Your clocks" : "Clocks in \(cityName)"
		return "\(who) \(Self.movement(shift)) \(Self.day(of: date, from: now, in: timeZone))"
	}

	/// "Mom will be 4h ahead" or "London will be on your time".
	func consequence(name: String) -> String {
		"\(name) will be \(Self.gapText(gapAfter))"
	}

	/// "go back an hour" or "go forward 30 minutes".
	static func movement(_ shift: Int) -> String {
		let direction = shift > 0 ? "go forward" : "go back"
		let minutes = abs(shift) / 60
		let amount = minutes == 60 ? "an hour" : minutes % 60 == 0 ? "\(minutes / 60) hours" : "\(minutes) minutes"
		return "\(direction) \(amount)"
	}

	/// "4h ahead", "3h 30m behind", or "on your time".
	static func gapText(_ seconds: Int) -> String {
		guard seconds != 0 else { return "on your time" }
		let hours = abs(seconds) / 3600
		let minutes = abs(seconds) % 3600 / 60
		let amount = minutes == 0 ? "\(hours)h" : hours == 0 ? "\(minutes)m" : "\(hours)h \(minutes)m"
		return "\(amount) \(seconds > 0 ? "ahead" : "behind")"
	}

	/// "today", "tomorrow", or "on Sunday", by the calendar of the clocks that change.
	static func day(of date: Date, from now: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> String {
		var calendar = Calendar.autoupdatingCurrent
		calendar.timeZone = timeZone
		if calendar.isDate(date, inSameDayAs: now) { return "today" }
		if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
			return "tomorrow"
		}
		var style = Date.FormatStyle.dateTime
		style.timeZone = timeZone
		if date.timeIntervalSince(now) < 7 * 86_400 {
			return "on \(date.formatted(style.weekday(.wide)))"
		}
		return "on \(date.formatted(style.month(.wide).day()))"
	}
}


#if os(iOS)
/// A heads-up a few days before a clock change: your own, and each World Clock city's.
/// Only the ringing device posts them, so you don't get one from every device.
enum DaylightSavingAlerts {
	private static let prefix = "dst."
	private static let leadDays = 3
	/// Planned this far ahead; the app reschedules whenever it runs.
	private static let horizon: TimeInterval = 60 * 86_400

	static func update(cities: [WorldClockCity]) {
		let center = UNUserNotificationCenter.current()
		Task {
			let stale = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
			center.removePendingNotificationRequests(withIdentifiers: stale)
			guard AppSettings.shared.daylightSavingAlerts, AlarmScheduler.isRingingDevice else { return }

			var requests: [UNNotificationRequest] = []
			let now = Date()

			if let local = ClockChange.nextLocal(from: now, within: horizon) {
				let content = UNMutableNotificationContent()
				content.title = "Clocks \(ClockChange.movement(local.shift)) \(ClockChange.day(of: local.date, from: remindDate(before: local.date) ?? now))"
				// Named by the time on the clock just before it changes: "2:00 AM", not "1:59".
				let before = TimeZone(secondsFromGMT: TimeZone.autoupdatingCurrent.secondsFromGMT(for: local.date.addingTimeInterval(-1))) ?? .autoupdatingCurrent
				content.body = "At \(ClockFormat.time(local.date, uses24Hour: AppSettings.shared.uses24Hour, timeZone: before)). Your alarms adjust on their own."
				if let request = request("\(prefix)local", content, before: local.date) { requests.append(request) }
			}

			for city in cities {
				guard let change = ClockChange.next(for: city, from: now, within: horizon) else { continue }
				let remindAt = remindDate(before: change.date) ?? now
				let content = UNMutableNotificationContent()
				content.title = change.headline(cityName: city.name, from: remindAt)
				content.body = "\(change.consequence(name: city.displayName)), instead of \(ClockChange.gapText(change.gapBefore))."
				if let request = request("\(prefix)\(city.id)", content, before: change.date) { requests.append(request) }
			}

			guard !requests.isEmpty else { return }
			center.delegate = NotificationPresenter.shared
			_ = try? await center.requestAuthorization(options: [.alert, .sound])
			for request in requests {
				try? await center.add(request)
			}
		}
	}

	/// 9 AM a few days before the change.
	private static func remindDate(before change: Date) -> Date? {
		let calendar = Calendar.autoupdatingCurrent
		guard let day = calendar.date(byAdding: .day, value: -leadDays, to: change) else { return nil }
		return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
	}

	private static func request(_ id: String, _ content: UNMutableNotificationContent, before change: Date) -> UNNotificationRequest? {
		guard let remindAt = remindDate(before: change), remindAt > Date() else { return nil }
		content.sound = .default
		let parts = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour, .minute], from: remindAt)
		return UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
	}
}
#endif
