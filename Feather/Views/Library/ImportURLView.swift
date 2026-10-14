import SwiftUI
import UIKit

struct ImportURLView: View {
	@Environment(\.dismiss) private var dismiss
	@FocusState private var isURLFocused: Bool
	@State private var text = ""
	@State private var showsValidation = false
	@State private var didSubmit = false
	let onSubmit: (URL) -> Void

	private var trimmedText: String {
		text.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var downloadURL: URL? {
		guard
			let url = URL(string: trimmedText),
			let scheme = url.scheme?.lowercased(),
			scheme == "https" || scheme == "http",
			let host = url.host, !host.isEmpty
		else { return nil }
		return url
	}

	var body: some View {
		NullSignMenuSheet(
			title: .localized("Import from URL"),
			systemImage: "link",
			detail: "Paste a direct download link to an IPA or TIPA. The app will appear in your imported library.",
			detents: [.large]
		) {
			VStack(alignment: .leading, spacing: 16) {
				NullSignSectionLabel(title: .localized("Download URL"), systemImage: "link")
				VStack(alignment: .leading, spacing: 12) {
					TextField("https://example.com/app.ipa", text: $text)
						.font(.roundedUI(.body))
						.keyboardType(.URL)
						.textContentType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.submitLabel(.go)
						.focused($isURLFocused)
						.onSubmit(submit)
						.padding(14)
						.frame(minHeight: 50)
						.background(NullSignStyle.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
						.accessibilityLabel(.localized("Download URL"))

					HStack {
						Button { text = UIPasteboard.general.string ?? text } label: {
							Label(.localized("Paste"), systemImage: "doc.on.clipboard")
						}
						.buttonStyle(NullSignSecondaryButtonStyle(height: 34))
						Spacer()
						if !text.isEmpty {
							Button(.localized("Clear")) { text = "" }
								.font(.roundedUI(.subheadline, weight: .bold))
								.frame(minWidth: 44, minHeight: 44)
						}
					}

					if showsValidation && downloadURL == nil {
						Label("Enter a complete http:// or https:// download URL.", systemImage: "exclamationmark.circle")
							.font(.roundedUI(.footnote))
							.foregroundStyle(NullSignStyle.danger)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.padding(16)
				.nullSignSurface(fill: NullSignStyle.groupedSurface)

				Button(action: submit) {
					Label(.localized("Import App"), systemImage: "arrow.down.circle.fill")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(NullSignPrimaryButtonStyle())
				.disabled(trimmedText.isEmpty || didSubmit)

				Button(.localized("Cancel")) { dismiss() }
					.font(.roundedUI(.subheadline, weight: .bold))
					.frame(maxWidth: .infinity, minHeight: 44)
					.foregroundStyle(NullSignStyle.muted)
			}
		}
		.onChange(of: text) { _ in showsValidation = false }
		.task { isURLFocused = true }
	}

	private func submit() {
		guard !didSubmit else { return }
		guard let downloadURL else {
			showsValidation = true
			return
		}
		didSubmit = true
		isURLFocused = false
		onSubmit(downloadURL)
		dismiss()
	}
}
