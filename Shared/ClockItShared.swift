//
//  ClockItShared.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(iOS)
import AlarmKit
import AppIntents
#endif
import SwiftUI


// Compiled into the app (every platform), the widget extension and the Watch app.
// AlarmKit pieces exist only on iPhone and iPad.


#if os(iOS)
/// Travels with every AlarmKit alarm so the Live Activity knows what it's showing.
nonisolated struct ClockItAlarmMetadata: AlarmMetadata {
	enum Kind: String, Codable, Hashable, Sendable {
		case alarm, timer
	}

	var kind: Kind = .alarm
	var label: String = ""
	var colorName: String = ClockItPalette.defaultName
	var symbolName: String = "timer"
	var uses24Hour: Bool? = nil // the app's 12/24-hour setting at schedule time; nil follows the system
}
#endif


/// Formats clock times honoring ClockIt's 12/24-hour setting.
nonisolated enum ClockFormat {
	/// `uses24Hour` nil means follow the system setting.
	static func locale(uses24Hour: Bool?) -> Locale {
		guard let uses24Hour else { return .autoupdatingCurrent }
		var components = Locale.Components(locale: .autoupdatingCurrent)
		components.hourCycle = uses24Hour ? .zeroToTwentyThree : .oneToTwelve
		return Locale(components: components)
	}

	static func is24Hour(_ uses24Hour: Bool?) -> Bool {
		if let uses24Hour { return uses24Hour }
		let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .autoupdatingCurrent) ?? ""
		return !pattern.contains("a")
	}

	/// "9:41 PM" or "21:41".
	static func time(_ date: Date, uses24Hour: Bool?, timeZone: TimeZone = .autoupdatingCurrent) -> String {
		date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale(uses24Hour: uses24Hour), timeZone: timeZone))
	}

	/// "Oct 25, 2026 at 9:41 PM".
	static func dateTime(_ date: Date, uses24Hour: Bool?) -> String {
		date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale(uses24Hour: uses24Hour)))
	}
}


/// Named soft colors that timers can pick from, shared with the Live Activity.
nonisolated enum ClockItPalette {
	static let accent = Color(red: 0.55, green: 0.50, blue: 1.0)
	static let defaultName = "lilac"

	static let named: [(name: String, color: Color)] = [
		("lilac", accent),
		("peach", Color(red: 1.00, green: 0.62, blue: 0.48)),
		("rose", Color(red: 0.98, green: 0.47, blue: 0.62)),
		("mint", Color(red: 0.30, green: 0.80, blue: 0.66)),
		("sky", Color(red: 0.36, green: 0.66, blue: 0.98)),
		("butter", Color(red: 0.98, green: 0.76, blue: 0.30))
	]

	static func color(named name: String) -> Color {
		named.first { $0.name == name }?.color ?? accent
	}
}


// MARK: - Live Activity buttons

#if os(iOS)

struct PauseAlarmIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Pause Timer"
	static let isDiscoverable = false

	@Parameter(title: "Alarm ID") var alarmID: String

	init() {}
	init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

	func perform() async throws -> some IntentResult {
		if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.pause(id: id) }
		return .result()
	}
}


struct ResumeAlarmIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Resume Timer"
	static let isDiscoverable = false

	@Parameter(title: "Alarm ID") var alarmID: String

	init() {}
	init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

	func perform() async throws -> some IntentResult {
		if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.resume(id: id) }
		return .result()
	}
}


struct CancelAlarmIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Cancel Timer"
	static let isDiscoverable = false

	@Parameter(title: "Alarm ID") var alarmID: String

	init() {}
	init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

	func perform() async throws -> some IntentResult {
		if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.cancel(id: id) }
		return .result()
	}
}
#endif
