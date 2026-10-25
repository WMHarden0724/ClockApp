//
//  TimeDial.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI



/// A 24-hour ring: midnight at the top, noon at the bottom. Drag the knob to set the time.
struct TimeDial: View {
	@Binding var hour: Int
	@Binding var minute: Int

	private let ringWidth: CGFloat = 28
	private let snapMinutes = 5

	private var totalMinutes: Int { hour * 60 + minute }
	private var fraction: Double { Double(totalMinutes) / 1440 }
	private var isDay: Bool { SkyPalette.isDaytime(hour: Double(totalMinutes) / 60) }

	private var timeText: String {
		let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
		return date.timeText
	}

	/// "12, 1, 2 … 11" twice around in 12-hour mode, "0 … 23" in 24-hour mode.
	private func hourLabel(_ h: Int) -> String {
		if AppSettings.shared.is24Hour { return "\(h)" }
		return "\(h % 12 == 0 ? 12 : h % 12)"
	}

	private var partOfDay: String {
		switch hour {
		case 0...11: return "Morning"
		case 12: return "Mid-Day"
		case 13...17: return "Afternoon"
		case 18...20: return "Evening"
		default: return "Night"
		}
	}

	var body: some View {
		GeometryReader { geo in
			let side = min(geo.size.width, geo.size.height)
			let radius = side / 2 - ringWidth / 2 - 4
			let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

			ZStack {
				Circle()
					.stroke(
						AngularGradient(colors: SkyPalette.dayRing, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
						lineWidth: ringWidth
					)
					.frame(width: radius * 2, height: radius * 2)

				ForEach(0..<24, id: \.self) { h in
					Capsule()
						.fill(.primary.opacity(h % 6 == 0 ? 0.5 : 0.2))
						.frame(width: 2, height: h % 6 == 0 ? 10 : 5)
						.offset(y: -(radius - ringWidth / 2 - 12))
						.rotationEffect(.degrees(Double(h) * 15))
				}

				// Hour numbers written on the sky ring, light on dark hours and dark on light ones.
				ForEach(0..<24, id: \.self) { h in
					Text(hourLabel(h))
						.font(.system(size: 11, weight: .bold, design: .rounded))
						.monospacedDigit()
						.foregroundStyle(SkyPalette.sky(atHour: Double(h)).prefersLightText ? Color.white.opacity(0.9) : Color(red: 0.10, green: 0.13, blue: 0.27).opacity(0.75))
						.position(point(for: Double(h) / 24, radius: radius, center: center))
						.accessibilityHidden(true)
				}

				VStack(spacing: 2) {
					Text(timeText)
						.font(Theme.clockFont(side * 0.15, weight: .thin))
						.monospacedDigit()
						.lineLimit(1)
						.minimumScaleFactor(0.6)
						.frame(maxWidth: (radius - ringWidth / 2) * 1.7)
						.contentTransition(.numericText())
					Text(partOfDay)
						.font(.subheadline.weight(.medium))
						.foregroundStyle(.secondary)
				}
				.animation(.snappy, value: totalMinutes)

				Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(isDay ? Color.orange : Theme.accent)
					.frame(width: 44, height: 44)
					.glassEffect(.regular.interactive(), in: .circle)
					.position(point(for: fraction, radius: radius, center: center))
			}
			.frame(width: geo.size.width, height: geo.size.height)
			.contentShape(Circle())
			.gesture(
				DragGesture(minimumDistance: 0)
					.onChanged { value in
						// Ignore touches that start in the middle, so tapping the time text doesn't move it.
						let start = value.startLocation
						guard hypot(start.x - center.x, start.y - center.y) > radius * 0.55 else { return }
						setTime(from: value.location, center: center)
					}
			)
		}
		.aspectRatio(1, contentMode: .fit)
		.sensoryFeedback(.selection, trigger: totalMinutes)
		.accessibilityElement()
		.accessibilityLabel("Alarm time")
		.accessibilityValue(timeText)
		.accessibilityAdjustableAction { direction in
			switch direction {
			case .increment: nudge(by: snapMinutes)
			case .decrement: nudge(by: -snapMinutes)
			@unknown default: break
			}
		}
	}

	/// Point on the ring for a fraction of the day, clockwise from the top.
	private func point(for fraction: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
		let angle = fraction * 2 * .pi
		return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
	}

	private func setTime(from location: CGPoint, center: CGPoint) {
		var angle = atan2(location.x - center.x, center.y - location.y)
		if angle < 0 { angle += 2 * .pi }
		let raw = Double(angle) / (2 * .pi) * 1440
		let snapped = Int((raw / Double(snapMinutes)).rounded()) * snapMinutes % 1440
		hour = snapped / 60
		minute = snapped % 60
	}

	func nudge(by minutes: Int) {
		let total = ((totalMinutes + minutes) % 1440 + 1440) % 1440
		hour = total / 60
		minute = total % 60
	}
}


#Preview {
	@Previewable @State var hour = 7
	@Previewable @State var minute = 30
	TimeDial(hour: $hour, minute: $minute)
		.padding()
		.background(AuroraBackground())
}
