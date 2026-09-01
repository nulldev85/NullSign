//
//  SigningFrameworksView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningFrameworksView: View {
	@State private var _frameworks: [String] = []
	@State private var _plugins: [String] = []
	
	private let _frameworksPath = "Frameworks"
	private let _pluginsPath = "PlugIns"
	
	var app: AppInfoPresentable
	@Binding var options: Options?
	
	// MARK: Body
	var body: some View {
		List {
			SigningSummaryCard {
				HStack(spacing: 13) {
					SigningRowIcon(systemImage: "shippingbox")
					VStack(alignment: .leading, spacing: 3) {
						Text("\((_frameworks.count + _plugins.count)) embedded items")
							.font(.headline)
						Text(options == nil
							 ? "A read-only view of bundled frameworks and app extensions."
							 : "Turn off an item to remove it from the signed package.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
					Spacer(minLength: 0)
				}
			}
			.signingSummaryRow()

			if !_frameworks.isEmpty {
				Section {
					ForEach(_frameworks, id: \.self) { framework in
						SigningToggleCellView(
							title: "\(_frameworksPath)/\(framework)",
							options: $options,
							arrayKeyPath: \.removeFiles,
							displayTitle: framework,
							detail: _frameworksPath,
							systemImage: "shippingbox",
							readOnlyLabel: "Included"
						)
						.signingDestinationRow()
					}
				} header: {
					SigningSectionHeader(title: .localized("Frameworks"), detail: "Libraries shipped inside the app bundle.")
				}
			}

			if !_plugins.isEmpty {
				Section {
					ForEach(_plugins, id: \.self) { plugin in
						SigningToggleCellView(
							title: "\(_pluginsPath)/\(plugin)",
							options: $options,
							arrayKeyPath: \.removeFiles,
							displayTitle: plugin,
							detail: _pluginsPath,
							systemImage: "puzzlepiece.extension",
							readOnlyLabel: "Included"
						)
						.signingDestinationRow()
					}
				} header: {
					SigningSectionHeader(title: .localized("PlugIns"), detail: "Extensions and secondary app bundles.")
				}
			}

			if _frameworks.isEmpty && _plugins.isEmpty {
				SigningEmptyState(
					systemImage: "shippingbox",
					title: .localized("No Embedded Items"),
					detail: "This app does not contain a Frameworks or PlugIns directory."
				)
				.signingSummaryRow()
			}
		}
		.listStyle(.plain)
		.scrollContentBackground(.hidden)
		.background(Color.black)
		.navigationTitle(.localized("Frameworks & PlugIns"))
		.tint(NullSignStyle.cyan)
		.onAppear(perform: _listFrameworksAndPlugins)
	}
}

// MARK: - Extension: View
extension SigningFrameworksView {
	private func _listFrameworksAndPlugins() {
		guard let path = Storage.shared.getAppDirectory(for: app) else { return }
		
		_frameworks = _listFiles(at: path.appendingPathComponent(_frameworksPath))
		_plugins = _listFiles(at: path.appendingPathComponent(_pluginsPath))
	}
	
	private func _listFiles(at path: URL) -> [String] {
		((try? FileManager.default.contentsOfDirectory(atPath: path.path)) ?? [])
			.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
	}
}
