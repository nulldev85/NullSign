//
//  AppInstaller.swift
//  NullSign
//
//  Created by Ryuk
//

import Combine
import Foundation
import SwiftUI
import IDeviceSwift

@MainActor
final class AppInstaller: ObservableObject {
	enum Outcome {
		case installed
		case cancelled
		case exported(URL?)
	}

	let app: AppInfoPresentable
	let viewModel: InstallerStatusViewModel

	@Published var fallbackPage: URL?

	private let _isSharing: Bool
	/// tvOS apps install on the paired Apple TV over Wi-Fi, whatever method
	/// iPhone apps use.
	private let _isAppleTV: Bool
	private let _installationMethod = AppInstaller.effectiveInstallationMethod()
	private let _serverMethod = UserDefaults.standard.integer(forKey: "Feather.serverMethod")
	private let _useShareSheet = UserDefaults.standard.bool(forKey: "Feather.useShareSheetForArchiving")

	private var _server: ServerInstaller?
	private var _archive: ArchiveHandler?
	private var _packageTask: Task<(package: URL, exported: URL?), Error>?
	private var _progressTask: Task<Void, Never>?
	private var _stallWatch: Task<Void, Never>?
	private var _statusObserver: AnyCancellable?
	private var _completion: ((Result<Outcome, Error>) -> Void)?
	private var _hasFinished = false
	private var _declineObserver: NSObjectProtocol?
	private var _declineCheck: DispatchWorkItem?
	private var _installedBefore: InstalledAppState?

	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.app = app
		self._isSharing = isSharing
		let isAppleTV = !isSharing && app.platform == .tvOS
		self._isAppleTV = isAppleTV
		self.viewModel = InstallerStatusViewModel(isIdevice: isAppleTV || _installationMethod == 1)

