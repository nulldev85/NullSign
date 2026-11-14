//
//  VerticalBarLayout.swift
//  Feather
//

import SwiftUI

/// Whether the system lays the toolbar and tab bar out vertically along the
/// side: on iPhone Duo's outer display, and on its inner display in landscape.
/// Toolbar buttons use it to carry a symbol and a title there, since the
/// system leaves text-only items in a horizontal bar.
private struct VerticalBarLayoutKey: EnvironmentKey {
	static let defaultValue = false
}

extension EnvironmentValues {
	var nullSignVerticalBars: Bool {
		get { self[VerticalBarLayoutKey.self] }
		set { self[VerticalBarLayoutKey.self] = newValue }
	}
}

extension View {
	/// Publishes the system's vertical-bar placement to this view's subtree as
	/// `nullSignVerticalBars`. Before iOS 27.1 there is no vertical bar.
	func readsVerticalBarLayout() -> some View {
		modifier(VerticalBarLayoutReader())
	}
}

private struct VerticalBarLayoutReader: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 27.1, *) {
			content.modifier(_SystemVerticalBarLayout())
		} else {
			content
		}
	}
}

@available(iOS 27.1, *)
private struct _SystemVerticalBarLayout: ViewModifier {
	/// The edge the system places its vertical bar on, or nil where it keeps
	/// bars horizontal (other iPhones, iPhone Duo's inner display in portrait).
	@Environment(\.toolbarVerticalEdge) private var _edge

	func body(content: Content) -> some View {
		content.environment(\.nullSignVerticalBars, _edge != nil)
	}
}
