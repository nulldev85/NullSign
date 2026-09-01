//
//  SigningTweaksView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningTweaksView: View {
	@State private var _isAddingPresenting = false
	
	@Binding var options: Options
	
	// MARK: Body
	var body: some View {
		List {
			SigningSummaryCard {
				HStack(spacing: 13) {
					SigningRowIcon(systemImage: "shippingbox.and.arrow.backward")
					VStack(alignment: .leading, spacing: 3) {
						Text(options.injectionFiles.isEmpty ? "No tweaks selected" : "\(options.injectionFiles.count) selected")
							.font(.headline)
						Text("NullSign accepts .deb packages and standalone .dylib files.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
					Spacer(minLength: 0)
				}
			}
			.signingSummaryRow()

			Section {
				SigningOptionsView.picker(
					.localized("Injection Path"),
					systemImage: "point.topleft.down.curvedto.point.bottomright.up",
					selection: $options.injectPath,
					values: Options.InjectPath.allCases
				)

				SigningOptionsView.picker(
					.localized("Injection Folder"),
					systemImage: "folder",
					selection: $options.injectFolder,
					values: Options.InjectFolder.allCases
				)

				Toggle(isOn: $options.injectIntoExtensions) {
					HStack(spacing: 12) {
						SigningRowIcon(systemImage: "puzzlepiece.extension")
						VStack(alignment: .leading, spacing: 2) {
							Text(.localized("Inject into Extensions"))
								.font(.body.weight(.medium))
							Text("Also patch compatible embedded extensions")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
				}
				.tint(NullSignStyle.cyan)
				.signingDestinationRow()
			} header: {
				SigningSectionHeader(
					title: .localized("Injection"),
					detail: "These settings apply only when at least one tweak is selected."
				)
			}

			Section {
				if !options.injectionFiles.isEmpty {
					ForEach(options.injectionFiles, id: \.absoluteString) { tweak in
						_file(tweak: tweak)
					}
				} else {
					SigningEmptyState(
						systemImage: "shippingbox",
						title: "No tweak files",
						detail: "Use the add button to choose one or more .deb or .dylib files."
					)
					.signingSummaryRow()
				}
			} header: {
				SigningSectionHeader(title: .localized("Files"), detail: "Swipe a file to remove it from this signing session.")
			}
		}
		.listStyle(.plain)
		.scrollContentBackground(.hidden)
		.background(Color.black)
		.navigationTitle(.localized("Tweaks"))
		.tint(NullSignStyle.cyan)
		.toolbar {
			NBToolbarButton(
				systemImage: "plus",
				style: .icon,
				placement: .topBarTrailing
			) {
				_isAddingPresenting = true
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.dylib, .deb],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					guard !urls.isEmpty else { return }
					
					for url in urls {
						FileManager.default.moveAndStore(url, with: "FeatherTweak") { url in
							options.injectionFiles.append(url)
						}
					}
				}
			)
			.ignoresSafeArea()
		}
		.animation(.smooth, value: options.injectionFiles)
	}
}

// MARK: - Extension: View
extension SigningTweaksView {
	@ViewBuilder
	private func _file(tweak: URL) -> some View {
		HStack(spacing: 12) {
			SigningRowIcon(
				systemImage: tweak.pathExtension.lowercased() == "deb" ? "shippingbox" : "link"
			)
			VStack(alignment: .leading, spacing: 2) {
				Text(tweak.deletingPathExtension().lastPathComponent)
					.font(.body.weight(.medium))
					.lineLimit(2)
				Text(tweak.pathExtension.uppercased())
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.secondary)
			}
			Spacer(minLength: 0)
		}
		.signingDestinationRow()
			.swipeActions(edge: .trailing, allowsFullSwipe: true) {
				_fileActions(tweak: tweak)
			}
			.contextMenu {
				_fileActions(tweak: tweak)
			}
	}
	
	@ViewBuilder
	private func _fileActions(tweak: URL) -> some View {
		Button(role: .destructive) {
			FileManager.default.deleteStored(tweak) { url in
				if let index = options.injectionFiles.firstIndex(where: { $0 == url }) {
					options.injectionFiles.remove(at: index)
				}
			}
		} label: {
			Label(.localized("Delete"), systemImage: "trash")
		}
	}
}
