//
//  AboutView.swift
//  NullSign
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
/// NullSign's About: the version, NullSign's own updates, Feather's credits
/// and the license.
struct AboutView: View {
	@ObservedObject private var _selfUpdate = SelfUpdateManager.shared
	@State private var _selected: SelfUpdateRelease?

	private let _sourceURL = "https://github.com/nulldev85/NullSign"

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				VStack(spacing: 10) {
					FRAppIconView(size: 84)
					Text(verbatim: "NullSign")
						.font(.roundedUI(.title2, weight: .heavy))
					Text(verbatim: .localized("Version %@", arguments: SelfUpdateManager.installedLabel))
						.font(.roundedUI(.subheadline))
						.foregroundStyle(NullSignStyle.muted)
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 12)

				NullSignSettingsSection(.localized("App Updates"), detail: _selfUpdateDetail) {
					Button(action: _selfUpdateAction) {
						NullSignSettingsRow(
							title: _selfUpdateTitle,
							detail: nil,
							systemImage: _selfUpdateIcon,
							showsChevron: false,
							isBusy: _selfUpdate.isChecking
						)
					}
					.buttonStyle(.plain)
					.disabled(_selfUpdate.isChecking)
				}

				NullSignSettingsSection(
					.localized("Credits"),
					detail: .localized("NullSign is a fork of Feather. Its signing, repository, and installation foundations came from Feather and its contributors.")
				) {
					_linkRow(
						title: "Feather",
						detail: "Original project by claration and contributors",
						systemImage: "arrow.triangle.branch",
						url: "https://github.com/claration/Feather"
					)
					NullSignSettingsDivider()
					_linkRow(
						title: "C",
						detail: "Feather developer · claration",
						systemImage: "person.2",
						url: "https://github.com/claration"
					)
					NullSignSettingsDivider()
					_linkRow(
						title: "Asami",
						detail: "Feather developer · Nyasami",
						systemImage: "person.2",
						url: "https://github.com/Nyasami"
					)
					NullSignSettingsDivider()
					_linkRow(
						title: "Lakhan Lothiyi",
						detail: "AltStore repository work · llsc12",
						systemImage: "person.2",
						url: "https://github.com/llsc12"
					)
				}

				NullSignSettingsSection(
					.localized("License"),
					detail: .localized("NullSign is free software distributed under GNU GPL v3. Forks and redistributed builds must keep the license and provide corresponding source.")
				) {
					_linkRow(
						title: "GNU GPL v3",
						detail: .localized("Read the full license text"),
						systemImage: "doc.text",
						url: "https://www.gnu.org/licenses/gpl-3.0.html"
					)
					NullSignSettingsDivider()
					_linkRow(
						title: .localized("Source Code"),
						detail: .localized("NullSign's complete source on GitHub"),
						systemImage: "chevron.left.forwardslash.chevron.right",
						url: _sourceURL
					)
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 16)
			.padding(.bottom, 28)
		}
		.nullSignPage()
		.nullSignNavigationTitle(.localized("About"))
		.sheet(item: $_selected) { release in
			SelfUpdateSheet(release: release, offersReminders: false)
		}
		.task {
			if _selfUpdate.latest == nil, !_selfUpdate.isChecking {
				await _selfUpdate.check()
			}
		}
	}
}

// MARK: - App Updates
extension AboutView {
	private func _selfUpdateAction() {
		if let available = _selfUpdate.available {
			_selected = available
		} else {
			Task { await _selfUpdate.check() }
		}
	}

	private var _selfUpdateTitle: String {
		if _selfUpdate.isChecking { return .localized("Checking for Updates…") }
		if let available = _selfUpdate.available {
			return .localized("Update to NullSign %@", arguments: available.label)
		}
		if _selfUpdate.latest != nil { return .localized("You're on the Latest Version") }
		if _selfUpdate.lastError != nil { return .localized("Couldn't Check — Tap to Try Again") }
		return .localized("Check for Updates")
	}

	private var _selfUpdateIcon: String {
		if _selfUpdate.available != nil { return "arrow.down.circle" }
		if _selfUpdate.latest != nil { return "checkmark.circle" }
		if _selfUpdate.lastError != nil { return "exclamationmark.triangle" }
		return "arrow.triangle.2.circlepath"
	}

	private var _selfUpdateDetail: String {
		if _selfUpdate.available != nil {
			return .localized("NullSign downloads the update, signs it with your certificate and installs it. iOS asks you to confirm, then NullSign closes while the new version replaces it. Open it again once it's done.")
		}
		if let error = _selfUpdate.lastError, _selfUpdate.latest == nil {
			return error
		}
		return .localized("Checks NullSign's own release feed for a newer build.")
	}

	private func _linkRow(
		title: String,
		detail: String,
		systemImage: String,
		url: String
	) -> some View {
		Button {
			UIApplication.open(url)
		} label: {
			NullSignSettingsRow(
				title: title,
				detail: detail,
				systemImage: systemImage
			)
		}
		.buttonStyle(.plain)
	}
}
