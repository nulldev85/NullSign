//
//  NullSignSelfUpdateBanner.swift
//  NullSign
//

import SwiftUI
import NimbleExtensions

/// At the top of the Signer while a newer NullSign is out: one tap downloads
/// it, signs it and hands it to the installer to replace this one. Tapping
/// the card shows what's new.
struct NullSignSelfUpdateBanner: View {
	@ObservedObject var selfUpdate: SelfUpdateManager
	let release: SelfUpdateRelease
	var onShowNotes: () -> Void

	var body: some View {
		HStack(spacing: 14) {
			Image(systemName: "arrow.down.app.fill")
				.font(.roundedUI(size: 30, weight: .semibold))
				.foregroundStyle(NullSignStyle.accent)
				.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 3) {
				Text(_title)
					.font(.roundedUI(.headline, weight: .heavy))
					.lineLimit(1)
					.minimumScaleFactor(0.85)
				Text(_detail)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(_isFailed ? NullSignStyle.danger : NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 8)

			Button {
				NBHaptic.tap()
				selfUpdate.beginUpdate(to: release)
			} label: {
				if _isBusy {
					ProgressView()
						.tint(.white)
				} else {
					Text(_isFailed ? String.localized("Try Again") : String.localized("Update"))
						.font(.roundedUI(.subheadline, weight: .bold))
						.lineLimit(1)
				}
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 34, dimsWhenDisabled: false))
			.frame(width: 96)
			.disabled(_isBusy)
		}
		.padding(16)
		.nullSignSurface()
		.contentShape(RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous))
		.onTapGesture(perform: onShowNotes)
		.accessibilityElement(children: .combine)
		.accessibilityAction(named: Text(.localized("What's New")), onShowNotes)
	}

	private var _isBusy: Bool {
		switch selfUpdate.phase {
		case .downloading, .importing, .signing: return true
		default: return false
		}
	}

	private var _isFailed: Bool {
		if case .failed = selfUpdate.phase { return true }
		return false
	}

	private var _title: String {
		switch selfUpdate.phase {
		case .downloading(let progress):
			return .localized("Downloading NullSign %@ · %lld%%", arguments: release.label, Int(progress * 100))
		case .importing: return .localized("Preparing NullSign %@…", arguments: release.label)
		case .signing: return .localized("Signing NullSign %@…", arguments: release.label)
		case .failed: return .localized("Couldn't Update NullSign")
		default: return .localized("NullSign %@ Is Out", arguments: release.label)
		}
	}

	private var _detail: String {
		if case .failed(let reason) = selfUpdate.phase { return reason }
		return .localized("Update in one tap. iOS asks you to confirm, then NullSign closes while the new version replaces it.")
	}
}
