//
//  NullSignSelfUpdateBanner.swift
//  Feather
//

import SwiftUI

/// At the top of the Library while a newer NullSign is out: one tap downloads
/// it, signs it with the certificate above and installs it over this one.
struct NullSignSelfUpdateBanner: View {
	@ObservedObject var selfUpdate: SelfUpdateManager

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
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 8)

			Button {
				Task { await selfUpdate.update() }
			} label: {
				if selfUpdate.isBusy {
					ProgressView()
						.tint(.white)
				} else {
					Text(_buttonTitle)
						.font(.roundedUI(.subheadline, weight: .bold))
						.lineLimit(1)
				}
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 34, dimsWhenDisabled: false))
			.frame(width: 96)
			.disabled(selfUpdate.isBusy)
		}
		.padding(16)
		.nullSignSurface()
		.accessibilityElement(children: .combine)
	}

	private var _version: String { selfUpdate.availableVersion ?? "" }

	private var _title: String {
		switch selfUpdate.state {
		case .downloading: return "Downloading NullSign \(_version)…"
		case .signing: return "Signing NullSign \(_version)…"
		case .installing: return "Installing NullSign \(_version)…"
		case .failed: return "Couldn't Update NullSign"
		default: return "NullSign \(_version) Is Out"
		}
	}

	private var _detail: String {
		switch selfUpdate.state {
		case .installing:
			return "Tap Install when iOS asks. NullSign closes while it updates; open it again once it's done."
		case .failed(let reason):
			return reason
		default:
			return "Update in one tap. iOS asks you to confirm, then NullSign closes while the new version replaces it."
		}
	}

	private var _buttonTitle: String {
		if case .failed = selfUpdate.state { return "Try Again" }
		return "Update"
	}
}
