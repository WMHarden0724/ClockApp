//
//  ClockItWatchWidgetsBundle.swift
//  ClockItWatchWidgets
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
import WidgetKit


/// Watch complications and Smart Stack widgets. They read what the Watch app shares
/// through the App Group; the views are shared with the iPhone widgets.
@main
struct ClockItWatchWidgetsBundle: WidgetBundle {
	var body: some Widget {
		NextAlarmWidget()
		TimersWidget()
		WorldClockWidget()
	}
}
