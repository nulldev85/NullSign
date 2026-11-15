import SwiftUI

/// Apply at each independent presentation/hosting root, not only the app window.
/// UIKit hosting controllers do not inherit the window's SwiftUI environment.
struct NullSignTypography: ViewModifier {
	func body(content: Content) -> some View {
		content
			.environment(\.font, .roundedUI(.body))
			.modifier(NullSignRoundedFontDesign())
	}
}

extension View {
	func nullSignTypography() -> some View {
		modifier(NullSignTypography())
	}

	/// SwiftUI can replace UIKit appearance title fonts; own the inline label.
	func nullSignNavigationTitle(_ title: String) -> some View {
		self.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .principal) {
					Text(title)
						.font(.roundedUI(.headline, weight: .heavy))
						.lineLimit(1)
						.minimumScaleFactor(0.8)
				}
			}
	}
}

/// Apply the rounded design to system-managed controls where supported.
struct NullSignRoundedFontDesign: ViewModifier {
	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(iOS 16.1, *) {
			content.fontDesign(.rounded)
		} else {
			content
		}
	}
}

extension Font {
	/// SF Rounded with a strong title hierarchy and readable supporting text.
	static func roundedUI(
		_ style: Font.TextStyle,
		weight: Font.Weight? = nil
	) -> Font {
		.system(style, design: .rounded)
			.weight(weight ?? roundedUIWeight(for: style))
	}

	static func roundedUI(
		size: CGFloat,
		weight: Font.Weight = .regular
	) -> Font {
		.system(size: size, weight: weight, design: .rounded)
	}

	private static func roundedUIWeight(for style: Font.TextStyle) -> Font.Weight {
		switch style {
		case .largeTitle, .title, .title2, .title3:
			return .heavy
		case .headline:
			return .bold
		default:
			return .regular
		}
	}
}
