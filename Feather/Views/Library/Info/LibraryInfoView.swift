//
//  LibraryInfoView.swift
//  Feather
//
//  Created by samara on 14.04.2025.
//

import SwiftUI
import NimbleViews
import Zsign

// MARK: - View
struct LibraryInfoView: View {
	@State private var _isStorageErrorPresented = false

	var app: AppInfoPresentable

	// MARK: Body
	var body: some View {
		NBNavigationView(app.name ?? "", displayMode: .inline) {
			List {
				_summary
				_infoSection(for: app)
				_certSection(for: app)
				_bundleSection(for: app)
				_executableSection(for: app)

				Section {
					Button {
						_openInFiles()
					} label: {
						HStack(spacing: 12) {
							SigningRowIcon(systemImage: "folder")
							VStack(alignment: .leading, spacing: 2) {
								Text(.localized("Open in Files"))
									.font(.body.weight(.medium))
								Text("View this app's working directory")
									.font(.caption)
									.foregroundStyle(NullSignStyle.muted)
							}
							Spacer()
							Image(systemName: "arrow.up.forward")
								.font(.caption.weight(.bold))
								.foregroundStyle(NullSignStyle.faint)
						}
					}
					.buttonStyle(.plain)
					.signingDestinationRow()
				} header: {
					SigningSectionHeader(title: .localized("Storage"))
				}
			}
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.background(Color.black)
			.tint(NullSignStyle.accent)
			.toolbar {
				NBToolbarButton(role: .close)
			}
			.alert("Files Unavailable", isPresented: $_isStorageErrorPresented) {
				Button("OK", role: .cancel) { }
			} message: {
				Text("NullSign could not open this app's working directory.")
			}
		}
	}
}

// MARK: - Extension: View
extension LibraryInfoView {
	private var _summary: some View {
		VStack(spacing: 12) {
			FRAppIconView(app: app, size: 84)
			VStack(spacing: 4) {
				Text(app.name ?? .localized("Unknown App"))
					.font(.title2.weight(.bold))
					.multilineTextAlignment(.center)
					.lineLimit(2)
				if let identifier = app.identifier {
					Text(identifier)
						.font(.subheadline)
						.foregroundStyle(NullSignStyle.muted)
						.lineLimit(1)
				}
			}
			HStack(spacing: 6) {
				PlatformBadge(platform: app.platform)
				if let version = app.version, !version.isEmpty {
					NullSignChip(text: version)
				}
				NullSignChip(text: app.isSigned ? "Signed" : "Not signed")
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 10)
		.signingSummaryRow()
	}

	@ViewBuilder
	private func _infoSection(for app: AppInfoPresentable) -> some View {
		Section {
			if let name = app.name {
				_infoCell(.localized("Name"), desc: name, systemImage: "textformat")
			}

			if let ver = app.version {
				_infoCell(.localized("Version"), desc: ver, systemImage: "number")
			}

			if let id = app.identifier {
				_infoCell(.localized("Identifier"), desc: id, systemImage: "app.badge")
			}

			if let date = app.date {
				_infoCell(.localized("Date Added"), desc: date.formatted(), systemImage: "calendar")
			}
		} header: {
			SigningSectionHeader(title: .localized("App"), detail: "Tap and hold a value to copy it.")
		}
	}

	@ViewBuilder
	private func _certSection(for app: AppInfoPresentable) -> some View {
		if let cert = Storage.shared.getCertificate(from: app) {
			Section {
				CertificatesCellView(cert: cert)
					.signingDestinationRow()
			} header: {
				SigningSectionHeader(title: .localized("Certificate"))
			}
		}
	}

	@ViewBuilder
	private func _bundleSection(for app: AppInfoPresentable) -> some View {
		Section {
			NavigationLink {
				SigningAlternativeIconView(app: app, appIcon: .constant(nil), isModifing: .constant(false))
			} label: {
				_navigationRow(
					title: .localized("Alternative Icons"),
					detail: "Icons included in the app bundle",
					systemImage: "app.dashed"
				)
			}
			.signingDestinationRow()

			NavigationLink {
				SigningFrameworksView(app: app, options: .constant(nil))
			} label: {
				_navigationRow(
					title: .localized("Frameworks & PlugIns"),
					detail: "Embedded libraries and extensions",
					systemImage: "shippingbox"
				)
			}
			.signingDestinationRow()
		} header: {
			SigningSectionHeader(title: .localized("Bundle Contents"))
		}
	}

	@ViewBuilder
	private func _executableSection(for app: AppInfoPresentable) -> some View {
		Section {
			NavigationLink {
				SigningDylibView(app: app, options: .constant(nil))
			} label: {
				_navigationRow(
					title: .localized("Linked Dylibs"),
					detail: "Libraries loaded by the main executable",
					systemImage: "link"
				)
			}
			.signingDestinationRow()
		} header: {
			SigningSectionHeader(title: .localized("Executable"))
		}
	}

	@ViewBuilder
	private func _infoCell(_ title: String, desc: String, systemImage: String) -> some View {
		HStack(spacing: 12) {
			SigningRowIcon(systemImage: systemImage)
			Text(title)
				.font(.body.weight(.medium))
			Spacer(minLength: 12)
			Text(desc)
				.font(.subheadline)
				.foregroundStyle(NullSignStyle.muted)
				.multilineTextAlignment(.trailing)
				.lineLimit(2)
		}
		.copyableText(desc)
		.signingDestinationRow()
	}

	private func _navigationRow(title: String, detail: String, systemImage: String) -> some View {
		HStack(spacing: 12) {
			SigningRowIcon(systemImage: systemImage)
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.body.weight(.medium))
				Text(detail)
					.font(.caption)
					.foregroundStyle(NullSignStyle.muted)
			}
		}
	}

	private func _openInFiles() {
		guard
			let directory = Storage.shared.getUuidDirectory(for: app),
			let sharedURL = directory.toSharedDocumentsURL()
		else {
			_isStorageErrorPresented = true
			return
		}
		UIApplication.open(sharedURL)
	}
}
