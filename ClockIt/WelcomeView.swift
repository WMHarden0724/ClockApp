//
//  WelcomeView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
import UserNotifications


/// First launch: what ClockMe does, then the permissions it needs to ring. Settings › General
/// can show it again.
struct WelcomeView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var page = Page.hello
	@State private var alarmsAllowed: Bool?
	@State private var notificationsAllowed: Bool?

	enum Page: Int, CaseIterable {
		case hello, features, permissions
	}

	var body: some View {
		VStack(spacing: 0) {
			ZStack {
				switch page {
				case .hello: hello
				case .features: features
				case .permissions: permissions
				}
			}
			.frame(maxWidth: 560, maxHeight: .infinity)
			.transition(.asymmetric(
				insertion: .move(edge: .trailing).combined(with: .opacity),
				removal: .move(edge: .leading).combined(with: .opacity)
			))
			.id(page)

			footer
				.frame(maxWidth: 560)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(AuroraBackground())
		.animation(.smooth(duration: 0.45), value: page)
		.sensoryFeedback(.selection, trigger: page)
		#if os(macOS)
		.frame(minWidth: 620, minHeight: 640)
		#endif
	}

	// MARK: Pages

	private var hello: some View {
		VStack(spacing: 28) {
			Spacer(minLength: 0)

			TimelineView(.animation(minimumInterval: 1.0 / 10)) { context in
				AnalogWallClock(date: context.date, timeZone: .current)
					.frame(width: 220, height: 220)
			}
			.accessibilityHidden(true)

			VStack(spacing: 10) {
				Text("Welcome to ClockMe")
					.font(.largeTitle.weight(.bold))
					.multilineTextAlignment(.center)
				Text("Alarms, timers, a stopwatch and the world's clocks, all in sync across your iPhone, iPad, Mac and Apple Watch.")
					.font(.title3)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}

			TimelineView(.everyMinute) { context in
				Label("\(context.date.timeText) · \(LocalTime.currentCity)", systemImage: "location.fill")
					.font(.subheadline.weight(.medium))
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.softGlass(.regular, in: .capsule)
			}

			Spacer(minLength: 0)
		}
	}

	private var features: some View {
		VStack(spacing: 20) {
			Spacer(minLength: 0)

			Text("Everything that keeps time")
				.font(.title.weight(.bold))
				.multilineTextAlignment(.center)

			GlassGroup(spacing: 12) {
				VStack(spacing: 12) {
					feature(
						"Alarms", systemImage: "alarm.fill", color: "lilac",
						detail: "Ring at sunrise or in another city's time, skip just tomorrow, and set a wake-up mission so you really get up."
					)
					feature(
						"Timers", systemImage: "timer", color: "peach",
						detail: "Kitchen, laundry and workout timers with their own sounds, step-by-step sequences, and the ones you use most saved."
					)
					feature(
						"Stopwatch", systemImage: "stopwatch.fill", color: "mint",
						detail: "Laps with best and worst, a full-screen view, and the time on your Lock Screen and wrist."
					)
					feature(
						"World Clock", systemImage: "globe", color: "sky",
						detail: "See every city's day and sky at a glance, and slide through time to plan across zones."
					)
				}
			}

			Spacer(minLength: 0)
		}
	}

	private func feature(_ title: String, systemImage: String, color: String, detail: String) -> some View {
		let tint = ClockItPalette.color(named: color)

		return HStack(alignment: .top, spacing: 14) {
			Image(systemName: systemImage)
				.font(.title3.weight(.semibold))
				.foregroundStyle(.white)
				.frame(width: 44, height: 44)
				.background(tint.gradient, in: .rect(cornerRadius: 12))

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.headline)
				Text(detail)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 0)
		}
		.padding(16)
		.softGlass(.regular.tint(tint.opacity(0.12)), in: .rect(cornerRadius: Theme.cornerRadius))
		.accessibilityElement(children: .combine)
	}

	private var permissions: some View {
		VStack(spacing: 20) {
			Spacer(minLength: 0)

			Image(systemName: "bell.badge.fill")
				.font(.system(size: 52))
				.foregroundStyle(Theme.accent)
				.symbolEffect(.bounce, value: page)

			VStack(spacing: 8) {
				Text("Let ClockMe ring")
					.font(.title.weight(.bold))
				Text("You can change these any time in Settings.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			VStack(spacing: 12) {
				#if os(iOS)
				permissionRow(
					"Alarms", systemImage: "alarm.fill",
					detail: "Alarms and timers ring even when your phone is silenced or locked.",
					allowed: alarmsAllowed
				) {
					alarmsAllowed = await AlarmScheduler.requestAuthorizationIfNeeded()
				}
				#endif
				permissionRow(
					"Notifications", systemImage: "bell.fill",
					detail: notificationDetail,
					allowed: notificationsAllowed
				) {
					notificationsAllowed = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
				}
			}

			Spacer(minLength: 0)
		}
	}

	private var notificationDetail: String {
		#if os(macOS)
		"Your Mac lets you know when a timer finishes, and when each step of a sequence starts."
		#else
		"Step cues in sequences, a heads-up before timers end, and your bedtime reminder."
		#endif
	}

	private func permissionRow(_ title: String, systemImage: String, detail: String, allowed: Bool?, request: @escaping () async -> Void) -> some View {
		HStack(spacing: 14) {
			Image(systemName: systemImage)
				.font(.title3.weight(.semibold))
				.foregroundStyle(Theme.accent)
				.frame(width: 36)

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.headline)
				Text(detail)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 8)

			switch allowed {
			case true?:
				Image(systemName: "checkmark.circle.fill")
					.font(.title2)
					.foregroundStyle(ClockItPalette.color(named: "mint"))
					.accessibilityLabel("Allowed")
			case false?:
				Text("Off")
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.secondary)
			case nil:
				Button("Allow") {
					Task { await request() }
				}
				.glassProminentButton()
			}
		}
		.padding(16)
		.softGlass(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
		.animation(.snappy, value: allowed)
	}

	// MARK: Footer

	private var footer: some View {
		VStack(spacing: 18) {
			HStack(spacing: 8) {
				ForEach(Page.allCases, id: \.self) { dot in
					Capsule()
						.fill(dot == page ? Theme.accent : Color.secondary.opacity(0.35))
						.frame(width: dot == page ? 22 : 8, height: 8)
				}
			}
			.accessibilityHidden(true)

			HStack {
				if page != .hello {
					Button("Back") {
						page = Page(rawValue: page.rawValue - 1) ?? .hello
					}
					.glassButton()
					.keyboardShortcut(.cancelAction)
				}

				Spacer()

				Button {
					if let next = Page(rawValue: page.rawValue + 1) {
						page = next
					} else {
						AppSettings.shared.hasSeenWelcome = true
						dismiss()
					}
				} label: {
					Text(page == .permissions ? "Get Started" : "Continue")
						.font(.headline)
						.frame(minWidth: 140)
						.padding(.vertical, 4)
				}
				.glassProminentButton()
				.keyboardShortcut(.defaultAction)
			}
		}
		.padding(.top, 16)
	}
}


#Preview {
	WelcomeView()
}
