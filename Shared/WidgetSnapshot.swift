//
//  WidgetSnapshot.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation
#if os(iOS) || os(watchOS)
import WidgetKit
#endif


// Compiled into the app, the widget extension and the Watch app. The app writes what its
// Home Screen widgets and Watch complications show; each device keeps its own copy.


nonisolated struct WidgetSnapshot: Codable, Hashable, Sendable {
	struct Alarm: Codable, Hashable, Sendable, Identifiable {
		/// The alarm plus its fire date: a repeating alarm appears once per upcoming ring.
		var id: String
		var label: String
		var date: Date
	}

	struct Timer: Codable, Hashable, Sendable, Identifiable {
		var id: UUID
		var label: String
		var colorName: String
		var symbol: String
		var duration: TimeInterval
		/// Time left while paused.
		var remaining: TimeInterval
		/// Set while running.
		var endDate: Date?

		/// Where the progress bar starts, so a countdown of `duration` ends at `endDate`.
		var startDate: Date? {
			endDate.map { $0.addingTimeInterval(-max(duration, 1)) }
		}
	}

	struct City: Codable, Hashable, Sendable, Identifiable {
		var id: UUID
		var name: String
		/// Someone who lives there ("Mom"), shown in place of the city name.
		var person: String?
		var timeZoneIdentifier: String

		var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
		var displayName: String { person ?? name }
	}

	/// Upcoming rings, soonest first.
	var alarms: [Alarm] = []
	var alarmsPausedUntil: Date?
	var timers: [Timer] = []
	var cities: [City] = []
	/// The app's 12/24-hour setting; nil follows the system.
	var uses24Hour: Bool?

	/// Rings still ahead of `date`.
	func alarms(after date: Date) -> [Alarm] {
		alarms.filter { $0.date > date }
	}

	/// Running timers that haven't ended by `date`, then paused ones.
	func timers(at date: Date) -> [Timer] {
		timers.filter { timer in timer.endDate.map { $0 > date } ?? (timer.remaining > 0) }
	}
}


/// Where the snapshot lives: the App Group, so the widget extension can read it.
nonisolated enum WidgetShelf {
	static let nextAlarmKind = "com.southerncode.ClockIt.widget.nextAlarm"
	static let timersKind = "com.southerncode.ClockIt.widget.timers"
	static let worldClockKind = "com.southerncode.ClockIt.widget.worldClock"
	private static let key = "widgetSnapshot"

	private static var defaults: UserDefaults {
		UserDefaults(suiteName: "group.com.southerncode.ClockIt") ?? .standard
	}

	static func read() -> WidgetSnapshot {
		guard let data = defaults.data(forKey: key) else { return WidgetSnapshot() }
		return (try? JSONDecoder().decode(WidgetSnapshot.self, from: data)) ?? WidgetSnapshot()
	}

	/// Applies a change and refreshes the widgets if anything they show is different.
	/// Only iPhone, iPad and Apple Watch have these widgets.
	static func update(_ change: (inout WidgetSnapshot) -> Void) {
		#if (os(iOS) || os(watchOS)) && !WIDGET_EXTENSION
		let current = read()
		var snapshot = current
		change(&snapshot)
		guard snapshot != current, let data = try? JSONEncoder().encode(snapshot) else { return }
		defaults.set(data, forKey: key)
		WidgetCenter.shared.reloadAllTimelines()
		#endif
	}
}
