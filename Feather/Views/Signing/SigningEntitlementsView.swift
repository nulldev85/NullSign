//
//  SigningEntitlementsView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningEntitlementsView: View {
	@State private var _isAddingPresenting = false
	
	@Binding var bindingValue: URL?
	
	// MARK: Body
	var body: some View {
		List {
			Section {
				if let ent = bindingValue {
					HStack(spacing: 12) {
						SigningRowIcon(systemImage: "doc.text")
						VStack(alignment: .leading, spacing: 2) {
							Text(ent.lastPathComponent)
								.font(.body.weight(.medium))
								.lineLimit(2)
							Text("Selected entitlements file")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
						Spacer(minLength: 0)
						Button("Replace") { _isAddingPresenting = true }
							.font(.subheadline.weight(.semibold))
					}
					.signingDestinationRow()
					.swipeActions(edge: .trailing, allowsFullSwipe: true) {
						Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
							_delete(ent)
						}
					}
					.contextMenu {
						Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
							_delete(ent)
						}
					}
				} else {
					Button {
						_isAddingPresenting = true
					} label: {
						SigningSummaryCard {
							HStack(spacing: 13) {
								SigningRowIcon(systemImage: "doc.badge.plus")
								VStack(alignment: .leading, spacing: 3) {
									Text(.localized("Select Entitlements File"))
										.font(.headline)
									Text("Choose a plist or .entitlements file for this signing session.")
										.font(.caption)
										.foregroundStyle(.secondary)
										.fixedSize(horizontal: false, vertical: true)
								}
								Spacer(minLength: 0)
								Image(systemName: "chevron.right")
									.font(.caption.weight(.semibold))
									.foregroundStyle(.secondary)
							}
						}
					}
					.buttonStyle(.plain)
					.signingSummaryRow()
				}
			} header: {
				SigningSectionHeader(
					title: .localized("Entitlements"),
					detail: "Custom entitlements can make an otherwise valid app fail verification. Use only the keys supported by your provisioning profile."
				)
			}
		}
		.listStyle(.plain)
		.scrollContentBackground(.hidden)
		.background(Color.black)
		.navigationTitle(.localized("Entitlements"))
		.tint(NullSignStyle.cyan)
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes:  [.xmlPropertyList, .plist, .entitlements],
				onDocumentsPicked: { urls in
					guard let selectedFileURL = urls.first else { return }
					
					FileManager.default.moveAndStore(selectedFileURL, with: "FeatherEntitlement") { url in
						bindingValue = url
					}
				}
			)
			.ignoresSafeArea()
		}
	}

	private func _delete(_ url: URL) {
		FileManager.default.deleteStored(url) { _ in
			bindingValue = nil
		}
	}
}
