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
	@Environment(\.editMode) private var editMode
	@ObservedObject private var updateManager = UpdateManager.shared
	@State private var _signedUpdateConfirmation: AppUpdate?
	@State private var _isSignedUpdateConfirmationPresented = false
	@State private var _isPeelingAway = false

	var certInfo: Date.ExpirationInfo? {
		Storage.shared.getCertificate(from: app)?.expiration?.expirationInfo()
	}
	
	var certRevoked: Bool {
		Storage.shared.getCertificate(from: app)?.revoked == true
	}
	
	var app: AppInfoPresentable
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	@Binding var selectedAppUUIDs: Set<String>
	
	// MARK: Selections
	private var _isSelected: Bool {
		guard let uuid = app.uuid else { return false }
		return selectedAppUUIDs.contains(uuid)
	}
	
	private func _toggleSelection() {
		guard let uuid = app.uuid else { return }
		if selectedAppUUIDs.contains(uuid) {
			selectedAppUUIDs.remove(uuid)
		} else {
			selectedAppUUIDs.insert(uuid)
		}
	}
	
	// MARK: Body
	var body: some View {
		let isEditing = editMode?.wrappedValue == .active
		
		HStack(spacing: 18) {
			if isEditing {
				Button {
					_toggleSelection()
				} label: {
					Image(systemName: _isSelected ? "checkmark.circle.fill" : "circle")
						.foregroundColor(_isSelected ? .accentColor : .secondary)
						.font(.title2)
				}
				.buttonStyle(.borderless)
			}
			
			_appIcon(for: app)
			
			NBTitleWithSubtitleView(
				title: app.name ?? .localized("Unknown"),
				subtitle: _desc,
				linelimit: 0
			)
			
			if !isEditing {
				_buttonActions(for: app)
			}
		}
		.nullSignPanel()
		.background(_isSelected && isEditing ? NullSignStyle.accent.opacity(0.08) : Color.clear)
		.rotation3DEffect(
			.degrees(_isPeelingAway ? -82 : 0),
			axis: (x: 0, y: 1, z: 0),
			anchor: .trailing,
			perspective: 0.72
		)
		.scaleEffect(x: _isPeelingAway ? 0.72 : 1, y: _isPeelingAway ? 0.96 : 1, anchor: .trailing)
		.offset(x: _isPeelingAway ? -34 : 0)
		.opacity(_isPeelingAway ? 0 : 1)
		.shadow(color: .black.opacity(_isPeelingAway ? 0.42 : 0), radius: 18, x: 14, y: 3)
		.animation(.timingCurve(0.22, 0.78, 0.28, 1, duration: 0.48), value: _isPeelingAway)
		.allowsHitTesting(!_isPeelingAway)
		.contentShape(Rectangle())
		.onTapGesture {
			if isEditing {
				_toggleSelection()
			}
		}
		.swipeActions {
			if !isEditing {
				_actions(for: app)
			}
		}
		.contextMenu {
			if !isEditing {
				_contextActions(for: app)
				Divider()
				_contextActionsExtra(for: app)
				Divider()
				_actions(for: app)
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
	}
	
	private var _desc: String {
		if let version = app.version, let id = app.identifier {
			return "\(version) • \(id)"
		} else {
			return .localized("Unknown")
		}
	}
}


// MARK: - Extension: View
extension LibraryCellView {
	private func _appIcon(for app: AppInfoPresentable) -> some View {
		FRAppIconView(app: app, size: 57)
			.overlay(alignment: .bottomTrailing) {
				PlatformBadge(platform: app.platform)
					.offset(x: 5, y: 4)
			}
			.overlay(alignment: .topTrailing) {
				if updateManager.update(for: app) != nil {
					Image(systemName: "arrow.down.circle.fill")
						.font(.system(size: 18, weight: .semibold))
						.symbolRenderingMode(.palette)
						.foregroundStyle(.white, NullSignStyle.muted)
						.background(
							Circle()
								.fill(Color(.systemBackground))
								.frame(width: 20, height: 20)
						)
						.offset(x: 5, y: -5)
						.accessibilityLabel(.localized("Update Available"))
				}
			}
	}
	
	@ViewBuilder
	private func _actions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			_peelAndDelete(app)
		}
	}

	private func _peelAndDelete(_ app: AppInfoPresentable) {
		guard !_isPeelingAway else { return }
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		_isPeelingAway = true
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(480))
			Storage.shared.deleteApp(for: app)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Get Info"), systemImage: "info.circle") {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
	}
	
	@ViewBuilder
	private func _contextActionsExtra(for app: AppInfoPresentable) -> some View {
		if let update = updateManager.update(for: app) {
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
	
	@ViewBuilder
	private func _buttonActions(for app: AppInfoPresentable) -> some View {
		Group {
			if let update = updateManager.update(for: app) {
				if app.isSigned {
					Button {
						_signedUpdateConfirmation = update
						_isSignedUpdateConfirmationPresented = true
					} label: {
						FRExpirationPillView(
							title: .localized("Install"),
							revoked: certRevoked,
							expiration: certInfo
						)
					}
				} else {
					Button {
						_startUpdateDownload(update)
					} label: {
						FRExpirationPillView(
							title: .localized("Update"),
							revoked: false,
							expiration: nil
						)
					}
				}
			} else if app.isSigned {
				Button {
					selectedInstallAppPresenting = AnyApp(base: app)
				} label: {
					FRExpirationPillView(
						title: .localized("Install"),
						revoked: certRevoked,
						expiration: certInfo
					)
				}
			} else {
				Button {
					selectedSigningAppPresenting = AnyApp(base: app)
				} label: {
					FRExpirationPillView(
						title: .localized("Sign"),
						revoked: false,
						expiration: nil
					)
				}
			}
		}
		.buttonStyle(.borderless)
	}
	
	private func _startUpdateDownload(_ update: AppUpdate) {
		_ = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "FeatherManualDownload_Update_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
	}
}
