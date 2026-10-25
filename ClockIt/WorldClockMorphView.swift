//
//  WorldClockMorphView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI

#if os(macOS)

/// World Clock on the Mac: the city cards scroll like a list, and scrolling past the end
/// morphs each card into an analog wall clock, lined up side by side.
struct WorldClockMorphView: View {
	let cities: [WorldClockCity]
	/// Minute-resolution time for the cards.
	let date: Date
	let offsetMinutes: Double
	var onRemove: (WorldClockCity) -> Void = { _ in }

	@State private var scroll = ScrollMetrics()
	@State private var rowFrames: [WorldClockCity.ID: CGRect] = [:]
	@State private var listHeight: CGFloat = 0

	/// How far you scroll to go from cards to clocks.
	private static let morphDistance: CGFloat = 320
	private static let space = "worldClockMorph"

	var body: some View {
		ScrollView {
			ZStack(alignment: .topLeading) {
				VStack(spacing: 12) {
					ForEach(cities) { city in
						WorldClockRow(city: city, date: date)
							.onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { rowFrames[city.id] = $0 }
							.contextMenu { removeButton(for: city) }
					}
				}
				.padding(.horizontal, 20)
				.padding(.vertical, 12)
				.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
				.opacity(progress > 0 ? 0 : 1)

				if progress > 0 {
					morphLayer
						.frame(width: scroll.size.width, height: scroll.size.height)
						.offset(y: scroll.offset - scroll.insets.top)
				}
			}
			.frame(
				maxWidth: .infinity,
				minHeight: cities.isEmpty ? 0 : max(listHeight, visibleHeight) + Self.morphDistance,
				alignment: .topLeading
			)
			.coordinateSpace(.named(Self.space))
		}
		// Scroll targets are measured from the top of the content, below the toolbar inset.
		.scrollTargetBehavior(MorphSnapBehavior(
			start: overflow,
			end: overflow + Self.morphDistance
		))
		.trackingScrollMetrics($scroll)
	}

	// MARK: - Morph

	private var visibleHeight: CGFloat {
		max(0, scroll.size.height - scroll.insets.top - scroll.insets.bottom)
	}

	/// How far the list itself scrolls before the morph starts.
	private var overflow: CGFloat {
		max(0, listHeight - visibleHeight)
	}

	/// 0 is the card list, 1 is the row of clocks.
	private var progress: Double {
		guard !cities.isEmpty else { return 0 }
		return min(max((scroll.offset - overflow) / Self.morphDistance, 0), 1)
	}

