//
//  InstallPreview.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import IDeviceSwift
import OSLog

// MARK: - View
struct InstallPreviewView: View {
	@Environment(\.dismiss) var dismiss

	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@State private var _isWebviewPresenting = false
	@State private var progressTask: Task<Void, Never>?
	@State private var operationTask: Task<Void, Never>?
	@State private var handoffTask: Task<Void, Never>?
	@State private var _hasStarted = false
	@State private var _didRequestInstall = false
	@State private var _needsBrowserFallback = false
	@State private var _installationObserver: SystemInstallRuntime.InstallationObserver?
	@State private var _isPreparing: Bool
	@State private var _signingStage: AppSigningStage? = .preparing
	@State private var _preparedApp: AppInfoPresentable?
	@State private var installAttempt = 0
	
	private let originalApp: AppInfoPresentable
	private var app: AppInfoPresentable { _preparedApp ?? originalApp }
	@StateObject var viewModel: InstallerStatusViewModel
	@State private var installer: ServerInstaller?
	
	@State var isSharing: Bool
	
	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.originalApp = app
		self.isSharing = isSharing
		self.__isPreparing = State(initialValue: !app.isSigned && !isSharing)
		let viewModel = InstallerStatusViewModel(isIdevice: app.platform == .tvOS)
		self._viewModel = StateObject(wrappedValue: viewModel)
	}
	
	// MARK: Body
	var body: some View {
		let cornerRadius = NullSignStyle.cardRadius
		
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 16) {
				InstallProgressView(app: app, viewModel: viewModel)
				VStack(alignment: .leading, spacing: 6) {
					HStack(spacing: 7) {
						Text(app.name ?? "App")
							.font(.roundedUI(.headline))
							.lineLimit(1)
						PlatformBadge(platform: app.platform)
					}
					_status()
				}
				Spacer(minLength: 8)
				_button()
			}

			NullSignInstallProgressBar(progress: _displayedProgress)
			.id(installAttempt)

			if let error = viewModel.installFailure {
				Text(error.localizedDescription)
					.font(.roundedUI(.caption))
					.foregroundStyle(NullSignStyle.danger)
			} else if _needsBrowserFallback {
				Text("No iOS prompt? Continue in the browser to finish this installation.")
					.font(.roundedUI(.caption))
					.foregroundStyle(NullSignStyle.muted)
				Button("Continue in Browser") { _isWebviewPresenting = true }
					.buttonStyle(NullSignSecondaryButtonStyle(height: 34))
			} else if !_isPreparing, case .ready = viewModel.status, !isSharing {
				Text("Confirm Install in the iOS prompt.")
					.font(.roundedUI(.caption))
					.foregroundStyle(NullSignStyle.muted)
			}
		}
		.padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.background(NullSignStyle.groupedSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
		.padding()
		.sheet(isPresented: $_isWebviewPresenting) {
			if let installer {
				SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
			}
		}
		.onReceive(viewModel.$status) { newStatus in
			if _installationMethod == 0 || app.platform == .iOS {
				if case .ready = newStatus {
					_openSystemInstaller()
				}

				if case .sendingManifest = newStatus {
					handoffTask?.cancel()
					_needsBrowserFallback = false
				}
				
				if case .sendingPayload = newStatus {
					_installationObserver?.arm()
					handoffTask?.cancel()
					_needsBrowserFallback = false
					_isWebviewPresenting = false
				}
				
				if case .installing = newStatus {
					if app.identifier == Bundle.main.bundleIdentifier {
						_stepAsideForSelfUpdate()
					}
				}
				
				switch newStatus {
				case .completed, .broken(_):
					_installationObserver?.stop()
					handoffTask?.cancel()
					progressTask?.cancel()
					progressTask = nil
					#if !targetEnvironment(macCatalyst)
					BackgroundAudioManager.shared.stop()
					#endif
				default:
					break
				}
			}
		}
		.onAppear(perform: _install)
		.onReceive(NotificationCenter.default.publisher(for: SystemInstallRuntime.installationDidFinish).receive(on: DispatchQueue.main)) { notification in
			guard let observer = notification.object as? SystemInstallRuntime.InstallationObserver,
				observer === _installationObserver, observer.didInstall,
				!viewModel.isCompleted, viewModel.installFailure == nil else { return }
			viewModel.updateInstallProgress(1)
			ReliabilityCenter.shared.record(.installing, "Confirmed installation by matching workspace event")
			viewModel.updateStatus(.completed(.success(())))
		}
		.onChange(of: installAttempt) { _ in _install() }
		
		#if !targetEnvironment(macCatalyst)
		.onAppear {
			BackgroundAudioManager.shared.start()
		}
		#endif
		
		.onDisappear {
			_installationObserver?.stop()
			_installationObserver = nil
			operationTask?.cancel()
			operationTask = nil
			handoffTask?.cancel()
			installer = nil
			progressTask?.cancel()
			progressTask = nil
			
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		}
	}
	
	@ViewBuilder
	private func _status() -> some View {
		Label(
			_isPreparing ? .localized((_signingStage ?? .preparing).rawValue) : viewModel.statusLabel,
			systemImage: _isPreparing ? "signature" : viewModel.statusImage
		)
			.font(.roundedUI(.footnote, weight: .bold))
			.foregroundStyle(viewModel.installSucceeded ? NullSignStyle.success : NullSignStyle.muted)
			.animation(.smooth, value: viewModel.statusImage)
	}
	
	@ViewBuilder
	private func _button() -> some View {
		Group {
			if viewModel.installSucceeded {
				if app.platform == .tvOS {
					_actionButton("Done", icon: "checkmark") { dismiss() }
				} else {
					_actionButton("Open", icon: "arrow.up.forward.app") {
						UIApplication.openApp(with: app.identifier ?? "")
					}
				}
			} else if viewModel.installFailure != nil {
				_actionButton("Retry", icon: "arrow.clockwise") {
					_installationObserver?.stop()
					operationTask?.cancel()
					handoffTask?.cancel()
					installer = nil
					_hasStarted = false
					_didRequestInstall = false
					_needsBrowserFallback = false
					_isPreparing = !app.isSigned && !isSharing
					_signingStage = .preparing
					viewModel.resetProgress()
					installAttempt += 1
				}
			}
		}
		.animation(.easeInOut(duration: 0.3), value: viewModel.isCompleted)
	}

	private func _actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Label(title, systemImage: icon)
		}
		.buttonStyle(NullSignPrimaryButtonStyle(height: 34))
	}
	
	private func _install() {
		guard !_hasStarted else { return }
		_hasStarted = true
		// backloop.dev retired the certificate Fully Local depended on. Migrate
		// existing selections before starting the server so iOS is never sent
		// to an HTTPS endpoint with a revoked or mismatched certificate.
		if UserDefaults.standard.integer(forKey: "Feather.serverMethod") == 0 {
			UserDefaults.standard.set(1, forKey: "Feather.serverMethod")
		}
		// NullSign can install its own update. The package is served before iOS
		// closes NullSign to replace it, and NullSign keeps running in the
		// background until then; if anything fails, iOS keeps the old version.


		operationTask = Task.detached {
			do {
				try Task.checkCancellation()
				if await !isSharing {
					let prepared = try await AppInstallPreparation.prepare(app) { stage in
						guard _isPreparing,
						      stage.progress >= (_signingStage?.progress ?? 0) else { return }
						_signingStage = stage
					}
					try Task.checkCancellation()
					await MainActor.run {
						_preparedApp = prepared
						_isPreparing = false
					}
				}
				let targetPlatform = await app.platform
				let sharing = await isSharing
				if targetPlatform == .tvOS && !sharing {
					try await AppleTVManager.shared.prepareForInstall()
				}
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				
				let packageUrl = try await handler.archive()
				try Task.checkCancellation()
				
				if !sharing {
					if targetPlatform == .iOS {
						try await MainActor.run {
							try Task.checkCancellation()
							let server = try ServerInstaller(app: app, viewModel: viewModel)
							server.packageUrl = packageUrl
							installer = server
							viewModel.updateStatus(.ready)
						}
					} else {
						let handler = await InstallationProxy(viewModel: viewModel)
						try await handler.install(at: packageUrl, suspend: app.identifier == Bundle.main.bundleIdentifier!)
					}
				} else {
					let package = try await handler.moveToArchive(packageUrl, shouldOpen: !_useShareSheet)
					
					if await !_useShareSheet {
						await MainActor.run {
							dismiss()
						}
					} else {
						if let package {
							await MainActor.run {
								dismiss()
								UIActivityViewController.show(activityItems: [package])
							}
						}
					}
				}
			} catch is CancellationError {
				// Signing may finish its current native call, but dismissing the
				// card must never open a new installation prompt afterwards.
				return
			} catch {
				await progressTask?.cancel()
				
				await MainActor.run {
					_isPreparing = false
					viewModel.updateStatus(.broken(error))
				}
			}
		}
	}

	private var _displayedProgress: Double {
		if _isPreparing { return (_signingStage ?? .preparing).progress }
		if viewModel.installFailure != nil, !originalApp.isSigned, _preparedApp == nil {
			return (_signingStage ?? .preparing).progress
		}
		let value = InstallHandoff.progress(
			afterSigning: !originalApp.isSigned && _preparedApp != nil,
			installerProgress: viewModel.overallProgress,
			succeeded: viewModel.installSucceeded
		)
		return value
	}

	private func _openSystemInstaller() {
		guard !_didRequestInstall, !isSharing, let installer else { return }
		_didRequestInstall = true
		if let identifier = app.identifier {
			// Observe BEFORE opening iOS: a fast or cached install may finish
			// before the final payload stream callback arrives.
			progressTask = startInstallProgressPolling(bundleID: identifier, viewModel: viewModel)
		}
		// Keep the progress card on screen. Opening itms-services directly
		// removes Safari's extra Open dialog; iOS still asks to confirm Install.
		UIApplication.shared.open(installer.installEndpoint, options: [:]) { accepted in
			if !accepted { _needsBrowserFallback = true }
		}
		// Some iOS versions accept the URL without requesting its manifest.
		// Preserve the proven browser route as an explicit recovery action,
		// rather than treating an accepted URL as a completed installation.
		handoffTask = Task { @MainActor in
			do { try await Task.sleep(nanoseconds: 15_000_000_000) }
			catch { return }
			if case .ready = viewModel.status { _needsBrowserFallback = true }
		}
	}

	/// iOS replaces an app only once it is off the screen. When NullSign is
	/// installing its own update, the new version has been handed over by now,
	/// so it stops keeping itself awake and goes to the Home Screen; iOS then
	/// closes it and puts the new version in its place.
	private func _stepAsideForSelfUpdate() {
		#if !targetEnvironment(macCatalyst)
		BackgroundAudioManager.shared.stop()
		#endif
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
		}
	}

	private func startInstallProgressPolling(
		bundleID: String,
		viewModel: InstallerStatusViewModel
	) -> Task<Void, Never> {

		func identity(_ value: SystemInstallRuntime.AppSnapshot?) -> InstalledAppIdentity? {
			value.map { InstalledAppIdentity(bundlePath: $0.bundlePath, version: $0.version,
				build: $0.build, registeredAt: $0.registeredAt) }
		}
		let initialState = SystemInstallRuntime.appState(for: bundleID)
		let baseline = identity(initialState.app)
		let expectedVersion = app.version.flatMap { $0.isEmpty ? nil : $0 }
		let observer = SystemInstallRuntime.observeInstallation(for: bundleID, version: expectedVersion)
		_installationObserver = observer
		let diagnosticID = String(UUID().uuidString.prefix(8))
		ReliabilityCenter.shared.record(.installing, "Attempt \(diagnosticID) bundle=\(bundleID) expected=\(expectedVersion ?? "unknown") baseline=\(initialState.diagnosticState) observer=\(observer != nil)")
		return Task { @MainActor in
			defer { observer?.stop() }
			var tracker = InstallCompletionTracker(baseline: baseline, expectedVersion: expectedVersion, baselineKnown: initialState.isAvailable)
			let started = ProcessInfo.processInfo.systemUptime
			var samples = 0
			var lastDiagnostic = ""
			var lastDiagnosticAt: TimeInterval = -15
			var appDiagnostic = initialState.diagnosticState
			while !Task.isCancelled, !viewModel.isCompleted, viewModel.installFailure == nil {
				let deliveryStarted: Bool
				switch viewModel.status {
				case .sendingPayload, .installing: deliveryStarted = true
				default: deliveryStarted = false
				}
				if deliveryStarted { observer?.arm() }
				let includeAppState = samples % 3 == 0
				let reading = await Task.detached(priority: .utility) {
					SystemInstallRuntime.observation(for: bundleID, includeAppState: includeAppState)
				}.value
				guard !Task.isCancelled, viewModel.installFailure == nil, !viewModel.isCompleted else { return }
				samples += 1
				let snapshot = reading.progress
				if let state = reading.state {
					let current = identity(state.app)
					appDiagnostic = "\(state.diagnosticState) changed=\(current != baseline) version=\(current?.version ?? "unknown") build=\(current?.build ?? "unknown")"
				}
				let elapsed = ProcessInfo.processInfo.systemUptime - started
				let raw = snapshot.map { "fraction=\($0.fractionCompleted) units=\($0.completedUnitCount)/\($0.totalUnitCount) finished=\($0.isFinished) cancelled=\($0.isCancelled) paused=\($0.isPaused)" } ?? "progress=unavailable"
				let diagnostic = "phase=\(viewModel.statusLabel) delivery=\(deliveryStarted) \(raw) app=\(appDiagnostic) observer=[\(observer?.diagnosticState ?? "unavailable")]"
				if diagnostic != lastDiagnostic || elapsed - lastDiagnosticAt >= 15 {
					ReliabilityCenter.shared.record(.installing, "Attempt \(diagnosticID) t=\(Int(elapsed)) \(diagnostic)")
					lastDiagnostic = diagnostic
					lastDiagnosticAt = elapsed
				}
				let update = tracker.observe(at: ProcessInfo.processInfo.systemUptime - started,
					fraction: snapshot?.fractionCompleted, finished: snapshot?.isFinished ?? false,
					cancelled: snapshot?.isCancelled ?? false, totalUnits: snapshot?.totalUnitCount ?? 0,
					installed: identity(reading.state?.app), deliveryStarted: deliveryStarted, installEvent: observer?.didInstall == true)
				if update.completed {
					ReliabilityCenter.shared.record(.installing, "Attempt \(diagnosticID) confirmed by completion tracker")
					viewModel.updateInstallProgress(1)
					viewModel.updateStatus(.completed(.success(())))
					return
				}
				if let progress = update.progress { viewModel.updateInstallProgress(progress) }
				do { try await Task.sleep(nanoseconds: 1_000_000_000) }
				catch { return }
			}
		}
	}
}
