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
struct InstallCardView: View {
	@ObservedObject var installer: AppInstaller
	var upcoming: [AnyApp] = []
	var onCancel: () -> Void

	var body: some View {
		ZStack {
			InstallProgressView(app: installer.app, viewModel: installer.viewModel)
			InstallStatusView(
				app: installer.app,
				viewModel: installer.viewModel,
				upcoming: upcoming,
				onCancel: onCancel
			)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.background(NullSignStyle.groupedSurface)
		.cornerRadius(NBRadius.large)
		.padding([.top, .horizontal])
		.padding(.bottom, 36)
		.ignoresSafeArea(.container, edges: .bottom)
		.preferredColorScheme(.dark)
		.tint(NullSignStyle.accent)
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

	var body: some View {
		ZStack {
			_status()
			_button()
			_close()

			if !upcoming.isEmpty {
				_upNext()
			}
		}
	}

	@ViewBuilder
	private func _close() -> some View {
		ZStack {
			if !viewModel.isCompleted {
				Button(action: onCancel) {
					Image(systemName: "xmark.circle.fill")
						.font(.roundedUI(.title3))
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(NullSignStyle.muted)
						.contentShape(Circle())
				}
				.buttonStyle(.plain)
				.padding()
				.compatTransition()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
		.animation(.easeInOut(duration: 0.3), value: viewModel.isCompleted)
	}

	/// NullSign's colors: red on failure, green once installed.
	private var _statusColor: Color {
		if viewModel.isFailed { return NullSignStyle.danger }
		if viewModel.isCompleted { return NullSignStyle.success }
		return .white
	}

	@ViewBuilder
	private func _status() -> some View {
		Label(viewModel.statusLabel, systemImage: viewModel.statusImage)
			.foregroundStyle(_statusColor)
			.font(.roundedUI(.body, weight: .semibold))
			.padding()
			.labelStyle(.titleAndIcon)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
			.animation(.smooth, value: viewModel.statusImage)
	}

	@ViewBuilder
	private func _button() -> some View {
		ZStack {
			if let failure = viewModel.failure {
				Button(.localized("Details")) {
					_isShowingError = true
				}
				.font(.roundedUI(.subheadline, weight: .semibold))
				.foregroundStyle(NullSignStyle.danger)
				.padding()
				.compatTransition()
				.alert(.localized("Install Failed"), isPresented: $_isShowingError) {
					Button(.localized("Copy")) { UIPasteboard.general.string = failure.message }
					Button(.localized("OK"), role: .cancel) {}
				} message: {
					Text(failure.message)
				}
			} else if viewModel.isCompleted, app.platform == .tvOS {
				// tvOS apps open from the Apple TV's Home Screen.
				Label(.localized("On Apple TV"), systemImage: "appletv.fill")
					.font(.roundedUI(.footnote, weight: .bold))
					.foregroundStyle(NullSignStyle.muted)
					.padding()
					.compatTransition()
			} else if viewModel.isCompleted {
				Button {
					UIApplication.openApp(with: app.identifier ?? "")
				} label: {
					NBButton("Open", systemImage: "", style: .text)
						.foregroundStyle(NullSignStyle.accent)
				}
				.padding()
				.compatTransition()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
		.animation(.easeInOut(duration: 0.3), value: viewModel.isCompleted)
		.animation(.easeInOut(duration: 0.3), value: viewModel.isFailed)
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
				.font(.roundedUI(.caption, weight: .medium))
				.foregroundStyle(NullSignStyle.muted)
		}
		.padding()
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}
