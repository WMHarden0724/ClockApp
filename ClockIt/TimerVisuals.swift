//
//  TimerVisuals.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


// MARK: - Ring

struct TimerRing: View {
	let remainingFraction: Double
	let color: Color
	let symbol: String
	var lineWidth: CGFloat = 7
	var isDone = false

	var body: some View {
		ZStack {
			Circle()
				.stroke(color.opacity(0.18), lineWidth: lineWidth)
			Circle()
				.trim(from: 0, to: max(0.001, remainingFraction))
				.stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				.rotationEffect(.degrees(-90))
				.shadow(color: color.opacity(0.5), radius: 4)
			TimerSymbol(symbol: symbol, color: color, isDone: isDone)
		}
	}
}


// MARK: - Pie

/// A disc that fills in clockwise from 12 as the timer runs.
struct TimerPie: View {
	let elapsedFraction: Double
	let color: Color
	let symbol: String
	var isDone = false

	var body: some View {
		ZStack {
			Circle()
				.fill(color.opacity(0.15))
			PieSlice(fraction: isDone ? 1 : elapsedFraction)
				.fill(color.gradient)
				.shadow(color: color.opacity(0.4), radius: 4)
			Circle()
				.strokeBorder(color.opacity(0.35), lineWidth: 1.5)
			TimerSymbol(symbol: symbol, color: elapsedFraction > 0.5 || isDone ? .white : color, isDone: isDone)
		}
	}
}


struct PieSlice: Shape {
	var fraction: Double

	var animatableData: Double {
		get { fraction }
		set { fraction = newValue }
	}

	func path(in rect: CGRect) -> Path {
		let radius = min(rect.width, rect.height) / 2
		let center = CGPoint(x: rect.midX, y: rect.midY)
		var path = Path()
		guard fraction > 0 else { return path }
		if fraction >= 1 {
			return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
		}
		path.move(to: center)
		path.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
		path.closeSubpath()
		return path
	}
}


// MARK: - Analog

/// A kitchen-timer face: minutes 0–55 around the edge and a colored wedge
/// from 12 to the minutes remaining. Over an hour, the wedge is full and a badge shows the extra hours.
struct AnalogTimerFace: View {
	let remaining: TimeInterval
	let color: Color
	var showsKnob = false

	var body: some View {
		GeometryReader { geo in
			let side = min(geo.size.width, geo.size.height)
			let radius = side / 2
			let minutes = remaining / 60
			let wedge = min(minutes, 60) / 60
			let wedgeRadius = radius * 0.72
			let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

			ZStack {
				Circle()
					.fill(.background.opacity(0.35))

				Canvas { context, size in
					let c = CGPoint(x: size.width / 2, y: size.height / 2)
					for tick in 0..<60 {
						let isMajor = tick % 5 == 0
						let angle = Double(tick) / 60 * 2 * .pi
						let outer = radius - 3
						let inner = outer - (isMajor ? radius * 0.09 : radius * 0.045)
						var path = Path()
						path.move(to: CGPoint(x: c.x + outer * sin(angle), y: c.y - outer * cos(angle)))
						path.addLine(to: CGPoint(x: c.x + inner * sin(angle), y: c.y - inner * cos(angle)))
						context.stroke(path, with: .color(.primary.opacity(isMajor ? 0.55 : 0.2)), lineWidth: isMajor ? 1.5 : 1)

						if isMajor && side > 160 {
							let labelRadius = radius * 0.8
							context.draw(
								Text("\(tick)").font(.system(size: radius * 0.12, weight: .semibold, design: .rounded)).foregroundStyle(.secondary),
								at: CGPoint(x: c.x + labelRadius * sin(angle), y: c.y - labelRadius * cos(angle))
							)
						}
					}
				}

				PieSlice(fraction: wedge)
					.fill(color.gradient)
					.frame(width: wedgeRadius * 2, height: wedgeRadius * 2)
					.shadow(color: color.opacity(0.45), radius: 6)

				// The hand sits on the wedge's leading edge.
				Capsule()
					.fill(.white)
					.frame(width: max(2, radius * 0.035), height: wedgeRadius)
					.offset(y: -wedgeRadius / 2)
					.rotationEffect(.degrees(wedge * 360))
					.shadow(color: .black.opacity(0.2), radius: 2)

				if showsKnob {
					Circle()
						.fill(.white)
						.frame(width: radius * 0.11, height: radius * 0.11)
						.shadow(color: color.opacity(0.6), radius: 6)
						.position(
							x: center.x + wedgeRadius * sin(wedge * 2 * .pi),
							y: center.y - wedgeRadius * cos(wedge * 2 * .pi)
						)
				}

				Circle()
					.fill(.white)
					.frame(width: radius * 0.12, height: radius * 0.12)
					.shadow(color: .black.opacity(0.2), radius: 2)

				if minutes > 60 {
					Text("+\(Int(minutes / 60))h")
						.font(.system(size: max(10, radius * 0.14), weight: .bold, design: .rounded))
						.foregroundStyle(.white)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(color, in: .capsule)
						.offset(y: radius * 0.38)
				}
			}
			.frame(width: geo.size.width, height: geo.size.height)
		}
		.aspectRatio(1, contentMode: .fit)
	}
}


