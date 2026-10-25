//
//  MenuBarTimer.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(macOS)
import SwiftUI


/// The menu bar item: the next timer's time left, or just the icon when nothing's running.
struct MenuBarTimerLabel: View {
	let store: TimerStore

	var body: some View {
		TimelineView(.periodic(from: .now, by: 1)) { context in
			if let timer = nextTimer(at: context.date) {
				let remaining = timer.remaining(at: context.date)
				Text("\(Image(systemName: timer.isRunning ? "timer" : "pause.fill")) \(remaining <= 0 ? timer.kind.doneText : remaining.timerText)")
					.monospacedDigit()
			} else {
				Image(systemName: "timer")
			}
		}
	}

	/// The running timer that ends soonest, else a paused one.
	private func nextTimer(at date: Date) -> AppTimer? {
		store.timers.filter(\.isRunning).min { $0.remaining(at: date) < $1.remaining(at: date) }
			?? store.timers.first
	}
}


/// Each timer with its controls, then all-timer actions, saved timers and quick starts.
struct MenuBarTimerMenu: View {
	@Environment(TimerStore.self) private var store

	var body: some View {
		let now = Date()

		if store.timers.isEmpty {
			Text("No Timers Running")
		}

		ForEach(store.timers) { timer in
			let remaining = timer.remaining(at: now)
			let isDone = timer.isRunning && remaining <= 0
			let status = isDone ? timer.kind.doneText : timer.isRunning ? "\(remaining.timerText) left" : "Paused · \(remaining.timerText)"

			Menu("\(timer.displayLabel) — \(status)") {
				if !isDone {
					Button(timer.isRunning ? "Pause" : "Resume", systemImage: timer.isRunning ? "pause.fill" : "play.fill") {
						timer.isRunning ? store.pause(id: timer.id) : store.resume(id: timer.id)
					}
				}
				Button("Add 1 Minute", systemImage: "plus") { store.addTime(60, to: timer.id) }
				if isDone {
					Button("Repeat", systemImage: "repeat") { store.restart(id: timer.id) }
				}
				Divider()
				Button(isDone ? "Stop" : "Cancel", systemImage: "xmark", role: .destructive) { store.cancel(id: timer.id) }
			}
		}

		if store.timers.count > 1 {
			Divider()
			if store.hasRunningTimers {
				Button("Pause All", systemImage: "pause.fill") { store.pauseAll() }
			} else {
				Button("Resume All", systemImage: "play.fill") { store.resumeAll() }
			}
			Button("Cancel All", systemImage: "xmark") { store.cancelAll() }
		}

		if !store.saved.isEmpty {
			Divider()
			Section("Saved") {
				ForEach(store.saved) { preset in
					Button("\(preset.displayName) · \(preset.duration.timerText)") { store.start(preset) }
				}
			}
		}

		Divider()
		Section("Quick Start") {
			ForEach(store.quickStarts.filter { !store.isSaved($0) }.prefix(6)) { preset in
				Button(preset.label.isEmpty ? preset.duration.durationLabel : "\(preset.label) · \(preset.duration.timerText)") {
					store.start(preset)
				}
			}
		}

		Divider()
		Button("Open ClockMe") {
			NSApplication.shared.activate()
			NSApplication.shared.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
		}
	}
}
#endif
