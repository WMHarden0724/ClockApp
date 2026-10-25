//
//  RadarDial.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// The stopwatch as a radar scope: a phosphor beam sweeps once a minute like a second hand,
/// and each lap is a blip that lights up as the beam passes, then fades.
struct RadarDial: View {
	let elapsed: TimeInterval
	let currentLap: TimeInterval
	let laps: [TimeInterval]

	private static let phosphor = Color(red: 0.35, green: 1.0, blue: 0.55)
	private static let deep = Color(red: 0.01, green: 0.09, blue: 0.04)

	var body: some View {
		GeometryReader { geo in
			let side = min(geo.size.width, geo.size.height)
			let parts = elapsed.stopwatchParts

			ZStack {
				Canvas { context, size in
					draw(in: &context, size: size)
				}

				VStack(spacing: 4) {
					HStack(alignment: .firstTextBaseline, spacing: 0) {
						Text(parts.main)
							.font(.system(size: side * 0.12, weight: .medium, design: .monospaced))
						Text(parts.fraction)
							.font(.system(size: side * 0.07, weight: .medium, design: .monospaced))
							.opacity(0.7)
					}
					if !laps.isEmpty {
						Text("LAP \(laps.count + 1)  \(currentLap.stopwatchText)")
							.font(.system(size: side * 0.045, weight: .semibold, design: .monospaced))
							.opacity(0.75)
					}
				}
				.foregroundStyle(Self.phosphor)
				.shadow(color: Self.phosphor.opacity(0.8), radius: 6)
				.padding(.horizontal, side * 0.1)
				.padding(.vertical, side * 0.03)
				.background(Self.deep.opacity(0.5), in: .capsule)
				.offset(y: side * 0.22)
			}
			.frame(width: geo.size.width, height: geo.size.height)
		}
		.aspectRatio(1, contentMode: .fit)
		.accessibilityElement()
		.accessibilityLabel("Elapsed time")
		.accessibilityValue(elapsed.stopwatchText)
	}

	private func draw(in context: inout GraphicsContext, size: CGSize) {
		let center = CGPoint(x: size.width / 2, y: size.height / 2)
		let radius = min(size.width, size.height) / 2
		let scope = radius - 6
		let phosphor = Self.phosphor
		let sweep = elapsed.truncatingRemainder(dividingBy: 60) / 60 // 0...1, 12 o'clock clockwise

		// The glass of the scope.
		let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
		context.fill(disc, with: .radialGradient(
			Gradient(colors: [Color(red: 0.03, green: 0.2, blue: 0.09), Self.deep, .black]),
			center: center, startRadius: 0, endRadius: radius
		))
		context.stroke(disc, with: .color(phosphor.opacity(0.55)), lineWidth: 2)

		// Range rings and crosshairs.
		for ring in 1...4 {
			let r = scope * CGFloat(ring) / 4
			context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
						   with: .color(phosphor.opacity(ring == 4 ? 0.35 : 0.16)), lineWidth: 1)
		}
		var cross = Path()
		cross.move(to: CGPoint(x: center.x - scope, y: center.y))
		cross.addLine(to: CGPoint(x: center.x + scope, y: center.y))
		cross.move(to: CGPoint(x: center.x, y: center.y - scope))
		cross.addLine(to: CGPoint(x: center.x, y: center.y + scope))
		context.stroke(cross, with: .color(phosphor.opacity(0.14)), lineWidth: 1)

		// Bearing ticks: one per second, longer every five.
		for tick in 0..<60 {
			let angle = Double(tick) / 60 * 2 * .pi
			let length: CGFloat = tick % 5 == 0 ? 10 : 4
			var path = Path()
			path.move(to: point(center, scope, angle))
			path.addLine(to: point(center, scope - length, angle))
			context.stroke(path, with: .color(phosphor.opacity(tick % 5 == 0 ? 0.6 : 0.25)), lineWidth: tick % 5 == 0 ? 1.5 : 1)
		}

		// The beam's fading trail, then its bright leading edge.
		let trail = 0.18
		let start = Angle.degrees((sweep - trail) * 360 - 90)
		let end = Angle.degrees(sweep * 360 - 90)
		var wedge = Path()
		wedge.move(to: center)
		wedge.addArc(center: center, radius: scope, startAngle: start, endAngle: end, clockwise: false)
		wedge.closeSubpath()
		context.fill(wedge, with: .conicGradient(
			Gradient(stops: [
				.init(color: phosphor.opacity(0), location: 0),
				.init(color: phosphor.opacity(0.45), location: trail),
				.init(color: phosphor.opacity(0), location: trail + 0.0001)
			]),
			center: center,
			angle: start
		))
		var beam = Path()
		beam.move(to: center)
		beam.addLine(to: point(center, scope, sweep * 2 * .pi))
		var glow = context
		glow.addFilter(.shadow(color: phosphor, radius: 6))
		glow.stroke(beam, with: .color(phosphor), lineWidth: 2)

		// A blip for each lap, at the bearing where it ended; newer laps sit further out.
		// Each one flares as the beam passes and fades over the rest of the turn.
		let stats = LapStats(laps: laps)
		var total: TimeInterval = 0
		for (index, lap) in laps.enumerated() {
			total += lap
			let bearing = total.truncatingRemainder(dividingBy: 60) / 60
			let behind = (sweep - bearing + 1).truncatingRemainder(dividingBy: 1)
			let glowLevel = 0.25 + 0.75 * pow(1 - behind, 3)
			let range = scope * (0.3 + 0.62 * CGFloat(index + 1) / CGFloat(laps.count + 1))
			let spot = point(center, range, bearing * 2 * .pi)
			let size = 5 + 5 * glowLevel
			let color = stats.best == nil ? phosphor : LapColors.color(for: lap, in: stats)

			var halo = context
			halo.addFilter(.blur(radius: 4))
			halo.fill(Path(ellipseIn: CGRect(x: spot.x - size, y: spot.y - size, width: size * 2, height: size * 2)),
					  with: .color(color.opacity(0.5 * glowLevel)))
			context.fill(Path(ellipseIn: CGRect(x: spot.x - size / 2, y: spot.y - size / 2, width: size, height: size)),
						 with: .color(color.opacity(glowLevel)))
		}

		// The hub.
		context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(phosphor))
	}

	/// A point `distance` from the center at `angle` radians clockwise from 12 o'clock.
	private func point(_ center: CGPoint, _ distance: CGFloat, _ angle: Double) -> CGPoint {
		CGPoint(x: center.x + distance * sin(angle), y: center.y - distance * cos(angle))
	}
}


#Preview {
	RadarDial(elapsed: 151.42, currentLap: 20.4, laps: [24.81, 22.17, 24.42, 59.6])
		.padding()
		.background(AuroraBackground())
}
