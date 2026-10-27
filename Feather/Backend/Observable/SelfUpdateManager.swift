//
//  SelfUpdateManager.swift
//  Feather
//

import AltSourceKit
import Combine
import CoreData
import Foundation
import NimbleJSON

/// NullSign updating itself. It looks for a newer NullSign in the app source
/// testers install it from and, when asked, downloads it, signs it with the
/// certificate shown in the Library and hands it to the installer. iOS asks
/// before installing, then closes NullSign while the new version replaces it.
@MainActor
final class SelfUpdateManager: ObservableObject {
	static let shared = SelfUpdateManager()

	/// The app source testers install NullSign from, which lists every release.
	static let sourceURL = URL(string: "https://raw.githubusercontent.com/nulldev85/AppSource/main/apps.json")!
	/// NullSign's identifier in that source, whatever this copy was signed as.
	static let sourceBundleIdentifier = "com.elmat.NullSign"

	enum State: Equatable {
		case idle
		case checking
		case upToDate
		case available
		case downloading
		case signing
		case installing
		case failed(String)
	}

	@Published private(set) var state: State = .idle
	/// The newer release, "1.4.3 (32)", while there is one.
	@Published private(set) var availableVersion: String?
	/// The signed update, for the installer sheet.
	@Published var installingApp: AnyApp?

	private var _offer: Offer?
	private var _lastChecked: Date?
	private let _checkInterval: TimeInterval = 6 * 60 * 60

	private struct Offer {
		let downloadURL: URL
		let provenance: SourceAppProvenance
		let bundleIdentifier: String
	}

	private init() {}

	var isBusy: Bool {
		switch state {
		case .checking, .downloading, .signing, .installing: return true
		default: return false
		}
	}

	/// Checks when NullSign opens or comes back, at most every six hours.
	func checkIfNeeded() async {
		if let _lastChecked, Date().timeIntervalSince(_lastChecked) < _checkInterval { return }
		await check()
	}

	func check() async {
		guard !isBusy else { return }
		state = .checking
		_lastChecked = Date()

		guard let repository = await Self._fetchRepository() else {
			state = .failed(.localized("Couldn't reach the app source. Check your connection and try again."))
			return
		}

		let running = Bundle.main.bundleIdentifier ?? Self.sourceBundleIdentifier
		guard
			let remoteApp = repository.apps.first(where: { $0.id == running })
				?? repository.apps.first(where: { $0.id == Self.sourceBundleIdentifier }),
			let remoteVersion = remoteApp.currentVersion, !remoteVersion.isEmpty,
			ReleaseOrder.isNewer(
				remoteVersion, build: remoteApp.currentAppVersion?.build,
				than: Bundle.main.version,
				installedBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
			),
			let downloadURL = remoteApp.currentDownloadUrl,
			let provenance = SourceAppProvenance(sourceURL: Self.sourceURL, repository: repository, app: remoteApp)
		else {
			_offer = nil
			availableVersion = nil
			state = .upToDate
			return
		}

		_offer = Offer(
			downloadURL: downloadURL,
			provenance: provenance,
			bundleIdentifier: remoteApp.id ?? Self.sourceBundleIdentifier
		)
		availableVersion = remoteApp.currentVersionLabel ?? remoteVersion
		state = .available
	}

	/// Updates when there is a newer NullSign, otherwise looks again.
	func primaryAction() async {
		if _offer != nil {
			await update()
		} else {
			await check()
		}
	}

	func update() async {
		guard !isBusy, let offer = _offer else { return }
		guard let certificate = NullSignIdentity.activeCertificate(in: Storage.shared.getAllCertificates()) else {
			state = .failed(.localized("Add a certificate first. NullSign signs its update with the certificate shown in your Library."))
			return
		}

		do {
			state = .downloading
			let package = try await Self._download(offer.downloadURL)
			defer { try? FileManager.default.removeItem(at: package) }

			let importStarted = Date()
			try await Self._import(package, provenance: offer.provenance)
			guard let imported: Imported = Self._newest(identifier: offer.bundleIdentifier, since: importStarted) else {
				throw SelfUpdateError.notImported
			}

			state = .signing
			let signStarted = Date()
			try await Self._sign(imported, with: certificate)
			let signedIdentifier = Bundle.main.bundleIdentifier ?? offer.bundleIdentifier
			guard let signed: Signed = Self._newest(identifier: signedIdentifier, since: signStarted) else {
				throw SelfUpdateError.notSigned
			}
			// The signed copy is what installs; the download stays only where the
			// signing settings keep originals.
			if OptionsManager.shared.options.post_deleteAppAfterSigned {
				Storage.shared.deleteApp(for: imported)
			}

			state = .installing
			installingApp = AnyApp(base: signed)
		} catch {
			state = .failed(error.localizedDescription)
		}
	}

	/// The installer sheet closed without NullSign being replaced, so the
	/// update can be started again.
	func installerDismissed() {
		installingApp = nil
		if state == .installing {
			state = _offer == nil ? .idle : .available
		}
	}

	// MARK: Steps

	private static func _fetchRepository() async -> ASRepository? {
		await withCheckedContinuation { continuation in
			NBFetchService().fetch(from: sourceURL) { (result: Result<ASRepository, Error>) in
				switch result {
				case .success(let repository): continuation.resume(returning: repository)
				case .failure: continuation.resume(returning: nil)
				}
			}
		}
	}

	private static func _download(_ url: URL) async throws -> URL {
		let (temporary, response) = try await URLSession.shared.download(from: url)
		if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
			try? FileManager.default.removeItem(at: temporary)
			throw URLError(.badServerResponse)
		}
		let package = FileManager.default.temporaryDirectory
			.appendingPathComponent("NullSignUpdate-\(UUID().uuidString).ipa")
		try FileManager.default.moveItem(at: temporary, to: package)
		return package
	}

	private static func _import(_ package: URL, provenance: SourceAppProvenance) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			FR.handlePackageFile(package, sourceProvenance: provenance) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	private static func _sign(_ app: AppInfoPresentable, with certificate: CertificatePair) async throws {
		var options = OptionsManager.shared.options
		// Replace this NullSign in place: its own identifier, name and version,
		// nothing injected or removed, signed with the certificate.
		options.appIdentifier = Bundle.main.bundleIdentifier
		options.appName = nil
		options.appVersion = nil
		options.signingOption = .default
		options.injectionFiles = []
		options.disInjectionFiles = []
		options.removeFiles = []
		options.post_installAppAfterSigned = false
		options.post_deleteAppAfterSigned = false

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			FR.signPackageFile(app, using: options, icon: nil, certificate: certificate) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	/// The library row a step just added: the newest with the identifier,
	/// made since the step began.
	private static func _newest<T: NSManagedObject>(identifier: String, since start: Date) -> T? {
		let request = NSFetchRequest<T>(entityName: String(describing: T.self))
		request.predicate = NSPredicate(format: "identifier == %@ AND date >= %@", identifier, start as NSDate)
		request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
		request.fetchLimit = 1
		return try? Storage.shared.context.fetch(request).first
	}

	private enum SelfUpdateError: LocalizedError {
		case notImported
		case notSigned

		var errorDescription: String? {
			switch self {
			case .notImported: return .localized("The update downloaded but couldn't be added to your Library.")
			case .notSigned: return .localized("The update was signed but couldn't be found in your Library.")
			}
		}
	}
}
