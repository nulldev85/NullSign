//
//  AppleTVPairingView.swift
//  NullSign
//

import SwiftUI
import NimbleViews
import IDeviceSwift

// MARK: - View
/// NullSign's Apple TV pairing: find an Apple TV on this network, pair it with
/// the six-digit code it shows, and keep the pairing. tvOS apps then install
/// straight to it, whatever installation method iPhone apps use.
struct AppleTVPairingView: View {
	@ObservedObject private var _appleTV = AppleTVManager.shared
	@State private var _selectedAppleTV: AppleTVDevice?
	@State private var _appleTVPIN = ""
	@State private var _isPairing = false
	@State private var _error: String?

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				NullSignSettingsIntro(
					systemImage: "appletv.fill",
					title: .localized("Apple TV"),
					detail: .localized("Sign tvOS apps here and install them on your Apple TV over Wi-Fi. No computer, VPN or pairing file needed."),
					status: _appleTV.pairedDevice == nil ? String.localized("Not paired") : String.localized("Paired"),
					statusColor: _appleTV.pairedDevice == nil ? NullSignStyle.muted : NullSignStyle.success
				)

				NullSignSettingsSection(
					.localized("Apple TV"),
					detail: _appleTV.pairedDevice == nil
						? String.localized("Leave Remote App and Devices open on Apple TV, then select it here. NullSign remembers the pairing.")
						: String.localized("Your pairing is saved. Keep both devices on the same Wi-Fi network to install tvOS apps.")
				) {
					if _appleTV.pairedDevice == nil {
						VStack(alignment: .leading, spacing: 5) {
							Text(.localized("ON YOUR APPLE TV"))
								.font(.roundedUI(size: 10, weight: .bold))
								.foregroundStyle(NullSignStyle.accent)
							Text(.localized("Settings  ›  Remotes and Devices  ›  Remote App and Devices"))
								.font(.roundedUI(.caption))
								.foregroundStyle(.secondary)
							Text(.localized("No VPN or imported pairing file is needed."))
								.font(.roundedUI(.caption2))
								.foregroundStyle(.secondary)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.vertical, 8)
						NullSignSettingsDivider()
					}

					if let paired = _appleTV.pairedDevice {
						_pairedRow(paired)
						if let udid = paired.udid, !udid.isEmpty {
							NullSignSettingsDivider()
							Button {
								UIPasteboard.general.string = udid
								Toast.success(.localized("UDID copied"))
							} label: {
								NullSignSettingsRow(
									title: .localized("UDID"),
									detail: udid,
									systemImage: "number",
									showsChevron: false
								)
							}
							.buttonStyle(.plain)
						}
					} else if _appleTV.discovered.isEmpty {
						_searchingRow
					} else {
						ForEach(Array(_appleTV.discovered.enumerated()), id: \.element.id) { index, device in
							if index > 0 { NullSignSettingsDivider() }
							Button {
								_beginPairing(device)
							} label: {
								NullSignSettingsRow(
									title: device.name,
									detail: .localized("Pair with six-digit code"),
									systemImage: "appletv",
									isBusy: _isPairing && _selectedAppleTV?.id == device.id
								)
							}
							.buttonStyle(.plain)
							.disabled(_isPairing)
						}
					}
				}

