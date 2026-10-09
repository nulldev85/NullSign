//
//  SigningAppAlternativeIconView.swift
//  Feather
//
//  Created by samara on 18.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningAlternativeIconView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var _alternateIcons: [(name: String, path: String)] = []
	
	var app: AppInfoPresentable
	@Binding var appIcon: UIImage?
	@Binding var isModifing: Bool
	
	// MARK: Body
	@ViewBuilder
	var body: some View {
		if isModifing {
			NBNavigationView(.localized("Alternative Icons"), displayMode: .inline) {
				_content
					.toolbar { NBToolbarButton(role: .close) }
			}
		} else {
			_content
				.navigationTitle(.localized("Alternative Icons"))
		}
	}
}

// MARK: - Extension: View
extension SigningAlternativeIconView {
	private var _content: some View {
		List {
			if !_alternateIcons.isEmpty {
				SigningSummaryCard {
					HStack(spacing: 12) {
						SigningRowIcon(systemImage: "app.dashed")
						VStack(alignment: .leading, spacing: 3) {
							Text("\(_alternateIcons.count) alternate \(_alternateIcons.count == 1 ? "icon" : "icons")")
								.font(.headline)
							Text(isModifing ? "Choose the icon to use for this signed app." : "Icons declared by this app's Info.plist.")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
						Spacer(minLength: 0)
					}
				}
				.signingSummaryRow()

				Section {
					ForEach(_alternateIcons, id: \.name) { icon in
						if isModifing {
							Button {
								appIcon = _iconUrl(icon.path)
								dismiss()
							} label: {
								_icon(icon, showsSelectionIndicator: true)
							}
							.buttonStyle(.plain)
							.signingDestinationRow(top: 7, bottom: 7)
						} else {
							_icon(icon, showsSelectionIndicator: false)
								.signingDestinationRow(top: 7, bottom: 7)
						}
					}
				} header: {
					SigningSectionHeader(title: .localized("Included Icons"))
				}
			} else {
				SigningEmptyState(
					systemImage: "app.dashed",
					title: .localized("No Alternate Icons"),
					detail: "This app does not declare any alternate icons."
				)
				.signingSummaryRow()
			}
		}
		.listStyle(.plain)
		.scrollContentBackground(.hidden)
		.background(Color.black)
		.tint(NullSignStyle.accent)
		.onAppear(perform: _loadAlternateIcons)
	}

	@ViewBuilder
	private func _icon(_ icon: (name: String, path: String), showsSelectionIndicator: Bool) -> some View {
		HStack(spacing: 12) {
			if let image = _iconUrl(icon.path) {
				Image(uiImage: image)
					.appIconStyle(size: 48)
			} else {
				Image("App_Unknown")
					.appIconStyle(size: 48)
			}
			
			Text(icon.name)
				.font(.body.weight(.medium))
				.foregroundColor(.primary)
				.lineLimit(2)

			Spacer(minLength: 0)

			if showsSelectionIndicator {
				Image(systemName: "chevron.right")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.secondary)
			}
		}
	}
	
	
	private func _iconUrl(_ path: String) -> UIImage? {
		guard let app = Storage.shared.getAppDirectory(for: app) else {
			return nil
		}
		return UIImage(contentsOfFile: app.appendingPathComponent(path).relativePath)?.resizeToSquare()
	}
	
	private func _loadAlternateIcons() {
		guard let appDirectory = Storage.shared.getAppDirectory(for: app) else { return }
		
		let infoPlistPath = appDirectory.appendingPathComponent("Info.plist")
		guard
			let infoPlist = NSDictionary(contentsOf: infoPlistPath),
			let iconDict = infoPlist["CFBundleIcons"] as? [String: Any],
			let alternateIconsDict = iconDict["CFBundleAlternateIcons"] as? [String: [String: Any]]
		else {
			return
		}
		
		_alternateIcons = alternateIconsDict.compactMap { (name, details) in
			if let files = details["CFBundleIconFiles"] as? [String], let path = files.first {
				return (name, path)
			}
			return nil
		}.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}
}
