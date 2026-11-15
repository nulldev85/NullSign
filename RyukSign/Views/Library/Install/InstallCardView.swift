//
//  InstallCardView.swift
//  RyukSign
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift

// MARK: - View: Card
/// NullSign's install card on RyukSign's install queue: the app, its status
/// and a progress bar, with the queue's cancel button and what's up next.
struct InstallCardView: View {
	@ObservedObject var installer: AppInstaller
	var upcoming: [AnyApp] = []
	var onCancel: () -> Void

	var body: some View {
		InstallStatusView(
			app: installer.app,
			viewModel: installer.viewModel,
			upcoming: upcoming,
			onCancel: onCancel
		)
		.padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.background(
			NullSignStyle.groupedSurface,
			in: RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous)
		)
		.padding([.top, .horizontal])
		.padding(.bottom, 36)
		.ignoresSafeArea(.container, edges: .bottom)
		.preferredColorScheme(.dark)
		.nullSignTypography()
		.installFallbackSheet(installer)
	}
}

// MARK: - View: Status
/// Observes the status model directly
private struct InstallStatusView: View {
	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel
	var upcoming: [AnyApp]
	var onCancel: () -> Void

	@State private var _isShowingError = false

	private var _succeeded: Bool { viewModel.isCompleted && !viewModel.isFailed }

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(spacing: 14) {
				InstallProgressView(app: app, viewModel: viewModel)

				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: 6) {
						Text(app.name ?? .localized("Unknown"))
							.font(.roundedUI(.headline))
							.foregroundStyle(.white)
							.lineLimit(1)
						PlatformBadge(platform: app.platform)
					}

					Label(viewModel.statusLabel, systemImage: viewModel.statusImage)
						.font(.roundedUI(.footnote, weight: .bold))
						.foregroundStyle(_statusColor)
						.labelStyle(.titleAndIcon)
						.lineLimit(2)
						.animation(.smooth, value: viewModel.statusImage)
				}

				Spacer(minLength: 8)

				_trailing()
			}

			if !viewModel.isCompleted && !viewModel.isFailed {
				NullSignInstallProgressBar(progress: _progress)
					.compatTransition()
			}

			if !upcoming.isEmpty {
				_upNext()
			}
		}
		.animation(.easeInOut(duration: 0.3), value: viewModel.isCompleted)
		.animation(.easeInOut(duration: 0.3), value: viewModel.isFailed)
	}

	/// Indeterminate until the transfer reports progress.
	private var _progress: Double? {
		viewModel.overallProgress > 0 ? viewModel.overallProgress : nil
	}

	private var _statusColor: Color {
		if viewModel.isFailed { return NullSignStyle.danger }
		if _succeeded { return NullSignStyle.success }
		return NullSignStyle.muted
	}

	@ViewBuilder
	private func _trailing() -> some View {
		ZStack {
			if let failure = viewModel.failure {
				Button(.localized("Details")) {
					_isShowingError = true
				}
				.buttonStyle(NullSignSecondaryButtonStyle(height: 34, tint: NullSignStyle.danger))
				.compatTransition()
				.alert(.localized("Install Failed"), isPresented: $_isShowingError) {
					Button(.localized("Copy")) { UIPasteboard.general.string = failure.message }
					Button(.localized("OK"), role: .cancel) {}
				} message: {
					Text(failure.message)
				}
			} else if viewModel.isCompleted {
				Button(.localized("Open")) {
					UIApplication.openApp(with: app.identifier ?? "")
				}
				.buttonStyle(NullSignPrimaryButtonStyle(height: 34))
				.compatTransition()
			} else {
				Button(action: onCancel) {
					Image(systemName: "xmark.circle.fill")
						.font(.roundedUI(size: 24, weight: .semibold))
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(NullSignStyle.muted)
						.frame(width: 44, height: 44)
						.contentShape(Circle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel(.localized("Cancel"))
				.compatTransition()
			}
		}
	}

	@ViewBuilder
	private func _upNext() -> some View {
		HStack(spacing: 8) {
			HStack(spacing: -8) {
				ForEach(upcoming.prefix(4)) { entry in
					FRAppIconView(app: entry.base, size: 22)
						.overlay {
							RoundedRectangle(cornerRadius: 6, style: .continuous)
								.strokeBorder(NullSignStyle.groupedSurface, lineWidth: 2)
						}
				}
			}

			Text(String.localized("%lld queued", arguments: upcoming.count))
				.font(.roundedUI(.caption, weight: .semibold))
				.foregroundStyle(NullSignStyle.muted)
		}
	}
}
