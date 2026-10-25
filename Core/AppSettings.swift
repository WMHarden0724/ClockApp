//
//  AppSettings.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation
import Observation
#if os(iOS)
import UIKit
#endif


/// App-wide preferences. Views that format times through it update as soon as a setting changes.
@Observable
final class AppSettings {
	static let shared = AppSettings()

	enum TimeFormat: String, CaseIterable, Identifiable {
		case system, twelveHour, twentyFourHour

		var id: String { rawValue }

		var title: String {
			switch self {
			case .system: "System"
			case .twelveHour: "12-Hour"
			case .twentyFourHour: "24-Hour"
			}
		}
	}

	/// A gentle notification before a timer ends.
	enum TimerHeadsUp: String, CaseIterable, Identifiable {
		case off, oneMinute, fiveMinutes, halfway

		var id: String { rawValue }

		var title: String {
			switch self {
			case .off: "Off"
			case .oneMinute: "1 Minute Before"
			case .fiveMinutes: "5 Minutes Before"
			case .halfway: "Halfway"
			}
		}

		/// When to warn for a timer of this length, as time before the end; nil when it's too short to bother.
		func lead(for duration: TimeInterval) -> TimeInterval? {
			switch self {
			case .off: nil
			case .oneMinute: duration > 120 ? 60 : nil
			case .fiveMinutes: duration > 600 ? 300 : nil
			case .halfway: duration >= 120 ? duration / 2 : nil
			}
		}
	}

	private static let timeFormatKey = "timeFormat"
	private static let timerStyleKey = "timerStyle"
	private static let homeCityNameKey = "homeCityName"
	private static let homeCityTimeZoneKey = "homeCityTimeZone"
	private static let defaultSnoozeKey = "defaultSnoozeMinutes"
	private static let keepAwakeKey = "stopwatchKeepsScreenAwake"
	private static let paceRingKey = "stopwatchShowsPaceRing"
	private static let ringsKey = "ringsOnThisDevice"
	private static let headsUpKey = "timerHeadsUp"
	private static let menuBarKey = "showsMenuBarTimer"
	private static let soundsKey = "timerSoundsByCategory"

	var timeFormat: TimeFormat {
		didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: Self.timeFormatKey) }
	}

	var timerStyle: TimerStyle {
		didSet { UserDefaults.standard.set(timerStyle.rawValue, forKey: Self.timerStyleKey) }
	}

	/// Snooze length for newly created alarms.
	var defaultSnoozeMinutes: Int {
		didSet { UserDefaults.standard.set(defaultSnoozeMinutes, forKey: Self.defaultSnoozeKey) }
	}

	var stopwatchKeepsScreenAwake: Bool {
		didSet { UserDefaults.standard.set(stopwatchKeepsScreenAwake, forKey: Self.keepAwakeKey) }
	}

	/// Whether this device schedules real alarms. Not synced: each device decides for itself.
	var ringsOnThisDevice: Bool {
		didSet { UserDefaults.standard.set(ringsOnThisDevice, forKey: Self.ringsKey) }
	}

	/// True on iPhone and iPad, the only devices AlarmKit can ring on.
	static var canRing: Bool {
		#if os(iOS)
		true
		#else
		false
		#endif
	}

	var stopwatchShowsPaceRing: Bool {
		didSet { UserDefaults.standard.set(stopwatchShowsPaceRing, forKey: Self.paceRingKey) }
	}

	var timerHeadsUp: TimerHeadsUp {
		didSet { UserDefaults.standard.set(timerHeadsUp.rawValue, forKey: Self.headsUpKey) }
	}

	/// Mac only: a menu bar item with the next timer's time left.
	var showsMenuBarTimer: Bool {
		didSet { UserDefaults.standard.set(showsMenuBarTimer, forKey: Self.menuBarKey) }
	}

	/// The last sound picked for each kind of timer, so laundry and pasta can sound different.
	private var timerSounds: [String: String] {
		didSet { UserDefaults.standard.set(timerSounds, forKey: Self.soundsKey) }
	}

	func timerSound(for category: TimerCategory) -> TimerSound {
		timerSounds[category.rawValue].flatMap(TimerSound.init) ?? .standard
	}

	func setTimerSound(_ sound: TimerSound, for category: TimerCategory) {
		timerSounds[category.rawValue] = sound.rawValue
	}

	/// The user's own city, shown beside local time while they're in its time zone.
	private(set) var homeCityName: String? {
		didSet { UserDefaults.standard.set(homeCityName, forKey: Self.homeCityNameKey) }
	}

	private(set) var homeCityTimeZone: String? {
		didSet { UserDefaults.standard.set(homeCityTimeZone, forKey: Self.homeCityTimeZoneKey) }
	}

	func setHomeCity(name: String, timeZone: TimeZone) {
		homeCityName = name
		homeCityTimeZone = timeZone.identifier
	}

	func clearHomeCity() {
		homeCityName = nil
		homeCityTimeZone = nil
	}

	/// nil follows the system setting.
	var uses24Hour: Bool? {
		switch timeFormat {
		case .system: nil
		case .twelveHour: false
		case .twentyFourHour: true
		}
	}

	var is24Hour: Bool { ClockFormat.is24Hour(uses24Hour) }

	private init() {
		timeFormat = UserDefaults.standard.string(forKey: Self.timeFormatKey).flatMap(TimeFormat.init) ?? .system
		timerStyle = UserDefaults.standard.string(forKey: Self.timerStyleKey).flatMap(TimerStyle.init) ?? .ring
		homeCityName = UserDefaults.standard.string(forKey: Self.homeCityNameKey)
		homeCityTimeZone = UserDefaults.standard.string(forKey: Self.homeCityTimeZoneKey)
		defaultSnoozeMinutes = UserDefaults.standard.object(forKey: Self.defaultSnoozeKey) as? Int ?? 9
		stopwatchKeepsScreenAwake = UserDefaults.standard.object(forKey: Self.keepAwakeKey) as? Bool ?? false
		stopwatchShowsPaceRing = UserDefaults.standard.object(forKey: Self.paceRingKey) as? Bool ?? true
		timerHeadsUp = UserDefaults.standard.string(forKey: Self.headsUpKey).flatMap(TimerHeadsUp.init) ?? .off
		showsMenuBarTimer = UserDefaults.standard.object(forKey: Self.menuBarKey) as? Bool ?? true
		timerSounds = UserDefaults.standard.dictionary(forKey: Self.soundsKey) as? [String: String] ?? [:]
		#if os(iOS)
		let ringsByDefault = UIDevice.current.userInterfaceIdiom == .phone
		#else
		let ringsByDefault = false
		#endif
		ringsOnThisDevice = Self.canRing && (UserDefaults.standard.object(forKey: Self.ringsKey) as? Bool ?? ringsByDefault)
	}
}


extension Date {
	/// This time in the user's chosen 12/24-hour format.
	var timeText: String {
		ClockFormat.time(self, uses24Hour: AppSettings.shared.uses24Hour)
	}

	func timeText(in timeZone: TimeZone) -> String {
		ClockFormat.time(self, uses24Hour: AppSettings.shared.uses24Hour, timeZone: timeZone)
	}

	var dateTimeText: String {
		ClockFormat.dateTime(self, uses24Hour: AppSettings.shared.uses24Hour)
	}
}
