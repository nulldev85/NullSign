import UIKit

extension UIFont {
	/// UIKit controls need their own rounded descriptor and Dynamic Type scaling.
	static func roundedUI(
		size: CGFloat,
		weight: UIFont.Weight,
		textStyle: UIFont.TextStyle,
		compatibleWith traits: UITraitCollection? = nil
	) -> UIFont {
		let base = UIFont.systemFont(ofSize: size, weight: weight)
		let rounded = base.fontDescriptor.withDesign(.rounded).map {
			UIFont(descriptor: $0, size: size)
		} ?? base
		return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: rounded, compatibleWith: traits)
	}
}
