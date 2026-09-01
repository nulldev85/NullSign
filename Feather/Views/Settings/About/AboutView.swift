import SwiftUI
import NimbleViews

struct AboutView: View {
	private var _build: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				VStack(spacing: 10) {
					FRAppIconView(size: 76)
						.clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
					Text("NullSign")
						.font(.title2.weight(.bold))
					Text("Version \(Bundle.main.version) · Build \(_build)")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 8)

				NullSignSettingsSection("Project") {
					_linkRow(
						title: "Source Code",
						detail: "nulldev85/NullSign",
						systemImage: "chevron.left.forwardslash.chevron.right",
						url: "https://github.com/nulldev85/NullSign"
					)
				}

				NullSignSettingsSection(
					"Credits",
					detail: "NullSign is a fork of Feather. Its signing, repository, and installation foundations came from Feather and its contributors."
				) {
					_linkRow(
						title: "nulldev85",
						detail: "NullSign maintainer",
						systemImage: "person",
						url: "https://github.com/nulldev85"
					)
					NullSignSettingsDivider()
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
						detail: "Read the license in this repository",
						systemImage: "doc.text",
						url: "https://github.com/nulldev85/NullSign/blob/main/LICENSE"
					)
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 16)
			.padding(.bottom, 28)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("About")
		.navigationBarTitleDisplayMode(.inline)
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
