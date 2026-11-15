//
//  NBTheme.swift
//  NimbleKit
//
//  NullSign's palette for NimbleKit's shared lists and sections, so every
//  screen built from them matches NullSign's look. The values mirror
//  NullSignStyle in the app, which this module can't see.
//

import SwiftUI

public enum NBTheme {
	/// Charcoal page background (NullSignStyle.canvas).
	public static let canvas = Color(red: 0.11, green: 0.11, blue: 0.12)
	/// Card and grouped-row surface (NullSignStyle.groupedSurface).
	public static let surface = Color(red: 0.17, green: 0.17, blue: 0.18)
	/// Secondary text (NullSignStyle.muted).
	public static let muted = Color(white: 0.72)
	/// Tertiary text and counts (NullSignStyle.faint).
	public static let faint = Color(white: 0.58)
}

/// SF Rounded for system-managed text where the OS supports a font design.
struct NBRoundedDesign: ViewModifier {
	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(iOS 16.1, tvOS 16.1, *) {
			content.fontDesign(.rounded)
		} else {
			content
		}
	}
}

extension View {
	/// A charcoal page with a matching navigation bar, for lists and forms.
	public func nbThemedPage() -> some View {
		self
			.scrollContentBackground(.hidden)
			.background(NBTheme.canvas.ignoresSafeArea())
			.toolbarBackground(NBTheme.canvas, for: .navigationBar)
			.toolbarBackground(.visible, for: .navigationBar)
			.toolbarColorScheme(.dark, for: .navigationBar)
			.modifier(NBRoundedDesign())
	}
}
