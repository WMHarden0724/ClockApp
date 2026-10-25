//
//  TimerGraphics.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// Draws a timer in any style at any size. Used by timer cards, the full-screen view and Settings previews.
struct TimerGraphic: View {
	let style: TimerStyle
	let remaining: TimeInterval
	/// Fraction of the timer that has elapsed, 0...1.
	let elapsed: Double
	let color: Color
	let symbol: String
	let isRunning: Bool
	let isDone: Bool
	/// Seconds that keep advancing while running; drives flames, sand and waves.
	let phase: Double
	var large = false

	var body: some View {
		switch style {
		case .ring:
			TimerRing(remainingFraction: 1 - elapsed, color: color, symbol: symbol, lineWidth: large ? 18 : 7, isDone: isDone)
				.scaleEffect(large ? 1 : 1)
		case .pie:
			TimerPie(elapsedFraction: elapsed, color: color, symbol: symbol, isDone: isDone)
		case .analog:
			AnalogTimerFace(remaining: isDone ? 0 : remaining, color: color)
		case .liquid:
			LiquidFill(level: isDone ? 0 : 1 - elapsed, color: color, phase: phase * 1.5)
				.clipShape(.rect(cornerRadius: large ? 48 : 14))
				.overlay(RoundedRectangle(cornerRadius: large ? 48 : 14).strokeBorder(color.opacity(0.3)))
		case .hourglass:
			TimerHourglass(remainingFraction: 1 - elapsed, color: color, isRunning: isRunning, phase: phase, isDone: isDone)
		case .candle:
			TimerCandle(remainingFraction: 1 - elapsed, color: color, isRunning: isRunning, phase: phase, isDone: isDone)
		case .battery:
			TimerBattery(remainingFraction: 1 - elapsed, color: color, isRunning: isRunning, phase: phase, isDone: isDone)
		case .sunset:
			TimerSunset(elapsed: isDone ? 1 : elapsed, color: color, large: large)
		case .moon:
			TimerMoon(elapsed: isDone ? 1 : elapsed)
		case .bloom:
			TimerBloom(elapsed: elapsed, color: color, isRunning: isRunning, phase: phase, isDone: isDone)
		}
	}

	/// Frame for a style on a timer card (scale up for the full-screen view).
	static func cardSize(for style: TimerStyle) -> CGSize {
		switch style {
		case .ring, .pie, .moon: CGSize(width: 64, height: 64)
		case .analog: CGSize(width: 96, height: 96)
		case .liquid, .sunset: CGSize(width: 68, height: 68)
		case .hourglass: CGSize(width: 50, height: 74)
		case .candle: CGSize(width: 44, height: 78)
		case .battery: CGSize(width: 40, height: 70)
		case .bloom: CGSize(width: 58, height: 78)
		}
	}
}


// MARK: - Candle

/// Wax burns down under a flickering flame; a wisp of smoke when it's done.
struct TimerCandle: View {
	let remainingFraction: Double
	let color: Color
	let isRunning: Bool
	let phase: Double
	var isDone = false

