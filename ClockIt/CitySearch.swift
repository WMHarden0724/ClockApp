//
//  CitySearch.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import MapKit
import Observation


/// Live city search through MapKit, so any town ("Brunswick, GA") can be found and placed in its time zone.
@Observable
final class CitySearch: NSObject, MKLocalSearchCompleterDelegate {
	struct Place {
		let name: String
		let region: String
		let timeZone: TimeZone
	}

	private(set) var results: [MKLocalSearchCompletion] = []

	var query = "" {
		didSet {
			if query.isEmpty {
				results = []
			} else {
				completer.queryFragment = query
			}
		}
	}

	@ObservationIgnored private let completer = MKLocalSearchCompleter()

	override init() {
		super.init()
		completer.resultTypes = .address
		if #available(iOS 18, macOS 15, visionOS 2, *) {
			completer.addressFilter = MKAddressFilter(including: [.locality])
		}
		completer.delegate = self
	}

	func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
		results = completer.results
	}

	func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
		results = []
	}

	/// Looks up the place behind a suggestion to find its time zone.
	func resolve(_ completion: MKLocalSearchCompletion) async -> Place? {
		let request = MKLocalSearch.Request(completion: completion)
		request.resultTypes = .address
		guard let item = try? await MKLocalSearch(request: request).start().mapItems.first,
			  let timeZone = item.timeZone else { return nil }

		// "Brunswick, GA" → name "Brunswick", region "GA, United States".
		let parts = completion.title.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
		let name = parts.first ?? completion.title
		let region = ([parts.count > 1 ? parts[1] : ""] + [completion.subtitle])
			.filter { !$0.isEmpty }
			.joined(separator: ", ")
		return Place(name: name, region: region, timeZone: timeZone)
	}
}
