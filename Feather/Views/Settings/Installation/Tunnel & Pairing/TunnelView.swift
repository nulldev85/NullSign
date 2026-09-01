import SwiftUI
import IDeviceSwift
import NimbleViews

struct TunnelView: View {
	@ObservedObject private var _appleTV = AppleTVManager.shared
	@State private var _isImportingPairingPresenting = false
	@State private var _hasPairingFile = false
	@State private var _isLocalDevVPNAvailable = false
	@State private var _selectedAppleTV: AppleTVDevice?
	@State private var _appleTVPIN = ""
	@State private var _isPairingAppleTV = false
	@State private var _appleTVError: String?

	var body: some View {
		VStack(spacing: 22) {
			NullSignSettingsSection(
				"Apple TV",
				detail: _appleTV.pairedDevice == nil
					? "Pair once with the code on your TV. NullSign remembers the secure pairing record."
					: "Your pairing is saved. Keep both devices on the same Wi-Fi network to install tvOS apps."
			) {
				if let paired = _appleTV.pairedDevice {
					HStack(spacing: 12) {
						Image(systemName: "appletv.fill")
							.foregroundStyle(NullSignStyle.cyan)
							.frame(width: 32, height: 32)
							.background(NullSignStyle.raisedPanel)
							.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
						VStack(alignment: .leading, spacing: 2) {
							Text(paired.name).font(.body.weight(.medium))
							Text(paired.connectionPort == nil ? "Saved • looking nearby" : "Saved • available")
								.font(.caption).foregroundStyle(.secondary)
						}
						Spacer()
						Button("Forget", role: .destructive) { _appleTV.forget() }
							.font(.subheadline.weight(.semibold))
					}
				} else if _appleTV.discovered.isEmpty {
					HStack {
						Label(_appleTV.isScanning ? "Looking for Apple TV…" : "No Apple TV found", systemImage: "appletv")
							.foregroundStyle(.secondary)
					Spacer()
					Button(_appleTV.isScanning ? "Refresh" : "Scan") { _appleTV.refresh() }
						.font(.subheadline.weight(.semibold)).foregroundStyle(NullSignStyle.cyan)
					}
				} else {
					ForEach(Array(_appleTV.discovered.enumerated()), id: \.element.id) { index, device in
						if index > 0 { NullSignSettingsDivider() }
						Button {
							_selectedAppleTV = device
							_appleTVPIN = ""
						} label: {
							NullSignSettingsRow(title: device.name, detail: "Pair with six-digit code", systemImage: "appletv")
						}
						.buttonStyle(.plain)
					}
				}
			}

			NullSignSettingsSection(
				"This iPhone",
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
			_appleTV.startScanning()
		}
		.alert("Pair Apple TV", isPresented: Binding(
			get: { _selectedAppleTV != nil },
			set: { if !$0 { _selectedAppleTV = nil } }
		)) {
			TextField("Six-digit code", text: $_appleTVPIN)
				.keyboardType(.numberPad)
			Button("Cancel", role: .cancel) { _selectedAppleTV = nil }
			Button(_isPairingAppleTV ? "Pairing…" : "Pair") { _pairAppleTV() }
				.disabled(_appleTVPIN.count != 6 || _isPairingAppleTV)
		} message: {
			Text("Enter the code currently shown on \(_selectedAppleTV?.name ?? "Apple TV").")
		}
		.alert("Apple TV", isPresented: Binding(
			get: { _appleTVError != nil },
			set: { if !$0 { _appleTVError = nil } }
		)) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(_appleTVError ?? "Unknown error")
		}
	}

	private func _pairAppleTV() {
		guard let device = _selectedAppleTV else { return }
		_isPairingAppleTV = true
		Task {
			do {
				try await _appleTV.pair(device: device, pin: _appleTVPIN)
				_selectedAppleTV = nil
			} catch {
				_selectedAppleTV = nil
				_appleTVError = String(describing: error)
			}
			_isPairingAppleTV = false
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
