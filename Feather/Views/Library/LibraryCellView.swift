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
	@State private var _isActionsPresenting = false
	@State private var _pendingAction: MenuAction?

	var app: AppInfoPresentable
	var isSelecting: Bool
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	@Binding var selectedAppUUIDs: Set<String>

	private let _cardShape = RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous)

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
						.font(.roundedUI(.headline))
						.foregroundStyle(.white)
						.lineLimit(1)
					if let version = app.version, !version.isEmpty {
						Text(version)
							.font(.roundedUI(.subheadline))
							.foregroundStyle(NullSignStyle.faint)
							.lineLimit(1)
							.layoutPriority(-1)
					}
				}
				Text(app.identifier ?? .localized("Unknown"))
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
					.minimumScaleFactor(0.85)
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
		.padding(14)
		.nullSignSurface()
		.overlay {
			if isSelecting && _isSelected {
				_cardShape.strokeBorder(NullSignStyle.accent, lineWidth: 2)
			}
		}
		.contentShape(_cardShape)
		.gesture(
			LongPressGesture().exclusively(before: TapGesture()).onEnded { value in
				switch value {
				case .first:
					guard !isSelecting else { return }
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					_isActionsPresenting = true
				case .second:
					if isSelecting { _toggleSelection() }
					else { selectedInfoAppPresenting = AnyApp(base: app) }
				}
			}
		)
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			if !isSelecting {
				Button(role: .destructive) {
					_delete()
				} label: {
					Label(.localized("Delete"), systemImage: "trash")
				}
				.tint(NullSignStyle.danger)
			}
		}
		.accessibilityAction(named: Text(.localized("App Actions"))) {
			guard !isSelecting else { return }
			_isActionsPresenting = true
		}
		.sheet(isPresented: $_isActionsPresenting, onDismiss: _performPendingAction) {
			NullSignMenuSheet(
				title: app.name ?? .localized("App Actions"), systemImage: "app.badge",
				detail: app.identifier
			) {
				NullSignSettingsCard {
					_menuActions
				}
			}
		}
		.sheet(isPresented: $_isSignedUpdateConfirmationPresented, onDismiss: _performPendingAction) {
			_signedUpdateMenu
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
			.font(.roundedUI(.title2, weight: .regular))
			.symbolRenderingMode(.palette)
			.foregroundStyle(_isSelected ? Color.white : NullSignStyle.faint, _isSelected ? NullSignStyle.accent : NullSignStyle.faint)
	}

	@ViewBuilder
	private var _status: some View {
		if _update != nil {
			Text("Update available")
				.font(.roundedUI(.caption, weight: .regular))
				.foregroundStyle(NullSignStyle.accent)
		} else if app.isSigned {
			if let certificate = Storage.shared.getCertificate(from: app) {
				if certificate.revoked {
					Text(.localized("Revoked"))
						.font(.roundedUI(.caption, weight: .regular))
						.foregroundStyle(NullSignStyle.danger)
				} else if let expiration = certificate.expiration {
					let label = NullSignValidity.shortLabel(for: expiration)
					Text(label.text)
						.font(.roundedUI(.caption))
						.foregroundStyle(label.tint)
				}
			}
		} else {
			Text("Not signed")
				.font(.roundedUI(.caption))
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

	private enum MenuAction {
		case info, open, install, sign, export, delete
		case update(AppUpdate)
		case downloadUpdate(AppUpdate)
	}

	private var _signedUpdateMenu: some View {
		NullSignMenuSheet(
			title: "Update Available", systemImage: "arrow.down.circle",
			detail: _signedUpdateConfirmation.map { "\($0.appName) \($0.remoteVersion)" }
		) {
			NullSignSettingsCard {
				NullSignMenuAction(title: "Install Current Version", systemImage: "square.and.arrow.down") {
					_pendingAction = .install
					_isSignedUpdateConfirmationPresented = false
				}
				if let update = _signedUpdateConfirmation {
					NullSignSettingsDivider()
					NullSignMenuAction(title: "Download Update", systemImage: "arrow.down.circle", tint: NullSignStyle.success) {
						_pendingAction = .downloadUpdate(update)
						_isSignedUpdateConfirmationPresented = false
					}
				}
			}
		}
	}

	@ViewBuilder
	private var _menuActions: some View {
		NullSignMenuAction(title: .localized("Get Info"), systemImage: "info.circle") { _chooseAction(.info) }
		NullSignSettingsDivider()
		if let update = _update {
			NullSignMenuAction(title: .localized("Update"), systemImage: "arrow.down.circle", tint: NullSignStyle.success) {
				_chooseAction(.update(update))
			}
			NullSignSettingsDivider()
		}
		if app.isSigned {
			if app.identifier != nil {
				NullSignMenuAction(title: .localized("Open"), systemImage: "app.badge.checkmark", tint: NullSignStyle.success) { _chooseAction(.open) }
				NullSignSettingsDivider()
			}
		}
		NullSignMenuAction(title: .localized("Install"), systemImage: "square.and.arrow.down") { _chooseAction(.install) }
		NullSignSettingsDivider()
		NullSignMenuAction(title: app.isSigned ? .localized("Re-sign") : .localized("Sign"), systemImage: "signature", tint: NullSignStyle.purple) { _chooseAction(.sign) }
		if app.isSigned {
			NullSignSettingsDivider()
			NullSignMenuAction(title: .localized("Export"), systemImage: "square.and.arrow.up", tint: NullSignStyle.warning) { _chooseAction(.export) }
		}
		NullSignSettingsDivider()
		NullSignMenuAction(title: .localized("Delete"), systemImage: "trash", isDestructive: true) { _chooseAction(.delete) }
	}

	private func _chooseAction(_ action: MenuAction) {
		_pendingAction = action
		_isActionsPresenting = false
	}

	/// Dismiss before presenting signing/install/info UI or deleting this row.
	private func _performPendingAction() {
		guard let action = _pendingAction else { return }
		_pendingAction = nil
		switch action {
		case .info: selectedInfoAppPresenting = AnyApp(base: app)
		case .open:
			if let id = app.identifier { UIApplication.openApp(with: id) }
		case .install: selectedInstallAppPresenting = AnyApp(base: app)
		case .sign: selectedSigningAppPresenting = AnyApp(base: app)
		case .export: selectedInstallAppPresenting = AnyApp(base: app, archive: true)
		case .delete: _delete()
		case .downloadUpdate(let update): _startUpdateDownload(update)
		case .update(let update):
			if app.isSigned {
				_signedUpdateConfirmation = update
				_isSignedUpdateConfirmationPresented = true
			} else {
				_startUpdateDownload(update)
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
