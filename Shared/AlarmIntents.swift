//
//  AlarmIntents.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import AppIntents
import Foundation
#if os(iOS)
import WidgetKit
#endif


// Compiled into the app, the widget extension and the Watch app, like TimerIntents.swift.
// The widget extension only describes these; the system performs them in the app.


nonisolated enum AlarmAction: Sendable {
	case set(hour: Int, minute: Int, label: String)
	case next
	case setEnabled(id: UUID, isEnabled: Bool)
	case skipNext(id: UUID)
	case pause(until: Date)
	/// The alarm's Stop button: book its next ring.
	case stopped(id: UUID)
	/// Stop on an alarm with a wake-up mission.
	case mission(id: UUID)
}


private func run(_ action: AlarmAction) async -> String {
	#if WIDGET_EXTENSION
	return ""
	#else
	return ClockStore.shared.perform(action)
	#endif
}


// MARK: - Alarms, shared with the widget extension

nonisolated struct AlarmSummary: Codable, Hashable, Sendable {
	var id: UUID
	var name: String
	var timeText: String
	var scheduleText: String
	var isEnabled: Bool
}


/// Alarms, kept where the widget extension can read them: the App Group on iPhone and iPad.
nonisolated enum AlarmShelf {
	static let toggleControlKind = "com.southerncode.ClockIt.alarm.toggle"
	private static let key = "alarms"

	private static var defaults: UserDefaults {
		#if os(iOS)
		UserDefaults(suiteName: "group.com.southerncode.ClockIt") ?? .standard
		#else
		.standard
		#endif
	}

	static func read() -> [AlarmSummary] {
		guard let data = defaults.data(forKey: key) else { return [] }
		return (try? JSONDecoder().decode([AlarmSummary].self, from: data)) ?? []
	}

	static func write(_ alarms: [AlarmSummary]) {
		guard alarms != read(), let data = try? JSONEncoder().encode(alarms) else { return }
		defaults.set(data, forKey: key)
		#if os(iOS) && !WIDGET_EXTENSION
		ControlCenter.shared.reloadControls(ofKind: toggleControlKind)
		#endif
	}
}


nonisolated struct AlarmEntity: AppEntity, Identifiable {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Alarm"
	static let defaultQuery = AlarmQuery()

	let id: UUID
	let name: String
	let timeText: String
	let scheduleText: String
	let isEnabled: Bool

	init(_ summary: AlarmSummary) {
		id = summary.id
		name = summary.name
		timeText = summary.timeText
		scheduleText = summary.scheduleText
		isEnabled = summary.isEnabled
	}

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(name) \(timeText)", subtitle: "\(scheduleText)", image: .init(systemName: "alarm"))
	}
}


nonisolated struct AlarmQuery: EntityQuery {
	func entities(for identifiers: [UUID]) async throws -> [AlarmEntity] {
		AlarmShelf.read().filter { identifiers.contains($0.id) }.map(AlarmEntity.init)
	}

	func suggestedEntities() async throws -> [AlarmEntity] {
		AlarmShelf.read().map(AlarmEntity.init)
	}
}


// MARK: - Intents

struct SetAlarmIntent: InAppIntent {
	static let title: LocalizedStringResource = "Set Alarm"
	static let description = IntentDescription("Sets a one-time alarm for the next time the clock reads this time.")

	@Parameter(title: "Time", kind: .time, requestValueDialog: "What time?")
	var time: DateComponents

	@Parameter(title: "Label")
	var label: String?

	static var parameterSummary: some ParameterSummary {
		Summary("Set an alarm for \(\.$time)") {
			\.$label
		}
	}

	func perform() async throws -> some IntentResult & ProvidesDialog {
		let action = AlarmAction.set(hour: time.hour ?? 7, minute: time.minute ?? 0, label: label ?? "")
		return .result(dialog: "\(await run(action))")
	}
}


struct NextAlarmIntent: InAppIntent {
	static let title: LocalizedStringResource = "Next Alarm"
	static let description = IntentDescription("Tells you when your next alarm rings.")

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.next))")
	}
}


struct TurnOffAlarmIntent: InAppIntent {
	static let title: LocalizedStringResource = "Turn Off Alarm"

	@Parameter(title: "Alarm")
	var alarm: AlarmEntity

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.setEnabled(id: alarm.id, isEnabled: false)))")
	}
}


struct TurnOnAlarmIntent: InAppIntent {
	static let title: LocalizedStringResource = "Turn On Alarm"

	@Parameter(title: "Alarm")
	var alarm: AlarmEntity

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.setEnabled(id: alarm.id, isEnabled: true)))")
	}
}


struct SkipNextAlarmIntent: InAppIntent {
	static let title: LocalizedStringResource = "Skip Next Alarm"
	static let description = IntentDescription("Skips the next ring of a repeating alarm and leaves it on.")

	@Parameter(title: "Alarm")
	var alarm: AlarmEntity

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.skipNext(id: alarm.id)))")
	}
}


struct PauseAlarmsIntent: InAppIntent {
	static let title: LocalizedStringResource = "Pause All Alarms"
	static let description = IntentDescription("No alarms ring until the day you choose. They come back on their own.")

	@Parameter(title: "Until", kind: .date)
	var until: Date

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.pause(until: until)))")
	}
}


#if os(iOS)
/// The alarm alert's Stop button, so the app can book the next ring.
struct AlarmStoppedIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Alarm Stopped"
	static let isDiscoverable = false

	@Parameter(title: "Alarm ID") var alarmID: String

	init() {}
	init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

	func perform() async throws -> some IntentResult {
		if let id = UUID(uuidString: alarmID) { _ = await run(.stopped(id: id)) }
		return .result()
	}
}


/// Stop on an alarm with a wake-up mission: opens ClockIt to the mission.
struct WakeMissionIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Wake-Up Mission"
	static let isDiscoverable = false
	static let supportedModes: IntentModes = .foreground(.immediate)

	@Parameter(title: "Alarm ID") var alarmID: String

	init() {}
	init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

	func perform() async throws -> some IntentResult {
		if let id = UUID(uuidString: alarmID) { _ = await run(.mission(id: id)) }
		return .result()
	}
}


/// The Control Center toggle's action: switches the chosen alarm on or off.
struct SetAlarmEnabledIntent: SetValueIntent, LiveActivityIntent {
	static let title: LocalizedStringResource = "Set Alarm"
	static let isDiscoverable = false

	@Parameter(title: "Alarm") var alarm: AlarmEntity?
	@Parameter(title: "On") var value: Bool

	init() {}
	init(alarm: AlarmEntity?) { self.alarm = alarm }

	func perform() async throws -> some IntentResult {
		if let alarm { _ = await run(.setEnabled(id: alarm.id, isEnabled: value)) }
		return .result()
	}
}


/// Picks which alarm the Control Center toggle switches.
struct SelectAlarmIntent: ControlConfigurationIntent {
	static let title: LocalizedStringResource = "Choose Alarm"

	@Parameter(title: "Alarm")
	var alarm: AlarmEntity?
}
#endif
