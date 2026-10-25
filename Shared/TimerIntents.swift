//
//  TimerIntents.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import AppIntents
import Foundation
#if os(iOS)
import WidgetKit
#endif


// Compiled into the app, the widget extension and the Watch app, like StopwatchIntents.swift.
// The widget extension only describes these; the system performs them in the app.


nonisolated enum TimerAction: Sendable {
	case start(duration: TimeInterval, label: String)
	case startSaved(id: String)
	case status
	case pauseAll, resumeAll, cancelAll
	case addTime(seconds: TimeInterval, timerID: UUID)
}


private func run(_ action: TimerAction) async -> String {
	#if WIDGET_EXTENSION
	return ""
	#else
	return TimerStore.shared.perform(action)
	#endif
}


// MARK: - Saved timers, shared with the widget extension

/// What Siri and Control Center need to know about a saved timer.
nonisolated struct SavedTimerSummary: Codable, Hashable, Sendable {
	var id: String
	var name: String
	var duration: TimeInterval
	var symbol: String
}


/// Saved timers, kept where the widget extension can read them: the App Group on iPhone and iPad.
nonisolated enum SavedTimerShelf {
	static let startControlKind = "com.southerncode.ClockIt.timer.start"
	private static let key = "savedTimers"

	private static var defaults: UserDefaults {
		#if os(iOS)
		UserDefaults(suiteName: "group.com.southerncode.ClockIt") ?? .standard
		#else
		.standard
		#endif
	}

	static func read() -> [SavedTimerSummary] {
		guard let data = defaults.data(forKey: key) else { return [] }
		return (try? JSONDecoder().decode([SavedTimerSummary].self, from: data)) ?? []
	}

	static func write(_ timers: [SavedTimerSummary]) {
		guard timers != read(), let data = try? JSONEncoder().encode(timers) else { return }
		defaults.set(data, forKey: key)
		#if os(iOS) && !WIDGET_EXTENSION
		if #available(iOS 18, *) { ControlCenter.shared.reloadControls(ofKind: startControlKind) }
		#endif
	}
}


nonisolated struct SavedTimerEntity: AppEntity, Identifiable {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Saved Timer"
	static let defaultQuery = SavedTimerQuery()

	let id: String
	let name: String
	let duration: TimeInterval
	let symbol: String

	init(_ summary: SavedTimerSummary) {
		id = summary.id
		name = summary.name
		duration = summary.duration
		symbol = summary.symbol
	}

	/// What the Control Center button starts before you pick one of your own.
	static let fiveMinutes = SavedTimerEntity(SavedTimerSummary(id: "duration:300", name: "5 Minutes", duration: 300, symbol: "timer"))

	var displayRepresentation: DisplayRepresentation {
		let length = Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
		return DisplayRepresentation(title: "\(name)", subtitle: "\(length)", image: .init(systemName: symbol))
	}
}


nonisolated struct SavedTimerQuery: EntityQuery {
	func entities(for identifiers: [String]) async throws -> [SavedTimerEntity] {
		all().filter { identifiers.contains($0.id) }
	}

	func suggestedEntities() async throws -> [SavedTimerEntity] {
		all()
	}

	private func all() -> [SavedTimerEntity] {
		SavedTimerShelf.read().map(SavedTimerEntity.init) + [.fiveMinutes]
	}
}


// MARK: - Intents

struct StartTimerIntent: InAppIntent {
	static let title: LocalizedStringResource = "Start Timer"
	static let description = IntentDescription("Starts a timer for however long you say.")

	@Parameter(title: "Duration", defaultUnit: .minutes, requestValueDialog: "For how long?")
	var duration: Measurement<UnitDuration>

	@Parameter(title: "Label")
	var label: String?

	static var parameterSummary: some ParameterSummary {
		Summary("Start a \(\.$duration) timer") {
			\.$label
		}
	}

	func perform() async throws -> some IntentResult & ProvidesDialog {
		let seconds = duration.converted(to: .seconds).value
		return .result(dialog: "\(await run(.start(duration: seconds, label: label ?? "")))")
	}
}


struct StartSavedTimerIntent: InAppIntent {
	static let title: LocalizedStringResource = "Start Saved Timer"
	static let description = IntentDescription("Starts one of the timers you saved in ClockMe.")

	@Parameter(title: "Timer")
	var timer: SavedTimerEntity

	init() {}
	init(timer: SavedTimerEntity) { self.timer = timer }

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.startSaved(id: timer.id)))")
	}
}


struct CheckTimersIntent: InAppIntent {
	static let title: LocalizedStringResource = "Check Timers"
	static let description = IntentDescription("Tells you how long is left on each timer.")

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.status))")
	}
}


struct PauseAllTimersIntent: InAppIntent {
	static let title: LocalizedStringResource = "Pause All Timers"

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.pauseAll))")
	}
}


struct ResumeAllTimersIntent: InAppIntent {
	static let title: LocalizedStringResource = "Resume All Timers"

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.resumeAll))")
	}
}


struct CancelAllTimersIntent: InAppIntent {
	static let title: LocalizedStringResource = "Cancel All Timers"

	func perform() async throws -> some IntentResult & ProvidesDialog {
		.result(dialog: "\(await run(.cancelAll))")
	}
}


#if os(iOS)
/// The Live Activity's +1 button.
struct AddMinuteToTimerIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Add a Minute"
	static let isDiscoverable = false

	@Parameter(title: "Alarm ID") var alarmID: String

	init() {}
	init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

	func perform() async throws -> some IntentResult {
		if let id = UUID(uuidString: alarmID) {
			_ = await run(.addTime(seconds: 60, timerID: id))
		}
		return .result()
	}
}


/// Picks which saved timer the Control Center button starts.
@available(iOS 18, *)
struct SelectSavedTimerIntent: ControlConfigurationIntent {
	static let title: LocalizedStringResource = "Choose Timer"

	@Parameter(title: "Timer")
	var timer: SavedTimerEntity?
}
#endif
