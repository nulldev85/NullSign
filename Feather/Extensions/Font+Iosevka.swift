import SwiftUI

extension Font {
	static func iosevka(
		_ style: Font.TextStyle,
		weight: Font.Weight? = nil
	) -> Font {
		let resolvedWeight = weight ?? defaultIosevkaWeight(for: style)
		return .custom(
			iosevkaName(for: resolvedWeight),
			size: iosevkaPointSize(for: style),
			relativeTo: style
		)
	}

	static func iosevka(
		size: CGFloat,
		weight: Font.Weight = .regular
	) -> Font {
		.custom(iosevkaName(for: weight), size: size)
	}

	private static func iosevkaName(for weight: Font.Weight) -> String {
		if weight == .bold || weight == .heavy || weight == .black {
			return "Iosevka-Bold"
		}
		if weight == .semibold {
			return "Iosevka-Semibold"
		}
		if weight == .medium {
			return "Iosevka-Medium"
		}
		return "Iosevka"
	}

	private static func defaultIosevkaWeight(for style: Font.TextStyle) -> Font.Weight {
		style == .headline ? .semibold : .regular
	}

	private static func iosevkaPointSize(for style: Font.TextStyle) -> CGFloat {
		switch style {
		case .largeTitle: return 34
		case .title: return 28
		case .title2: return 22
		case .title3: return 20
		case .headline, .body: return 17
		case .callout: return 16
		case .subheadline: return 15
		case .footnote: return 13
		case .caption: return 12
		case .caption2: return 11
		@unknown default: return 17
		}
	}
}
