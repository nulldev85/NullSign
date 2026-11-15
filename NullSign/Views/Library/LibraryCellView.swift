//
//  LibraryCellView.swift
//  NullSign
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
/// A library app as a NullSign card: icon, name and version, bundle ID,
/// platform and status, and one primary action.
struct LibraryCellView: View {
	@Environment(\.editMode) private var editMode

	var app: AppInfoPresentable
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedAppUUIDs: Set<String>
	var isHighlighted: Bool = false
	var update: AppUpdate?
	var onUpdate: ((AppUpdate) -> Void)?
	var onSelectMore: (() -> Void)?

	private let _cardShape = RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous)

	// MARK: Selections
	private var _isSelected: Bool {
		guard let uuid = app.uuid else { return false }
		return selectedAppUUIDs.contains(uuid)
	}

	private func _toggleSelection() {
		guard let uuid = app.uuid else { return }
		NBHaptic.selection()
		if selectedAppUUIDs.contains(uuid) {
			selectedAppUUIDs.remove(uuid)
		} else {
			selectedAppUUIDs.insert(uuid)
		}
	}

	// MARK: Body
	var body: some View {
		let isEditing = editMode?.wrappedValue == .active

		HStack(spacing: 12) {
			if isEditing {
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
					if let version = app.versionLabel, !version.isEmpty {
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

			if !isEditing {
				_primaryAction
			}
		}
		.padding(14)
		.nullSignSurface()
		.overlay {
			if isHighlighted {
				_cardShape.strokeBorder(NullSignStyle.accent.opacity(0.9), lineWidth: 2)
			} else if isEditing && _isSelected {
				_cardShape.strokeBorder(NullSignStyle.accent, lineWidth: 2)
			}
		}
		.animation(.easeInOut(duration: 0.3), value: isHighlighted)
		.contentShape(_cardShape)
		.onTapGesture {
			if isEditing {
				_toggleSelection()
			} else {
				selectedInfoAppPresenting = AnyApp(base: app)
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			if !isEditing {
				Button(role: .destructive) {
					Storage.shared.deleteApp(for: app)
				} label: {
					Label(.localized("Delete"), systemImage: "trash")
				}
				.tint(NullSignStyle.danger)
			}
		}
		.contextMenu {
			if !isEditing {
				LibraryAppMenu(
					app: app,
					selectedInfoAppPresenting: $selectedInfoAppPresenting,
					selectedSigningAppPresenting: $selectedSigningAppPresenting,
					onUpdate: onUpdate,
					onSelectMore: onSelectMore
				)
			}
		}
		.accessibilityAddTraits(isEditing && _isSelected ? .isSelected : [])
	}
}

// MARK: - Extension: View
extension LibraryCellView {
	private var _appIcon: some View {
		FRAppIconView(app: app, size: 56)
			.overlay(alignment: .topTrailing) {
				if update != nil {
					Circle()
						.fill(NullSignStyle.accent)
						.frame(width: 12, height: 12)
						.overlay(Circle().strokeBorder(NullSignStyle.groupedSurface, lineWidth: 2))
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
		if let update {
			Text(String.localized("Update to %@", arguments: update.best.versionLabel))
				.font(.roundedUI(.caption, weight: .regular))
				.foregroundStyle(NullSignStyle.accent)
				.lineLimit(1)
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
			Text(.localized("Not signed"))
				.font(.roundedUI(.caption))
				.foregroundStyle(NullSignStyle.faint)
		}
	}

	@ViewBuilder
	private var _primaryAction: some View {
		if let update, let onUpdate {
			Button {
				NBHaptic.tap()
				onUpdate(update)
			} label: {
				Text(.localized("Update"))
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 32))
		} else if app.isSigned {
			Button {
				NBHaptic.tap()
				InstallQueue.shared.enqueue(app)
			} label: {
				Text(.localized("Install"))
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 32))
			.disabled(Storage.shared.getCertificate(from: app)?.revoked == true)
		} else {
			Button {
				NBHaptic.tap()
				selectedSigningAppPresenting = AnyApp(base: app)
			} label: {
				Text(.localized("Sign"))
			}
			.buttonStyle(NullSignSecondaryButtonStyle(height: 32))
		}
	}
}
