//
//  MoonPhase.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// Lunar phase from the date alone (mean synodic month), accurate to well under a day.
enum MoonPhase {
	private static let synodicMonth = 29.530588853 // days
	private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UTC

	/// 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
	static func fraction(at date: Date) -> Double {
		let days = date.timeIntervalSince(referenceNewMoon) / 86_400
		let fraction = (days / synodicMonth).truncatingRemainder(dividingBy: 1)
		return fraction < 0 ? fraction + 1 : fraction
	}

	static func name(for fraction: Double) -> String {
		switch fraction {
		case ..<0.0339: "New Moon"
		case ..<0.216: "Waxing Crescent"
		case ..<0.284: "First Quarter"
		case ..<0.466: "Waxing Gibbous"
		case ..<0.534: "Full Moon"
		case ..<0.716: "Waning Gibbous"
		case ..<0.784: "Last Quarter"
		case ..<0.966: "Waning Crescent"
		default: "New Moon"
		}
	}
}


/// The moon drawn as it actually looks tonight: a full disc at full moon, a sliver at crescent.
struct MoonGlyph: View {
	let phase: Double

	private let litColor = Color(red: 0.98, green: 0.96, blue: 0.88)

	var body: some View {
		Canvas { context, size in
			let radius = min(size.width, size.height) / 2
			let center = CGPoint(x: size.width / 2, y: size.height / 2)

			// The unlit part stays faintly visible, like earthshine.
			context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
						 with: .color(.white.opacity(0.14)))
			context.fill(litPath(center: center, radius: radius), with: .color(litColor))
		}
		.shadow(color: litColor.opacity(0.35 + 0.4 * illumination), radius: 6)
		.accessibilityLabel(MoonPhase.name(for: phase))
	}

	/// 0 at new moon, 1 at full moon.
	private var illumination: Double {
		(1 - cos(2 * .pi * phase)) / 2
	}

	/// Bounded by the bright limb (right side while waxing, left while waning) and the terminator,
	/// an ellipse whose half-width shrinks to zero at the quarters.
	private func litPath(center: CGPoint, radius: CGFloat) -> Path {
		let waxing = phase < 0.5
		let t = CGFloat(cos(2 * .pi * phase)) // 1 at new, 0 at quarters, −1 at full

		var path = Path()
		path.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: !waxing)

		let steps = 48
		for step in 0...steps {
			let y = radius - 2 * radius * CGFloat(step) / CGFloat(steps) // bottom to top
			let halfWidth = sqrt(max(0, radius * radius - y * y))
			let x = waxing ? t * halfWidth : -t * halfWidth
			path.addLine(to: CGPoint(x: center.x + x, y: center.y + y))
		}
		path.closeSubpath()
		return path
	}
}


#Preview {
	HStack(spacing: 12) {
		ForEach([0.0, 0.12, 0.25, 0.38, 0.5, 0.62, 0.75, 0.88], id: \.self) { phase in
			MoonGlyph(phase: phase)
				.frame(width: 32, height: 32)
		}
	}
	.padding()
	.background(.black)
}
