//
//  StopwatchView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif


struct StopwatchView: View {
	/// Keyboard shortcuts only work while this is the selected tab.
	var isSelected = true

	@Environment(TimerStore.self) private var store
	@State private var showingHistory = false
	@State private var showingFocus = false

	var body: some View {
		let stopwatch = store.stopwatch
		let hasTime = stopwatch.isRunning || stopwatch.accumulated > 0
		let keepsAwake = stopwatch.isRunning && AppSettings.shared.stopwatchKeepsScreenAwake
		let shortcutsEnabled = isSelected && !showingFocus && !showingHistory

		NavigationStack {
			ScrollView {
				VStack(spacing: 20) {
					TimelineView(.animation(paused: !stopwatch.isRunning)) { context in
						StopwatchDial(
							elapsed: stopwatch.elapsed(at: context.date),
							currentLap: stopwatch.currentLap(at: context.date),
							laps: stopwatch.laps
						)
					}
					.frame(maxWidth: 360)
					.padding(.top, 8)

					StopwatchControls(keyboardShortcuts: shortcutsEnabled)

					if stopwatch.laps.count >= 2 {
						LapStatsRow(laps: stopwatch.laps)
						LapChart(laps: stopwatch.laps)
					}

					if !stopwatch.laps.isEmpty {
						TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !stopwatch.isRunning)) { context in
							LapList(laps: stopwatch.laps, currentLap: stopwatch.currentLap(at: context.date))
						}
					}
				}
				.padding(16)
				.animation(.smooth, value: stopwatch.laps.count)
			}
			.overlay(alignment: .bottom) {
				UndoResetToast(keyboardShortcuts: shortcutsEnabled)
					.padding(.bottom, 16)
			}
			.background(AuroraBackground())
			.navigationTitle("Stopwatch")
			.localTimeSubtitle()
			.settingsButton(section: .stopwatch)
			.onChange(of: keepsAwake, initial: true) { _, keepsAwake in
				ScreenAwake.set(keepsAwake)
			}
			.onDisappear {
				ScreenAwake.set(false)
			}
			.toolbar {
				ToolbarItem(placement: .barLeading) {
					Button {
						showingHistory = true
					} label: {
						Image(systemName: "clock.arrow.circlepath")
					}
					.accessibilityLabel("History")
				}
				if hasTime && !stopwatch.isRunning {
					ToolbarItem(placement: .barTrailing) {
						ShareLink(item: stopwatch.summary(at: Date()))
					}
				}
				ToolbarItem(placement: .barTrailing) {
					Button {
						showingFocus = true
					} label: {
						Image(systemName: "arrow.up.left.and.arrow.down.right")
					}
					.keyboardShortcut(shortcutsEnabled ? KeyboardShortcut("f", modifiers: []) : nil)
					.help("Focus (F)")
					.accessibilityLabel("Focus")
				}
			}
			.sheet(isPresented: $showingHistory) {
				StopwatchHistoryView()
			}
			.fullScreenOrSheet(isPresented: $showingFocus) {
				StopwatchFocusView()
			}
		}
	}
}


/// Lap / Reset and Start / Stop. With a keyboard: Space starts and stops, L laps, R resets.
struct StopwatchControls: View {
	var keyboardShortcuts = true

	@Environment(TimerStore.self) private var store

	private let startColor = ClockItPalette.color(named: "mint")
	private let stopColor = ClockItPalette.color(named: "rose")

	var body: some View {
		let stopwatch = store.stopwatch
		let hasTime = stopwatch.isRunning || stopwatch.accumulated > 0
		let lapCount: Int = stopwatch.laps.count

		GlassGroup(spacing: 40) {
			HStack {
				roundButton(
					title: stopwatch.isRunning || !hasTime ? "Lap" : "Reset",
					shortcut: stopwatch.isRunning || !hasTime ? "L" : "R",
					tint: nil,
					action: {
						if stopwatch.isRunning { store.lap() } else { store.resetStopwatch() }
					}
				)
				.keyboardShortcut(keyboardShortcuts ? KeyboardShortcut(stopwatch.isRunning ? "l" : "r", modifiers: []) : nil)
				.help(stopwatch.isRunning ? "Lap (L)" : "Reset (R)")
				.disabled(!hasTime)
				.opacity(hasTime ? 1 : 0.5)

				Spacer()

				roundButton(
					title: stopwatch.isRunning ? "Stop" : "Start",
					shortcut: "Space",
					tint: stopwatch.isRunning ? stopColor : startColor,
					action: {
						if stopwatch.isRunning { store.stopStopwatch() } else { store.startStopwatch() }
					}
				)
				.keyboardShortcut(keyboardShortcuts ? KeyboardShortcut(.space, modifiers: []) : nil)
				.help(stopwatch.isRunning ? "Stop (Space)" : "Start (Space)")
			}
			.padding(.horizontal, 24)
		}
		.sensoryFeedback(.impact(weight: .medium), trigger: stopwatch.isRunning)
		.sensoryFeedback(.selection, trigger: lapCount)
	}

	/// `shortcut` is the key printed under the title on the Mac.
	private func roundButton(title: String, shortcut: String, tint: Color?, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			VStack(spacing: 2) {
				Text(title)
					.font(.headline)
					.contentTransition(.interpolate)
				#if os(macOS)
				if keyboardShortcuts {
					Text(shortcut)
						.font(.caption2.weight(.medium))
						.opacity(0.6)
						.contentTransition(.interpolate)
				}
				#endif
			}
			.foregroundStyle(tint == nil ? Color.primary : .white)
			.frame(width: 84, height: 84)
		}
		.buttonStyle(.plain)
		.softGlass(tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(), in: .circle)
	}
}


/// "Run saved" with an Undo button for a few seconds after Reset.
struct UndoResetToast: View {
	var keyboardShortcuts = true

	@Environment(TimerStore.self) private var store

	var body: some View {
		Group {
			if let reset = store.lastReset {
				HStack(spacing: 14) {
					Label("Run saved to History", systemImage: "checkmark.circle.fill")
						.font(.subheadline.weight(.medium))
					Button("Undo") {
						withAnimation(.smooth) { store.undoReset() }
					}
					.font(.subheadline.weight(.semibold))
					.keyboardShortcut(keyboardShortcuts ? KeyboardShortcut("z", modifiers: .command) : nil)
					.buttonStyle(.plain)
					.foregroundStyle(Theme.accent)
				}
				.padding(.horizontal, 18)
				.padding(.vertical, 12)
				.softGlass(.regular, in: .capsule)
				.transition(.move(edge: .bottom).combined(with: .opacity))
				.task(id: reset.id) {
					try? await Task.sleep(for: .seconds(6))
					withAnimation(.smooth) { store.dismissUndo(reset.id) }
				}
			}
		}
		.animation(.smooth, value: store.lastReset)
	}
}


#Preview {
	StopwatchView()
		.environment(TimerStore.preview)
}


/// Keeps the display from sleeping while the stopwatch runs.
private enum ScreenAwake {
	#if os(macOS)
	private static var activity: NSObjectProtocol?
	#endif

	static func set(_ awake: Bool) {
		#if canImport(UIKit) && !os(watchOS)
		UIApplication.shared.isIdleTimerDisabled = awake
		#elseif os(macOS)
		if awake, activity == nil {
			activity = ProcessInfo.processInfo.beginActivity(options: .idleDisplaySleepDisabled, reason: "Stopwatch running")
		} else if !awake, let current = activity {
			ProcessInfo.processInfo.endActivity(current)
			activity = nil
		}
		#endif
	}
}
