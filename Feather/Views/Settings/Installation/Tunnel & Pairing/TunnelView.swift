import SwiftUI
import IDeviceSwift
import NimbleViews

struct TunnelView: View {
	@State private var _isImportingPairingPresenting = false
	@State private var _hasPairingFile = false
	@State private var _isLocalDevVPNAvailable = false

	var body: some View {
		VStack(spacing: 22) {
			NullSignSettingsSection(
				"Pairing",
				detail: _hasPairingFile
					? "The pairing record is stored locally and ready for device installation."
					: "Create a pairing record on a trusted computer, then import it here."
			) {
				HStack(spacing: 12) {
					Image(systemName: _hasPairingFile ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(_hasPairingFile ? NullSignStyle.cyan : NullSignStyle.peach)
						.frame(width: 32, height: 32)
						.background(NullSignStyle.raisedPanel)
						.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

					VStack(alignment: .leading, spacing: 2) {
						Text("Pairing File")
							.font(.body.weight(.medium))
						Text(_hasPairingFile ? "Imported" : "Required")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Spacer()
					Button(_hasPairingFile ? "Replace" : "Import") {
						_isImportingPairingPresenting = true
					}
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(NullSignStyle.cyan)
				}
			}

			if #available(iOS 17.4, *) {
				// Newer iOS versions do not use the legacy heartbeat controls.
			} else {
				NullSignSettingsSection(
					"Connection",
					detail: "Heartbeat is restarted when NullSign opens. A live connection is required while installation begins."
				) {
					TunnelHeaderView()
					NullSignSettingsDivider()
					Button {
						_restartHeartbeat()
					} label: {
						NullSignSettingsRow(
							title: "Restart Heartbeat",
							detail: nil,
							systemImage: "arrow.clockwise",
							showsChevron: false
						)
					}
					.buttonStyle(.plain)
				}
			}

			NullSignSettingsSection("Setup Help") {
				Button {
					UIApplication.open("https://github.com/claration/Impactor#pairing-file")
				} label: {
					NullSignSettingsRow(
						title: "Pairing File Guide",
						detail: "How to create a device pairing record",
						systemImage: "questionmark.circle"
					)
				}
				.buttonStyle(.plain)

				NullSignSettingsDivider()

				Button {
					if _isLocalDevVPNAvailable {
						UIApplication.open("localdevvpn://enable?scheme=feather")
					} else {
						UIApplication.open("https://apps.apple.com/us/app/localdevvpn/id6755608044")
					}
				} label: {
					NullSignSettingsRow(
						title: _isLocalDevVPNAvailable ? "Open LocalDevVPN" : "Get LocalDevVPN",
						detail: _isLocalDevVPNAvailable ? "Enable the loopback connection" : "Required for the device tunnel",
						systemImage: "network"
					)
				}
				.buttonStyle(.plain)
			}
		}
		.sheet(isPresented: $_isImportingPairingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.xmlPropertyList, .plist, .mobiledevicepairing],
				onDocumentsPicked: { urls in
					guard let selectedFileURL = urls.first else { return }
					FR.movePairing(selectedFileURL)
					_hasPairingFile = true
				}
			)
			.ignoresSafeArea()
		}
		.onAppear {
			_hasPairingFile = FileManager.default.fileExists(atPath: HeartbeatManager.pairingFile())
			if let url = URL(string: "localdevvpn://") {
				_isLocalDevVPNAvailable = UIApplication.shared.canOpenURL(url)
			}
		}
	}

	private func _restartHeartbeat() {
		HeartbeatManager.shared.start(true)

		DispatchQueue.global(qos: .userInitiated).async {
			guard !HeartbeatManager.shared.checkSocketConnection().isConnected else { return }
			DispatchQueue.main.async {
				UIAlertController.showAlertWithOk(
					title: "Connection Unavailable",
					message: "Enable the loopback VPN and connect to Wi-Fi, or use Airplane Mode with Wi-Fi enabled."
				)
			}
		}
	}
}