				NullSignSettingsSection(.localized("Setup Help")) {
					NullSignSettingsRow(
						title: .localized("Turn on Remote App and Devices"),
						detail: .localized("On the Apple TV: Settings → Remotes and Devices → Remote App and Devices. Leave that screen open while you pair."),
						systemImage: "appletv",
						showsChevron: false
					)
					NullSignSettingsDivider()
					NullSignSettingsRow(
						title: .localized("Stay on the same Wi-Fi network"),
						detail: .localized("NullSign only finds an Apple TV that's on the same network as this iPhone."),
						systemImage: "wifi",
						showsChevron: false
					)
					NullSignSettingsDivider()
					NullSignSettingsRow(
						title: .localized("Use a tvOS certificate"),
						detail: .localized("tvOS apps are signed with a certificate whose provisioning profile includes tvOS and this Apple TV's UDID. A new Apple TV has to be added to the profile first; tap UDID above to copy it for your certificate provider."),
						systemImage: "checkmark.seal",
						showsChevron: false
					)
				}
			}
			.padding(.horizontal, 20)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.nullSignPage()
		.nullSignNavigationTitle(.localized("Apple TV"))
		.onAppear { _appleTV.startScanning() }
		.onDisappear { _appleTV.stopScanning() }
		.alert(.localized("Pair Apple TV"), isPresented: Binding(
			get: { _appleTV.isAwaitingPIN },
			set: { if !$0 && _appleTV.isAwaitingPIN { _appleTV.cancelPairing() } }
		)) {
			TextField(.localized("Six-digit code"), text: $_appleTVPIN)
				.keyboardType(.numberPad)
			Button(.localized("Cancel"), role: .cancel) { _appleTV.cancelPairing() }
			Button(.localized("Pair")) { _ = _appleTV.submitPIN(_appleTVPIN) }
				.disabled(_appleTVPIN.count != 6)
		} message: {
			Text(verbatim: .localized("Enter the code currently shown on %@.", arguments: _selectedAppleTV?.name ?? String.localized("Apple TV")))
		}
		.alert(.localized("Apple TV"), isPresented: Binding(
			get: { _error != nil },
			set: { if !$0 { _error = nil } }
		)) {
			Button(.localized("OK"), role: .cancel) {}
		} message: {
			Text(_error ?? "")
		}
	}
}

// MARK: - Rows
extension AppleTVPairingView {
	private func _pairedRow(_ paired: AppleTVDevice) -> some View {
		HStack(spacing: 12) {
			NullSignIconTile(systemImage: "appletv.fill", tint: NullSignStyle.accent, size: 32, filled: true)
			VStack(alignment: .leading, spacing: 2) {
				Text(paired.name)
					.font(.roundedUI(.body))
				Text(paired.connectionPort == nil ? String.localized("Saved • looking nearby") : String.localized("Saved • available"))
					.font(.roundedUI(.caption))
					.foregroundStyle(paired.connectionPort == nil ? NullSignStyle.muted : NullSignStyle.success)
			}
			Spacer()
			Button(.localized("Forget"), role: .destructive) { _appleTV.forget() }
				.font(.roundedUI(.subheadline, weight: .bold))
				.foregroundStyle(NullSignStyle.danger)
		}
		.frame(minHeight: 52)
	}

	private var _searchingRow: some View {
		HStack(spacing: 12) {
			if _appleTV.isScanning {
				ProgressView()
					.frame(width: 32, height: 32)
			} else {
				NullSignIconTile(systemImage: "appletv", tint: NullSignStyle.muted, size: 32, filled: false)
			}
			Text(_appleTV.isScanning ? String.localized("Looking for Apple TV…") : String.localized("No Apple TV found"))
				.font(.roundedUI(.body))
				.foregroundStyle(.secondary)
			Spacer()
			Button(_appleTV.isScanning ? String.localized("Refresh") : String.localized("Scan")) { _appleTV.refresh() }
				.font(.roundedUI(.subheadline, weight: .bold))
				.foregroundStyle(NullSignStyle.accent)
		}
		.frame(minHeight: 52)
	}

	private func _beginPairing(_ device: AppleTVDevice) {
		_selectedAppleTV = device
		_appleTVPIN = ""
		_isPairing = true
		Task {
			do {
				try await _appleTV.pair(device: device)
				Toast.success(.localized("Paired with %@", arguments: _appleTV.pairedDevice?.name ?? device.name))
			} catch {
				_error = error.localizedDescription
			}
			_selectedAppleTV = nil
			_isPairing = false
		}
	}
}
