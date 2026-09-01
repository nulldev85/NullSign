import SwiftUI
import NimbleViews

extension ServerView {
	struct ServerPackModel: Decodable {
		var cert: String
		var ca: String
		var key: String
		var info: ServerPackInfo

		private enum CodingKeys: String, CodingKey {
			case cert, ca, key1, key2, info
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			cert = try container.decode(String.self, forKey: .cert)
			ca = try container.decode(String.self, forKey: .ca)
			let key1 = try container.decode(String.self, forKey: .key1)
			let key2 = try container.decode(String.self, forKey: .key2)
			key = key1 + key2
			info = try container.decode(ServerPackInfo.self, forKey: .info)
		}

		struct ServerPackInfo: Decodable {
			var issuer: Domains
			var domains: Domains
		}

		struct Domains: Decodable {
			var commonName: String
		}
	}
}

struct ServerView: View {
	@AppStorage("Feather.ipFix") private var _ipFix = false
	@AppStorage("Feather.serverMethod") private var _serverMethod = 0
	@State private var _isUpdatingCertificates = false

	private let _serverPackURL = "https://backloop.dev/pack.json"

	var body: some View {
		VStack(spacing: 22) {
			NullSignSettingsSection(
				"Server Setup",
				detail: _serverMethod == 0
					? "Fully Local keeps the install route on your network. If installation stalls, try Semi Local."
					: "Semi Local can be more tolerant of network restrictions but relies on an external service."
			) {
				Picker("Server type", selection: $_serverMethod) {
					Text("Fully Local").tag(0)
					Text("Semi Local").tag(1)
				}
				.pickerStyle(.segmented)

				NullSignSettingsDivider()

				Toggle(isOn: $_ipFix) {
					VStack(alignment: .leading, spacing: 2) {
						Text("Use localhost only")
							.font(.body.weight(.medium))
						Text("Avoid exposing the temporary server on your LAN")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.tint(NullSignStyle.cyan)
				.disabled(_serverMethod != 1)
			}

			NullSignSettingsSection(
				"Local Trust",
				detail: "Refresh these files if the installer remains at Ready or iOS reports that it cannot connect to the server."
			) {
				Button {
					_updateCertificates()
				} label: {
					HStack(spacing: 12) {
						Image(systemName: "lock.rotation")
							.foregroundStyle(NullSignStyle.cyan)
							.frame(width: 32, height: 32)
							.background(NullSignStyle.raisedPanel)
							.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
						Text(_isUpdatingCertificates ? "Updating certificates…" : "Update SSL Certificates")
							.font(.body.weight(.medium))
							.foregroundStyle(.primary)
						Spacer()
						if _isUpdatingCertificates {
							ProgressView().tint(NullSignStyle.cyan)
						} else {
							Image(systemName: "arrow.down")
								.foregroundStyle(.secondary)
						}
					}
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.disabled(_isUpdatingCertificates)
			}
		}
	}

	private func _updateCertificates() {
		_isUpdatingCertificates = true
		FR.downloadSSLCertificates(from: _serverPackURL) { success in
			DispatchQueue.main.async {
				_isUpdatingCertificates = false
				UIAlertController.showAlertWithOk(
					title: "SSL Certificates",
					message: success
						? "Certificates updated successfully."
						: "The update failed. Check your connection and try again."
				)
			}
		}
	}
}
