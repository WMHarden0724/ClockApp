//
//  TimeScrubber.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


/// A glass ruler you drag to shift every clock forward or back by up to 12 hours.
struct TimeScrubber: View {
	@Binding var offsetMinutes: Double

	@State private var dragStartOffset: Double?
	private let pointsPerHour: CGFloat = 32
	private let range: ClosedRange<Double> = -720...720

	var body: some View {
		VStack(spacing: 10) {
			HStack {
				Text(offsetMinutes == 0 ? "Drag to compare times" : LocalTime.offsetText(minutes: offsetMinutes))
					.font(.subheadline.weight(.semibold))
					.contentTransition(.numericText())
					.foregroundStyle(offsetMinutes == 0 ? .secondary : .primary)

				Spacer()

				if offsetMinutes != 0 {
					Button("Now") {
						withAnimation(.spring) { offsetMinutes = 0 }
					}
					.glassButton()
					.controlSize(.small)
					.transition(.scale.combined(with: .opacity))
				}
			}
			.frame(height: 28)

			ruler
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 14)
		.softGlass(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
		.animation(.snappy, value: offsetMinutes == 0)
		.sensoryFeedback(.selection, trigger: offsetMinutes)
		.accessibilityElement()
		.accessibilityLabel("Time shift")
		.accessibilityValue(offsetMinutes == 0 ? "Now" : LocalTime.offsetText(minutes: offsetMinutes))
		.accessibilityAdjustableAction { direction in
			switch direction {
			case .increment: offsetMinutes = min(offsetMinutes + 60, range.upperBound)
			case .decrement: offsetMinutes = max(offsetMinutes - 60, range.lowerBound)
			@unknown default: break
			}
		}
	}

	private var ruler: some View {
		Canvas { context, size in
			let mid = size.width / 2
			let offset = offsetMinutes

			for quarter in stride(from: Int(range.lowerBound) / 15, through: Int(range.upperBound) / 15, by: 1) {
				let minutes = Double(quarter * 15)
				let x = mid + CGFloat((minutes - offset) / 60) * pointsPerHour
				guard x > -10, x < size.width + 10 else { continue }

				let isHour = quarter % 4 == 0
				let height: CGFloat = isHour ? 14 : (quarter % 2 == 0 ? 8 : 4)
				let tick = Path(roundedRect: CGRect(x: x - 1, y: 0, width: 2, height: height), cornerRadius: 1)
				context.fill(tick, with: .color(.primary.opacity(isHour ? 0.55 : 0.25)))

				if isHour, quarter % 12 == 0 {
					let hours = quarter / 4
					let label = hours == 0 ? "0" : (hours > 0 ? "+\(hours)" : "−\(-hours)")
					context.draw(
						Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary),
						at: CGPoint(x: x, y: size.height - 6)
					)
				}
			}
		}
		.overlay {
			Capsule()
				.fill(Theme.accent)
				.frame(width: 4, height: 24)
				.shadow(color: Theme.accent.opacity(0.6), radius: 6)
				.frame(maxHeight: .infinity, alignment: .top)
				.offset(y: -4)
		}
		.mask {
			LinearGradient(stops: [
				.init(color: .clear, location: 0),
				.init(color: .black, location: 0.15),
				.init(color: .black, location: 0.85),
				.init(color: .clear, location: 1)
			], startPoint: .leading, endPoint: .trailing)
		}
		.frame(height: 36)
		.contentShape(Rectangle())
		.gesture(
			DragGesture(minimumDistance: 0)
				.onChanged { value in
					let start = dragStartOffset ?? offsetMinutes
					dragStartOffset = start
					let proposed = start - Double(value.translation.width / pointsPerHour) * 60
					offsetMinutes = min(max((proposed / 15).rounded() * 15, range.lowerBound), range.upperBound)
				}
				.onEnded { _ in dragStartOffset = nil }
		)
	}
}


#Preview {
	@Previewable @State var offset: Double = 0
	TimeScrubber(offsetMinutes: $offset)
		.padding()
		.background(AuroraBackground())
}
