//
//  StopwatchDial.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// Chronograph-style glass dial: sweeping second hand with a comet trail, a minutes sub-dial,
/// a pace ring comparing this lap to your best, and a precise digital readout.
struct StopwatchDial: View {
	let elapsed: TimeInterval
	let currentLap: TimeInterval
	let laps: [TimeInterval]

	private let fast = ClockItPalette.color(named: "mint")
	private let slow = ClockItPalette.color(named: "rose")
	private let lapColor = ClockItPalette.color(named: "peach")

	var body: some View {
		GeometryReader { geo in
			let side = min(geo.size.width, geo.size.height)
			let radius = side / 2
			let seconds = elapsed.truncatingRemainder(dividingBy: 60) / 60
			let parts = elapsed.stopwatchParts

			ZStack {
				face(radius: radius, seconds: seconds)

				paceRing

				SubDial(fraction: (elapsed / 60).truncatingRemainder(dividingBy: 30) / 30, ticks: 30, label: "MIN", tint: lapColor)
					.frame(width: side * 0.26, height: side * 0.26)
					.offset(y: -side * 0.2)

				VStack(spacing: 6) {
					HStack(alignment: .firstTextBaseline, spacing: 0) {
						Text(parts.main)
							.font(Theme.clockFont(side * 0.13, weight: .light))
						Text(parts.fraction)
							.font(Theme.clockFont(side * 0.075, weight: .light))
							.foregroundStyle(.secondary)
					}
					.monospacedDigit()

					if !laps.isEmpty {
						Text("Lap \(laps.count + 1)  \(currentLap.stopwatchText)")
							.font(.subheadline.weight(.medium))
							.monospacedDigit()
							.foregroundStyle(lapColor)
					}
				}
				.offset(y: side * 0.2)

				hand(fraction: seconds, length: radius - 26, tail: 18, width: 3, color: Theme.accent)

				Circle()
					.fill(Theme.accent)
					.frame(width: 12, height: 12)
					.overlay(Circle().fill(.white).frame(width: 4, height: 4))
					.shadow(color: Theme.accent.opacity(0.6), radius: 6)
			}
			.frame(width: geo.size.width, height: geo.size.height)
			.softGlass(.regular, in: .circle)
		}
		.aspectRatio(1, contentMode: .fit)
		.accessibilityElement()
		.accessibilityLabel("Elapsed time")
		.accessibilityValue(elapsed.stopwatchText)
	}

	/// Tick marks plus a fading wedge of light that trails the second hand.
	private func face(radius: CGFloat, seconds: Double) -> some View {
		Canvas { context, size in
			let center = CGPoint(x: size.width / 2, y: size.height / 2)
			let trailLength = 0.22
			let end = Angle.degrees(seconds * 360 - 90)
			let start = Angle.degrees((seconds - trailLength) * 360 - 90)

			var wedge = Path()
			wedge.move(to: center)
			wedge.addArc(center: center, radius: radius - 22, startAngle: start, endAngle: end, clockwise: false)
			wedge.closeSubpath()
			context.fill(wedge, with: .conicGradient(
				Gradient(stops: [
					.init(color: Theme.accent.opacity(0), location: 0),
					.init(color: Theme.accent.opacity(0.32), location: trailLength),
					.init(color: Theme.accent.opacity(0), location: trailLength + 0.0001)
				]),
				center: center,
				angle: start
			))

			for tick in 0..<240 {
				let isSecond = tick % 4 == 0
				let isFive = tick % 20 == 0
				let length: CGFloat = isFive ? 14 : (isSecond ? 8 : 4)
				let angle = Double(tick) / 240 * 2 * .pi
				let outer = radius - 16
				let inner = outer - length
				var path = Path()
				path.move(to: CGPoint(x: center.x + outer * sin(angle), y: center.y - outer * cos(angle)))
				path.addLine(to: CGPoint(x: center.x + inner * sin(angle), y: center.y - inner * cos(angle)))
				context.stroke(path, with: .color(.primary.opacity(isFive ? 0.6 : (isSecond ? 0.3 : 0.12))), lineWidth: isFive ? 2 : 1)
			}
		}
	}

	/// Fills as the current lap approaches your best lap time; turns rose once you're slower.
	@ViewBuilder
	private var paceRing: some View {
		if AppSettings.shared.stopwatchShowsPaceRing, let best = laps.min(), best > 0 {
			let pace = currentLap / best
			ZStack {
				Circle()
					.stroke(.primary.opacity(0.06), lineWidth: 4)
				Circle()
					.trim(from: 0, to: min(pace, 1))
					.stroke(pace > 1 ? slow : fast, style: StrokeStyle(lineWidth: 4, lineCap: .round))
					.rotationEffect(.degrees(-90))
					.shadow(color: (pace > 1 ? slow : fast).opacity(0.6), radius: 4)
			}
			.padding(5)
			.animation(.smooth, value: pace > 1)
			.accessibilityLabel(pace > 1 ? "Slower than best lap" : "Ahead of best lap")
		}
	}

	private func hand(fraction: Double, length: CGFloat, tail: CGFloat, width: CGFloat, color: Color) -> some View {
		Capsule()
			.fill(color.gradient)
			.frame(width: width, height: length + tail)
			.shadow(color: color.opacity(0.6), radius: 6)
			.offset(y: -(length - tail) / 2)
			.rotationEffect(.degrees(fraction * 360))
	}
}


/// A small inset dial, like a chronograph's minute counter.
private struct SubDial: View {
	let fraction: Double
	let ticks: Int
	let label: String
	let tint: Color

	var body: some View {
		GeometryReader { geo in
			let radius = min(geo.size.width, geo.size.height) / 2

			ZStack {
				Circle()
					.fill(.primary.opacity(0.04))
				Circle()
					.strokeBorder(.primary.opacity(0.08), lineWidth: 1)

				Canvas { context, size in
					let center = CGPoint(x: size.width / 2, y: size.height / 2)
					for tick in 0..<ticks {
						let isMajor = tick % 5 == 0
						let angle = Double(tick) / Double(ticks) * 2 * .pi
						let outer = radius - 4
						let inner = outer - (isMajor ? 6 : 3)
						var path = Path()
						path.move(to: CGPoint(x: center.x + outer * sin(angle), y: center.y - outer * cos(angle)))
						path.addLine(to: CGPoint(x: center.x + inner * sin(angle), y: center.y - inner * cos(angle)))
						context.stroke(path, with: .color(.primary.opacity(isMajor ? 0.5 : 0.2)), lineWidth: 1)
					}
				}

				Text(label)
					.font(.system(size: radius * 0.24, weight: .semibold, design: .rounded))
					.foregroundStyle(.secondary)
					.offset(y: radius * 0.42)

				Capsule()
					.fill(tint.gradient)
					.frame(width: 2, height: radius - 8)
					.offset(y: -(radius - 8) / 2)
					.rotationEffect(.degrees(fraction * 360))

				Circle()
					.fill(tint)
					.frame(width: 5, height: 5)
			}
			.frame(width: geo.size.width, height: geo.size.height)
		}
		.accessibilityHidden(true)
	}
}


#Preview {
	StopwatchDial(elapsed: 151.42, currentLap: 20.4, laps: [24.81, 22.17, 24.42, 59.6])
		.padding()
		.background(AuroraBackground())
}