	var body: some View {
		let remaining = isDone ? 0 : min(max(remainingFraction, 0), 1)
		let waxLight = color.mix(with: .white, by: 0.72)
		let waxShade = color.mix(with: .white, by: 0.42)

		Canvas { context, size in
			let w = size.width, h = size.height
			let plateHeight = max(3, h * 0.07)
			let bodyWidth = w * 0.52
			let bodyX = (w - bodyWidth) / 2
			let wax = max(h * 0.06, h * 0.6 * remaining)
			let bodyTop = h - plateHeight - wax
			let wickTop = bodyTop - h * 0.06

			context.fill(
				Path(roundedRect: CGRect(x: w * 0.06, y: h - plateHeight, width: w * 0.88, height: plateHeight), cornerRadius: plateHeight / 2),
				with: .color(color)
			)

			let body = Path(roundedRect: CGRect(x: bodyX, y: bodyTop, width: bodyWidth, height: wax), cornerRadius: bodyWidth * 0.16)
			context.fill(body, with: .linearGradient(
				Gradient(colors: [waxLight, waxShade]),
				startPoint: CGPoint(x: bodyX, y: 0),
				endPoint: CGPoint(x: bodyX + bodyWidth, y: 0)
			))

			// A drip running down the side.
			let dripHeight = min(wax * 0.45, h * 0.14)
			context.fill(
				Path(roundedRect: CGRect(x: bodyX + bodyWidth * 0.14, y: bodyTop, width: bodyWidth * 0.16, height: dripHeight), cornerRadius: bodyWidth * 0.08),
				with: .color(waxLight)
			)

			var wick = Path()
			wick.move(to: CGPoint(x: w / 2, y: bodyTop))
			wick.addLine(to: CGPoint(x: w / 2, y: wickTop))
			context.stroke(wick, with: .color(.primary.opacity(0.7)), lineWidth: max(1.2, w * 0.03))

			if remaining > 0 {
				let flicker = isRunning ? 1 + 0.09 * sin(phase * 13) + 0.05 * sin(phase * 7.3) : 0.8
				let sway = isRunning ? CGFloat(sin(phase * 5)) * w * 0.03 : 0
				let flameHeight = h * 0.2 * flicker
				let flameWidth = w * 0.2
				let base = CGPoint(x: w / 2, y: wickTop + h * 0.015)
				let tip = CGPoint(x: w / 2 + sway, y: wickTop - flameHeight)
				let middle = wickTop - flameHeight * 0.35

				let glowCenter = CGPoint(x: w / 2, y: wickTop - flameHeight * 0.4)
				context.fill(
					Path(ellipseIn: CGRect(x: glowCenter.x - flameHeight, y: glowCenter.y - flameHeight, width: flameHeight * 2, height: flameHeight * 2)),
					with: .radialGradient(Gradient(colors: [Color.orange.opacity(0.35), .clear]), center: glowCenter, startRadius: 0, endRadius: flameHeight)
				)

				var flame = Path()
				flame.move(to: base)
				flame.addQuadCurve(to: tip, control: CGPoint(x: w / 2 + flameWidth, y: middle))
				flame.addQuadCurve(to: base, control: CGPoint(x: w / 2 - flameWidth, y: middle))
				context.fill(flame, with: .linearGradient(
					Gradient(colors: [Color(red: 1.0, green: 0.93, blue: 0.55), Color(red: 1.0, green: 0.55, blue: 0.25)]),
					startPoint: tip,
					endPoint: base
				))

				var core = Path()
				let coreTip = CGPoint(x: w / 2 + sway * 0.5, y: wickTop - flameHeight * 0.45)
				core.move(to: base)
				core.addQuadCurve(to: coreTip, control: CGPoint(x: w / 2 + flameWidth * 0.45, y: wickTop - flameHeight * 0.15))
				core.addQuadCurve(to: base, control: CGPoint(x: w / 2 - flameWidth * 0.45, y: wickTop - flameHeight * 0.15))
				context.fill(core, with: .color(.white.opacity(0.85)))
			} else {
				var smoke = Path()
				smoke.move(to: CGPoint(x: w / 2, y: wickTop))
				smoke.addCurve(
					to: CGPoint(x: w / 2 + w * 0.08, y: wickTop - h * 0.22),
					control1: CGPoint(x: w / 2 - w * 0.14, y: wickTop - h * 0.07),
					control2: CGPoint(x: w / 2 + w * 0.2, y: wickTop - h * 0.13)
				)
				context.stroke(smoke, with: .color(.gray.opacity(0.45)), style: StrokeStyle(lineWidth: max(1.5, w * 0.04), lineCap: .round))
			}
		}
		.accessibilityHidden(true)
	}
}


// MARK: - Battery

/// A battery that drains bar by bar and turns rose when it's nearly empty.
struct TimerBattery: View {
	let remainingFraction: Double
	let color: Color
	let isRunning: Bool
	let phase: Double
	var isDone = false

	var body: some View {
		let level = isDone ? 0 : min(max(remainingFraction, 0), 1)
		let low = ClockItPalette.color(named: "rose")
		let fill = level < 0.2 ? low : color

		Canvas { context, size in
			let w = size.width, h = size.height
			let nubHeight = h * 0.07
			let body = CGRect(x: w * 0.06, y: nubHeight, width: w * 0.88, height: h - nubHeight - 1)
			let corner = w * 0.2

			context.fill(
				Path(roundedRect: CGRect(x: w * 0.32, y: 0, width: w * 0.36, height: nubHeight + corner * 0.3), cornerRadius: 2),
				with: .color(fill.opacity(0.6))
			)
			context.fill(Path(roundedRect: body, cornerRadius: corner), with: .color(.white.opacity(0.25)))

			let blink = isDone ? 0.45 + 0.45 * abs(sin(phase * 3)) : 1
			context.stroke(Path(roundedRect: body, cornerRadius: corner), with: .color(fill.opacity(0.75 * blink)), lineWidth: max(2, w * 0.06))

			let inner = body.insetBy(dx: w * 0.13, dy: w * 0.13)
			if level > 0 {
				let height = inner.height * level
				let levelRect = CGRect(x: inner.minX, y: inner.maxY - height, width: inner.width, height: height)
				let levelPath = Path(roundedRect: levelRect, cornerRadius: corner * 0.45)
				context.fill(levelPath, with: .linearGradient(
					Gradient(colors: [fill.mix(with: .white, by: 0.25), fill]),
					startPoint: CGPoint(x: levelRect.minX, y: 0),
					endPoint: CGPoint(x: levelRect.maxX, y: 0)
				))

				// A soft band of light rising through the charge while running.
				if isRunning {
					var shine = context
					shine.clip(to: levelPath)
					let travel = (phase.truncatingRemainder(dividingBy: 1.8)) / 1.8
					let y = levelRect.maxY - CGFloat(travel) * (levelRect.height + 12)
					shine.fill(Path(CGRect(x: levelRect.minX, y: y, width: levelRect.width, height: 6)), with: .color(.white.opacity(0.35)))
				}
			}

			// Segment dividers.
			for segment in 1..<4 {
				let y = inner.maxY - inner.height * CGFloat(segment) / 4
				var line = Path()
				line.move(to: CGPoint(x: inner.minX, y: y))
				line.addLine(to: CGPoint(x: inner.maxX, y: y))
				context.stroke(line, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
			}
		}
		.accessibilityHidden(true)
	}
}


// MARK: - Sunset

/// The sun drops across a sky that moves from noon to dusk; stars come out at the end.
struct TimerSunset: View {
	let elapsed: Double
	let color: Color
	var large = false

