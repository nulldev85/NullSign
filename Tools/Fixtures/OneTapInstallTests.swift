import Foundation

// Controlled storage/signing boundary. The preparation, progress mapping and
// nested installer URL construction below are the production implementations.
enum AppPlatform { case iOS, tvOS }
protocol AppInfoPresentable {
	var identifier: String? { get }
	var name: String? { get }
	var isSigned: Bool { get }
	var platform: AppPlatform { get }
}
class TestApp: AppInfoPresentable {
	var identifier: String? = "test.original"
	var name: String? = "Original"
	var isSigned: Bool = false
	var platform: AppPlatform = .iOS
}
final class Signed: TestApp {
	override init() { super.init(); isSigned = true }
}
final class CertificatePair { var ppQCheck = true }
struct Options {
	enum SigningOption { case `default`, onlyModify }
	var signingOption = SigningOption.default
	var ppqProtection = false
	var ppqString = "protection"
	var identifiers: [String: String] = [:]
	var displayNames: [String: String] = [:]
	var appIdentifier: String?
	var appName: String?
	var post_installAppAfterSigned = false
	var post_deleteAppAfterSigned = false
}
@MainActor final class OptionsManager {
	static let shared = OptionsManager()
	var options = Options()
}
@MainActor final class Storage {
	static let shared = Storage()
	var certificates = [CertificatePair()]
	var selectedIndex: Int? = 0
	var requestedPlatform: AppPlatform?
	var remembered: CertificatePair?
	var deleted: [AppInfoPresentable] = []
	func getAllCertificates() -> [CertificatePair] { certificates }
	func preferredCertificateIndex(for platform: AppPlatform) -> Int? {
		requestedPlatform = platform
		return selectedIndex
	}
	func rememberCertificate(_ certificate: CertificatePair, for platform: AppPlatform) { remembered = certificate }
	func deleteApp(for app: AppInfoPresentable) { deleted.append(app) }
}
enum TestError: Error { case signingFailed }
@MainActor enum FR {
	static var result = Signed()
	static var calls = 0
	static var capturedOptions: Options?
	static var capturedCertificate: CertificatePair?
	static var fail = false
	static var cancel = false
	static func signedPackageFile(
		_ app: AppInfoPresentable, using options: Options, icon: String?,
		certificate: CertificatePair?, onStageChange: @escaping @MainActor (AppSigningStage) -> Void
	) async throws -> Signed {
		calls += 1
		capturedOptions = options
		capturedCertificate = certificate
		for stage in [AppSigningStage.preparing, .modifying, .signing, .verifying] { onStageChange(stage) }
		if fail { throw TestError.signingFailed }
		if cancel { withUnsafeCurrentTask { $0?.cancel() } }
		return result
	}
}
extension String { static func localized(_ string: String) -> String { string } }

@main struct OneTapInstallTests {
	@MainActor static func reset() {
		OptionsManager.shared.options = Options()
		Storage.shared.certificates = [CertificatePair()]
		Storage.shared.selectedIndex = 0
		Storage.shared.requestedPlatform = nil
		Storage.shared.remembered = nil
		Storage.shared.deleted = []
		FR.result = Signed()
		FR.calls = 0
		FR.capturedOptions = nil
		FR.capturedCertificate = nil
		FR.fail = false
		FR.cancel = false
	}

