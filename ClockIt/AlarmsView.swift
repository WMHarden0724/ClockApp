//
//  AlarmsView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI



struct AlarmsView: View {
	/// Keyboard shortcuts only work while this is the selected tab.
	var isSelected = true

	@Environment(ClockStore.self) private var store
	@State private var editing: EditorTarget?
	@State private var choosingPauseDate = false

	private struct EditorTarget: Identifiable {
		let id = UUID()
		let alarm: AppAlarm?
	}

	/// Ungrouped alarms first, then each group in order.
	private var sections: [(group: String?, alarms: [AppAlarm])] {
		let ungrouped = store.alarms.filter { ($0.group ?? "").isEmpty }
		let grouped = store.groups.map { name in (Optional(name), store.alarms.filter { $0.group == name }) }
		return (ungrouped.isEmpty ? [] : [(nil, ungrouped)]) + grouped
	}

	var body: some View {
		NavigationStack {
			List {
				if !store.alarms.isEmpty {
					if store.isPaused, let until = store.pausedUntil {
						PausedBanner(until: until) { store.resumeAlarms() }
							.glassListRow()
					}

					NextAlarmCard(next: store.nextAlarm)
						.glassListRow()
				}

				QuickAlarmBar()
					.glassListRow()
					.padding(.bottom, 8)

				ForEach(sections, id: \.group) { section in
					Section {
						ForEach(section.alarms) { alarm in
							row(alarm)
						}
						.onDelete { offsets in
							for index in offsets { store.deleteAlarm(id: section.alarms[index].id) }
						}
					} header: {
						if let group = section.group {
							GroupHeader(name: group, isOn: Binding(
								get: { store.isGroupEnabled(group) },
								set: { store.setGroupEnabled($0, group: group) }
							))
						}
					}
				}
			}
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.background(AuroraBackground())
			.overlay {
				if store.alarms.isEmpty {
					ContentUnavailableView {
						Label("No Alarms", systemImage: "alarm.fill")
					} description: {
						Text("Create alarms that can target a specific date or repeat on the days you choose.")
					} actions: {
						Button("New Alarm") {
							editing = EditorTarget(alarm: nil)
						}
						.glassProminentButton()
					}
					.padding(.top, 160)
				}
			}
			.animation(.smooth, value: store.alarms.map(\.id))
			.animation(.smooth, value: store.pausedUntil)
			.navigationTitle("Alarms")
			.localTimeSubtitle()
			.settingsButton(section: .alarms)
			.toolbar {
				ToolbarItem(placement: .barTrailing) {
					Button {
						editing = EditorTarget(alarm: nil)
					} label: {
						Image(systemName: "plus")
					}
					.keyboardShortcut(isSelected ? KeyboardShortcut("n", modifiers: .command) : nil)
					.help("New Alarm (⌘N)")
				}
				ToolbarItem(placement: .barLeading) {
					Menu {
						if store.isPaused {
							Button("Resume Alarms", systemImage: "play.fill") { store.resumeAlarms() }
						} else {
							Button("Pause All Alarms…", systemImage: "pause.circle") { choosingPauseDate = true }
						}
					} label: {
						Image(systemName: store.isPaused ? "pause.circle.fill" : "ellipsis.circle")
					}
					.accessibilityLabel("More")
				}
			}
			.sheet(item: $editing) { target in
				AlarmEditorView(
					alarm: target.alarm,
					onSave: { store.save($0) },
					onDelete: target.alarm.map { alarm in { store.deleteAlarm(id: alarm.id) } }
				)
			}
			.sheet(isPresented: $choosingPauseDate) {
				PauseAlarmsSheet { store.pauseAlarms(until: $0) }
			}
		}
	}

	private func row(_ alarm: AppAlarm) -> some View {
		let number = store.alarms.firstIndex { $0.id == alarm.id }.map { $0 + 1 }.flatMap { $0 <= 9 ? $0 : nil }

		return AlarmRow(
			alarm: alarm,
			isEnabled: Binding(
				get: { alarm.isEnabled },
				set: { store.setEnabled($0, for: alarm.id) }
			),
			isGroupOff: !(alarm.group.map(store.isGroupEnabled) ?? true),
			shortcutHint: isSelected ? number.map { "⌘\($0)" } : nil
		)
		.contentShape(.rect(cornerRadius: Theme.cornerRadius))
		.onTapGesture {
			editing = EditorTarget(alarm: alarm)
		}
		.contextMenu {
			if alarm.isSkipping {
				Button("Don't Skip", systemImage: "arrow.uturn.backward") { store.cancelSkip(id: alarm.id) }
			} else if alarm.isEnabled && !alarm.isOneTime {
				Button("Skip Next", systemImage: "forward.end") { store.skipNext(id: alarm.id) }
			}
			Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicate(id: alarm.id) }
			Divider()
			Button("Delete", systemImage: "trash", role: .destructive) { store.deleteAlarm(id: alarm.id) }
		}
		.background {
			// ⌘1–9 switch the alarms on and off on the Mac.
			if isSelected, let number {
				Button("") { store.setEnabled(!alarm.isEnabled, for: alarm.id) }
					.keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
					.hidden()
			}
		}
		.glassListRow()
	}
}