	var body: some View {
		let t = min(max(elapsed, 0), 1)
		let hour = 12 + 9.5 * t
		let sky = SkyPalette.sky(atHour: hour)
		let sunColor = Color(red: 1.0, green: 0.86, blue: 0.42).mix(with: Color(red: 1.0, green: 0.48, blue: 0.32), by: t)
		let hillNear = color.mix(with: .black, by: 0.25 + 0.4 * t)
		let hillFar = color.mix(with: .black, by: 0.05 + 0.4 * t).opacity(0.75)

		Canvas { context, size in
			let w = size.width, h = size.height
			let horizon = h * 0.72

			context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
				Gradient(colors: [sky.top, sky.bottom]),
				startPoint: .zero,
				endPoint: CGPoint(x: 0, y: h)
			))

			if sky.prefersLightText {
				var generator = SeededGenerator(seed: "timer-sunset")
				for _ in 0..<14 {
					let x = CGFloat.random(in: 0...w, using: &generator)
					let y = CGFloat.random(in: 0...(horizon * 0.8), using: &generator)
					let d = CGFloat.random(in: 1...(large ? 3 : 1.8), using: &generator)
					context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity(0.7)))
				}
			}

			let sunRadius = w * 0.13
			let sun = CGPoint(x: w * (0.22 + 0.56 * t), y: h * 0.2 + (horizon + sunRadius * 0.6 - h * 0.2) * CGFloat(pow(t, 1.3)))
			context.fill(
				Path(ellipseIn: CGRect(x: sun.x - sunRadius * 2.6, y: sun.y - sunRadius * 2.6, width: sunRadius * 5.2, height: sunRadius * 5.2)),
				with: .radialGradient(Gradient(colors: [sunColor.opacity(0.45), .clear]), center: sun, startRadius: sunRadius, endRadius: sunRadius * 2.6)
			)
			context.fill(Path(ellipseIn: CGRect(x: sun.x - sunRadius, y: sun.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)), with: .color(sunColor))

			var far = Path()
			far.move(to: CGPoint(x: 0, y: h))
			far.addLine(to: CGPoint(x: 0, y: horizon - h * 0.04))
			far.addQuadCurve(to: CGPoint(x: w * 0.55, y: horizon - h * 0.02), control: CGPoint(x: w * 0.25, y: horizon - h * 0.16))
			far.addQuadCurve(to: CGPoint(x: w, y: horizon - h * 0.06), control: CGPoint(x: w * 0.8, y: horizon - h * 0.14))
			far.addLine(to: CGPoint(x: w, y: h))
			far.closeSubpath()
			context.fill(far, with: .color(hillFar))

			var near = Path()
			near.move(to: CGPoint(x: 0, y: h))
			near.addLine(to: CGPoint(x: 0, y: horizon + h * 0.06))
			near.addQuadCurve(to: CGPoint(x: w, y: horizon + h * 0.04), control: CGPoint(x: w * 0.6, y: horizon - h * 0.08))
			near.addLine(to: CGPoint(x: w, y: h))
			near.closeSubpath()
			context.fill(near, with: .color(hillNear))
		}
		.clipShape(.rect(cornerRadius: large ? 48 : 16))
		.accessibilityHidden(true)
	}
}


// MARK: - Moon

/// The moon wanes from full to new as the timer runs.
struct TimerMoon: View {
	let elapsed: Double