/// Drag around the face to set a duration. Each full turn is an hour; up to 12 hours.
struct AnalogTimerPicker: View {
	@Binding var duration: TimeInterval
	let color: Color

	@State private var dragMinutes: Double?
	@State private var lastAngle: Double?

	private var wholeMinutes: Int { Int(duration / 60) }

	var body: some View {
		VStack(spacing: 10) {
			GeometryReader { geo in
				let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

				AnalogTimerFace(remaining: duration, color: color, showsKnob: true)
					.frame(width: geo.size.width, height: geo.size.height)
					.contentShape(Circle())
					.gesture(
						DragGesture(minimumDistance: 0)
							.onChanged { value in
								let angle = angleFromTop(value.location, center: center)
								var minutes = dragMinutes ?? duration / 60
								if let lastAngle {
									var delta = angle - lastAngle
									if delta > .pi { delta -= 2 * .pi }
									if delta < -.pi { delta += 2 * .pi }
									minutes += delta / (2 * .pi) * 60
								} else if duration == 0 {
									// First touch on an empty face jumps straight to that minute.
									minutes = angle / (2 * .pi) * 60
								}
								minutes = min(max(minutes, 0), 720)
								dragMinutes = minutes
								lastAngle = angle
								duration = minutes.rounded() * 60
							}
							.onEnded { _ in
								dragMinutes = nil
								lastAngle = nil
							}
					)
			}
			.aspectRatio(1, contentMode: .fit)
			.frame(maxWidth: 260)

			Text(duration > 0 ? duration.timerText : "Drag to set")
				.font(Theme.clockFont(34))
				.monospacedDigit()
				.contentTransition(.numericText())
				.foregroundStyle(duration > 0 ? .primary : .secondary)
				.animation(.snappy, value: wholeMinutes)
		}
		.sensoryFeedback(.selection, trigger: wholeMinutes)
		.accessibilityElement()
		.accessibilityLabel("Timer duration")
		.accessibilityValue(duration > 0 ? duration.durationLabel : "Not set")
		.accessibilityAdjustableAction { direction in
			switch direction {
			case .increment: duration = min(duration + 60, 720 * 60)
			case .decrement: duration = max(duration - 60, 0)
			@unknown default: break
			}
		}
	}

	/// Radians clockwise from 12 o'clock, 0..<2π.
	private func angleFromTop(_ point: CGPoint, center: CGPoint) -> Double {
		var angle = atan2(Double(point.x - center.x), Double(center.y - point.y))
		if angle < 0 { angle += 2 * .pi }
		return angle
	}
}


// MARK: - Liquid

/// Two drifting waves filling a shape to `level` (0 empty, 1 full).
struct LiquidFill: View {
	let level: Double
	let color: Color
	let phase: Double

	var body: some View {
		ZStack {
			Wave(level: level, phase: phase * 1.3 + 1.7, amplitude: 5)
				.fill(color.opacity(0.25))
			Wave(level: level, phase: phase, amplitude: 7)
				.fill(color.opacity(0.35).gradient)
		}
		.animation(.smooth, value: level)
	}
}


private struct Wave: Shape {
	var level: Double
	var phase: Double
	var amplitude: CGFloat

	var animatableData: Double {
		get { level }
		set { level = newValue }
	}

	func path(in rect: CGRect) -> Path {
		let baseline = rect.maxY - rect.height * CGFloat(min(max(level, 0), 1))
		var path = Path()
		path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
		for x in stride(from: rect.minX, through: rect.maxX, by: 4) {
			let relative = Double((x - rect.minX) / max(rect.width, 1))
			let y = baseline + CGFloat(sin(relative * 2 * .pi * 1.4 + phase)) * amplitude
			path.addLine(to: CGPoint(x: x, y: y))
		}
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
		path.closeSubpath()
		return path
	}
}


// MARK: - Hourglass

/// Sand drains from the top bulb, streams through the neck while running, and piles up below.
struct TimerHourglass: View {
	let remainingFraction: Double
	let color: Color
	let isRunning: Bool
	/// Advances over time to animate the falling stream.
	var phase: Double = 0
	var isDone = false

