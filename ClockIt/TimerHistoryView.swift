//
//  TimerHistoryView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// Finished and cancelled timers by day, so "what did I set for the rice last time?" has an answer.
/// Tap one to run it again.
struct TimerHistoryView: View {
	@Environment(TimerStore.self) private var store
	@Environment(\.dismiss) private var dismiss
	@State private var search = ""
	@State private var confirmingClear = false

	private var records: [TimerRecord] {
		guard !search.isEmpty else { return store.timerHistory }
		return store.timerHistory.filter {
			$0.preset.displayName.localizedCaseInsensitiveContains(search) || $0.preset.kind.title.localizedCaseInsensitiveContains(search)
		}
	}

	private var days: [(day: Date, records: [TimerRecord])] {
		let grouped = Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.endedAt) }
		return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
	}

	var body: some View {
		NavigationStack {
			List {
				ForEach(days, id: \.day) { day in
					Section(day.day.formatted(.relative(presentation: .named, unitsStyle: .wide)).capitalized) {
						ForEach(day.records) { record in
							row(record)
						}
						.onDelete { offsets in
							store.deleteTimerRecords(Set(offsets.map { day.records[$0].id }))
						}
					}
				}
			}
			.overlay {
				if store.timerHistory.isEmpty {
					ContentUnavailableView("No Timers Yet", systemImage: "clock.arrow.circlepath", description: Text("Timers you finish or cancel show up here."))
				} else if records.isEmpty {
					ContentUnavailableView.search(text: search)
				}
			}
			.searchable(text: $search, placement: .drawer, prompt: "Rice, laundry, tea…")
			.navigationTitle("Timer History")
			.inlineNavigationTitle()
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
				if !store.timerHistory.isEmpty {
					ToolbarItem(placement: .destructiveAction) {
						Button("Clear", role: .destructive) { confirmingClear = true }
					}
				}
			}
			.confirmationDialog("Clear timer history?", isPresented: $confirmingClear) {
				Button("Clear History", role: .destructive) { store.clearTimerHistory() }
			}
		}
		#if os(macOS)
		.frame(minWidth: 460, minHeight: 520)
		#endif
	}

	private func row(_ record: TimerRecord) -> some View {
		let preset = record.preset
		let color = ClockItPalette.color(named: preset.colorName)

		return Button {
			store.start(preset)
			dismiss()
		} label: {
			HStack(spacing: 12) {
				Image(systemName: preset.isSequence ? "list.bullet" : preset.kind.symbol)
					.font(.body.weight(.semibold))
					.foregroundStyle(color)
					.frame(width: 32, height: 32)
					.background(color.opacity(0.15), in: .circle)

				VStack(alignment: .leading, spacing: 2) {
					Text(preset.label.isEmpty ? preset.kind.title : preset.label)
						.font(.body.weight(.medium))
					Text("\(record.completed ? "Finished" : "Cancelled") \(record.endedAt.timeText)")
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Spacer()

				Text(preset.duration.durationLabel)
					.font(.subheadline.weight(.semibold))
					.monospacedDigit()
					.foregroundStyle(record.completed ? .primary : .secondary)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.contextMenu {
			Button("Start Again", systemImage: "play.fill") {
				store.start(preset)
				dismiss()
			}
			if !store.isSaved(preset) {
				Button("Save", systemImage: "bookmark") { store.save(preset) }
			}
			Button("Delete", systemImage: "trash", role: .destructive) {
				store.deleteTimerRecords([record.id])
			}
		}
		.accessibilityHint("Starts this timer again")
	}
}


#Preview {
	TimerHistoryView()
		.environment(TimerStore.preview)
}
