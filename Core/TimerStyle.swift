//
//  TimerStyle.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation


/// How running timers are drawn. Chosen in Settings.
enum TimerStyle: String, CaseIterable, Identifiable {
	case ring, pie, analog, liquid, hourglass, candle, battery, sunset, moon, bloom

	var id: String { rawValue }

	var title: String {
		switch self {
		case .ring: "Ring"
		case .pie: "Pie"
		case .analog: "Analog"
		case .liquid: "Liquid"
		case .hourglass: "Hourglass"
		case .candle: "Candle"
		case .battery: "Battery"
		case .sunset: "Sunset"
		case .moon: "Moon"
		case .bloom: "Bloom"
		}
	}

	var caption: String {
		switch self {
		case .ring: "A ring that drains"
		case .pie: "A circle that fills"
		case .analog: "Drag the clock to set"
		case .liquid: "The card drains"
		case .hourglass: "Sand runs through"
		case .candle: "Burns down"
		case .battery: "Drains to empty"
		case .sunset: "The sun goes down"
		case .moon: "Full to new moon"
		case .bloom: "Grows while you wait"
		}
	}

	/// Styles with motion (flames, sand, waves) that need frequent redraws while running.
	var isAnimated: Bool {
		switch self {
		case .liquid, .hourglass, .candle, .battery, .bloom: true
		default: false
		}
	}
}
