//
//  WakeMissionView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

#if os(iOS)
import CoreMotion
import SwiftUI


/// Opens when you stop an alarm with a wake-up mission. The alarm rings again every minute
/// until the mission is done.
struct WakeMissionView: View {
	let mission: ClockStore.ActiveMission
	@Environment(ClockStore.self) private var store

	var body: some View {
		VStack(spacing: 28) {
			VStack(spacing: 8) {
				Image(systemName: mission.type.symbol)
					.font(.system(size: 44, weight: .semibold))
					.foregroundStyle(Theme.accent)
				Text(mission.label)
					.font(.title2.weight(.bold))
				Text("Finish this to turn the alarm off. It rings again in a minute if you don't.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}

			switch mission.type {
			case .math:
				MathMission { store.completeMission() }
			case .shake:
				ShakeMission { store.completeMission() }
			case .none:
				Color.clear.onAppear { store.completeMission() }
			}

			Spacer(minLength: 0)
		}
		.padding(24)
		.padding(.top, 40)
		.background(AuroraBackground())
		.interactiveDismissDisabled()
	}
}


/// Three arithmetic problems, typed on the number pad.
private struct MathMission: View {
	let onDone: () -> Void

	@State private var problem = MathProblem.random()
	@State private var solved = 0
	@State private var answer = ""
	@State private var wrong = 0
	@FocusState private var focused: Bool

	private let needed = 3

	var body: some View {
		VStack(spacing: 20) {
			Text("\(solved + 1) of \(needed)")
				.font(.headline)
				.foregroundStyle(.secondary)

			Text(problem.question)
				.font(Theme.clockFont(56, weight: .regular))
				.monospacedDigit()

			TextField("Answer", text: $answer)
				.keyboardType(.numberPad)
				.font(Theme.clockFont(40, weight: .regular))
				.multilineTextAlignment(.center)
				.padding(.vertical, 12)
				.softGlass(.regular, in: .capsule)
				.focused($focused)
				.onChange(of: answer) { _, text in
					guard Int(text) == problem.answer else { return }
					solved += 1
					answer = ""
					if solved >= needed { onDone() } else { problem = .random() }
				}

			Button("Check") {
				if Int(answer) != problem.answer {
					wrong += 1
					answer = ""
				}
			}
			.glassProminentButton()
			.disabled(answer.isEmpty)
		}
		.sensoryFeedback(.success, trigger: solved)
		.sensoryFeedback(.error, trigger: wrong)
		.onAppear { focused = true }
	}
}


private struct MathProblem {
	let question: String
	let answer: Int

	static func random() -> MathProblem {
		if Bool.random() {
			let a = Int.random(in: 12...79), b = Int.random(in: 12...79)
			return MathProblem(question: "\(a) + \(b)", answer: a + b)
		}
		let a = Int.random(in: 3...12), b = Int.random(in: 6...19)
		return MathProblem(question: "\(a) × \(b)", answer: a * b)
	}
}


/// Thirty good shakes, counted with the accelerometer.
private struct ShakeMission: View {
	let onDone: () -> Void

	@State private var shakes = 0
	@State private var motion = CMMotionManager()
	@State private var lastShake = Date.distantPast

	private let needed = 30

	var body: some View {
		VStack(spacing: 24) {
			ZStack {
				Circle()
					.stroke(Theme.accent.opacity(0.2), lineWidth: 14)
				Circle()
					.trim(from: 0, to: Double(shakes) / Double(needed))
					.stroke(Theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
					.rotationEffect(.degrees(-90))
				Text("\(max(0, needed - shakes))")
					.font(Theme.clockFont(64, weight: .regular))
					.monospacedDigit()
					.contentTransition(.numericText(countsDown: true))
			}
			.frame(width: 200, height: 200)
			.animation(.snappy, value: shakes)

			Text("Shake your phone")
				.font(.title3.weight(.semibold))
		}
		.sensoryFeedback(.impact(weight: .light), trigger: shakes)
		.onAppear(perform: start)
		.onDisappear { motion.stopAccelerometerUpdates() }
	}

	private func start() {
		guard motion.isAccelerometerAvailable else {
			onDone() // nothing to shake with; don't trap anyone
			return
		}
		motion.accelerometerUpdateInterval = 1.0 / 30
		motion.startAccelerometerUpdates(to: .main) { data, _ in
			guard let a = data?.acceleration else { return }
			let force = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
			let now = Date()
			guard force > 2.2, now.timeIntervalSince(lastShake) > 0.15 else { return }
			lastShake = now
			shakes += 1
			if shakes >= needed {
				motion.stopAccelerometerUpdates()
				onDone()
			}
		}
	}
}
#endif
