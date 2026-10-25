//
//  AppTimer.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import Foundation

struct AppTimer: Identifiable, Codable {
	let id: UUID
	var label: String
	var duration: TimeInterval
	var remaining: TimeInterval
	var isRunning: Bool
	var colorName: String // "orange", "blue", etc.
	var soundName: String
	var createdAt: Date
	
	var progress: Double {
		guard duration > 0 else { return 0 }
		return 1.0 - (remaining / duration)
	}
	
	static let sample = AppTimer(
		id: UUID(),
		label: "Pasta",
		duration: 600,
		remaining: 420,
		isRunning: true,
		colorName: "orange",
		soundName: "default",
		createdAt: Date()
	)
}