	@MainActor static func main() async throws {
		reset()
		let imported = TestApp()
		var stages: [AppSigningStage] = []
		let prepared = try await AppInstallPreparation.prepare(imported) { stages.append($0) }
		precondition((prepared as? Signed) === FR.result, "Install must receive this operation's exact result")
		precondition(FR.calls == 1 && Storage.shared.remembered === FR.capturedCertificate)
		precondition(stages == [.preparing, .modifying, .signing, .verifying])
		precondition(Storage.shared.deleted.isEmpty, "Keep imported files by default")
		print("PASS imported app signs once with saved certificate and real milestones")

		reset()
		let existing = Signed()
		Storage.shared.certificates = []
		Storage.shared.selectedIndex = nil
		let existingResult = try await AppInstallPreparation.prepare(existing) { _ in preconditionFailure() }
		precondition((existingResult as? Signed) === existing && FR.calls == 0)
		print("PASS signed apps bypass signing even without a saved certificate")

		for invalidIndex in [nil, -1, 5] as [Int?] {
			reset()
			Storage.shared.selectedIndex = invalidIndex
			do {
				_ = try await AppInstallPreparation.prepare(imported) { _ in }
				preconditionFailure("Missing certificate must stop before signing")
			} catch AppInstallPreparation.PreparationError.noCertificate {}
			precondition(FR.calls == 0 && Storage.shared.deleted.isEmpty)
		}
		print("PASS absent and stale certificate selections fail without deleting imports")

		reset()
		OptionsManager.shared.options.signingOption = .onlyModify
		do {
			_ = try await AppInstallPreparation.prepare(imported) { _ in }
			preconditionFailure("Modify Only is not an installable signature")
		} catch AppInstallPreparation.PreparationError.normalSigningRequired {}
		precondition(FR.calls == 0)
		print("PASS Modify Only stops before installation")

		reset()
		OptionsManager.shared.options.ppqProtection = true
		_ = try await AppInstallPreparation.prepare(imported) { _ in }
		precondition(FR.capturedOptions?.appIdentifier == "test.original.protection")
		OptionsManager.shared.options.identifiers = ["test.original": "test.replacement"]
		OptionsManager.shared.options.displayNames = ["Original": "Renamed"]
		_ = try await AppInstallPreparation.prepare(imported) { _ in }
		precondition(FR.capturedOptions?.appIdentifier == "test.replacement")
		precondition(FR.capturedOptions?.appName == "Renamed")
		print("PASS PPQ and explicit name/identifier defaults match customization")

		reset()
		OptionsManager.shared.options.post_installAppAfterSigned = true
		OptionsManager.shared.options.post_deleteAppAfterSigned = true
		_ = try await AppInstallPreparation.prepare(imported) { _ in }
		precondition(FR.capturedOptions?.post_installAppAfterSigned == false)
		precondition(FR.capturedOptions?.post_deleteAppAfterSigned == false)
		precondition(Storage.shared.deleted.count == 1)
		precondition(OptionsManager.shared.options.post_installAppAfterSigned, "Do not change saved preferences")
		print("PASS one owner for installation and delete-after-sign preference preserved")

		reset()
		OptionsManager.shared.options.post_deleteAppAfterSigned = true
		FR.fail = true
		do {
			_ = try await AppInstallPreparation.prepare(imported) { _ in }
			preconditionFailure("Signing failure must propagate")
		} catch TestError.signingFailed {}
		precondition(Storage.shared.deleted.isEmpty)
		print("PASS failed signing preserves original and does not produce an install target")

		reset()
		OptionsManager.shared.options.post_deleteAppAfterSigned = true
		FR.cancel = true
		let cancelled = Task { @MainActor in
			try await AppInstallPreparation.prepare(imported) { _ in }
		}
		do { _ = try await cancelled.value; preconditionFailure("Dismissal must cancel handoff") }
		catch is CancellationError {}
		precondition(Storage.shared.deleted.isEmpty)
		print("PASS dismissal after native signing stops handoff and preserves original")

		reset()
		let tvApp = TestApp()
		tvApp.platform = .tvOS
		_ = try await AppInstallPreparation.prepare(tvApp) { _ in }
		precondition(Storage.shared.requestedPlatform == .tvOS)
		print("PASS Apple TV imports use the compatible platform certificate")

		let payload = URL(string: "http://192.168.1.4:5555/package.ipa?token=a%2Bb%26c")!
		let manifest = InstallHandoff.externalManifestURL(
			identifier: "test.app", name: "A+B & 東京 \"App\"", version: "1.0+2", payload: payload
		)
		let installURL = InstallHandoff.installURL(manifest: manifest)
		let outer = URLComponents(url: installURL, resolvingAgainstBaseURL: false)!
		precondition(installURL.scheme == "itms-services")
		let outerItems = Dictionary(uniqueKeysWithValues: outer.queryItems!.map { ($0.name, $0.value!) })
		precondition(outerItems["action"] == "download-manifest" && outerItems["url"] == manifest.absoluteString)
		let inner = URLComponents(string: outerItems["url"]!)!
		let innerItems = Dictionary(uniqueKeysWithValues: inner.queryItems!.map { ($0.name, $0.value!) })
		precondition(innerItems["name"] == "A+B & 東京 \"App\"")
		precondition(innerItems["version"] == "1.0+2" && innerItems["fetchurl"] == payload.absoluteString)
		precondition(!inner.percentEncodedQuery!.contains("+"), "Form decoders must not replace literal plus signs with spaces")
		let local = URL(string: "https://local.test:5555/install.plist?x=1&y=2")!
		let localOuter = URLComponents(url: InstallHandoff.installURL(manifest: local), resolvingAgainstBaseURL: false)!
		precondition(localOuter.queryItems!.first { $0.name == "url" }?.value == local.absoluteString)
		print("PASS local and external manifest URL round trips preserve nested queries and app names")

		var previous = AppSigningStage.verifying.progress
		for installerProgress in [0.0, 0.1, 0.35, 0.38, 0.42, 0.45, 0.7, 1.0] {
			let progress = InstallHandoff.progress(afterSigning: true, installerProgress: installerProgress, succeeded: false)
			precondition(progress >= previous && progress < 1, "Progress must not reset after signing or finish on URL acceptance")
			previous = progress
		}
		precondition(InstallHandoff.progress(afterSigning: false, installerProgress: -5, succeeded: false) == 0)
		precondition(InstallHandoff.progress(afterSigning: true, installerProgress: 0.5, succeeded: true) == 1)
		print("PASS signing-to-install progress is monotonic and 100% requires completion")
	}
}
