//
//  InstallPreview.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift
import OSLog

// MARK: - View
struct InstallPreviewView: View {
	@Environment(\.dismiss) var dismiss

	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 0
	@State private var _isWebviewPresenting = false
	@State private var progressTask: Task<Void, Never>?
	@State private var installAttempt = 0
	
	var app: AppInfoPresentable
	@StateObject var viewModel: InstallerStatusViewModel
	@StateObject var installer: ServerInstaller
	
	@State var isSharing: Bool
	
	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.app = app
		self.isSharing = isSharing
		let viewModel = InstallerStatusViewModel(isIdevice: app.platform == .tvOS)
		self._viewModel = StateObject(wrappedValue: viewModel)
		self._installer = StateObject(wrappedValue: try! ServerInstaller(app: app, viewModel: viewModel))
	}
	
	// MARK: Body
	var body: some View {
		let cornerRadius = {
			if #available(iOS 26.0, *) {
				28.0
			} else {
				10.5
			}
		}()
		
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 16) {
				InstallProgressView(app: app, viewModel: viewModel)
				VStack(alignment: .leading, spacing: 6) {
					HStack(spacing: 7) {
						Text(app.name ?? "App")
							.font(.system(size: 18, weight: .semibold, design: .rounded))
							.lineLimit(1)
						PlatformBadge(platform: app.platform)
					}
					_status()
				}
				Spacer(minLength: 8)
				_button()
			}

			NullSignInstallProgressBar(
				progress: viewModel.isCompleted ? 1 : (viewModel.overallProgress > 0 ? viewModel.overallProgress : nil)
			)
			.id(installAttempt)
		}
		.padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.background(Color(red: 0.110, green: 0.110, blue: 0.118))
		.cornerRadius(cornerRadius)
		.padding()
		.sheet(isPresented: $_isWebviewPresenting) {
			SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
		}
		.onReceive(viewModel.$status) { newStatus in
			if _installationMethod == 0 || app.platform == .iOS {
				if case .ready = newStatus {
					if _serverMethod == 0 {
						UIApplication.shared.open(URL(string: installer.iTunesLink)!)
					} else if _serverMethod == 1 {
						_isWebviewPresenting = true
					}
				}
				
				if case .sendingPayload = newStatus, _serverMethod == 1 {
					_isWebviewPresenting = false
				}
				
				if case .installing = newStatus {
					if progressTask == nil {
						progressTask = startInstallProgressPolling(
							bundleID: app.identifier!,
							viewModel: viewModel
						)
					}
				}
				
				switch newStatus {
				case .completed, .broken(_):
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
		.onChange(of: installAttempt) { _ in _install() }
		
		#if !targetEnvironment(macCatalyst)
		.onAppear {
			BackgroundAudioManager.shared.start()
		}
		#endif
		
		.onDisappear {
			progressTask?.cancel()
			progressTask = nil
			
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		}
	}
	
	@ViewBuilder
	private func _status() -> some View {
		Label(viewModel.statusLabel, systemImage: viewModel.statusImage)
			.font(.system(size: 12, weight: .semibold))
			.foregroundStyle(viewModel.isCompleted ? NullSignStyle.accent : NullSignStyle.muted)
			.animation(.smooth, value: viewModel.statusImage)
	}
	
	@ViewBuilder
	private func _button() -> some View {
		Group {
			if viewModel.isCompleted {
				if app.platform == .tvOS {
					_actionButton("Done", icon: "checkmark") { dismiss() }
				} else {
					_actionButton("Open", icon: "arrow.up.forward.app") {
						UIApplication.openApp(with: app.identifier ?? "")
					}
				}
			} else if case .broken = viewModel.status {
				_actionButton("Retry", icon: "arrow.clockwise") {
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
				.font(.system(size: 12, weight: .semibold))
				.padding(.horizontal, 12)
				.frame(height: 34)
				.foregroundStyle(.black)
				.background(NullSignStyle.accent)
				.clipShape(Capsule())
		}
		.buttonStyle(.plain)
	}
	
	private func _install() {
		guard isSharing || app.identifier != Bundle.main.bundleIdentifier! || _installationMethod == 1 else {
			UIAlertController.showAlertWithOk(
				title: .localized("Install"),
				message: .localized("You cannot update ‘%@‘ with itself, please use an alternative tool to update it.", arguments: Bundle.main.name)
			)
			return
		}
				
		Task.detached {
			do {
				let targetPlatform = await app.platform
				let sharing = await isSharing
				if targetPlatform == .tvOS && !sharing {
					try await AppleTVManager.shared.prepareForInstall()
				}
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				
				let packageUrl = try await handler.archive()
				
				if !sharing {
					if targetPlatform == .iOS {
						await MainActor.run {
							installer.packageUrl = packageUrl
							viewModel.updateStatus(.ready)
						}
						
						if case .installing = await viewModel.status {
							let task = await startInstallProgressPolling(
								bundleID: app.identifier!,
								viewModel: viewModel
							)

							await MainActor.run {
								progressTask = task
							}
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
			} catch {
				await progressTask?.cancel()
				
				await MainActor.run {
					UIAlertController.showAlertWithOk(
						title: .localized("Install"),
						message: String(describing: error),
						action: {
							HeartbeatManager.shared.start(true)
							dismiss()
						}
					)
				}
			}
		}
	}
	
	private func startInstallProgressPolling(
		bundleID: String,
		viewModel: InstallerStatusViewModel
	) -> Task<Void, Never> {

		Task.detached(priority: .background) {
			var hasStarted = false

			while !Task.isCancelled {
				let snapshot = await UIApplication.installProgressSnapshot(for: bundleID)
				let rawProgress = snapshot?.fractionCompleted ?? 0.0

				if rawProgress > 0 {
					hasStarted = true
				}

				let progress = await hasStarted
					? _normalizeInstallProgress(rawProgress)
					: 0.0

				Logger.misc.info("Install progress for \(bundleID): \(progress)")

				await MainActor.run {
					viewModel.updateInstallProgress(progress)
				}

				// iOS may report a terminal Progress object whose fraction stops below
				// 1.0. Treat the system's finished flag as authoritative; disappearance
				// after progress began remains the fallback used on older releases.
				if hasStarted && (snapshot?.isFinished == true || snapshot == nil || rawProgress == 0) {
					await MainActor.run {
						viewModel.updateInstallProgress(1.0)
						viewModel.updateStatus(.completed(.success(())))
					}
					break
				}

				try? await Task.sleep(nanoseconds: 500_000_000)
			}
		}
	}

	private func _normalizeInstallProgress(_ rawProgress: Double) -> Double {
		min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
	}
}
