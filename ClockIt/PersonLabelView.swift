//
//  PersonLabelView.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI
#if os(iOS)
import ContactsUI
#endif


/// Labels a World Clock city with someone who lives there, so you check on Mom, not Sydney.
struct PersonLabelView: View {
	let city: WorldClockCity
	var onSave: (String?) -> Void

	@Environment(\.dismiss) private var dismiss
	@State private var name: String

	init(city: WorldClockCity, onSave: @escaping (String?) -> Void) {
		self.city = city
		self.onSave = onSave
		_name = State(initialValue: city.person ?? "")
	}

	private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

	var body: some View {
		NavigationStack {
			Form {
				Section {
					HStack(spacing: 14) {
						PersonAvatar(name: trimmed.isEmpty ? city.name : trimmed, size: 48)
						VStack(alignment: .leading, spacing: 2) {
							Text(trimmed.isEmpty ? city.name : trimmed)
								.font(.headline)
							Text(trimmed.isEmpty ? "No one yet" : city.name)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
					.padding(.vertical, 4)
				}

				Section {
					TextField("Name, like Mom or Alex", text: $name)
						.textContentType(.name)
						.onSubmit(save)
					#if os(iOS)
					Button("Choose from Contacts", systemImage: "person.crop.circle") {
						Task {
							if let picked = await ContactPicker.pickName() { name = picked }
						}
					}
					#endif
				} footer: {
					Text("The clock shows their name, with \(city.name) underneath.")
				}

				if city.person != nil {
					Section {
						Button("Remove Label", role: .destructive) {
							onSave(nil)
							dismiss()
						}
					}
				}
			}
			.navigationTitle("Who's in \(city.name)?")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", action: save)
						.disabled(trimmed.isEmpty)
				}
			}
		}
		#if os(macOS)
		.frame(minWidth: 380, minHeight: 300)
		#endif
	}

	private func save() {
		guard !trimmed.isEmpty else { return }
		onSave(trimmed)
		dismiss()
	}
}


/// Initials in a soft circle, tinted by the name so each person keeps their color.
struct PersonAvatar: View {
	let name: String
	var size: CGFloat = 32

	var body: some View {
		Text(initials)
			.font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
			.foregroundStyle(.white)
			.frame(width: size, height: size)
			.background(color.gradient, in: .circle)
			.accessibilityHidden(true)
	}

	private var initials: String {
		let formatter = PersonNameComponentsFormatter()
		formatter.style = .abbreviated
		if let components = formatter.personNameComponents(from: name) {
			let text = formatter.string(from: components)
			if !text.isEmpty { return String(text.prefix(2)) }
		}
		return String(name.prefix(1)).uppercased()
	}

	private var color: Color {
		// A stable pick: String.hashValue changes every launch.
		let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
		let palette = ClockItPalette.named
		return palette[sum % palette.count].color
	}
}


#if os(iOS)
/// Shows the system contact picker, which needs no Contacts permission, and returns the
/// name someone goes by: their nickname, else their first name.
@MainActor
private final class ContactPicker: NSObject, CNContactPickerDelegate {
	private var continuation: CheckedContinuation<String?, Never>?
	private static var current: ContactPicker?

	static func pickName() async -> String? {
		guard let presenter = topViewController() else { return nil }
		let picker = ContactPicker()
		current = picker
		defer { current = nil }
		return await withCheckedContinuation { continuation in
			picker.continuation = continuation
			let controller = CNContactPickerViewController()
			controller.delegate = picker
			presenter.present(controller, animated: true)
		}
	}

	func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
		let name = [contact.nickname, contact.givenName, CNContactFormatter.string(from: contact, style: .fullName) ?? ""]
			.first { !$0.isEmpty }
		continuation?.resume(returning: name)
		continuation = nil
	}

	func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
		continuation?.resume(returning: nil)
		continuation = nil
	}

	private static func topViewController() -> UIViewController? {
		let scene = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first { $0.activationState == .foregroundActive }
		var top = scene?.keyWindow?.rootViewController
		while let presented = top?.presentedViewController { top = presented }
		return top
	}
}
#endif


#Preview {
	PersonLabelView(city: WorldClockCity.sampleCities[3]) { _ in }
}
