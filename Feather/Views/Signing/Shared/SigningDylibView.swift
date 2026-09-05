//
//  SigningOptionsDylibSharedView.swift
//  Feather
//
//  Created by samara on 19.04.2025.
//

import SwiftUI
import NimbleViews
import ZsignSwift

// MARK: - View
struct SigningDylibView: View {
	@State private var _dylibs: [String] = []
	@State private var _hiddenDylibCount: Int = 0
	
	var app: AppInfoPresentable
	@Binding var options: Options?
	
	var body: some View {
		List {
			SigningSummaryCard {
				HStack(spacing: 13) {
					SigningRowIcon(systemImage: "link")
					VStack(alignment: .leading, spacing: 3) {
						Text("\(_dylibs.count) app-linked \(_dylibs.count == 1 ? "library" : "libraries")")
							.font(.headline)
						Text(options == nil
							 ? "System libraries are hidden from this inspection view."
							 : "Turn off a library to remove its load command while signing.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
					Spacer(minLength: 0)
				}
			}
			.signingSummaryRow()

			Section {
				if _dylibs.isEmpty {
					SigningEmptyState(
						systemImage: "link",
						title: .localized("No App-Linked Dylibs"),
						detail: "The main executable does not reference any bundled dynamic libraries."
					)
					.signingSummaryRow()
				} else {
					ForEach(_dylibs, id: \.self) { dylib in
						SigningToggleCellView(
							title: dylib,
							options: $options,
							arrayKeyPath: \.disInjectionFiles,
							displayTitle: _displayName(for: dylib),
							detail: dylib,
							systemImage: "link",
							readOnlyLabel: "Linked"
						)
						.signingDestinationRow()
					}
				}
			} header: {
				SigningSectionHeader(title: .localized("Load Commands"))
			} footer: {
				if _hiddenDylibCount > 0 {
					Text(verbatim: .localized("%lld required system dylibs are hidden.", arguments: _hiddenDylibCount))
						.font(.footnote)
						.foregroundStyle(.secondary)
						.padding(.top, 4)
				}
			}
		}
		.listStyle(.plain)
		.scrollContentBackground(.hidden)
		.background(Color.black)
		.navigationTitle(.localized("Dylibs"))
		.tint(NullSignStyle.accent)
		.onAppear(perform: _loadDylibs)
	}
}

// MARK: - Extension: View
extension SigningDylibView {
	private func _loadDylibs() {
		guard let path = Storage.shared.getAppDirectory(for: app) else { return }
		
		let bundle = Bundle(url: path)
		let execPath = path.appendingPathComponent(bundle?.exec ?? "").relativePath
		
		let allDylibs = Zsign.listDylibs(appExecutable: execPath).map { $0 as String }
		
		_dylibs = allDylibs
			.filter { $0.hasPrefix("@rpath") || $0.hasPrefix("@executable_path") }
			.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
		_hiddenDylibCount = allDylibs.count - _dylibs.count
	}

	private func _displayName(for dylib: String) -> String {
		dylib.split(separator: "/").last.map(String.init) ?? dylib
	}
}
