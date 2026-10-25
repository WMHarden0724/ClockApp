//
//  Theme.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


/// Shared look for the whole app: soft pastels, Liquid Glass cards, rounded numerals.
enum Theme {
	static let accent = ClockItPalette.accent
	static let cornerRadius: CGFloat = 28

	static func clockFont(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
		.system(size: size, weight: weight, design: .rounded)
	}
}


// MARK: - Background

/// Slowly drifting pastel mesh that sits behind every screen.
struct AuroraBackground: View {
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { context in
			MeshGradient(
				width: 3,
				height: 3,
				points: points(at: context.date.timeIntervalSinceReferenceDate),
				colors: colorScheme == .dark ? Self.darkColors : Self.lightColors
			)
		}
		.ignoresSafeArea()
	}

	private func points(at time: Double) -> [SIMD2<Float>] {
		func drift(_ phase: Double) -> Float {
			reduceMotion ? 0 : Float(sin(time * 0.15 + phase)) * 0.08
		}
		return [
			[0, 0], [0.5 + drift(0), 0], [1, 0],
			[0, 0.5 + drift(1.3)], [0.5 + drift(2.1), 0.5 + drift(0.7)], [1, 0.5 + drift(3.4)],
			[0, 1], [0.5 + drift(4.2), 1], [1, 1]
		]
	}

	private static let lightColors: [Color] = [
		Color(red: 0.86, green: 0.84, blue: 1.00), Color(red: 0.99, green: 0.87, blue: 0.93), Color(red: 1.00, green: 0.89, blue: 0.84),
		Color(red: 0.82, green: 0.91, blue: 1.00), Color(red: 0.93, green: 0.90, blue: 1.00), Color(red: 0.99, green: 0.92, blue: 0.88),
		Color(red: 0.84, green: 0.96, blue: 0.94), Color(red: 0.84, green: 0.90, blue: 1.00), Color(red: 0.91, green: 0.86, blue: 1.00)
	]

	private static let darkColors: [Color] = [
		Color(red: 0.10, green: 0.09, blue: 0.22), Color(red: 0.20, green: 0.10, blue: 0.26), Color(red: 0.24, green: 0.12, blue: 0.20),
		Color(red: 0.06, green: 0.12, blue: 0.25), Color(red: 0.14, green: 0.11, blue: 0.30), Color(red: 0.20, green: 0.12, blue: 0.26),
		Color(red: 0.04, green: 0.17, blue: 0.20), Color(red: 0.07, green: 0.12, blue: 0.26), Color(red: 0.13, green: 0.08, blue: 0.24)
	]
}


// MARK: - Glass

extension View {
	/// A padded, full-width Liquid Glass card.
	func glassCard(tint: Color? = nil, padding: CGFloat = 20) -> some View {
		let glass: Glass = tint.map { Glass.regular.tint($0) } ?? .regular
		return self
			.padding(padding)
			.frame(maxWidth: .infinity, alignment: .leading)
			.glassEffect(glass, in: .rect(cornerRadius: Theme.cornerRadius))
	}

	/// Strips the default List row chrome so glass cards float over the background.
	func glassListRow() -> some View {
		self
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
			.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
	}

	/// Shows the user's live local time under the navigation title.
	func localTimeSubtitle() -> some View {
		modifier(LocalTimeSubtitle())
	}
}


private struct LocalTimeSubtitle: ViewModifier {
	func body(content: Content) -> some View {
		TimelineView(.everyMinute) { context in
			content.navigationSubtitle(Text(LocalTime.label(for: context.date)))
		}
	}
}


enum LocalTime {
	/// "Local · 9:41 PM", plus the shift when the user has scrubbed away from now.
	static func label(for date: Date, offsetMinutes: Double = 0) -> String {
		let time = date.timeText
		guard offsetMinutes != 0 else { return "Local · \(time)" }
		return "Local · \(time) (\(offsetText(minutes: offsetMinutes)))"
	}

	/// The user's city as named by their time zone, e.g. "New York" for America/New_York.
	static var currentCity: String {
		let identifier = TimeZone.current.identifier
		let parts = identifier.split(separator: "/")
		guard parts.count >= 2, let last = parts.last else {
			return TimeZone.current.localizedName(for: .generic, locale: .current) ?? identifier
		}
		return String(last).replacing("_", with: " ")
	}

	static func offsetText(minutes: Double) -> String {
		let total = Int(minutes)
		let sign = total >= 0 ? "+" : "−"
		let hours = abs(total) / 60
		let mins = abs(total) % 60
		if hours == 0 { return "\(sign)\(mins)m" }
		return mins == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h \(mins)m"
	}
}