		if !isSharing, !isAppleTV, _installationMethod == 0 {
			_server = try? ServerInstaller(app: app, viewModel: viewModel)
		}
	}

	/// iPhone apps installed through the local server and iOS's install prompt.
	private var _usesServer: Bool { !_isAppleTV && _installationMethod == 0 }

	/// The installation type iPhone apps use. Installing over a pairing file
	/// can't work without this iPhone's pairing file, so until one is
	/// imported NullSign installs through the local server. An Apple TV
	/// pairing is separate and doesn't count.
	nonisolated static func effectiveInstallationMethod() -> Int {
		let method = UserDefaults.standard.integer(forKey: "Feather.installationMethod")
		if method == 1, !FileManager.default.fileExists(atPath: HeartbeatManager.pairingFile()) {
			return 0
		}
		return method
	}

	/// tvOS only accepts an app whose embedded profile is current and lists
	/// the Apple TV. Say which of those is wrong instead of tvOS's "A valid
	/// provisioning profile for this executable was not found".
	private func _verifyProfileForAppleTV() throws {
		guard let directory = Storage.shared.getAppDirectory(for: app) else { return }
		let profileURL = directory.appendingPathComponent("embedded.mobileprovision")

		guard FileManager.default.fileExists(atPath: profileURL.path) else {
			throw Self.error(.localized("This copy was signed without its provisioning profile, so Apple TV won't accept it. Sign it again, then install."))
		}
		guard let profile = CertificateReader(profileURL).decoded else { return }

		if profile.ExpirationDate < Date() {
			throw Self.error(.localized("The provisioning profile in this app has expired. Sign it again with a current certificate."))
		}
		if !profile.Platform.contains(where: { $0.lowercased().contains("tvos") || $0.lowercased().contains("appletv") }) {
			throw Self.error(.localized("This app was signed with a profile that doesn't include tvOS. Sign it again with your Apple TV certificate."))
		}
	}

	/// tvOS's "A valid provisioning profile for this executable was not found"
	/// almost always means the profile doesn't list this Apple TV.
	private func _explainAppleTVFailure(_ error: Error) -> Error {
		let message = error.localizedDescription
		guard message.contains("0xe8008015") || message.localizedCaseInsensitiveContains("valid provisioning profile") else {
			return error
		}
		let udid = AppleTVManager.shared.pairedDevice?.udid ?? ""
		var listed: Bool?
		if !udid.isEmpty,
		   let directory = Storage.shared.getAppDirectory(for: app),
		   let profile = CertificateReader(directory.appendingPathComponent("embedded.mobileprovision")).decoded,
		   profile.ProvisionsAllDevices != true,
		   let devices = profile.ProvisionedDevices {
			listed = devices.contains { $0.caseInsensitiveCompare(udid) == .orderedSame }
		}

		let explanation: String
		if listed == false {
			explanation = .localized("Apple TV refused the app because your provisioning profile doesn't include this Apple TV. Ask your certificate provider to add its UDID, %@, then sign the app again with the new profile.", arguments: udid)
		} else if !udid.isEmpty {
			explanation = .localized("Apple TV refused the provisioning profile. Make sure your certificate provider added this Apple TV's UDID, %@, to your tvOS profile, then sign the app again.", arguments: udid)
		} else {
			explanation = .localized("Apple TV refused the provisioning profile. Make sure your certificate provider added this Apple TV's UDID to your tvOS profile, then sign the app again.")
		}
		return Self.error(explanation + "\n\n" + message)
	}

	/// The Wi-Fi connection to an Apple TV doesn't always open on the first
	/// try. Until the app starts uploading, a failed attempt is retried on a
	/// fresh connection; a refusal after that (a profile problem, say) isn't.
	private func _installOnAppleTV(_ packageUrl: URL) async throws {
		let attempts = 3
		for attempt in 1...attempts {
			try await _connectAppleTV()
			if attempt == 1, let id = app.identifier {
				// tvOS waits for an open copy of the app to quit before
				// replacing it, so close it first.
				await AppleTVAppCloser.close(id)
			}
			FileLogger.log("installing \(app.identifier ?? "?") on Apple TV \(AppleTVManager.shared.pairedDevice?.name ?? "?"), attempt \(attempt)", category: "install")
			do {
				try await InstallationProxy(viewModel: viewModel).install(at: packageUrl, suspend: false)
				return
			} catch {
				let started: Bool
				switch viewModel.status {
				case .sendingPayload, .installing, .completed: started = true
				default: started = viewModel.uploadProgress > 0
				}
				guard attempt < attempts, !started, !Task.isCancelled else { throw error }
				FileLogger.error("Apple TV attempt \(attempt) failed before uploading: \(error.localizedDescription)", category: "install")
				viewModel.resetProgress()
				HeartbeatManager.shared.resetRSDTunnel()
				try await Task.sleep(nanoseconds: 1_500_000_000)
			}
		}
	}

	/// If the Apple TV sits on "Installing", the app is usually still open
	/// there (or tvOS brought it back), so NullSign closes it again, the same
	/// way opening and closing it by hand gets the install moving.
	private func _watchAppleTVStall() {
		guard _stallWatch == nil, let id = app.identifier else { return }
		_stallWatch = Task { [weak self] in
			for delay: UInt64 in [8, 15, 20] {
				try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
				guard let self, !Task.isCancelled, !self._hasFinished,
					  case .installing = self.viewModel.status else { return }
				FileLogger.log("Apple TV install still waiting, closing \(id) on the TV", category: "install")
				await AppleTVAppCloser.close(id, cycleIfIdle: true)
			}
		}
	}

	/// Ends the search and points the device connection back at this iPhone.
	private func _releaseAppleTV() {
		_stallWatch?.cancel()
		_stallWatch = nil
		guard _isAppleTV else { return }
		// Discovery keeps running while an Apple TV is paired, so its address
		// and port stay current for the next install.
		if HeartbeatManager.shared.isAppleTVTarget {
			HeartbeatManager.shared.usePhoneTarget()
		}
	}

	/// A restart gives an Apple TV a new port, and its address can change, so
	/// NullSign looks for the paired Apple TV again before connecting.
	private func _connectAppleTV() async throws {
		let manager = AppleTVManager.shared
		if let paired = manager.pairedDevice {
			let deadline = Date().addingTimeInterval(6)
			while Date() < deadline, !manager.discovered.contains(where: {
				$0.connectionPort != nil && ($0.name == paired.name || $0.host == paired.host)
			}) {
				try await Task.sleep(nanoseconds: 250_000_000)
			}
		}
		try manager.prepareForInstall()
	}

	deinit {
		_archive?.cleanup()
		_progressTask?.cancel()
		_stallWatch?.cancel()
		_declineCheck?.cancel()
		if let _declineObserver { NotificationCenter.default.removeObserver(_declineObserver) }
	}

	func start(completion: @escaping (Result<Outcome, Error>) -> Void) {
		guard _completion == nil, !_hasFinished else { return }
		_completion = completion

		// NullSign can install its own update: the package is served before iOS
		// closes NullSign to replace it, and if anything fails iOS keeps the
		// installed version.

		_statusObserver = viewModel.$status
			.receive(on: DispatchQueue.main)
			.sink { [weak self] in self?._handle($0) }

		Task { await _run() }
	}

	func stop() {
		_hasFinished = true
		_releaseAppleTV()
		_completion = nil
		_disarmDeclineWatch()
		_statusObserver = nil
		_progressTask?.cancel()
		_progressTask = nil
		_release()
	}

	private func _release() {
		_packageTask?.cancel()
		_packageTask = nil
		_server = nil
		_archive?.cleanup()
		_archive = nil
	}

	// MARK: Pipeline

	private func _run() async {
		let keepAlive = BackgroundTaskManager(
			taskName: "Install",
			expirationTitle: .localized("Installation continuing"),
			expirationBody: .localized("The installation will continue when you reopen the app")
		)
		keepAlive.start()
		defer { keepAlive.stop() }

		do {
			if _isAppleTV {
				// Fail before packaging when no Apple TV is paired.
				if AppleTVManager.shared.pairedDevice == nil {
					try AppleTVManager.shared.prepareForInstall()
				}
				try _verifyProfileForAppleTV()
				// Find the Apple TV on the network while the app is packaged.
				AppleTVManager.shared.startScanning()
			}

			let (packageUrl, exported) = try await _package()

			guard !_isSharing else {
				_finish(.success(.exported(_useShareSheet ? exported : nil)))
				return
			}

			if _isAppleTV {
				try await _installOnAppleTV(packageUrl)
			} else if _installationMethod == 1 {
				// An Apple TV install leaves the connection pointed at the TV.
				if HeartbeatManager.shared.isAppleTVTarget {
					HeartbeatManager.shared.usePhoneTarget()
					HeartbeatManager.shared.start(true)
				}
				try await InstallationProxy(viewModel: viewModel)
					.install(at: packageUrl, suspend: app.identifier == Bundle.main.bundleIdentifier!)
			} else {
				await _serveForOTA(packageUrl)
			}
		} catch {
			_progressTask?.cancel()
			_finish(.failure(error))
		}
	}

	private func _package() async throws -> (package: URL, exported: URL?) {
		let handler = ArchiveHandler(app: app, viewModel: viewModel)
		_archive = handler
		let isSharing = _isSharing
		let useShareSheet = _useShareSheet

		let task = Task.detached(priority: .userInitiated) {
			try await handler.move()
			try Task.checkCancellation()
			let package = try await handler.archive(forExport: isSharing)
			try Task.checkCancellation()

			guard isSharing else { return (package: package, exported: URL?.none) }
			return (package: package, exported: try await handler.moveToArchive(package, shouldOpen: !useShareSheet))
		}
		_packageTask = task
		return try await task.value
	}

	private func _serveForOTA(_ packageUrl: URL) async {
		guard let server = _server else {
			_finish(.failure(Self.error(.localized("Could not build the installation link, check your connection and try again."))))
			return
		}

		server.packageUrl = packageUrl

		if _serverMethod == 1 {
			viewModel.status = .sendingManifest
			server.manifestUrl = await ManifestService.resolve(for: app, payload: server.payloadEndpoint)
		}

		var failure = server.startupError
		if failure == nil {
			failure = await server.selfCheck()
		}

		if let id = app.identifier {
			_installedBefore = InstalledAppState.current(for: id)
		}
		FileLogger.log("sending \(app.identifier ?? "?") \(app.version ?? "?"), installed: \(_installedBefore?.description ?? "none")", category: "install")

		viewModel.status = failure.map { .broken($0) } ?? .ready
	}

	// MARK: Status

	private func _handle(_ status: InstallerStatusViewModel.InstallerStatus) {
		switch status {
		case .ready where _usesServer:
			_armDeclineWatch()
			_openInstall(_serverMethod == 0 ? _server?.iTunesLink : _server?.iTunesLinkExternal)
		case .sendingManifest where _progressTask == nil:
			_armDeclineWatch()
		case .sendingPayload:
			fallbackPage = nil
			_disarmDeclineWatch()
		case .installing where _usesServer:
			_startProgressPolling()
			if _isSelfUpdate {
				// Normally the progress watch steps aside once iOS has the whole
				// update; this covers an iOS that never reports it.
				DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
					self?._stepAsideForSelfUpdate()
				}
			}
		case .installing where _isAppleTV:
			_watchAppleTVStall()
		case .completed(let result):
			_progressTask?.cancel()
			_progressTask = nil
			_finish(result.map { .installed })
		case .broken(let error):
			_progressTask?.cancel()
			_progressTask = nil
			_finish(.failure(error))
		default:
			break
		}
	}

	private func _openInstall(_ link: String?) {
		guard let link, let url = URL(string: link) else {
			_finish(.failure(Self.error(.localized("Could not build the installation link, check your connection and try again."))))
			return
		}

		FileLogger.log("opening \(link)", category: "install")

		UIApplication.shared.open(url) { [weak self] opened in
			FileLogger.log("itms-services accepted by iOS: \(opened)", category: "install")

			if !opened {
				FileLogger.error("iOS refused the scheme, falling back to the redirect page", category: "install")
				self?.fallbackPage = self?._server?.pageEndpoint
			}
		}
	}

	// Declining iOS's install prompt never reports back.
	private func _armDeclineWatch() {
		guard _declineObserver == nil else { return }

		_declineObserver = NotificationCenter.default.addObserver(
			forName: UIApplication.didBecomeActiveNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?._scheduleDeclineCheck(after: 3)
		}

		_scheduleDeclineCheck(after: 60)
	}

	private func _scheduleDeclineCheck(after delay: TimeInterval) {
		_declineCheck?.cancel()

		let work = DispatchWorkItem { [weak self] in
			guard let self, self.fallbackPage == nil else { return }
			switch self.viewModel.status {
			case .ready, .sendingManifest: Task { await self._cancelIfIdle() }
			default: break
			}
		}

		_declineCheck = work
		DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
	}

	// Slow manifest fetch can mimic a decline.
	private func _cancelIfIdle() async {
		if let id = app.identifier, (await UIApplication.installProgress(for: id) ?? 0) > 0 { return }
		switch viewModel.status {
		case .ready, .sendingManifest: _finish(.success(.cancelled))
		default: break
		}
	}

	private func _disarmDeclineWatch() {
		_declineCheck?.cancel()
		_declineCheck = nil

		if let _declineObserver {
			NotificationCenter.default.removeObserver(_declineObserver)
		}
		_declineObserver = nil
	}

	private func _finish(_ result: Result<Outcome, Error>) {
		guard !_hasFinished else { return }
		_hasFinished = true
		_releaseAppleTV()
		_disarmDeclineWatch()
		_statusObserver = nil
		fallbackPage = nil

		var result = result
		if _isAppleTV, case .failure(let error) = result {
			let explained = _explainAppleTVFailure(error)
			result = .failure(explained)
			if viewModel.isFailed { viewModel.status = .broken(explained) }
		}
		if case .failure(let error) = result, !viewModel.isFailed {
			viewModel.status = .broken(error)
		}

		let completion = _completion
		_completion = nil
		_release()
		completion?(result)
	}

	static let detectsRejectionKey = "RyukSign.detectFailedInstalls"

	private static var detectsRejection: Bool {
		UserDefaults.standard.object(forKey: detectsRejectionKey) as? Bool ?? true
	}

	private static func error(_ message: String) -> Error {
		NSError(domain: "Install", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
	}

	/// iOS replaces an app only once it's off the screen. When NullSign is
	/// installing its own update, the new version has been handed over by
	/// now, so it stops keeping itself awake and goes to the Home Screen; iOS
	/// then closes it and puts the new version in its place.
	private var _isSelfUpdate: Bool { app.identifier == Bundle.main.bundleIdentifier }
	private var _hasSteppedAside = false

	private func _stepAsideForSelfUpdate() {
		guard _isSelfUpdate, !_hasSteppedAside, !viewModel.isFailed else { return }
		_hasSteppedAside = true
		FileLogger.log("stepping aside for NullSign's own update", category: "install")
		_server?.endKeepAlive()
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
		}
	}

	// MARK: Progress

	private func _startProgressPolling() {
		guard _progressTask == nil, let bundleID = app.identifier else { return }
		let before = _installedBefore

		_progressTask = Task.detached(priority: .utility) { [weak self, viewModel] in
			let pollingStarted = Date()
			var startedAt: Date?
			var peak = 0.0
			var logged = -1.0
			var last = 0.0
			var lastChange = Date()
			var nextStateCheck = Date()

			while !Task.isCancelled {
				let raw = await UIApplication.installProgress(for: bundleID) ?? 0.0
				let now = Date()

				if raw > 0, startedAt == nil { startedAt = now }
				let hasStarted = startedAt != nil
				peak = max(peak, raw)
				if raw != last {
					last = raw
					lastChange = now
				}

				if abs(raw - logged) >= 0.1 || (raw == 0) != (logged == 0) {
					FileLogger.log("progress \(bundleID): \(raw)", category: "install")
					logged = raw
				}

				// iOS has the whole update once its progress passes the download
				// stage; only then can NullSign get out of the way without
				// cutting the transfer short.
				if raw >= 0.6 {
					await self?._stepAsideForSelfUpdate()
				}

				// The drop back to zero at the end is installd finishing, not progress going backwards.
				if raw > 0 {
					let value = min(1.0, max(0.0, (raw - 0.6) / 0.3))
					await MainActor.run {
						if viewModel.installProgress != value {
							viewModel.installProgress = value
						}
					}
				}

				var endReason: String?
				if hasStarted, raw == 0 {
					endReason = "progress ended"
				} else if !hasStarted, now.timeIntervalSince(pollingStarted) > 120 {
					endReason = "never started"
				} else if peak >= 0.85, now.timeIntervalSince(lastChange) > 60 {
					endReason = "progress stuck at \(raw) after installd accepted the app"
				} else if now.timeIntervalSince(pollingStarted) > 900 {
					endReason = "timed out at \(raw)"
				} else if now >= nextStateCheck {
					// Tiny apps can finish between samples, and iOS doesn't always reset progress afterwards.
					nextStateCheck = now.addingTimeInterval(1)
					if let current = InstalledAppState.current(for: bundleID), current != before {
						endReason = "installed app changed"
					}
				}

				if let endReason {
					FileLogger.log("install watch ended: \(endReason)", category: "install")
					await self?._verifyInstall(started: hasStarted, peak: peak, before: before)
					break
				}

				// Small apps finish within seconds and need dense samples; long installs don't.
				let isLongInstall = startedAt.map { now.timeIntervalSince($0) > 5 } ?? false
				try? await Task.sleep(nanoseconds: isLongInstall ? 250_000_000 : 50_000_000)
			}
		}
	}

	// installd only reaches 0.88 once it accepts the app.
	private func _verifyInstall(started: Bool, peak: Double, before: InstalledAppState?) {
		let after = app.identifier.flatMap(InstalledAppState.current(for:))
		let replaced = after != nil && after != before
		FileLogger.log("install ended, started=\(started), peak=\(peak), installed: \(after?.description ?? "none"), replaced=\(replaced)", category: "install")

		if peak < 0.85, !replaced, Self.detectsRejection {
			FileLogger.error("iOS rejected \(app.identifier ?? "?") \(app.version ?? "?")", category: "install")
			let message: String = started || after != nil
				? .localized("iOS couldn't install the app. If a copy is already installed, delete it and try again.")
				: .localized("iOS never started installing the app. Try again.")
			viewModel.status = .broken(Self.error(message))
			return
		}

		viewModel.installProgress = 1.0
		viewModel.status = .completed(.success(()))
	}
}
