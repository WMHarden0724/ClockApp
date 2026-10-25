//
//  Glass.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/25/26.
//

import SwiftUI


/// A glass description that renders as Liquid Glass on iPhone, iPad and Mac,
/// and as visionOS's own glass material on Vision Pro.
struct SoftGlass {
	var tint: Color?
	var isInteractive = false

	static let regular = SoftGlass()

	func tint(_ color: Color) -> SoftGlass {
		var copy = self
		copy.tint = color
		return copy
	}

	func interactive() -> SoftGlass {
		var copy = self
		copy.isInteractive = true
		return copy
	}

	#if !os(visionOS)
	var glass: Glass {
		var glass = Glass.regular
		if let tint { glass = glass.tint(tint) }
		if isInteractive { glass = glass.interactive() }
		return glass
	}
	#endif
}


extension View {
	func softGlass(_ glass: SoftGlass = .regular, in shape: some InsettableShape) -> some View {
		#if os(visionOS)
		self
			.background(glass.tint ?? .clear, in: shape)
			.glassBackgroundEffect(in: shape)
		#else
		glassEffect(glass.glass, in: shape)
		#endif
	}

	@ViewBuilder
	func glassButton() -> some View {
		#if os(visionOS)
		buttonStyle(.bordered)
		#else
		buttonStyle(.glass)
		#endif
	}

	@ViewBuilder
	func glassProminentButton() -> some View {
		#if os(visionOS)
		buttonStyle(.borderedProminent)
		#else
		buttonStyle(.glassProminent)
		#endif
	}

	/// Navigation subtitle where supported; a bottom ornament on Vision Pro.
	@ViewBuilder
	func navigationSubtitleIfAvailable(_ subtitle: Text) -> some View {
		#if os(visionOS)
		toolbar {
			ToolbarItem(placement: .bottomOrnament) {
				subtitle.font(.headline)
			}
		}
		#else
		navigationSubtitle(subtitle)
		#endif
	}

	@ViewBuilder
	func dismissKeyboardOnScroll() -> some View {
		#if os(visionOS)
		self
		#else
		scrollDismissesKeyboard(.interactively)
		#endif
	}
}


/// Groups glass shapes so they blend together; a plain container on Vision Pro.
struct GlassGroup<Content: View>: View {
	let spacing: CGFloat
	@ViewBuilder let content: Content

	init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
		self.spacing = spacing
		self.content = content()
	}

	var body: some View {
		#if os(visionOS)
		content
		#else
		GlassEffectContainer(spacing: spacing) { content }
		#endif
	}
}
