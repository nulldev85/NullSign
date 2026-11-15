//
//  Color+userTint.swift
//  NullSign
//
//  Created by Ryuk on 24.08.2026.
//

import SwiftUI
import AltSourceKit

extension Color {
	/// NullSign blue (NullSignStyle.accent). NullSign always uses it; the
	/// saved tint is reset to it on launch, as NullSign 1.x did.
	static let defaultUserTintHex = "#0094FF"

	static var userTint: Color {
		Color(hex: defaultUserTintHex)
	}

	/// Darker sibling of the user's tint for secondary states.
	static var userTintDeep: Color {
		Color(uiColor: UIColor(userTint).darkened())
	}
}

private extension UIColor {
	func darkened() -> UIColor {
		var hue: CGFloat = 0
		var saturation: CGFloat = 0
		var brightness: CGFloat = 0
		var alpha: CGFloat = 0

		guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }

		return UIColor(
			hue: hue,
			saturation: min(saturation * 1.1, 1),
			// Floor keeps a near-black tint from vanishing into a dark background.
			brightness: min(max(brightness * 0.62, 0.32), 0.78),
			alpha: alpha
		)
	}
}
