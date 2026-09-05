import SwiftUI
import Nuke
import CoreData
import NimbleViews

struct ResetView: View {
	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				NullSignSettingsIntro(
					systemImage: "internaldrive",
					title: "Storage & Reset",
					detail: "Clear a specific category without disturbing the rest of your setup. Every action asks before removing data."
				)

				NullSignSettingsSection("Caches") {
					_actionRow(
						title: "Work Cache",
						detail: "Temporary signing and extraction files",
						systemImage: "shippingbox"
					) {
						Self.resetAlert(title: "Clear Work Cache") {
							Self.clearWorkCache()
						}
					}

					NullSignSettingsDivider()

					_actionRow(
						title: "Network & Image Cache",
						detail: _cacheSize(),
						systemImage: "network"
					) {
						Self.resetAlert(title: "Clear Network Cache", message: _cacheSize()) {
							Self.clearNetworkCache()
						}
					}
				}

				NullSignSettingsSection(
					"Library",
					detail: "Certificate resets also remove local .p12 and provisioning-profile files."
				) {
					_actionRow(
						title: "Repositories",
						detail: Storage.shared.countContent(for: AltSource.self),
						systemImage: "tray.full"
					) {
						Self.resetAlert(title: "Reset Repositories", message: Storage.shared.countContent(for: AltSource.self)) {
							Self.resetSources()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Signed Apps",
						detail: Storage.shared.countContent(for: Signed.self),
						systemImage: "checkmark.seal"
					) {
						Self.resetAlert(title: "Reset Signed Apps", message: Storage.shared.countContent(for: Signed.self)) {
							Self.deleteSignedApps()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Imported Apps",
						detail: Storage.shared.countContent(for: Imported.self),
						systemImage: "square.and.arrow.down"
					) {
						Self.resetAlert(title: "Reset Imported Apps", message: Storage.shared.countContent(for: Imported.self)) {
							Self.deleteImportedApps()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Certificates",
						detail: Storage.shared.countContent(for: CertificatePair.self),
						systemImage: "key"
					) {
						Self.resetAlert(title: "Reset Certificates", message: Storage.shared.countContent(for: CertificatePair.self)) {
							Self.resetCertificates()
						}
					}
				}

				NullSignSettingsSection(
					"Danger Zone",
					detail: "These actions cannot be undone. Export anything you need before continuing."
				) {
					_actionRow(
						title: "Reset Settings",
						detail: "Restore every preference to its default",
						systemImage: "slider.horizontal.3",
						tint: NullSignStyle.warning
					) {
						Self.resetAlert(title: "Reset Settings") {
							Self.resetUserDefaults()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Erase All NullSign Data",
						detail: "Apps, certificates, repositories, caches, and settings",
						systemImage: "trash",
						tint: NullSignStyle.warning
					) {
						Self.resetAlert(title: "Erase All NullSign Data") {
							Self.resetAll()
						}
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("Storage & Reset")
	}

	private func _actionRow(
		title: String,
		detail: String,
		systemImage: String,
		tint: Color = NullSignStyle.accent,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			NullSignSettingsRow(
				title: title,
				detail: detail,
				systemImage: systemImage,
				tint: tint,
				showsChevron: false
			)
		}
		.buttonStyle(.plain)
	}

	private func _cacheSize() -> String {
		var totalCacheSize = URLCache.shared.currentDiskUsage
		if let nukeCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
			totalCacheSize += nukeCache.totalSize
		}
		return ByteCountFormatter.string(fromByteCount: Int64(totalCacheSize), countStyle: .file)
	}

	static func resetAlert(
		title: String,
		message: String = "",
		action: @escaping () -> Void
	) {
		let proceedAction = UIAlertAction(title: "Proceed", style: .destructive) { _ in
			action()
			UIApplication.shared.suspendAndReopen()
		}

		let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
		let detail = message.isEmpty
			? "This action cannot be undone."
			: "\(message)\n\nThis action cannot be undone."

		UIAlertController.showAlertWithCancel(
			title: title,
			message: detail,
			style: style,
			actions: [proceedAction]
		)
	}
}

extension ResetView {
	static func clearWorkCache() {
		let fileManager = FileManager.default
		let temporaryDirectory = fileManager.temporaryDirectory

		if let files = try? fileManager.contentsOfDirectory(atPath: temporaryDirectory.path()) {
			for file in files {
				try? fileManager.removeItem(atPath: temporaryDirectory.appendingPathComponent(file).path())
			}
		}
	}

	static func clearNetworkCache() {
		URLCache.shared.removeAllCachedResponses()
		HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

		if let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
			dataCache.removeAll()
		}

		if let imageCache = ImagePipeline.shared.configuration.imageCache as? Nuke.ImageCache {
			imageCache.removeAll()
		}
	}

	static func resetSources() {
		Storage.shared.clearContext(request: AltSource.fetchRequest())
	}

	static func deleteSignedApps() {
		Storage.shared.deleteSourceMetadata(kind: .signed)
		Storage.shared.clearContext(request: Signed.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.signed)
	}

	static func deleteImportedApps() {
		Storage.shared.deleteSourceMetadata(kind: .imported)
		Storage.shared.clearContext(request: Imported.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.unsigned)
	}

	static func resetCertificates(resetAll: Bool = false) {
		if !resetAll { UserDefaults.standard.set(0, forKey: "feather.selectedCert") }
		Storage.shared.clearContext(request: CertificatePair.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.certificates)
	}

	static func resetUserDefaults() {
		UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
	}

	static func resetAll() {
		clearWorkCache()
		clearNetworkCache()
		resetSources()
		deleteSignedApps()
		deleteImportedApps()
		resetCertificates(resetAll: true)
		resetUserDefaults()
	}
}
