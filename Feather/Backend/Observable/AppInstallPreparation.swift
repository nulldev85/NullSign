import Foundation

/// Both file imports and repository downloads arrive in the same library.
/// Install signs an imported app once, then hands that exact signed copy on.
enum AppInstallPreparation {
	@MainActor
	static func prepare(
		_ app: AppInfoPresentable,
		onStageChange: @escaping @MainActor (AppSigningStage) -> Void
	) async throws -> AppInfoPresentable {
		try Task.checkCancellation()
		guard !app.isSigned else { return app }

		var options = OptionsManager.shared.options
		guard options.signingOption == .default else {
			throw PreparationError.normalSigningRequired
		}
		let certificates = Storage.shared.getAllCertificates()
		guard let index = Storage.shared.preferredCertificateIndex(for: app.platform),
		      certificates.indices.contains(index) else {
			throw PreparationError.noCertificate
		}
		let certificate = certificates[index]
		Storage.shared.rememberCertificate(certificate, for: app.platform)

		// Match the defaults shown in the customization screen.
		if let identifier = app.identifier, let replacement = options.identifiers[identifier] {
			options.appIdentifier = replacement
		}
		if let name = app.name, let replacement = options.displayNames[name] {
			options.appName = replacement
		}
		let deleteOriginal = options.post_deleteAppAfterSigned
		// This flow owns the handoff. The legacy post-sign notification must
		// never select a different app or present a second installer sheet.
		options.post_installAppAfterSigned = false
		options.post_deleteAppAfterSigned = false

		let signed = try await FR.signedPackageFile(
			app, using: options, icon: nil, certificate: certificate,
			onStageChange: onStageChange
		)
		try Task.checkCancellation()
		if deleteOriginal { Storage.shared.deleteApp(for: app) }
		return signed
	}

	enum PreparationError: LocalizedError {
		case noCertificate
		case normalSigningRequired

		var errorDescription: String? {
			switch self {
			case .noCertificate:
				return .localized("Add a compatible certificate in Settings before installing this app.")
			case .normalSigningRequired:
				return .localized("Choose normal signing in Settings to install an app. Modify Only is available from App Actions → Sign.")
			}
		}
	}
}