	var body: some View {
		let sand = Color(red: 0.95, green: 0.80, blue: 0.55).blend(with: color, by: 0.35)
		let remaining = isDone ? 0 : min(max(remainingFraction, 0), 1)

		Canvas { context, size in
			let capHeight = max(3, size.height * 0.06)
			let glassRect = CGRect(x: size.width * 0.1, y: capHeight, width: size.width * 0.8, height: size.height - capHeight * 2)
			let glass = Self.glassPath(in: glassRect)
			let neckY = glassRect.midY
			let bulbDepth = glassRect.height / 2

			context.fill(glass, with: .color(.white.opacity(0.22)))

			var inside = context
			inside.clip(to: glass)

			// Top bulb: sand rests against the neck and its surface drops as time runs out.
			if remaining > 0 {
				let surface = neckY - bulbDepth * 0.88 * remaining
				inside.fill(Path(CGRect(x: glassRect.minX, y: surface, width: glassRect.width, height: neckY - surface)), with: .color(sand))
			}

			// Bottom bulb: a mound that grows with elapsed time.
			let elapsed = 1 - remaining
			let moundTop = glassRect.maxY - bulbDepth * 0.8 * elapsed
			if elapsed > 0 {
				var mound = Path()
				let peak = min(bulbDepth * 0.12, (glassRect.maxY - moundTop))
				mound.move(to: CGPoint(x: glassRect.minX, y: glassRect.maxY))
				mound.addLine(to: CGPoint(x: glassRect.minX, y: moundTop + peak))
				mound.addQuadCurve(to: CGPoint(x: glassRect.maxX, y: moundTop + peak), control: CGPoint(x: glassRect.midX, y: moundTop - peak))
				mound.addLine(to: CGPoint(x: glassRect.maxX, y: glassRect.maxY))
				mound.closeSubpath()
				inside.fill(mound, with: .color(sand))
			}

			// The falling stream.
			if isRunning && remaining > 0 {
				var stream = Path()
				stream.move(to: CGPoint(x: glassRect.midX, y: neckY))
				stream.addLine(to: CGPoint(x: glassRect.midX, y: moundTop))
				inside.stroke(stream, with: .color(sand), style: StrokeStyle(lineWidth: max(1.2, size.width * 0.03), lineCap: .round, dash: [3, 2.5], dashPhase: -phase * 24))
			}

			context.stroke(glass, with: .color(color.opacity(0.6)), lineWidth: 1.5)

			for y in [0, size.height - capHeight] {
				context.fill(Path(roundedRect: CGRect(x: 0, y: y, width: size.width, height: capHeight), cornerRadius: capHeight / 2), with: .color(color))
			}
		}
		.rotationEffect(.degrees(isDone ? 180 : 0))
		.animation(.spring(duration: 0.8, bounce: 0.3), value: isDone)
		.accessibilityHidden(true)
	}

	/// Two rounded bulbs meeting at a narrow neck.
	private static func glassPath(in rect: CGRect) -> Path {
		let neck = rect.width * 0.07
		let mid = rect.midY
		var path = Path()
		path.move(to: CGPoint(x: rect.minX, y: rect.minY))
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
		path.addCurve(to: CGPoint(x: rect.midX + neck, y: mid),
					  control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3),
					  control2: CGPoint(x: rect.midX + neck, y: mid - rect.height * 0.08))
		path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
					  control1: CGPoint(x: rect.midX + neck, y: mid + rect.height * 0.08),
					  control2: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.3))
		path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
		path.addCurve(to: CGPoint(x: rect.midX - neck, y: mid),
					  control1: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.3),
					  control2: CGPoint(x: rect.midX - neck, y: mid + rect.height * 0.08))
		path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
					  control1: CGPoint(x: rect.midX - neck, y: mid - rect.height * 0.08),
					  control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3))
		path.closeSubpath()
		return path
	}
}


// MARK: - Shared

private struct TimerSymbol: View {
	let symbol: String
	let color: Color
	let isDone: Bool

	var body: some View {
		Image(systemName: isDone ? "bell.and.waves.left.and.right.fill" : symbol)
			.font(.system(size: 18, weight: .semibold))
			.foregroundStyle(color)
			.wiggleSymbol(isActive: isDone)
	}
}


/// A small sample of a style, for the Settings picker.
struct TimerStylePreview: View {
	let style: TimerStyle
	let color: Color

	var body: some View {
		let size = TimerGraphic.cardSize(for: style)
		let scale = min(64 / size.width, 64 / size.height)

		TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !style.isAnimated)) { context in
			TimerGraphic(
				style: style,
				remaining: 20 * 60,
				elapsed: 0.4,
				color: color,
				symbol: "timer",
				isRunning: true,
				isDone: false,
				phase: context.date.timeIntervalSinceReferenceDate
			)
			.frame(width: size.width * scale, height: size.height * scale)
		}
		.frame(width: 64, height: 64)
	}
}
