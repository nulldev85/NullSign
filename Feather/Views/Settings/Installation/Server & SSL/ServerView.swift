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

	var body: some View {
		VStack(spacing: 22) {
			NullSignSettingsSection(
				"Server Setup",
				detail: "Semi Local is currently required because the certificate service used by Fully Local was retired."
			) {
				HStack {
					Text("Server type")
					Spacer()
					Text("Semi Local").foregroundStyle(.secondary)
				}

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
				.tint(NullSignStyle.accent)
				.disabled(_serverMethod != 1)
			}

			NullSignSettingsSection(
				"Fully Local",
				detail: "Temporarily unavailable. NullSign will not open a local HTTPS page that Safari cannot verify."
			) { EmptyView() }
		}
		.onAppear {
			if _serverMethod == 0 { _serverMethod = 1 }
		}
	}
}
