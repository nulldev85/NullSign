import SwiftUI
import UIKit

/// SwiftUI's searchable bar is UIKit-owned and can ignore the content font.
/// Use only public navigation/search-controller APIs; keep native search behavior.
struct NullSignSearchTypography: UIViewControllerRepresentable {
	func makeUIViewController(context: Context) -> Controller { Controller() }

	func updateUIViewController(_ controller: Controller, context: Context) {
		controller.updateSearchFont()
	}

	final class Controller: UIViewController {
		override func loadView() {
			view = UIView()
			view.isUserInteractionEnabled = false
		}

		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
			updateSearchFont()
		}

		override func viewDidLayoutSubviews() {
			super.viewDidLayoutSubviews()
			updateSearchFont()
		}

		override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
			super.traitCollectionDidChange(previousTraitCollection)
			updateSearchFont()
		}

		func updateSearchFont() {
			guard let searchBar = navigationController?.topViewController?.navigationItem.searchController?.searchBar else { return }
			let field = searchBar.searchTextField
			let font = UIFont.roundedUI(
				size: 17, weight: .regular, textStyle: .body, compatibleWith: field.traitCollection
			)
			// Avoid changing layout repeatedly when nothing has changed.
			if field.font != font { field.font = font }
			field.adjustsFontForContentSizeCategory = true
			if let placeholder = field.attributedPlaceholder,
			   placeholder.length > 0,
			   (placeholder.attribute(.font, at: 0, effectiveRange: nil) as? UIFont) != font {
				let roundedPlaceholder = NSMutableAttributedString(attributedString: placeholder)
				roundedPlaceholder.addAttribute(.font, value: font, range: NSRange(location: 0, length: placeholder.length))
				field.attributedPlaceholder = roundedPlaceholder
			}
		}
	}
}