/// One tap for a nap, a reminder to leave, or tomorrow at your usual time.
private struct QuickAlarmBar: View {
	@Environment(ClockStore.self) private var store

	var body: some View {
		let usual = store.usualWakeTime

		ScrollView(.horizontal) {
			GlassGroup(spacing: 8) {
				HStack(spacing: 8) {
					chip("20 min", systemImage: "bed.double.fill", label: "Nap") { Date().addingTimeInterval(20 * 60 + 59) }
					chip("1 hr", systemImage: "clock", label: "Quick Alarm") { Date().addingTimeInterval(3600 + 59) }
					chip("2 hr", systemImage: "clock", label: "Quick Alarm") { Date().addingTimeInterval(7200 + 59) }
					chip(usualText(usual), systemImage: "sunrise.fill", label: "Wake Up") {
						var parts = DateComponents()
						parts.hour = usual.hour
						parts.minute = usual.minute
						return Calendar.current.nextDate(after: Date(), matching: parts, matchingPolicy: .nextTime) ?? Date()
					}
				}
				.padding(.horizontal, 4)
			}
		}
		.scrollIndicators(.hidden)
	}

	private func usualText(_ usual: (hour: Int, minute: Int)) -> String {
		let date = Calendar.current.date(from: DateComponents(hour: usual.hour, minute: usual.minute)) ?? Date()
		return "Next \(date.timeText)"
	}

	private func chip(_ title: String, systemImage: String, label: String, date: @escaping () -> Date) -> some View {
		Button {
			store.addQuickAlarm(at: date(), label: label)
		} label: {
			Label(title, systemImage: systemImage)
				.font(.subheadline.weight(.semibold))
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
		}
		.buttonStyle(.plain)
		.softGlass(.regular.interactive(), in: .capsule)
		.accessibilityHint("Sets a one-time alarm that goes away after it rings")
	}
}


private struct GroupHeader: View {
	let name: String
	@Binding var isOn: Bool

	var body: some View {
		HStack {
			Label(name, systemImage: "square.stack")
				.font(.headline)
				.foregroundStyle(.primary)
			Spacer()
			Toggle(name, isOn: $isOn)
				.labelsHidden()
				.tint(Theme.accent)
		}
		.padding(.horizontal, 8)
		.padding(.top, 8)
	}
}


private struct PausedBanner: View {
	let until: Date
	let onResume: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: "pause.circle.fill")
				.font(.title2)
				.foregroundStyle(Theme.accent)
			VStack(alignment: .leading, spacing: 2) {
				Text("Alarms paused")
					.font(.headline)
				Text("Back on \(until.formatted(date: .complete, time: .omitted))")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			Spacer()
			Button("Resume", action: onResume)
				.glassButton()
		}
		.glassCard(tint: Theme.accent.opacity(0.12))
	}
}


/// Vacation mode: pick the day alarms come back.
private struct PauseAlarmsSheet: View {
	let onPause: (Date) -> Void
	@Environment(\.dismiss) private var dismiss
	@State private var until = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 16) {
				Text("No alarms ring until the day you pick. They switch back on by themselves, so you won't forget.")
					.foregroundStyle(.secondary)
				DatePicker("Back on", selection: $until, in: Date()..., displayedComponents: .date)
					.datePickerStyle(.graphical)
					.tint(Theme.accent)
				Spacer()
			}
			.padding(20)
			.navigationTitle("Pause All Alarms")
			.inlineNavigationTitle()
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Pause") {
						onPause(Calendar.current.startOfDay(for: until))
						dismiss()
					}
				}
			}
		}
		#if os(macOS)
		.frame(minWidth: 380, minHeight: 480)
		#endif
	}
}


#Preview {
	AlarmsView()
		.environment(ClockStore.preview)
}
