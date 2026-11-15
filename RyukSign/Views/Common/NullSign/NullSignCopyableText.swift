import SwiftUI
import UIKit

struct NullSignCopyableText: ViewModifier {
	let value: String
	@State private var isPresenting = false
	@State private var didCopy = false

	func body(content: Content) -> some View {
		content
			.onLongPressGesture { didCopy = false; isPresenting = true }
			.accessibilityAction(named: Text("Copy"), copy)
			.sheet(isPresented: $isPresenting) {
				NullSignMenuSheet(title: "Copy Value", systemImage: "doc.on.doc", detail: "Copy this value to the clipboard.") {
					NullSignSettingsCard {
						NullSignMenuAction(title: didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc", action: copy)
					}
				}
			}
	}

	private func copy() {
		UIPasteboard.general.string = value
		didCopy = true
		UINotificationFeedbackGenerator().notificationOccurred(.success)
	}
}

extension View {
	func nullSignCopyableText(_ value: String) -> some View {
		modifier(NullSignCopyableText(value: value))
	}
}
