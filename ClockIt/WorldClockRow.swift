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
	/// Used by the Mac morph into analog clocks: fades the text, rounds the card, and lets it fill its frame.
	var detailOpacity: Double = 1
	var cornerRadius: CGFloat = Theme.cornerRadius
	var fillsFrame = false

	var body: some View {
		let hour = city.localHour(at: date)
		let sky = SkyPalette.sky(atHour: hour)
		let isNight = sky.prefersLightText
		let ink: Color = isNight ? .white : Color(red: 0.10, green: 0.13, blue: 0.27)
		let moonPhase = MoonPhase.fraction(at: date)

		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .firstTextBaseline) {
				HStack(spacing: 10) {
					if let person = city.person {
						PersonAvatar(name: person, size: 36)
					}

					VStack(alignment: .leading, spacing: 4) {
						Text(city.displayName)
							.font(.title3.weight(.semibold))

						// A person's clock names their city too.
						Text([city.person == nil ? nil : city.name, city.relativeDayText(at: date), city.hourOffsetText(at: date)].compactMap { $0 }.joined(separator: " · "))
							.font(.subheadline)
							.opacity(0.75)
					}
				}

				Spacer()

				Text(city.timeText(at: date))
					.font(Theme.clockFont(44))
					.monospacedDigit()
					.contentTransition(.numericText())
			}

			DayTrack(hour: hour, moonPhase: moonPhase, ink: ink)

			if let change = ClockChange.next(for: city, from: date) {
				ClockChangeNotice(change: change, city: city, date: date)
					.transition(.opacity)
			}

			if isNight {
				Text(MoonPhase.name(for: moonPhase))
					.font(.caption.weight(.medium))
					.opacity(0.6)
					.transition(.opacity)
			}
		}
		.opacity(detailOpacity)
		.frame(maxWidth: fillsFrame ? .infinity : nil, maxHeight: fillsFrame ? .infinity : nil, alignment: .topLeading)
		.foregroundStyle(ink)
		.padding(20)
		.background {
			ZStack {
				LinearGradient(colors: [sky.top, sky.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
				StarField(seed: city.timeZoneIdentifier)
					.opacity(isNight ? 1 : 0)
			}
			.opacity(0.95)
			.clipShape(.rect(cornerRadius: cornerRadius))
		}
		.softGlass(.regular, in: .rect(cornerRadius: cornerRadius))
		.animation(.smooth, value: date)
		.animation(.smooth(duration: 0.8), value: isNight)
		.accessibilityElement(children: .combine)
	}
}


/// "Clocks in London go back on Sunday · Mom will be 4h ahead", for the week before.
private struct ClockChangeNotice: View {
	let change: ClockChange
	let city: WorldClockCity
	let date: Date

	var body: some View {
		Label {
			Text("\(change.headline(cityName: city.name, from: date)) · \(change.consequence(name: city.displayName))")
		} icon: {
			Image(systemName: "clock.arrow.2.circlepath")
		}
		.font(.caption.weight(.medium))
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(.white.opacity(0.18), in: .capsule)
	}
}


/// A 24-hour line with the sun, or tonight's moon phase, riding along it at the city's current hour.
private struct DayTrack: View {
	let hour: Double
	let moonPhase: Double
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

				Group {
					if isDay {
						Image(systemName: "sun.max.fill")
							.font(.system(size: 14, weight: .semibold))
							.foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.40))
							.shadow(color: .yellow.opacity(0.7), radius: 6)
					} else {
						MoonGlyph(phase: moonPhase)
							.frame(width: 16, height: 16)
					}
				}
				.position(x: x, y: geo.size.height / 2)
			}
		}
		.frame(height: 18)
		.accessibilityHidden(true)
	}
}


/// A sprinkle of faint stars, laid out the same way every time for a given seed.
struct StarField: View {
	let seed: String
	var count = 28

	var body: some View {
		Canvas { context, size in
			var generator = SeededGenerator(seed: seed)
			for _ in 0..<count {
				let x = CGFloat.random(in: 0...size.width, using: &generator)
				let y = CGFloat.random(in: 0...size.height, using: &generator)
				let diameter = CGFloat.random(in: 1...2.4, using: &generator)
				let brightness = Double.random(in: 0.25...0.8, using: &generator)
				context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
							 with: .color(.white.opacity(brightness)))
			}
		}
		.allowsHitTesting(false)
	}
}


/// Deterministic random numbers (FNV-1a seed, SplitMix64), so stars don't jump between renders.
struct SeededGenerator: RandomNumberGenerator {
	private var state: UInt64

	init(seed: String) {
		var hash: UInt64 = 14_695_981_039_346_656_037
		for byte in seed.utf8 {
			hash ^= UInt64(byte)
			hash &*= 1_099_511_628_211
		}
		state = hash
	}

	mutating func next() -> UInt64 {
		state &+= 0x9E37_79B9_7F4A_7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		return z ^ (z >> 31)
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
