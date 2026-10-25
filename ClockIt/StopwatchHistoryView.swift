//
//  StopwatchHistoryView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// Past stopwatch runs, saved automatically whenever the stopwatch is reset.
struct StopwatchHistoryView: View {
	@Environment(TimerStore.self) private var store
	@Environment(\.dismiss) private var dismiss
	@State private var confirmingClear = false

	var body: some View {
		NavigationStack {
			List {
				ForEach(store.history) { session in
					NavigationLink {
						SessionDetailView(session: session)
					} label: {
						SessionRow(session: session)
					}
					.glassListRow()
				}
				.onDelete(perform: store.deleteSessions)
			}
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.background(AuroraBackground())
			.overlay {
				if store.history.isEmpty {
					ContentUnavailableView(
						"No History Yet",
						systemImage: "stopwatch",
						description: Text("Runs are saved here when you reset the stopwatch.")
					)
				}
			}
			.navigationTitle("History")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
				if !store.history.isEmpty {
					ToolbarItem(placement: .topBarLeading) {
						Button("Clear", role: .destructive) { confirmingClear = true }
					}
				}
			}
			.confirmationDialog("Clear all stopwatch history?", isPresented: $confirmingClear, titleVisibility: .visible) {
				Button("Clear History", role: .destructive) { store.clearHistory() }
			}
		}
	}
}


private struct SessionRow: View {
	let session: StopwatchSession

	var body: some View {
		let stats = LapStats(laps: session.laps)

		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(session.total.stopwatchText)
					.font(Theme.clockFont(30))
					.monospacedDigit()

				Text(session.date.formatted(.relative(presentation: .named)))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer()

			VStack(alignment: .trailing, spacing: 4) {
				if !session.laps.isEmpty {
					Text("\(session.laps.count) laps")
						.font(.subheadline.weight(.medium))
				}
				if let best = stats.best {
					Label(best.stopwatchText, systemImage: "hare.fill")
						.font(.caption)
						.monospacedDigit()
						.foregroundStyle(LapColors.fast)
				}
			}
		}
		.glassCard(padding: 16)
	}
}


private struct SessionDetailView: View {
	let session: StopwatchSession

	var body: some View {
		ScrollView {
			VStack(spacing: 16) {
				VStack(spacing: 4) {
					Text(session.total.stopwatchText)
						.font(Theme.clockFont(48, weight: .light))
						.monospacedDigit()
					Text(session.date.dateTimeText)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity)
				.glassCard()

				if session.laps.count >= 2 {
					LapStatsRow(laps: session.laps)
					LapChart(laps: session.laps)
				}

				if !session.laps.isEmpty {
					LapList(laps: session.laps)
				}
			}
			.padding(16)
		}
		.background(AuroraBackground())
		.navigationTitle("Run")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				ShareLink(item: summary)
			}
		}
	}

	private var summary: String {
		var lines = ["Stopwatch · \(session.total.stopwatchText) · \(session.date.dateTimeText)"]
		for (index, lap) in session.laps.enumerated() {
			lines.append("Lap \(index + 1)   \(lap.stopwatchText)")
		}
		return lines.joined(separator: "\n")
	}
}
