//
//  WorldClockRow.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


struct WorldClockRow: View {
	let city: WorldClockCity
	let date: Date

	var body: some View {
		let hour = city.localHour(at: date)
		let sky = SkyPalette.sky(atHour: hour)
		let ink: Color = sky.prefersLightText ? .white : Color(red: 0.10, green: 0.13, blue: 0.27)

		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .firstTextBaseline) {
				VStack(alignment: .leading, spacing: 4) {
					Text(city.displayName)
						.font(.title3.weight(.semibold))

					Text("\(city.relativeDayText(at: date)) · \(city.hourOffsetText(at: date))")
						.font(.subheadline)
						.opacity(0.75)
				}

				Spacer()

				Text(city.timeText(at: date))
					.font(Theme.clockFont(44))
					.monospacedDigit()
					.contentTransition(.numericText())
			}

			DayTrack(hour: hour, ink: ink)
		}
		.foregroundStyle(ink)
		.padding(20)
		.background {
			LinearGradient(colors: [sky.top, sky.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
				.opacity(0.85)
				.clipShape(.rect(cornerRadius: Theme.cornerRadius))
		}
		.glassEffect(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
		.animation(.smooth, value: date)
		.accessibilityElement(children: .combine)
	}
}


/// A 24-hour line with the sun or moon riding along it at the city's current hour.
private struct DayTrack: View {
	let hour: Double
	let ink: Color

	var body: some View {
		let isDay = SkyPalette.isDaytime(hour: hour)

		GeometryReader { geo in
			let x = geo.size.width * hour / 24

			ZStack(alignment: .leading) {
				Capsule()
					.fill(ink.opacity(0.18))
					.frame(height: 3)

				Capsule()
					.fill(ink.opacity(0.45))
					.frame(width: max(x, 3), height: 3)

				Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(isDay ? Color(red: 1.0, green: 0.84, blue: 0.40) : .white)
					.shadow(color: isDay ? .yellow.opacity(0.7) : .white.opacity(0.6), radius: 6)
					.position(x: x, y: geo.size.height / 2)
			}
		}
		.frame(height: 18)
		.accessibilityHidden(true)
	}
}


#Preview {
	VStack {
		ForEach(WorldClockCity.sampleCities) { city in
			WorldClockRow(city: city, date: Date())
		}
	}
	.padding()
	.background(AuroraBackground())
}
