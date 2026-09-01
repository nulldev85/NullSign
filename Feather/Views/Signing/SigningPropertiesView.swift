//
//  SigningAppPropertiesView.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningPropertiesView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var text: String = ""
	@FocusState private var _isFieldFocused: Bool
	
	var saveButtonDisabled: Bool {
		text == initialValue
	}
	
	var title: String
	var initialValue: String 
	@Binding var bindingValue: String?
	
	// MARK: Body
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 12) {
				SigningSectionHeader(
					title: title,
					detail: "This change applies only to the current signing session."
				)

				HStack(spacing: 11) {
					SigningRowIcon(systemImage: _fieldIcon)
					TextField(initialValue, text: $text)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.focused($_isFieldFocused)

					if !text.isEmpty && text != initialValue {
						Button {
							text = initialValue
						} label: {
							Image(systemName: "arrow.uturn.backward.circle.fill")
								.foregroundStyle(.secondary)
						}
						.buttonStyle(.plain)
						.accessibilityLabel("Restore original value")
					}
				}
				.padding(12)
				.background(NullSignStyle.panel)
				.overlay {
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.stroke(_isFieldFocused ? NullSignStyle.cyan.opacity(0.7) : NullSignStyle.hairline, lineWidth: 1)
				}
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

				if text != initialValue {
					Label("Unsaved change", systemImage: "circle.fill")
						.font(.caption)
						.foregroundStyle(NullSignStyle.cyan)
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle(title)
		.tint(NullSignStyle.cyan)
		.toolbar {
			NBToolbarButton(
				.localized("Save"),
				style: .text,
				placement: .topBarTrailing,
				isDisabled: saveButtonDisabled
			) {
				if !saveButtonDisabled {
					bindingValue = text
					dismiss()
				}
			}
		}
		.onAppear {
			text = initialValue
			DispatchQueue.main.async { _isFieldFocused = true }
		}
	}

	private var _fieldIcon: String {
		switch title.lowercased() {
		case let value where value.contains("identifier"): "number"
		case let value where value.contains("version"): "tag"
		default: "textformat"
		}
	}
}
