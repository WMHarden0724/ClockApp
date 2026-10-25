//
//  ClockWallView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// A row of analog wall clocks with city plaques, like the clock walls in government offices
/// and newsrooms. Used for World Clock on Vision Pro. Your local clock always comes first.
struct ClockWallView: View {
	let cities: [WorldClockCity]
	let offsetMinutes: Double
	var onRemove: (WorldClockCity) -> Void = { _ in }

	var body: some View {
		TimelineView(.animation(minimumInterval: 1.0 / 10)) { context in
			let date = context.date.addingTimeInterval(offsetMinutes * 60)

			ScrollView(.horizontal) {
				HStack(alignment: .top, spacing: 36) {
					clock(
						name: LocalTime.currentCity,
						caption: "Local",
						timeZone: .current,
						date: date,
						isLocal: true
					)

					ForEach(cities) { city in
						clock(
							name: city.displayName,
							caption: "\(city.relativeDayText(at: date)) · \(city.hourOffsetText(at: date))",
							timeZone: city.timeZone,
							date: date,
							isLocal: false
						)
						.contextMenu {
							Button("Remove \(city.displayName)", systemImage: "trash", role: .destructive) {
								onRemove(city)
							}
						}
					}
				}
				.padding(.horizontal, 48)
				.padding(.vertical, 32)
			}
			.scrollIndicators(.hidden)
		}
	}

	private func clock(name: String, caption: String, timeZone: TimeZone, date: Date, isLocal: Bool) -> some View {
		VStack(spacing: 18) {
			AnalogWallClock(date: date, timeZone: timeZone)
				.frame(width: 220, height: 220)

			VStack(spacing: 4) {
				Text(name.uppercased())
					.font(.title3.weight(.bold))
					.tracking(2)
					.lineLimit(1)
					.minimumScaleFactor(0.7)
				Text(date.timeText(in: timeZone))
					.font(Theme.clockFont(22, weight: .medium))
					.monospacedDigit()
				Text(caption)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(width: 200)
			.padding(.vertical, 14)
			.softGlass(isLocal ? .regular.tint(Theme.accent.opacity(0.25)) : .regular, in: .rect(cornerRadius: 18))
		}
		.accessibilityElement(children: .combine)
	}
}


/// A classic office wall clock for any time zone: twelve numerals, hour and minute hands,
/// and a sweeping second hand. The face goes dark when it's night in that city.
struct AnalogWallClock: View {
	let date: Date
	let timeZone: TimeZone

	var body: some View {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone
		let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
		let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1_000_000_000
		let minutes = Double(parts.minute ?? 0) + seconds / 60
		let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
		let isDay = SkyPalette.isDaytime(hour: Double(parts.hour ?? 0) + minutes / 60)
		let ink: Color = isDay ? Color(red: 0.10, green: 0.12, blue: 0.22) : .white

		return GeometryReader { geo in
			let side = min(geo.size.width, geo.size.height)
			let radius = side / 2

			ZStack {
				Circle()
					.fill(isDay
						  ? LinearGradient(colors: [.white, Color(red: 0.95, green: 0.94, blue: 0.90)], startPoint: .top, endPoint: .bottom)
						  : LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.18), Color(red: 0.02, green: 0.02, blue: 0.06)], startPoint: .top, endPoint: .bottom))

				Circle()
					.strokeBorder(
						LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
						lineWidth: side * 0.05
					)

				Canvas { context, size in
					let center = CGPoint(x: size.width / 2, y: size.height / 2)
					for tick in 0..<60 {
						let isHour = tick % 5 == 0
						let angle = Double(tick) / 60 * 2 * .pi
						let outer = radius * 0.88
						let inner = outer - (isHour ? radius * 0.1 : radius * 0.04)
						var path = Path()
						path.move(to: CGPoint(x: center.x + outer * sin(angle), y: center.y - outer * cos(angle)))
						path.addLine(to: CGPoint(x: center.x + inner * sin(angle), y: center.y - inner * cos(angle)))
						context.stroke(path, with: .color(ink.opacity(isHour ? 0.85 : 0.35)), lineWidth: isHour ? radius * 0.025 : 1)
					}
					for hour in 1...12 {
						let angle = Double(hour) / 12 * 2 * .pi
						let labelRadius = radius * 0.64
						context.draw(
							Text("\(hour)").font(.system(size: radius * 0.16, weight: .semibold, design: .rounded)).foregroundStyle(ink),
							at: CGPoint(x: center.x + labelRadius * sin(angle), y: center.y - labelRadius * cos(angle))
						)
					}
				}

				hand(fraction: hours / 12, length: radius * 0.5, width: radius * 0.06, color: ink)
				hand(fraction: minutes / 60, length: radius * 0.75, width: radius * 0.04, color: ink)
				hand(fraction: seconds / 60, length: radius * 0.82, width: radius * 0.015, color: ClockItPalette.color(named: "rose"), tail: radius * 0.18)

				Circle()
					.fill(ClockItPalette.color(named: "rose"))
					.frame(width: radius * 0.1, height: radius * 0.1)
			}
			.frame(width: geo.size.width, height: geo.size.height)
			.shadow(color: .black.opacity(0.25), radius: 12, y: 6)
		}
		.aspectRatio(1, contentMode: .fit)
		.animation(.smooth(duration: 1.2), value: isDay)
	}

	private func hand(fraction: Double, length: CGFloat, width: CGFloat, color: Color, tail: CGFloat = 0) -> some View {
		Capsule()
			.fill(color)
			.frame(width: width, height: length + tail)
			.offset(y: -(length - tail) / 2)
			.rotationEffect(.degrees(fraction * 360))
	}
}


#Preview {
	ClockWallView(cities: WorldClockCity.sampleCities, offsetMinutes: 0)
		.background(AuroraBackground())
}
