//
//  InstallProgressView.swift
//  RyukSign
//
//  Created by samara on 23.04.2025.
//

import SwiftUI
import IDeviceSwift

/// NullSign's install icon: the app icon pulses while work runs, dims to grey
/// on failure and gains a green check once the install succeeds.
struct InstallProgressView: View {
	@State private var _isPulsing = false
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel

	private var _isActive: Bool { !viewModel.isCompleted && !viewModel.isFailed }
	private var _succeeded: Bool { viewModel.isCompleted && !viewModel.isFailed }

	var body: some View {
		ZStack {
			FRAppIconView(app: app, size: 58)
				.grayscale(viewModel.isFailed ? 1 : 0)
				.opacity(!_isActive || _reduceMotion ? 1 : (_isPulsing ? 0.6 : 1))
				.animation(
					!_isActive || _reduceMotion
						? .easeOut(duration: 0.2)
						: .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
					value: _isPulsing
				)

			if _succeeded {
				Image(systemName: "checkmark.circle.fill")
					.font(.roundedUI(size: 20, weight: .bold))
					.symbolRenderingMode(.palette)
					.foregroundStyle(.white, NullSignStyle.success)
					.background(Circle().fill(NullSignStyle.groupedSurface).padding(2))
					.offset(x: 27, y: 27)
					.transition(.scale.combined(with: .opacity))
			}
		}
		.frame(width: 68, height: 68)
		.animation(.easeOut(duration: 0.25), value: viewModel.isCompleted)
		.onAppear {
			_isPulsing = _isActive
		}
		.onChange(of: _isActive) { active in
			_isPulsing = active
		}
	}
}


/// A single progress treatment for packaging, transfer, and installation.
/// Pass `nil` while progress is indeterminate, otherwise a value from 0...1.
struct NullSignInstallProgressBar: View {
	let progress: Double?
	var showsPercentage = true

	private var targetProgress: Double {
		min(max(progress ?? 0, 0), 1)
	}

	var body: some View {
		VStack(alignment: .trailing, spacing: 6) {
			Text("\(Int(targetProgress * 100))%")
				.font(.roundedUI(.caption2, weight: .bold))
				.monospacedDigit()
				.foregroundStyle(NullSignStyle.muted)
				.opacity(showsPercentage && progress != nil && targetProgress > 0 && targetProgress < 1 ? 1 : 0)
				.frame(height: 12)

			TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: progress != nil)) { timeline in
				GeometryReader { proxy in
					let width = max(proxy.size.width, 1)
					let seconds = timeline.date.timeIntervalSinceReferenceDate

					ZStack(alignment: .leading) {
						Capsule()
							.fill(NullSignStyle.fill)

						if progress == nil {
							_indeterminateFill(width: width, seconds: seconds)
						} else {
							_determinateFill(width: width)
						}
					}
					.frame(width: width, height: 6, alignment: .leading)
					.clipShape(Capsule())
				}
				.frame(height: 6)
			}
		}
	}

	@ViewBuilder
	private func _determinateFill(width: CGFloat) -> some View {
		let fillWidth = min(width, max(0, width * targetProgress))

		Capsule()
			.fill(NullSignStyle.accent)
			.frame(width: fillWidth)
			.animation(.linear(duration: 0.2), value: targetProgress)
	}

	@ViewBuilder
	private func _indeterminateFill(width: CGFloat, seconds: TimeInterval) -> some View {
		let segmentWidth = min(width, max(54, width * 0.26))
		let travel = max(0, width - segmentWidth)
		let easedPosition = (sin(seconds * 2.1) + 1) / 2

		Capsule()
			.fill(NullSignStyle.accent)
			.frame(width: segmentWidth)
			.offset(x: travel * CGFloat(easedPosition))
	}

}

