//
//  TimerCategory.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation


/// What a timer is for. Drives its icon, color, prompts, one-tap suggestions and finish message.
enum TimerCategory: String, Codable, CaseIterable, Identifiable {
	case general, food, laundry, timeOut, tea, workout, focus, nap

	var id: String { rawValue }

	var title: String {
		switch self {
		case .general: "Timer"
		case .food: "Food"
		case .laundry: "Laundry"
		case .timeOut: "Time-Out"
		case .tea: "Tea & Coffee"
		case .workout: "Workout"
		case .focus: "Focus"
		case .nap: "Nap"
		}
	}

	var symbol: String {
		switch self {
		case .general: "timer"
		case .food: "fork.knife"
		case .laundry: "washer.fill"
		case .timeOut: "figure.child"
		case .tea: "cup.and.saucer.fill"
		case .workout: "figure.run"
		case .focus: "brain.head.profile"
		case .nap: "bed.double.fill"
		}
	}

	var colorName: String {
		switch self {
		case .general, .focus: "lilac"
		case .food: "peach"
		case .laundry, .nap: "sky"
		case .timeOut: "rose"
		case .tea: "butter"
		case .workout: "mint"
		}
	}

	var labelPrompt: String {
		switch self {
		case .general: "Label"
		case .food: "What's cooking?"
		case .laundry: "Which load?"
		case .timeOut: "Child's name"
		case .tea: "Which brew?"
		case .workout: "Exercise"
		case .focus: "What are you working on?"
		case .nap: "Label"
		}
	}

	var notesPrompt: String {
		switch self {
		case .general: "Notes"
		case .food: "Stir, flip, check the oven…"
		case .laundry: "Hang delicates, move to dryer…"
		case .timeOut: "What happened? What to talk about after…"
		case .tea: "Water temp, ratio…"
		case .workout: "Sets, reps, weight…"
		case .focus: "Goal for this session…"
		case .nap: "Notes"
		}
	}

	/// Shown when the timer hits zero.
	var doneText: String {
		switch self {
		case .general: "Done"
		case .food: "Ready"
		case .laundry: "Load done"
		case .timeOut: "All done"
		case .tea: "Steeped"
		case .workout: "Time!"
		case .focus: "Break time"
		case .nap: "Wake up"
		}
	}

	/// One-tap durations for this kind of timer. Time-outs are set by age instead.
	var suggestions: [TimerSuggestion] {
		switch self {
		case .general, .timeOut:
			[]
		case .food:
			[.init("Soft-boiled egg", minutes: 6), .init("Hard-boiled egg", minutes: 10), .init("Pasta", minutes: 10),
			 .init("Rice", minutes: 18), .init("Cookies", minutes: 12), .init("Rest the steak", minutes: 5)]
		case .laundry:
			[.init("Quick wash", minutes: 30), .init("Normal wash", minutes: 50), .init("Delicates", minutes: 40),
			 .init("Dryer", minutes: 60)]
		case .tea:
			[.init("Green tea", minutes: 3), .init("Black tea", minutes: 4), .init("Herbal tea", minutes: 6),
			 .init("French press", minutes: 4), .init("Pour-over", minutes: 3.5)]
		case .workout:
			[.init("Rest", minutes: 1.5), .init("Plank", minutes: 1), .init("Stretch", minutes: 5),
			 .init("HIIT", minutes: 20), .init("Run", minutes: 30)]
		case .focus:
			[.init("Pomodoro", minutes: 25), .init("Short break", minutes: 5), .init("Long break", minutes: 15),
			 .init("Deep work", minutes: 50)]
		case .nap:
			[.init("Power nap", minutes: 20), .init("Recharge", minutes: 30), .init("Full cycle", minutes: 90)]
		}
	}
}


struct TimerSuggestion: Identifiable, Hashable {
	let label: String
	let duration: TimeInterval

	var id: String { label }

	init(_ label: String, minutes: Double) {
		self.label = label
		self.duration = minutes * 60
	}
}
