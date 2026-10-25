//
//  RepeatDaysPicker.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
//

import SwiftUI


struct RepeatDaysPicker: View {
	@Binding var selected: Set<Int>
	private let days = Calendar.current.veryShortWeekdaySymbols

	var body: some View {
		GlassEffectContainer(spacing: 6) {
			HStack(spacing: 6) {
				ForEach(1...7, id: \.self) { day in
					let isOn = selected.contains(day)

					Button {
						if isOn {
							selected.remove(day)
						} else {
							selected.insert(day)
						}
					} label: {
						Text(days[day - 1])
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(isOn ? .white : .primary)
							.frame(width: 38, height: 38)
					}
					.buttonStyle(.plain)
					.glassEffect(isOn ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .circle)
					.accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
					.accessibilityAddTraits(isOn ? .isSelected : [])
				}
			}
		}
		.frame(maxWidth: .infinity)
		.sensoryFeedback(.selection, trigger: selected)
	}
}
