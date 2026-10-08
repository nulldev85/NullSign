import SwiftUI
import Nuke
import CoreData
import NimbleViews

struct ResetView: View {
	/// Bumped after each action so the counts below re-read the store.
	@State private var _refreshToken = 0
	@State private var _cacheSize = "—"

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
						_confirm(title: "Clear Work Cache") {
							Self.clearWorkCache()
						}
					}

					NullSignSettingsDivider()

					_actionRow(
						title: "Network & Image Cache",
						detail: _cacheSize,
						systemImage: "network"
					) {
						_confirm(title: "Clear Network Cache", message: _cacheSize) {
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
						detail: _count(AltSource.self),
						systemImage: "tray.full"
					) {
						_confirm(title: "Reset Repositories", message: _count(AltSource.self)) {
							Self.resetSources()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Signed Apps",
						detail: _count(Signed.self),
						systemImage: "checkmark.seal"
					) {
						_confirm(title: "Reset Signed Apps", message: _count(Signed.self)) {
							Self.deleteSignedApps()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Imported Apps",
						detail: _count(Imported.self),
						systemImage: "square.and.arrow.down"
					) {
						_confirm(title: "Reset Imported Apps", message: _count(Imported.self)) {
							Self.deleteImportedApps()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Certificates",
						detail: _count(CertificatePair.self),
						systemImage: "key"
					) {
						_confirm(title: "Reset Certificates", message: _count(CertificatePair.self)) {
							Self.resetCertificates()
						}
					}
				}

				NullSignSettingsSection(
					"Danger Zone",
					detail: "These actions cannot be undone, and NullSign restarts afterwards. Export anything you need before continuing."
				) {
					_actionRow(
						title: "Reset Settings",
						detail: "Restore every preference to its default",
						systemImage: "slider.horizontal.3",
						tint: NullSignStyle.danger
					) {
						_confirm(title: "Reset Settings", restartsApp: true) {
							Self.resetUserDefaults()
						}
					}
					NullSignSettingsDivider()
					_actionRow(
						title: "Erase All NullSign Data",
						detail: "Apps, certificates, repositories, caches, and settings",
						systemImage: "trash",
						tint: NullSignStyle.danger
					) {
						_confirm(title: "Erase All NullSign Data", restartsApp: true) {
							Self.resetAll()
						}
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
			.id(_refreshToken)
		}
		.background(NullSignBackdrop(intensity: 0.8))
		.navigationTitle("Storage & Reset")
		.navigationBarTitleDisplayMode(.inline)
		.task(id: _refreshToken) {
			_cacheSize = await Self.cacheSize()
		}
	}

	private func _actionRow(
		title: String,
		detail: String,
		systemImage: String,
		tint: Color = .white,
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

	private func _count<T: NSManagedObject>(_ type: T.Type) -> String {
		let count = Storage.shared.countContent(for: type)
		return count == "1" ? "1 item" : "\(count) items"
	}

	/// Library actions apply in place. Only resets that wipe preferences
	/// relaunch NullSign, so every in-memory setting starts fresh — the
	/// alert says so up front rather than the app vanishing unannounced.
	private func _confirm(
		title: String,
		message: String = "",
		restartsApp: Bool = false,
		action: @escaping () -> Void
	) {
		let proceedAction = UIAlertAction(title: restartsApp ? "Erase & Restart" : "Proceed", style: .destructive) { _ in
			action()
			UINotificationFeedbackGenerator().notificationOccurred(.success)
			if restartsApp {
				UIApplication.shared.suspendAndReopen()
			} else {
				_refreshToken += 1
			}
		}

		let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
		var detail = message.isEmpty ? "This action cannot be undone." : "\(message)\n\nThis action cannot be undone."
		if restartsApp {
			detail += " NullSign will restart when it's done."
		}

		UIAlertController.showAlertWithCancel(
			title: title,
			message: detail,
			style: style,
			actions: [proceedAction]
		)
	}
}

extension ResetView {
	/// Removes what is in the temporary directory right now; files created
	/// afterwards (a new import, a signing session) are never touched.
	static func clearWorkCache() {
		FileManager.default.removeContentsInBackground(of: FileManager.default.temporaryDirectory)
	}

	static func cacheSize() async -> String {
		let size = await Task.detached(priority: .utility) { () -> Int in
			var total = URLCache.shared.currentDiskUsage
			if let nukeCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
				total += nukeCache.totalSize
			}
			return total
		}.value
		return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
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
		FileManager.default.removeContentsInBackground(of: FileManager.default.signed)
	}

	static func deleteImportedApps() {
		Storage.shared.deleteSourceMetadata(kind: .imported)
		Storage.shared.clearContext(request: Imported.fetchRequest())
		FileManager.default.removeContentsInBackground(of: FileManager.default.unsigned)
	}

	static func resetCertificates(resetAll: Bool = false) {
		if !resetAll {
			UserDefaults.standard.set(0, forKey: "feather.selectedCert")
			UserDefaults.standard.removeObject(forKey: "feather.selectedCert.iOS")
			UserDefaults.standard.removeObject(forKey: "feather.selectedCert.tvOS")
		}
		Storage.shared.clearContext(request: CertificatePair.fetchRequest())
		FileManager.default.removeContentsInBackground(of: FileManager.default.certificates)
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
