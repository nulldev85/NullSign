//
//  UpdatesSettingsView.swift
//  NullSign
//
//  Created by Ryuk on 05.07.2026.
//

import SwiftUI
import NimbleViews
import UIKit

/// NullSign's own updates: what's installed, what NullSign's app source
/// offers, and how updates are signed.
struct UpdatesSettingsView: View {
	@ObservedObject private var _manager = SelfUpdateManager.shared
	@AppStorage("Feather.selfUpdateAutoCheck") private var _autoCheck: Bool = true
	@AppStorage("Feather.selfUpdateCertIndex") private var _certIndex: Int = -1

	@State private var _selected: SelfUpdateRelease?

	private let _certificates = Storage.shared.getAllCertificates()

	var body: some View {
		NBList(.localized("Updates")) {
			_statusSection
			_optionsSection
			if !_manager.ignoredVersions.isEmpty { _ignoredSection }
			Section {
				NavigationLink(destination: AllVersionsView()) {
					Label(.localized("All Versions"), systemImage: "square.stack.3d.up")
				}
			}
			.listRowBackground(NullSignStyle.groupedSurface)
		}
		.sheet(item: $_selected) { release in
			SelfUpdateSheet(release: release, offersReminders: false)
		}
		.task {
			await _manager.check()
		}
	}

	// MARK: Status

	private var _statusSection: some View {
		NBSection(.localized("Current Version")) {
			HStack {
				Text(.localized("Installed"))
				Spacer()
				Text(SelfUpdateManager.installedLabel).foregroundStyle(.secondary)
			}
			if let available = _manager.available {
				HStack {
					Label(String.localized("Update available: %@", arguments: available.label), systemImage: "arrow.up.circle.fill")
						.foregroundStyle(NullSignStyle.accent)
					Spacer()
					Button(.localized("View")) { _selected = available }
						.font(.subheadline.bold())
				}
			} else if let latest = _manager.latest {
				HStack {
					VStack(alignment: .leading, spacing: 2) {
						Text(.localized("Latest Release"))
						Text(latest.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
					}
					Spacer()
					Button(latest.isInstalled ? .localized("Reinstall") : .localized("Install")) { _selected = latest }
						.font(.subheadline.bold())
				}
			} else if let error = _manager.lastError, !_manager.isChecking {
				Label(error, systemImage: "exclamationmark.triangle.fill")
					.font(.footnote)
					.foregroundStyle(NullSignStyle.warning)
			}
			Button {
				Task { await _manager.check() }
			} label: {
				HStack {
					Text(.localized("Check for Updates"))
					Spacer()
					if _manager.isChecking { ProgressView() }
				}
			}
			.disabled(_manager.isChecking)
		}
	}

	// MARK: Options

	private var _optionsSection: some View {
		NBSection(.localized("Options")) {
			Toggle(.localized("Automatic Update Checks"), isOn: $_autoCheck)
			Picker(.localized("Signing Certificate"), selection: $_certIndex) {
				Text(.localized("Selected Certificate")).tag(-1)
				ForEach(Array(_certificates.enumerated()), id: \.offset) { index, cert in
					Text(_certName(cert)).tag(index)
				}
			}
		} footer: {
			VStack(alignment: .leading, spacing: 6) {
				Text(.localized("Updates come from NullSign's app source. NullSign signs the update on this device and installs it with the installation method in Settings."))
				Text(.localized("Sign with the certificate you first installed NullSign with, or iOS won't update it in place."))
			}
		}
	}

	// MARK: Ignored

	private var _ignoredSection: some View {
		NBSection(.localized("Ignored Versions")) {
			ForEach(Array(_manager.ignoredVersions).sorted { SelfUpdateManager.isNewerLabel($0, than: $1) }, id: \.self) { version in
				HStack {
					Text(version)
					Spacer()
					Button(.localized("Resume")) { _manager.unignore(version) }
						.font(.subheadline)
				}
			}
		}
	}

	private func _certName(_ cert: CertificatePair) -> String {
		cert.nickname ?? Storage.shared.getProvisionFileDecoded(for: cert)?.Name ?? .localized("Unknown")
	}
}
