//
//  StopwatchActivity.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(iOS)
import ActivityKit
import Foundation
import WidgetKit


/// Starts, updates and ends the stopwatch's Live Activity to match the stopwatch.
enum StopwatchActivity {
	static func update(for stopwatch: StopwatchState) {
		updateControl(isRunning: stopwatch.isRunning)

		let hasTime = stopwatch.isRunning || stopwatch.accumulated > 0
		let now = Date()
		let elapsed = stopwatch.elapsed(at: now)
		let currentLap = stopwatch.currentLap(at: now)
		let state = StopwatchActivityAttributes.ContentState(
			isRunning: stopwatch.isRunning,
			runStart: now.addingTimeInterval(-elapsed),
			lapStart: now.addingTimeInterval(-currentLap),
			elapsed: elapsed,
			currentLap: currentLap,
			lapCount: stopwatch.laps.count
		)

		Task {
			let activities = Activity<StopwatchActivityAttributes>.activities
			guard hasTime else {
				for activity in activities {
					await activity.end(nil, dismissalPolicy: .immediate)
				}
				return
			}

			let content = ActivityContent(state: state, staleDate: nil)
			if let activity = activities.first {
				await activity.update(content)
			} else if ActivityAuthorizationInfo().areActivitiesEnabled {
				_ = try? Activity.request(attributes: StopwatchActivityAttributes(), content: content)
			}
		}
	}

	/// Tells the Control Center toggle when the stopwatch starts or stops.
	private static func updateControl(isRunning: Bool) {
		guard StopwatchControlState.isRunning != isRunning else { return }
		StopwatchControlState.isRunning = isRunning
		ControlCenter.shared.reloadControls(ofKind: StopwatchControlState.controlKind)
	}
}
#endif
