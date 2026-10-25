//
//  TimerVisuals.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// How running timers are drawn. Chosen in Settings.
enum TimerStyle: String, CaseIterable, Identifiable {
	case ring, pie, analog, liquid

	var id: String { rawValue }

	var title: String {
		switch self {
		case .ring: "Ring"
		case .pie: "Pie"
		case .analog: "Analog"
		case .liquid: "Liquid"
		}
	}

	var caption: String {
		switch self {
		case .ring: "A ring that drains"
		case .pie: "A circle that fills"
		case .analog: "Drag the clock to set"
		case .liquid: "The card drains"
		}
	}
}


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


// MARK: - Shared

private struct TimerSymbol: View {
	let symbol: String
	let color: Color
	let isDone: Bool

	var body: some View {
		Image(systemName: isDone ? "bell.and.waves.left.and.right.fill" : symbol)
			.font(.system(size: 18, weight: .semibold))
			.foregroundStyle(color)
			.symbolEffect(.wiggle, options: .repeat(.continuous), isActive: isDone)
	}
}


/// A small sample of a style, for the Settings picker.
struct TimerStylePreview: View {
	let style: TimerStyle
	let color: Color

	var body: some View {
		Group {
			switch style {
			case .ring:
				TimerRing(remainingFraction: 0.65, color: color, symbol: "timer", lineWidth: 6)
			case .pie:
				TimerPie(elapsedFraction: 0.35, color: color, symbol: "timer")
			case .analog:
				AnalogTimerFace(remaining: 20 * 60, color: color)
			case .liquid:
				TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
					LiquidFill(level: 0.6, color: color, phase: context.date.timeIntervalSinceReferenceDate * 1.5)
						.clipShape(.rect(cornerRadius: 14))
						.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.3)))
				}
			}
		}
		.frame(width: 64, height: 64)
	}
}
