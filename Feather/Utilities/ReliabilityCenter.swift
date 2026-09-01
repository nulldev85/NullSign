import Foundation
import OSLog

enum SigningStage: String {
	case preparing = "Preparing"
	case preflight = "Checking app"
	case modifying = "Applying changes"
	case signing = "Signing"
	case verifying = "Verifying"
	case packaging = "Packaging"
	case complete = "Complete"
}

final class ReliabilityCenter {
	static let shared = ReliabilityCenter()

	private let queue = DispatchQueue(label: "com.nulldev.NullSign.diagnostics")
	private let fileManager = FileManager.default
	private let maximumLogSize: UInt64 = 512 * 1024

	var logURL: URL {
		fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("NullSign-Diagnostics.log")
	}

	func record(_ stage: SigningStage, _ message: String) {
		let safeMessage = message
			.replacingOccurrences(of: NSHomeDirectory(), with: "<app-container>")
		let line = "\(ISO8601DateFormatter().string(from: Date())) [\(stage.rawValue)] \(safeMessage)\n"
		Logger.signing.info("[\(stage.rawValue)] \(safeMessage)")

		queue.async {
			if let size = try? self.logURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
			   size > self.maximumLogSize {
				try? Data().write(to: self.logURL, options: .atomic)
			}
			guard let data = line.data(using: .utf8) else { return }
			if self.fileManager.fileExists(atPath: self.logURL.path),
			   let handle = try? FileHandle(forWritingTo: self.logURL) {
				defer { try? handle.close() }
				try? handle.seekToEnd()
				try? handle.write(contentsOf: data)
			} else {
				try? data.write(to: self.logURL, options: .atomic)
			}
		}
	}

	func clearLog() {
		queue.async { try? self.fileManager.removeItem(at: self.logURL) }
	}
}

enum AppValidationError: LocalizedError {
	case missingInfoPlist
	case missingBundleIdentifier
	case missingExecutable(String)
	case certificateExpired
	case missingCertificateFile
	case missingProvisioningProfile
	case malformedProvisioningProfile
	case incompatibleProvisioningProfile(required: String)
	case insufficientStorage(required: Int64, available: Int64)
	case unsupportedInjectionFile(String)
	case missingCodeSignature(String)
	case missingEmbeddedProfile
	case malformedIPA(String)

	var errorDescription: String? {
		switch self {
		case .missingInfoPlist: "The app does not contain a readable Info.plist."
		case .missingBundleIdentifier: "The app is missing its bundle identifier."
		case .missingExecutable(let name): "The app executable \"\(name)\" is missing."
		case .certificateExpired: "The selected signing certificate has expired."
		case .missingCertificateFile: "The selected .p12 file is no longer available. Import the certificate again."
		case .missingProvisioningProfile: "The selected provisioning profile is no longer available."
		case .malformedProvisioningProfile: "The selected provisioning profile could not be decoded."
		case .incompatibleProvisioningProfile(let required): "This app requires a \(required) provisioning profile. Choose a certificate imported with the matching profile."
		case .insufficientStorage(let required, let available): "Signing needs about \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), but only \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) is available."
		case .unsupportedInjectionFile(let name): "\(name) is not a supported .deb or .dylib file."
		case .missingCodeSignature(let name): "Signature verification failed for \(name)."
		case .missingEmbeddedProfile: "The signed app does not contain an embedded provisioning profile."
		case .malformedIPA(let reason): "The finished IPA is invalid: \(reason)"
		}
	}
}

enum AppValidator {
	static func preflight(appURL: URL, certificate: CertificatePair?, options: Options) throws {
		let fileManager = FileManager.default
		let infoURL = appURL.appendingPathComponent("Info.plist")
		guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
			throw AppValidationError.missingInfoPlist
		}
		guard let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty else {
			throw AppValidationError.missingBundleIdentifier
		}
		let executable = (info["CFBundleExecutable"] as? String) ?? appURL.deletingPathExtension().lastPathComponent
		guard fileManager.fileExists(atPath: appURL.appendingPathComponent(executable).path) else {
			throw AppValidationError.missingExecutable(executable)
		}

