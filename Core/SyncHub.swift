//
//  SyncHub.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import Foundation
#if os(iOS) || os(watchOS)
import WatchConnectivity
#endif


/// What gets synced. Each channel is one store's shareable state.
enum SyncChannel: String, CaseIterable {
	case clock   // alarms and world clock cities
	case timers  // running and paused timers
	case stopwatch // the stopwatch and its saved runs
	case timerLibrary // saved timers and timer history
}


/// Keeps every device's copy of alarms, cities, timers and the stopwatch in step.
///
/// iPhone, iPad and Mac share through iCloud key-value storage. The Watch talks to the iPhone
/// directly with WatchConnectivity (which wakes the iPhone app), and the iPhone relays between
/// the Watch and iCloud. Each change is stamped with when it happened; the newest change wins.
final class SyncHub: NSObject {
	static let shared = SyncHub()

	/// Identifies this device so it ignores its own echoes.
	let deviceID: String

	private struct Envelope: Codable {
		var modifiedAt: Date
		var origin: String
		var payload: Data
	}

	private struct Channel {
		var apply: (Data) -> Void
		var seed: () -> Data?
	}

	private var channels: [SyncChannel: Channel] = [:]
	/// The newest envelope seen or sent per channel, persisted so stale updates are ignored after relaunch.
	private var latest: [SyncChannel: Data] = [:]
	private var started = false

	#if !os(watchOS)
	private let cloud = NSUbiquitousKeyValueStore.default
	#endif

	private override init() {
		let defaults = UserDefaults.standard
		if let id = defaults.string(forKey: "syncDeviceID") {
			deviceID = id
		} else {
			deviceID = UUID().uuidString
			defaults.set(deviceID, forKey: "syncDeviceID")
		}
		super.init()
		for channel in SyncChannel.allCases {
			latest[channel] = defaults.data(forKey: Self.key(channel))
		}
	}

	/// Stores call this once. `apply` receives another device's payload; `seed` supplies this
	/// device's current payload for the very first sync.
	func register(_ channel: SyncChannel, apply: @escaping (Data) -> Void, seed: @escaping () -> Data?) {
		channels[channel] = Channel(apply: apply, seed: seed)
	}

	func start() {
		guard !started else { return }
		started = true

		#if !os(watchOS)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(cloudDidChange(_:)),
			name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
			object: cloud
		)
		cloud.synchronize()
		pullFromCloud()
		#endif

		// The ringing device (normally your iPhone) gives everyone else a starting point.
		if AlarmScheduler.isRingingDevice {
			for channel in SyncChannel.allCases where latest[channel] == nil {
				if let payload = channels[channel]?.seed() {
					publish(channel, payload: payload)
				}
			}
		}

		#if os(iOS) || os(watchOS)
		if WCSession.isSupported() {
			WCSession.default.delegate = self
			WCSession.default.activate()
		}
		#endif
	}

	/// Picks up anything missed while in the background.
	func refresh() {
		#if !os(watchOS)
		cloud.synchronize()
		pullFromCloud()
		#endif
	}

	/// Shares a local change with every other device.
	func publish(_ channel: SyncChannel, payload: Data) {
		let envelope = Envelope(modifiedAt: Date(), origin: deviceID, payload: payload)
		guard let data = try? JSONEncoder().encode(envelope) else { return }
		remember(data, for: channel)
		forward(data, channel: channel, toCloud: true, toCounterpart: true)
	}

	// MARK: Receiving

	private func receive(_ data: Data, channel: SyncChannel, fromCloud: Bool) {
		guard let incoming = try? JSONDecoder().decode(Envelope.self, from: data),
			  incoming.origin != deviceID else { return }
		if let current = latest[channel].flatMap({ try? JSONDecoder().decode(Envelope.self, from: $0) }),
		   current.modifiedAt >= incoming.modifiedAt {
			return
		}
		remember(data, for: channel)
		channels[channel]?.apply(incoming.payload)
		// Relay: changes from iCloud go on to the Watch, and the Watch's changes go up to iCloud.
		forward(data, channel: channel, toCloud: !fromCloud, toCounterpart: fromCloud)
	}

	private func remember(_ data: Data, for channel: SyncChannel) {
		latest[channel] = data
		UserDefaults.standard.set(data, forKey: Self.key(channel))
	}

	private func forward(_ data: Data, channel: SyncChannel, toCloud: Bool, toCounterpart: Bool) {
		#if !os(watchOS)
		if toCloud {
			cloud.set(data, forKey: Self.key(channel))
			cloud.synchronize()
		}
		#endif
		#if os(iOS) || os(watchOS)
		if toCounterpart {
			sendToCounterpart(data, channel: channel)
		}
		#endif
	}

	private static func key(_ channel: SyncChannel) -> String {
		"sync.\(channel.rawValue)"
	}

	// MARK: iCloud

	#if !os(watchOS)
	private func pullFromCloud() {
		for channel in SyncChannel.allCases {
			if let data = cloud.data(forKey: Self.key(channel)) {
				receive(data, channel: channel, fromCloud: true)
			}
		}
	}

	@objc nonisolated private func cloudDidChange(_ notification: Notification) {
		let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
		Task { @MainActor in
			for channel in SyncChannel.allCases where keys.contains(Self.key(channel)) {
				if let data = self.cloud.data(forKey: Self.key(channel)) {
					self.receive(data, channel: channel, fromCloud: true)
				}
			}
		}
	}
	#endif
}


// MARK: - Watch

#if os(iOS) || os(watchOS)
extension SyncHub: WCSessionDelegate {
	private func sendToCounterpart(_ data: Data, channel: SyncChannel) {
		let session = WCSession.default
		guard session.activationState == .activated else { return }
		#if os(watchOS)
		// Messages wake the iPhone app right away so it can schedule; queued transfers are the fallback.
		let message = [channel.rawValue: data]
		if session.isReachable {
			session.sendMessage(message, replyHandler: nil) { _ in
				session.transferUserInfo(message)
			}
		} else {
			session.transferUserInfo(message)
		}
		#else
		guard session.isPaired, session.isWatchAppInstalled else { return }
		var context: [String: Any] = [:]
		for (channel, data) in latest {
			context[channel.rawValue] = data
		}
		try? session.updateApplicationContext(context)
		#endif
	}

	private func receive(watchPayload: [String: Any]) {
		for channel in SyncChannel.allCases {
			if let data = watchPayload[channel.rawValue] as? Data {
				receive(data, channel: channel, fromCloud: false)
			}
		}
	}

	nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
		Task { @MainActor in
			guard activationState == .activated else { return }
			#if os(watchOS)
			self.receive(watchPayload: session.receivedApplicationContext)
			#else
			if let (channel, data) = self.latest.first {
				self.sendToCounterpart(data, channel: channel)
			}
			#endif
		}
	}

	nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
		let payload = applicationContext.compactMapValues { $0 as? Data }
		Task { @MainActor in self.receive(watchPayload: payload) }
	}

	nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
		let payload = message.compactMapValues { $0 as? Data }
		Task { @MainActor in self.receive(watchPayload: payload) }
	}

	nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
		let payload = userInfo.compactMapValues { $0 as? Data }
		Task { @MainActor in self.receive(watchPayload: payload) }
	}

	#if os(iOS)
	nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

	nonisolated func sessionDidDeactivate(_ session: WCSession) {
		session.activate()
	}
	#endif
}
#endif
