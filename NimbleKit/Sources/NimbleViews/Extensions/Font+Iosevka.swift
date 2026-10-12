import SwiftUI

extension Font {
	static func iosevka(
		_ style: Font.TextStyle,
		weight: Font.Weight? = nil
	) -> Font {
		let resolvedWeight = weight ?? (style == .headline ? .semibold : .regular)
		let name: String
		if resolvedWeight == .bold || resolvedWeight == .heavy || resolvedWeight == .black {
			name = "Iosevka-Bold"
		} else if resolvedWeight == .semibold {
			name = "Iosevka-Semibold"
		} else if resolvedWeight == .medium {
			name = "Iosevka-Medium"
		} else {
			name = "Iosevka"
		}

		let size: CGFloat
		switch style {
		case .largeTitle: size = 34
		case .title: size = 28
		case .title2: size = 22
		case .title3: size = 20
		case .headline, .body: size = 17
		case .callout: size = 16
		case .subheadline: size = 15
		case .footnote: size = 13
		case .caption: size = 12
		case .caption2: size = 11
		@unknown default: size = 17
		}
		return .custom(name, size: size, relativeTo: style)
	}
}