		if options.signingOption == .default {
			guard let certificate else { throw SigningFileHandlerError.missingCertifcate }
			if let expiration = certificate.expiration, expiration <= Date() {
				throw AppValidationError.certificateExpired
			}
			guard let p12 = Storage.shared.getFile(.certificate, from: certificate), fileManager.fileExists(atPath: p12.path) else {
				throw AppValidationError.missingCertificateFile
			}
			guard let provision = Storage.shared.getFile(.provision, from: certificate), fileManager.fileExists(atPath: provision.path) else {
				throw AppValidationError.missingProvisioningProfile
			}
			guard let profile = CertificateReader(provision).decoded else {
				throw AppValidationError.malformedProvisioningProfile
			}
			let supportedPlatforms = profile.Platform.map { $0.lowercased() }
			let appPlatforms = info["CFBundleSupportedPlatforms"] as? [String] ?? []
			let deviceFamilies = info["UIDeviceFamily"] as? [Int] ?? []
			let hasTVPlatform = appPlatforms.contains { $0.localizedCaseInsensitiveContains("AppleTV") }
			let hasPhonePlatform = appPlatforms.contains { $0.localizedCaseInsensitiveContains("iPhone") }
			let isTVApp = hasTVPlatform || (!hasPhonePlatform && appPlatforms.isEmpty && deviceFamilies.contains(3))
			if isTVApp && !supportedPlatforms.contains(where: { $0.contains("tvos") || $0.contains("appletv") }) {
				throw AppValidationError.incompatibleProvisioningProfile(required: "tvOS")
			}
		}

		for file in options.injectionFiles where !["deb", "dylib"].contains(file.pathExtension.lowercased()) {
			throw AppValidationError.unsupportedInjectionFile(file.lastPathComponent)
		}

		let appSize = directorySize(appURL)
		let available = (try? appURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? Int64.max
		let required = max(appSize * 2, 100 * 1024 * 1024)
		guard available >= required else {
			throw AppValidationError.insufficientStorage(required: required, available: available)
		}
	}

	static func verifySignedApp(at appURL: URL, requiresProfile: Bool) throws {
		try preflightBundle(at: appURL)
		if requiresProfile && !FileManager.default.fileExists(atPath: appURL.appendingPathComponent("embedded.mobileprovision").path) {
			throw AppValidationError.missingEmbeddedProfile
		}

		let nested = nestedBundles(in: appURL)
		for bundleURL in [appURL] + nested {
			try preflightBundle(at: bundleURL)
			let resources = bundleURL.appendingPathComponent("_CodeSignature/CodeResources")
			guard FileManager.default.fileExists(atPath: resources.path) else {
				throw AppValidationError.missingCodeSignature(bundleURL.lastPathComponent)
			}
		}
	}

	static func verifyPayload(at payloadURL: URL) throws {
		let entries = (try? FileManager.default.contentsOfDirectory(at: payloadURL, includingPropertiesForKeys: nil)) ?? []
		let apps = entries.filter { $0.pathExtension.lowercased() == "app" }
		guard apps.count == 1 else {
			throw AppValidationError.malformedIPA("Payload must contain exactly one top-level .app bundle.")
		}
		try preflightBundle(at: apps[0])
	}

	private static func preflightBundle(at url: URL) throws {
		let infoURL = url.appendingPathComponent("Info.plist")
		guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else { throw AppValidationError.missingInfoPlist }
		let executable = (info["CFBundleExecutable"] as? String) ?? url.deletingPathExtension().lastPathComponent
		guard FileManager.default.fileExists(atPath: url.appendingPathComponent(executable).path) else {
			throw AppValidationError.missingExecutable(executable)
		}
	}

	private static func nestedBundles(in appURL: URL) -> [URL] {
		guard let enumerator = FileManager.default.enumerator(at: appURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
		var bundles: [URL] = []
		for case let url as URL in enumerator where ["appex", "app"].contains(url.pathExtension.lowercased()) {
			bundles.append(url)
			enumerator.skipDescendants()
		}
		return bundles
	}

	private static func directorySize(_ url: URL) -> Int64 {
		guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
		return enumerator.reduce(into: Int64(0)) { total, item in
			guard let fileURL = item as? URL else { return }
			total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
		}
	}
}
