import SwiftUI
import NimbleViews
import NimbleJSON
import AltSourceKit

struct AboutView: View {
	private static let _selfUpdateSourceURL = URL(string: "https://raw.githubusercontent.com/nulldev85/NullSign/main/app-repo.json")!

	private enum SelfUpdateState: Equatable {
		case idle
		case checking
		case upToDate
		case available(version: String)
		case downloading
		case failed
	}

	@State private var _selfUpdateState: SelfUpdateState = .idle
	@State private var _pendingUpdateDownloadURL: URL?
	@State private var _pendingUpdateProvenance: SourceAppProvenance?

	private var _build: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				VStack(spacing: 14) {
					FRAppIconView(size: 92, glow: true)
					HStack(alignment: .firstTextBaseline, spacing: 3) {
						Text("NullSign")
							.font(NullSignStyle.display(28))
						Circle()
							.fill(NullSignStyle.accent)
							.frame(width: 8, height: 8)
							.shadow(color: NullSignStyle.accent.opacity(0.9), radius: 6)
					}
					HStack(spacing: 6) {
						NullSignChip(text: "v\(Bundle.main.version)", uppercased: false)
						NullSignChip(text: "Build \(_build)", tint: NullSignStyle.muted)
						NullSignChip(text: "GPL-3.0", tint: NullSignStyle.violet)
					}
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 22)
				.background(
					RadialGradient(
						colors: [NullSignStyle.accent.opacity(0.25), .clear],
						center: .top,
						startRadius: 2,
						endRadius: 220
					)
				)
				.nullSignSurface(cornerRadius: 28)

				NullSignSettingsSection("App Updates", detail: _selfUpdateDetail) {
					Button {
						if case .available = _selfUpdateState {
							_startSelfUpdateDownload()
						} else {
							Task { await _checkForAppUpdate() }
						}
					} label: {
						NullSignSettingsRow(
							title: _selfUpdateTitle,
							detail: nil,
							systemImage: _selfUpdateIcon,
							showsChevron: false,
							isBusy: _selfUpdateState == .checking || _selfUpdateState == .downloading
						)
					}
					.buttonStyle(.plain)
					.disabled(_selfUpdateState == .checking || _selfUpdateState == .downloading)
				}

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
		.background(NullSignBackdrop(intensity: 0.8))
		.navigationTitle("About")
		.navigationBarTitleDisplayMode(.inline)
		.task {
			if _selfUpdateState == .idle {
				await _checkForAppUpdate()
			}
		}
	}

	private var _selfUpdateTitle: String {
		switch _selfUpdateState {
		case .idle, .checking: return "Checking for Updates…"
		case .upToDate: return "You're on the Latest Version"
		case .available(let version): return "Download NullSign \(version)"
		case .downloading: return "Downloading…"
		case .failed: return "Couldn't Check for Updates — Tap to Retry"
		}
	}

	private var _selfUpdateIcon: String {
		switch _selfUpdateState {
		case .idle, .checking, .downloading: return "arrow.triangle.2.circlepath"
		case .upToDate: return "checkmark.circle"
		case .available: return "arrow.down.circle"
		case .failed: return "exclamationmark.triangle"
		}
	}

	private var _selfUpdateDetail: String {
		switch _selfUpdateState {
		case .available:
			return "The download is added to your Library like any other app. Sign it with your certificate, then install it using Semi Local — Fully Local can't replace an app while it's running."
		default:
			return "Checks NullSign's own release feed for a newer build."
		}
	}

	private func _checkForAppUpdate() async {
		_selfUpdateState = .checking

		let repository: ASRepository? = await withCheckedContinuation { continuation in
			NBFetchService().fetch(from: Self._selfUpdateSourceURL) { (result: Result<ASRepository, Error>) in
				switch result {
				case .success(let repository): continuation.resume(returning: repository)
				case .failure: continuation.resume(returning: nil)
				}
			}
		}

		guard
			let repository,
			let bundleIdentifier = Bundle.main.bundleIdentifier,
			let remoteApp = repository.apps.first(where: { $0.id == bundleIdentifier })
		else {
			_selfUpdateState = .failed
			return
		}

		guard
			let remoteVersion = remoteApp.currentVersion, !remoteVersion.isEmpty,
			remoteVersion.compare(
				Bundle.main.version,
				options: [.numeric, .caseInsensitive]
			) == .orderedDescending,
			let downloadURL = remoteApp.currentDownloadUrl,
			let provenance = SourceAppProvenance(
				sourceURL: Self._selfUpdateSourceURL,
				repository: repository,
				app: remoteApp
			)
		else {
			_selfUpdateState = .upToDate
			return
		}

		_pendingUpdateDownloadURL = downloadURL
		_pendingUpdateProvenance = provenance
		_selfUpdateState = .available(version: remoteVersion)
	}

	private func _startSelfUpdateDownload() {
		guard let downloadURL = _pendingUpdateDownloadURL else { return }
		_ = DownloadManager.shared.startDownload(
			from: downloadURL,
			id: "FeatherManualDownload_AppUpdate_\(UUID().uuidString)",
			sourceProvenance: _pendingUpdateProvenance
		)
		_selfUpdateState = .downloading
		UIAlertController.showAlertWithOk(
			title: .localized("Downloading Update"),
			message: .localized("NullSign is downloading to your Library. Once it finishes, sign it with your certificate and install it using Semi Local (Settings → Installation → iPhone → Semi Local).")
		)
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
