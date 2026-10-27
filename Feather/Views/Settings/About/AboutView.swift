import SwiftUI
import NimbleViews
import NimbleJSON
import AltSourceKit

struct AboutView: View {
	@StateObject private var _selfUpdate = SelfUpdateManager.shared

	private var _build: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				VStack(spacing: 10) {
					FRAppIconView(size: 84)
					Text("NullSign")
						.font(.roundedUI(.title2, weight: .heavy))
					Text("Version \(Bundle.main.version) (\(_build))")
						.font(.roundedUI(.subheadline))
						.foregroundStyle(NullSignStyle.muted)
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 12)

				NullSignSettingsSection("App Updates", detail: _selfUpdateDetail) {
					Button {
						Task { await _selfUpdate.primaryAction() }
					} label: {
						NullSignSettingsRow(
							title: _selfUpdateTitle,
							detail: nil,
							systemImage: _selfUpdateIcon,
							showsChevron: false,
							isBusy: _selfUpdate.isBusy
						)
					}
					.buttonStyle(.plain)
					.disabled(_selfUpdate.isBusy)
				}

				NullSignSettingsSection(
					"Credits",
					detail: "NullSign is a fork of Feather. Its signing, repository, and installation foundations came from Feather and its contributors."
				) {
					_linkRow(
						title: "Feather",
						detail: "Original project by claration and contributors",
						systemImage: "arrow.triangle.branch",
						url: "https://github.com/claration/Feather"
					)
					NullSignSettingsDivider()
					_linkRow(
						title: "C",
						detail: "Feather developer · claration",
						systemImage: "person.2",
						url: "https://github.com/claration"
					)
					NullSignSettingsDivider()
					_linkRow(
						title: "Asami",
						detail: "Feather developer · Nyasami",
						systemImage: "person.2",
						url: "https://github.com/Nyasami"
					)
					NullSignSettingsDivider()
					_linkRow(
						title: "Lakhan Lothiyi",
						detail: "AltStore repository work · llsc12",
						systemImage: "person.2",
						url: "https://github.com/llsc12"
					)
				}

				NullSignSettingsSection(
					"License",
					detail: "NullSign is free software distributed under GNU GPL v3. Forks and redistributed builds must keep the license and provide corresponding source."
				) {
					_linkRow(
						title: "GNU GPL v3",
						detail: "Read the full license text",
						systemImage: "doc.text",
						url: "https://www.gnu.org/licenses/gpl-3.0.html"
					)
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 16)
			.padding(.bottom, 28)
		}
		.nullSignPage()
		.nullSignNavigationTitle("About")
		.navigationBarTitleDisplayMode(.inline)
		.task {
			switch _selfUpdate.state {
			case .idle, .upToDate, .failed: await _selfUpdate.check()
			default: break
			}
		}
	}

	private var _selfUpdateTitle: String {
		let version = _selfUpdate.availableVersion ?? ""
		switch _selfUpdate.state {
		case .idle, .checking: return "Checking for Updates…"
		case .upToDate: return "You're on the Latest Version"
		case .available: return "Update to NullSign \(version)"
		case .downloading: return "Downloading NullSign \(version)…"
		case .signing: return "Signing NullSign \(version)…"
		case .installing: return "Installing NullSign \(version)…"
		case .failed: return "Couldn't Update — Tap to Try Again"
		}
	}

	private var _selfUpdateIcon: String {
		switch _selfUpdate.state {
		case .idle, .checking, .downloading, .signing, .installing: return "arrow.triangle.2.circlepath"
		case .upToDate: return "checkmark.circle"
		case .available: return "arrow.down.circle"
		case .failed: return "exclamationmark.triangle"
		}
	}

	private var _selfUpdateDetail: String {
		switch _selfUpdate.state {
		case .available, .downloading, .signing:
			return "NullSign downloads the update, signs it with the certificate shown in your Library and installs it. iOS asks you to confirm, then NullSign closes while the new version replaces it. Open it again once it's done."
		case .installing:
			return "Tap Install when iOS asks. NullSign then steps out to the Home Screen while the new version replaces it; open it again once its icon finishes."
		case .failed(let reason):
			return reason
		default:
			return "Checks NullSign's own release feed for a newer build."
		}
	}

	private func _linkRow(
		title: String,
		detail: String,
		systemImage: String,
		url: String
	) -> some View {
		Button {
			UIApplication.open(url)
		} label: {
			NullSignSettingsRow(
				title: title,
				detail: detail,
				systemImage: systemImage
			)
		}
		.buttonStyle(.plain)
	}
}
