//
//  LibraryUpdateManager.swift
//  Feather
//

import Foundation

/// Updates an app in the library in one tap. A signed app is downloaded,
/// signed with the certificate and identifier it was installed with, and
/// handed to the installer so the new version replaces it. An app that was
/// never signed gets its new version added to the library, ready to sign.
@MainActor
final class LibraryUpdateManager: ObservableObject {
	static let shared = LibraryUpdateManager()

	enum Phase: Equatable {
		case downloading
		case signing
	}

	struct Failure: Identifiable {
		let id = UUID()
		let appName: String
		let reason: String
	}

	/// The step each updating app is at, by the library app's uuid.
	@Published private(set) var phases: [String: Phase] = [:]
	/// The signed update, for the installer sheet.
	@Published var installingApp: AnyApp?
	@Published var failure: Failure?

	private init() {}

	func update(_ app: AppInfoPresentable, to update: AppUpdate) async {
		guard let uuid = app.uuid, phases[uuid] == nil else { return }

		// Read before the first suspension: the app can be deleted meanwhile.
		let isSigned = app.isSigned
		let installedIdentifier = app.identifier
		let certificate = isSigned ? _certificate(for: app) : nil

		if isSigned && certificate == nil {
			failure = Failure(appName: update.appName, reason: AppUpdateError.noCertificate.localizedDescription)
			return
		}

		phases[uuid] = .downloading
		defer { phases[uuid] = nil }

		do {
			let package = try await AppUpdatePipeline.download(update.downloadURL)
			defer { try? FileManager.default.removeItem(at: package) }

			let importStarted = Date()
			try await AppUpdatePipeline.importPackage(package, provenance: update.sourceProvenance)

			// Never signed: the new version waits in the library to be signed.
			guard isSigned, let certificate, let installedIdentifier else { return }

			guard let imported: Imported = AppUpdatePipeline.newest(identifier: update.bundleIdentifier, since: importStarted)
				?? AppUpdatePipeline.newest(identifier: nil, since: importStarted)
			else {
				throw AppUpdateError.notImported
			}

			phases[uuid] = .signing
			let signStarted = Date()
			try await AppUpdatePipeline.sign(imported, using: _options(identifier: installedIdentifier), certificate: certificate)
			guard let signed: Signed = AppUpdatePipeline.newest(identifier: installedIdentifier, since: signStarted) else {
				throw AppUpdateError.notSigned
			}
			// The signed copy is what installs; the download stays only where the
			// signing settings keep originals.
			if OptionsManager.shared.options.post_deleteAppAfterSigned {
				Storage.shared.deleteApp(for: imported)
			}

			installingApp = AnyApp(base: signed)
		} catch {
			failure = Failure(appName: update.appName, reason: error.localizedDescription)
		}
	}

	/// The certificate the installed copy was signed with, so the update
	/// replaces it, or the Library's certificate once that one has lapsed.
	private func _certificate(for app: AppInfoPresentable) -> CertificatePair? {
		if let original = Storage.shared.getCertificate(from: app),
		   !original.revoked,
		   (original.expiration ?? .distantFuture) > Date() {
			return original
		}
		return NullSignIdentity.activeCertificate(in: Storage.shared.getAllCertificates())
	}

	/// The user's signing settings, keeping the identifier the app is
	/// installed under so iOS replaces it rather than adding a second copy.
	private func _options(identifier: String) -> Options {
		var options = OptionsManager.shared.options
		options.appIdentifier = identifier
		options.appVersion = nil
		options.signingOption = .default
		options.post_installAppAfterSigned = false
		options.post_deleteAppAfterSigned = false
		return options
	}
}
