//
//  SelfUpdateManager.swift
//  RyukSign
//
//  Created by Ryuk
//

import Foundation
import CoreData
import UIKit
import AltSourceKit
import NimbleJSON
import OSLog

/// One NullSign release as NullSign's app source lists it.
struct SelfUpdateRelease: Identifiable, Equatable {
	let version: String
	/// CFBundleVersion. Test builds share a version, so the build tells them apart.
	let build: String?
	let notes: String
	let publishedAt: Date?
	let downloadURL: URL?
	let size: UInt?

	var id: String { label }

	/// "2.0.0 (55)", or the version alone when the source gives no build.
	var label: String {
		guard let build, !build.isEmpty, build != version else { return version }
		return "\(version) (\(build))"
	}

	var title: String { "NullSign \(label)" }

	/// How this release sits against the running NullSign: descending means
	/// it's newer.
	var orderAgainstInstalled: ComparisonResult {
		let installed = Bundle.main.version
		let installedBuild = SelfUpdateManager.installedBuild
		if AppUpdateChecker.isNewerRelease(version, build: build, than: installed, installedBuild: installedBuild) {
			return .orderedDescending
		}
		if AppUpdateChecker.isNewerRelease(installed, build: installedBuild, than: version, installedBuild: build) {
			return .orderedAscending
		}
		return .orderedSame
	}

	var isInstalled: Bool { orderAgainstInstalled == .orderedSame }
}

enum SelfUpdatePhase: Equatable {
	case idle
	case downloading(Double)
	case importing
	case signing
	/// Signed and handed to the install queue, which takes it from here.
	case done
	case failed(String)
}

/// NullSign updating itself. It reads NullSign's releases from the app source
/// testers install it from, and to update, downloads the release, signs it on
/// this device with the chosen certificate and hands it to the installer,
/// which uses the installation method set in Settings. iOS asks before
/// installing, then closes NullSign while the new version replaces it.
final class SelfUpdateManager: NSObject, ObservableObject {
	static let shared = SelfUpdateManager()

	/// NullSign's app source, which lists every release.
	static let sourceURL = URL(string: "https://raw.githubusercontent.com/nulldev85/AppSource/main/apps.json")!
	/// NullSign's identifier in that source, whatever this copy was signed as.
	static let sourceBundleIdentifier = "com.elmat.NullSign"

	static var installedBuild: String? {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
	}

	/// The running NullSign, "2.0.0 (55)".
	static var installedLabel: String {
		let version = Bundle.main.version
		guard let build = installedBuild, !build.isEmpty, build != version else { return version }
		return "\(version) (\(build))"
	}

	@Published private(set) var releases: [SelfUpdateRelease] = []
	@Published private(set) var latest: SelfUpdateRelease?
	@Published private(set) var available: SelfUpdateRelease?
	@Published private(set) var isChecking = false
	@Published private(set) var lastError: String?
	@Published var phase: SelfUpdatePhase = .idle
	@Published var presentUpdatePrompt = false

	private enum Keys {
		static let autoCheck = "Feather.selfUpdateAutoCheck"
		static let ignored = "Feather.selfUpdateIgnored"
		static let certIndex = "Feather.selfUpdateCertIndex"
		static let lastCheck = "Feather.selfUpdateLastCheck"
	}

	private var _downloadContinuation: CheckedContinuation<URL, Error>?
	private var _progressHandler: ((Double) -> Void)?
	private var _flow: Task<Void, Never>?

	private override init() {
		super.init()
		UserDefaults.standard.register(defaults: [Keys.autoCheck: true, Keys.certIndex: -1])
	}

	// MARK: - Settings

	var isAutoCheckEnabled: Bool {
		get { UserDefaults.standard.bool(forKey: Keys.autoCheck) }
		set { UserDefaults.standard.set(newValue, forKey: Keys.autoCheck) }
	}

	var certIndex: Int {
		get { UserDefaults.standard.integer(forKey: Keys.certIndex) }
		set { UserDefaults.standard.set(newValue, forKey: Keys.certIndex); objectWillChange.send() }
	}

	/// Releases the update prompt skips, by label ("2.0.0 (55)").
	var ignoredVersions: Set<String> {
		Set(UserDefaults.standard.stringArray(forKey: Keys.ignored) ?? [])
	}