	private var morphLayer: some View {
		TimelineView(.animation(minimumInterval: 1.0 / 10)) { context in
			let clockDate = context.date.addingTimeInterval(offsetMinutes * 60)
			let slots = clockSlots()
			// The cards stay pinned where they were when the list stopped scrolling.
			let pinShift = scroll.insets.top - min(scroll.offset, overflow)

			ZStack(alignment: .topLeading) {
				ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
					if let row = rowFrames[city.id] {
						MorphingCityClock(
							city: city,
							cardDate: date,
							clockDate: clockDate,
							from: row.offsetBy(dx: 0, dy: pinShift),
							to: slots[index],
							progress: staggered(progress, index: index)
						)
						.contextMenu { removeButton(for: city) }
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
	}

	/// Each clock lands a beat after the one before it.
	private func staggered(_ progress: Double, index: Int) -> Double {
		guard cities.count > 1 else { return progress }
		let spread = 0.2
		let delay = spread * Double(index) / Double(cities.count - 1)
		return min(max((progress - delay) / (1 - spread), 0), 1)
	}

	/// Clock faces in a centered row, shrinking to fit as cities are added.
	private func clockSlots() -> [CGRect] {
		let count = CGFloat(max(cities.count, 1))
		let spacing: CGFloat = 28
		let available = scroll.size.width - 80 - spacing * (count - 1)
		let side = max(72, min(220, available / count))
		let total = side * count + spacing * (count - 1)
		let startX = (scroll.size.width - total) / 2
		let blockHeight = side + MorphingCityClock.plaqueGap + MorphingCityClock.plaqueHeight
		let top = scroll.insets.top + max(0, (visibleHeight - blockHeight) / 2)

		return cities.indices.map { index in
			CGRect(x: startX + CGFloat(index) * (side + spacing), y: top, width: side, height: side)
		}
	}

	private func removeButton(for city: WorldClockCity) -> some View {
		Button("Remove \(city.displayName)", systemImage: "trash", role: .destructive) {
			onRemove(city)
		}
	}
}


/// One city partway between its card and its clock face.
private struct MorphingCityClock: View {
	let city: WorldClockCity
	let cardDate: Date
	let clockDate: Date
	let from: CGRect
	let to: CGRect
	let progress: Double

	static let plaqueGap: CGFloat = 16
	static let plaqueHeight: CGFloat = 64

	var body: some View {
		let eased = progress * progress * (3 - 2 * progress)
		let rect = from.interpolated(to: to, by: eased)
		let side = min(rect.width, rect.height)
		let clockReveal = ramp(progress, 0.4, 0.85)

		ZStack {
			WorldClockRow(
				city: city,
				date: cardDate,
				detailOpacity: 1 - ramp(progress, 0, 0.35),
				cornerRadius: Theme.cornerRadius + (side / 2 - Theme.cornerRadius) * eased,
				fillsFrame: true
			)
			.frame(width: rect.width, height: rect.height)
			.opacity(1 - ramp(progress, 0.6, 0.95))

			AnalogWallClock(date: clockDate, timeZone: city.timeZone)
				.frame(width: side, height: side)
				.scaleEffect(0.8 + 0.2 * clockReveal)
				.opacity(clockReveal)
		}
		.frame(width: rect.width, height: rect.height)
		.overlay(alignment: .top) {
			plaque
				.offset(y: rect.height + Self.plaqueGap)
				.opacity(ramp(progress, 0.7, 1))
		}
		.position(x: rect.midX, y: rect.midY)
	}

	private var plaque: some View {
		VStack(spacing: 2) {
			Text(city.displayName.uppercased())
				.font(.headline.weight(.bold))
				.tracking(1.5)
				.lineLimit(1)
				.minimumScaleFactor(0.6)
			Text(clockDate.timeText(in: city.timeZone))
				.font(Theme.clockFont(18, weight: .medium))
				.monospacedDigit()
			Text("\(city.relativeDayText(at: clockDate)) · \(city.hourOffsetText(at: clockDate))")
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.frame(width: max(to.width, 140), height: Self.plaqueHeight)
		.accessibilityElement(children: .combine)
	}

	private func ramp(_ value: Double, _ start: Double, _ end: Double) -> Double {
		min(max((value - start) / (end - start), 0), 1)
	}
}


/// Lets the scroll rest on either the cards or the clocks, never halfway between.
private struct MorphSnapBehavior: ScrollTargetBehavior {
	let start: CGFloat
	let end: CGFloat

	func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
		let y = target.rect.minY
		guard y > start, y < end else { return }
		target.rect.origin.y = (y - start) < (end - y) ? start : end
	}
}


private struct ScrollMetrics: Equatable {
	/// Distance scrolled from the top, ignoring the toolbar inset.
	var offset: CGFloat = 0
	var insets = EdgeInsets()
	var size: CGSize = .zero
}


private extension CGRect {
	func interpolated(to other: CGRect, by amount: Double) -> CGRect {
		let t = CGFloat(amount)
		return CGRect(
			x: minX + (other.minX - minX) * t,
			y: minY + (other.minY - minY) * t,
			width: width + (other.width - width) * t,
			height: height + (other.height - height) * t
		)
	}
}


private extension View {
	/// Scroll geometry needs macOS 15; on macOS 14 the cards stay a plain list and never morph.
	@ViewBuilder
	func trackingScrollMetrics(_ scroll: Binding<ScrollMetrics>) -> some View {
		if #available(macOS 15, *) {
			onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
				ScrollMetrics(
					offset: geometry.contentOffset.y + geometry.contentInsets.top,
					insets: geometry.contentInsets,
					size: geometry.containerSize
				)
			} action: { _, metrics in
				scroll.wrappedValue = metrics
			}
		} else {
			self
		}
	}
}


#Preview {
	WorldClockMorphView(cities: WorldClockCity.sampleCities, date: Date(), offsetMinutes: 0)
		.background(AuroraBackground())
}

#endif
