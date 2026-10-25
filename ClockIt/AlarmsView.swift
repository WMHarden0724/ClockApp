//
//  AlarmsView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI



struct AlarmsView: View {
	@Environment(ClockStore.self) private var store
	@State private var editing: EditorTarget?

	private struct EditorTarget: Identifiable {
		let id = UUID()
		let alarm: AppAlarm?
	}

	var body: some View {
		NavigationStack {
			List {
				if !store.alarms.isEmpty {
					NextAlarmCard(next: store.nextAlarm)
						.glassListRow()
						.padding(.bottom, 8)
				}

				ForEach(store.alarms) { alarm in
					AlarmRow(alarm: alarm, isEnabled: Binding(
						get: { alarm.isEnabled },
						set: { store.setEnabled($0, for: alarm.id) }
					))
					.contentShape(.rect(cornerRadius: Theme.cornerRadius))
					.onTapGesture {
						editing = EditorTarget(alarm: alarm)
					}
					.glassListRow()
				}
				.onDelete(perform: store.deleteAlarms)
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
				}
			}
			.animation(.smooth, value: store.alarms.map(\.id))
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
				}
			}
			.sheet(item: $editing) { target in
				AlarmEditorView(
					alarm: target.alarm,
					onSave: { store.save($0) },
					onDelete: target.alarm.map { alarm in { store.deleteAlarm(id: alarm.id) } }
				)
			}
		}
	}
}


#Preview {
	AlarmsView()
		.environment(ClockStore.preview)
}