	/// The certificate updates are signed with: the one chosen in Updates, else
	/// the signer's selected certificate.
	func resolvedCertificate() -> CertificatePair? {
		let idx = certIndex >= 0 ? certIndex : UserDefaults.standard.integer(forKey: "feather.selectedCert")
		return Storage.shared.getCertificate(for: idx)
	}

	func ignore(_ label: String) {
		var set = ignoredVersions
		set.insert(label)
		UserDefaults.standard.set(Array(set), forKey: Keys.ignored)
		_recomputeAvailable()
	}

	func unignore(_ label: String) {
		var set = ignoredVersions
		set.remove(label)
		UserDefaults.standard.set(Array(set), forKey: Keys.ignored)
		_recomputeAvailable()
	}

	/// Orders release labels newest first, builds included.
	static func isNewerLabel(_ lhs: String, than rhs: String) -> Bool {
		lhs.compare(rhs, options: [.numeric, .caseInsensitive]) == .orderedDescending
	}

	// MARK: - Check

	@MainActor
	func checkOnLaunch() async {
		guard isAutoCheckEnabled else { return }
		await check()
		if available != nil { presentUpdatePrompt = true }
	}

	/// Looks again when NullSign comes back, at most every six hours.
	@MainActor
	func checkIfNeeded() async {
		guard isAutoCheckEnabled else { return }
		if let last = UserDefaults.standard.object(forKey: Keys.lastCheck) as? Date,
		   Date().timeIntervalSince(last) < 6 * 60 * 60 {
			return
		}
		await check()
	}

	@MainActor
	func check() async {
		guard !isChecking else { return }
		isChecking = true
		defer { isChecking = false }

		do {
			releases = try await Self._fetchReleases()
			latest = releases.first
			lastError = nil
			UserDefaults.standard.set(Date(), forKey: Keys.lastCheck)
			_recomputeAvailable()
		} catch {
			lastError = error.localizedDescription
			Logger.misc.error("Self-update check failed: \(error.localizedDescription)")
		}
	}

	private func _recomputeAvailable() {
		guard let candidate = latest, candidate.orderAgainstInstalled == .orderedDescending else {
			available = nil
			return
		}
		available = ignoredVersions.contains(candidate.label) ? nil : candidate
	}

	/// Every NullSign release in the app source, newest first.
	private static func _fetchReleases() async throws -> [SelfUpdateRelease] {
		let repository: ASRepository = try await withCheckedThrowingContinuation { continuation in
			NBFetchService().fetch(from: sourceURL) { (result: Result<ASRepository, Error>) in
				continuation.resume(with: result)
			}
		}

		let running = Bundle.main.bundleIdentifier ?? sourceBundleIdentifier
		guard let app = repository.apps.first(where: { $0.id == running })
			?? repository.apps.first(where: { $0.id == sourceBundleIdentifier })
		else {
			throw NSError(domain: "SelfUpdate", code: -1, userInfo: [
				NSLocalizedDescriptionKey: String.localized("NullSign isn't listed in its app source.")
			])
		}

		let versions: [SelfUpdateRelease] = (app.versions ?? []).map {
			SelfUpdateRelease(
				version: $0.version,
				build: $0.build,
				notes: $0.localizedDescription ?? "",
				publishedAt: $0.date?.date,
				downloadURL: $0.downloadURL,
				size: $0.size
			)
		}
		let list = versions.isEmpty
			? [SelfUpdateRelease(
				version: app.currentVersion ?? "",
				build: nil,
				notes: "",
				publishedAt: app.currentDate?.date,
				downloadURL: app.currentDownloadUrl,
				size: nil
			)]
			: versions

		return list
			.filter { !$0.version.isEmpty }
			.sorted {
				AppUpdateChecker.isNewerRelease($0.version, build: $0.build, than: $1.version, installedBuild: $1.build)
			}
	}

	// MARK: - Install

	/// One cancellable task per run; closing the sheet cancels it.
	@MainActor
	func beginUpdate(to release: SelfUpdateRelease) {
		_flow?.cancel()
		_flow = Task { await performUpdate(to: release) }
	}

