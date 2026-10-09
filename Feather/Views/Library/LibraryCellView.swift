//
//  LibraryAppIconView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
struct LibraryCellView: View {
	// Not @ObservedObject: UpdateManager also publishes isChecking/lastCheckedDate,
	// which would re-render every visible row on every check start/finish even
	// though only the per-app update entry below is ever read from it.
	private let updateManager = UpdateManager.shared
	@State private var _update: AppUpdate?
	@State private var _signedUpdateConfirmation: AppUpdate?
	@State private var _isSignedUpdateConfirmationPresented = false

	var app: AppInfoPresentable
	var isSelecting: Bool
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	@Binding var selectedAppUUIDs: Set<String>

	private let _cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

	// MARK: Selections
	private var _isSelected: Bool {
		guard let uuid = app.uuid else { return false }
		return selectedAppUUIDs.contains(uuid)
	}

	private func _toggleSelection() {
		guard let uuid = app.uuid else { return }
		UISelectionFeedbackGenerator().selectionChanged()
		if selectedAppUUIDs.contains(uuid) {
			selectedAppUUIDs.remove(uuid)
		} else {
			selectedAppUUIDs.insert(uuid)
		}
	}

	// MARK: Body
	var body: some View {
		HStack(spacing: 12) {
			if isSelecting {
				_selectionIndicator
					.transition(.opacity)
			}

			_appIcon

			VStack(alignment: .leading, spacing: 2) {
				HStack(alignment: .firstTextBaseline, spacing: 6) {
					Text(app.name ?? .localized("Unknown"))
						.font(.headline)
						.foregroundStyle(.white)
						.lineLimit(1)
					if let version = app.version, !version.isEmpty {
						Text(version)
							.font(.subheadline)
							.foregroundStyle(NullSignStyle.faint)
							.lineLimit(1)
							.layoutPriority(-1)
					}
				}
				Text(app.identifier ?? .localized("Unknown"))
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
				HStack(spacing: 6) {
					PlatformBadge(platform: app.platform)
					_status
				}
				.padding(.top, 4)
			}

			Spacer(minLength: 4)

			if !isSelecting {
				_primaryAction
			}
		}
		.padding(12)
		.nullSignSurface()
		.overlay {
			if isSelecting && _isSelected {
				_cardShape.strokeBorder(NullSignStyle.accent, lineWidth: 2)
			}
		}
		.contentShape(_cardShape)
		.contentShape(.contextMenuPreview, _cardShape)
		.onTapGesture {
			if isSelecting {
				_toggleSelection()
			} else {
				selectedInfoAppPresenting = AnyApp(base: app)
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			if !isSelecting {
				Button(role: .destructive) {
					_delete()
				} label: {
					Label(.localized("Delete"), systemImage: "trash")
				}
				.tint(NullSignStyle.accent)
			}
		}
		.contextMenu {
			if !isSelecting {
				_contextActions(for: app)
				Divider()
				_contextActionsExtra(for: app)
				Divider()
				Button(role: .destructive) {
					// Let the menu finish dismissing before the row goes away.
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
						_delete()
					}
				} label: {
					Label(.localized("Delete"), systemImage: "trash")
				}
			}
		}
		.confirmationDialog(
			.localized("Update Available"),
			isPresented: $_isSignedUpdateConfirmationPresented,
			titleVisibility: .visible
		) {
			Button(.localized("Install Current Version"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			if let update = _signedUpdateConfirmation {
				Button(.localized("Download Update"), systemImage: "arrow.down.circle") {
					_startUpdateDownload(update)
				}
			}
			Button(.localized("Cancel"), role: .cancel) {}
		} message: {
			if let update = _signedUpdateConfirmation {
				Text("\(update.appName) \(update.remoteVersion)")
			}
		}
		.onReceive(updateManager.$updates) { updates in
			_update = app.uuid.flatMap { updates[$0] }
		}
		.accessibilityAddTraits(isSelecting && _isSelected ? .isSelected : [])
	}
}


// MARK: - Extension: View
extension LibraryCellView {
	private var _appIcon: some View {
		FRAppIconView(app: app, size: 56)
			.overlay(alignment: .topTrailing) {
				if _update != nil {
					Circle()
						.fill(NullSignStyle.accent)
						.frame(width: 12, height: 12)
						.overlay(Circle().strokeBorder(Color.black, lineWidth: 2))
						.offset(x: 4, y: -4)
						.accessibilityLabel(.localized("Update Available"))
				}
			}
	}

	private var _selectionIndicator: some View {
		Image(systemName: _isSelected ? "checkmark.circle.fill" : "circle")
			.font(.title2)
			.symbolRenderingMode(.palette)
			.foregroundStyle(_isSelected ? Color.white : NullSignStyle.faint, _isSelected ? NullSignStyle.accent : NullSignStyle.faint)
	}

	@ViewBuilder
	private var _status: some View {
		if _update != nil {
			Text("Update available")
				.font(.caption.weight(.medium))
				.foregroundStyle(NullSignStyle.accent)
		} else if app.isSigned {
			if let certificate = Storage.shared.getCertificate(from: app) {
				if certificate.revoked {
					Text(.localized("Revoked"))
						.font(.caption.weight(.medium))
						.foregroundStyle(NullSignStyle.danger)
				} else if let expiration = certificate.expiration {
					let label = NullSignValidity.shortLabel(for: expiration)
					Text(label.text)
						.font(.caption)
						.foregroundStyle(label.tint)
				}
			}
		} else {
			Text("Not signed")
				.font(.caption)
				.foregroundStyle(NullSignStyle.faint)
		}
	}

	@ViewBuilder
	private var _primaryAction: some View {
		if let update = _update {
			Button {
				if app.isSigned {
					_signedUpdateConfirmation = update
					_isSignedUpdateConfirmationPresented = true
				} else {
					_startUpdateDownload(update)
				}
			} label: {
				Text(.localized("Update"))
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 32))
		} else if app.isSigned {
			Button {
				selectedInstallAppPresenting = AnyApp(base: app)
			} label: {
				Text(.localized("Install"))
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 32))
		} else {
			Button {
				selectedSigningAppPresenting = AnyApp(base: app)
			} label: {
				Text(.localized("Sign"))
			}
			.buttonStyle(NullSignSecondaryButtonStyle(height: 32))
		}
	}

	private func _delete() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		if let uuid = app.uuid {
			selectedAppUUIDs.remove(uuid)
		}
		// Safe to call twice or on an app that is already gone.
		Storage.shared.deleteApp(for: app)
	}

	@ViewBuilder
	private func _contextActions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Get Info"), systemImage: "info.circle") {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
	}

	@ViewBuilder
	private func _contextActionsExtra(for app: AppInfoPresentable) -> some View {
		if let update = _update {
			Button(.localized("Update"), systemImage: "arrow.down.circle") {
				if app.isSigned {
					_signedUpdateConfirmation = update
					_isSignedUpdateConfirmationPresented = true
				} else {
					_startUpdateDownload(update)
				}
			}
		}

		if app.isSigned {
			if let id = app.identifier {
				Button(.localized("Open"), systemImage: "app.badge.checkmark") {
					UIApplication.openApp(with: id)
				}
			}
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			Button(.localized("Re-sign"), systemImage: "signature") {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
			Button(.localized("Export"), systemImage: "square.and.arrow.up") {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		} else {
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			Button(.localized("Sign"), systemImage: "signature") {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
		}
	}

	private func _startUpdateDownload(_ update: AppUpdate) {
		_ = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "FeatherManualDownload_Update_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
	}
}
