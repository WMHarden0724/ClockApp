//
//  Compatibility.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


// Compiled into the app, the widget extension and the Watch app. Stand-ins for SwiftUI
// added after iOS 17 / macOS 14 / watchOS 10, so callers don't need availability checks.


extension Color {
	/// `mix(with:by:)` where available; a plain sRGB blend before that.
	func blend(with other: Color, by fraction: Double) -> Color {
		if #available(iOS 18, macOS 15, watchOS 11, visionOS 2, *) {
			return mix(with: other, by: fraction)
		}
		let environment = EnvironmentValues()
		let a = resolve(in: environment)
		let b = other.resolve(in: environment)
		let t = Float(min(max(fraction, 0), 1))
		return Color(Color.Resolved(
			red: a.red + (b.red - a.red) * t,
			green: a.green + (b.green - a.green) * t,
			blue: a.blue + (b.blue - a.blue) * t,
			opacity: a.opacity + (b.opacity - a.opacity) * t
		))
	}
}


extension View {
	/// Wiggles a symbol for as long as `isActive`; pulses before wiggle existed.
	@ViewBuilder
	func wiggleSymbol(isActive: Bool) -> some View {
		if #available(iOS 18, macOS 15, watchOS 11, visionOS 2, *) {
			symbolEffect(.wiggle, options: .repeat(.continuous), isActive: isActive)
		} else {
			symbolEffect(.pulse, options: .repeating, isActive: isActive)
		}
	}
}