	@MainActor
	func endFlow() {
		_flow?.cancel()
		_flow = nil
		if case .failed = phase {} else {
			phase = .idle
		}
	}

	@MainActor
	func performUpdate(to release: SelfUpdateRelease) async {
		guard let certificate = resolvedCertificate() else {
			phase = .failed(.localized("Add a certificate first, or choose one in Settings > Updates."))
			return
		}
		guard let url = release.downloadURL else {
			phase = .failed(.localized("This release has no download."))
			return
		}

		FileLogger.log("Update \(release.label) cert=\(certificate.nickname ?? Storage.shared.getProvisionFileDecoded(for: certificate)?.Name ?? "?")", category: "update")

		let keepAlive = BackgroundTaskManager(
			taskName: "SelfUpdate",
			expirationTitle: .localized("Update continuing"),
			expirationBody: .localized("The update will continue when you reopen the app")
		)
		keepAlive.start()
		defer { keepAlive.stop() }

		var imported: AppInfoPresentable?
		do {
			phase = .downloading(0)
			let ipa = try await _download(from: url)
			defer { try? FileManager.default.removeItem(at: ipa) }
			try Task.checkCancellation()

			phase = .importing
			let app = try await withCheckedThrowingContinuation { (c: CheckedContinuation<AppInfoPresentable, Error>) in
				FR.handlePackageFile(ipa) { c.resume(with: $0) }
			}
			imported = app
			try Task.checkCancellation()

			phase = .signing
			let signed = try await withCheckedThrowingContinuation { (c: CheckedContinuation<Signed, Error>) in
				FR.signPackageFile(app, using: Self._updateOptions(), icon: nil, certificate: certificate) { result in
					c.resume(with: result)
				}
			}

			// The signed copy is what installs; the download isn't kept.
			Storage.shared.deleteApp(for: app)
			imported = nil

			phase = .done
			InstallQueue.shared.enqueue(signed)
		} catch is CancellationError {
			phase = .idle
		} catch let error as URLError where error.code == .cancelled {
			phase = .idle
		} catch {
			Logger.misc.error("Self-update failed: \(error.localizedDescription)")
			FileLogger.error("Failed: \(release.label) — \(error.localizedDescription)", category: "update")
			phase = .failed(error.localizedDescription)
		}

		if let imported {
			Storage.shared.deleteApp(for: imported)
		}
	}

	/// Replace this NullSign in place: its own identifier, the release's name
	/// and version, nothing injected or removed.
	private static func _updateOptions() -> Options {
		var options = OptionsManager.shared.options
		options.appIdentifier = Bundle.main.bundleIdentifier
		options.appName = nil
		options.appVersion = nil
		options.appEntitlementsFile = nil
		options.signingOption = .default
		options.injectionFiles = []
		options.disInjectionFiles = []
		options.removeFiles = []
		options.tweakInjections = nil
		options.infoPlistOverrides = nil
		options.infoPlistRemovals = nil
		options.experiment_replaceSubstrateWithEllekit = false
		options.post_installAppAfterSigned = false
		options.post_deleteAppAfterSigned = false
		return options
	}

	// MARK: - Download

	private func _download(from url: URL) async throws -> URL {
		let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
		_progressHandler = { [weak self] progress in
			Task { @MainActor in self?.phase = .downloading(progress) }
		}
		return try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				_downloadContinuation = continuation
				session.downloadTask(with: url).resume()
			}
		} onCancel: {
			session.invalidateAndCancel()
		}
	}
}

extension SelfUpdateManager: URLSessionDownloadDelegate {
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
					didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		guard totalBytesExpectedToWrite > 0 else { return }
		_progressHandler?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		let dest = FileManager.default.temporaryDirectory
			.appendingPathComponent("SelfUpdate-\(downloadTask.taskIdentifier).ipa")
		try? FileManager.default.removeItem(at: dest)
		do {
			try FileManager.default.moveItem(at: location, to: dest)
			_downloadContinuation?.resume(returning: dest)
		} catch {
			_downloadContinuation?.resume(throwing: error)
		}
		_downloadContinuation = nil
		session.finishTasksAndInvalidate()
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let error else { return }
		_downloadContinuation?.resume(throwing: error)
		_downloadContinuation = nil
		session.invalidateAndCancel()
	}
}