	var body: some View {
		let t = min(max(elapsed, 0), 1)

		ZStack {
			Circle()
				.fill(LinearGradient(
					colors: [Color(red: 0.04, green: 0.04, blue: 0.10), Color(red: 0.13, green: 0.10, blue: 0.27)],
					startPoint: .top,
					endPoint: .bottom
				))
			StarField(seed: "timer-moon", count: 18)
				.clipShape(Circle())
			MoonGlyph(phase: 0.5 + 0.4999 * t)
				.padding(.horizontal, 0)
				.scaleEffect(0.62)
		}
		.accessibilityHidden(true)
	}
}


// MARK: - Bloom

/// A sprout that grows a stem and leaves, then opens into a flower as time passes.
struct TimerBloom: View {
	let elapsed: Double
	let color: Color
	let isRunning: Bool
	let phase: Double
	var isDone = false

	var body: some View {
		let growth = isDone ? 1 : min(max(elapsed, 0), 1)
		let leaf = ClockItPalette.color(named: "mint")
		let potColor = color.mix(with: .black, by: 0.15)

		Canvas { context, size in
			let w = size.width, h = size.height
			let soil = h * 0.78
			let sway = isRunning || isDone ? CGFloat(sin(phase * 1.6)) * w * 0.03 : 0

			// Pot.
			var pot = Path()
			pot.move(to: CGPoint(x: w * 0.2, y: soil))
			pot.addLine(to: CGPoint(x: w * 0.8, y: soil))
			pot.addLine(to: CGPoint(x: w * 0.7, y: h))
			pot.addLine(to: CGPoint(x: w * 0.3, y: h))
			pot.closeSubpath()
			context.fill(pot, with: .color(potColor))
			context.fill(Path(roundedRect: CGRect(x: w * 0.15, y: soil - h * 0.04, width: w * 0.7, height: h * 0.06), cornerRadius: h * 0.02), with: .color(potColor.mix(with: .white, by: 0.2)))

			// Stem grows during the first 70%.
			let stemProgress = min(1, growth / 0.7)
			let top = CGPoint(x: w / 2 + sway, y: soil - h * 0.58 * stemProgress)
			guard stemProgress > 0.02 else { return }
			var stem = Path()
			stem.move(to: CGPoint(x: w / 2, y: soil - h * 0.04))
			stem.addQuadCurve(to: top, control: CGPoint(x: w / 2 - w * 0.08, y: (soil + top.y) / 2))
			context.stroke(stem, with: .color(leaf), style: StrokeStyle(lineWidth: max(2, w * 0.05), lineCap: .round))

			// Leaves unfurl from 25%.
			let leafScale = min(1, max(0, (growth - 0.25) * 3))
			if leafScale > 0 {
				for (side, height) in [(-1.0, 0.45), (1.0, 0.62)] {
					var leafContext = context
					let anchor = CGPoint(x: w / 2 - w * 0.03, y: soil - (soil - top.y) * height)
					leafContext.translateBy(x: anchor.x, y: anchor.y)
					leafContext.rotate(by: .degrees(side * 50))
					let leafWidth = w * 0.13 * leafScale, leafHeight = w * 0.3 * leafScale
					leafContext.fill(Path(ellipseIn: CGRect(x: -leafWidth / 2, y: -leafHeight, width: leafWidth, height: leafHeight)), with: .color(leaf.opacity(0.9)))
				}
			}

			// Petals open over the last 45%.
			let bloom = max(0, (growth - 0.55) / 0.45)
			if bloom > 0 {
				let petalCount = 6
				for index in 0..<petalCount {
					var petalContext = context
					petalContext.translateBy(x: top.x, y: top.y)
					petalContext.rotate(by: .degrees(Double(index) * 360 / Double(petalCount) + phase * (isDone ? 10 : 0)))
					let petalWidth = w * 0.16 * bloom, petalHeight = w * 0.26 * bloom
					petalContext.fill(
						Path(ellipseIn: CGRect(x: -petalWidth / 2, y: -petalHeight, width: petalWidth, height: petalHeight)),
						with: .linearGradient(
							Gradient(colors: [color.mix(with: .white, by: 0.35), color]),
							startPoint: CGPoint(x: 0, y: -petalHeight),
							endPoint: .zero
						)
					)
				}
				let centerRadius = w * 0.075 * max(bloom, 0.5)
				context.fill(Path(ellipseIn: CGRect(x: top.x - centerRadius, y: top.y - centerRadius, width: centerRadius * 2, height: centerRadius * 2)), with: .color(ClockItPalette.color(named: "butter")))
			} else {
				let bud = w * 0.07 * max(0.5, growth / 0.55)
				context.fill(Path(ellipseIn: CGRect(x: top.x - bud * 0.7, y: top.y - bud * 1.4, width: bud * 1.4, height: bud * 1.8)), with: .color(color))
			}
		}
		.accessibilityHidden(true)
	}
}
