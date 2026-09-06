//
//  InstallProgressView.swift
//  Feather
//
//  Created by samara on 23.04.2025.
//

import SwiftUI
import IDeviceSwift

struct InstallProgressView: View {
	@State private var _isPulsing = false
	
	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	var body: some View {
		VStack(spacing: 12) { _appIcon() }
			.onAppear {
				guard !viewModel.isCompleted else { return }
				_isPulsing = true
			}
			.onChange(of: viewModel.isCompleted) { _ in _updateAnimation() }
	}
	
	@ViewBuilder
	private func _appIcon() -> some View {
		ZStack {
			FRAppIconView(app: app, size: 58)
				.scaleEffect(viewModel.isCompleted ? 1 : (_isPulsing ? 1.03 : 1.0))
				.animation(
					viewModel.isCompleted ? .easeOut(duration: 0.2) : .easeInOut(duration: 1.25).repeatForever(autoreverses: true),
					value: _isPulsing
				)
			if viewModel.isCompleted {
				Image(systemName: "checkmark.circle.fill")
					.font(.system(size: 20, weight: .bold))
					.symbolRenderingMode(.palette)
					.foregroundStyle(.black, NullSignStyle.accent)
					.background(Circle().fill(.black).padding(2))
					.offset(x: 31, y: 31)
			}
		}
		.frame(width: 68, height: 68)
	}

	private func _updateAnimation() {
		if viewModel.isCompleted {
			_isPulsing = false
		} else {
			_isPulsing = true
		}
	}
}

/// A single progress treatment for packaging, transfer, and installation.
/// Pass `nil` while progress is indeterminate, otherwise a value from 0...1.
struct NullSignInstallProgressBar: View {
	let progress: Double?
	var showsPercentage = true

	@State private var displayedProgress = 0.0

	private var targetProgress: Double {
		min(max(progress ?? 0, 0), 1)
	}

	var body: some View {
		VStack(alignment: .trailing, spacing: 5) {
			Text("\(Int((displayedProgress * 100).rounded()))%")
				.font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
				.foregroundStyle(NullSignStyle.muted)
				.opacity(showsPercentage && progress != nil && displayedProgress > 0 && displayedProgress < 1 ? 1 : 0)
				.frame(height: 12)

			TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
				GeometryReader { proxy in
					let width = max(proxy.size.width, 1)
					let seconds = timeline.date.timeIntervalSinceReferenceDate

					ZStack(alignment: .leading) {
						Capsule()
							.fill(Color(red: 0.173, green: 0.173, blue: 0.180))
							.overlay {
								Capsule()
									.stroke(Color.black.opacity(0.62), lineWidth: 1)
									.blur(radius: 0.35)
									.offset(y: 0.5)
							}

						if progress == nil {
							_indeterminateFill(width: width, seconds: seconds)
						} else {
							_determinateFill(width: width, seconds: seconds)
						}
					}
					.frame(width: width, height: 8, alignment: .leading)
					.clipShape(Capsule())
				}
				.frame(height: 8)
			}
		}
		.animation(.easeInOut(duration: 0.22), value: progress == nil)
		.onAppear { animate(to: targetProgress) }
		.onChange(of: progress) { _ in animate(to: targetProgress) }
	}

	@ViewBuilder
	private func _determinateFill(width: CGFloat, seconds: TimeInterval) -> some View {
		let fillWidth = min(width, max(0, width * displayedProgress))
		let shimmerWidth = min(44, fillWidth)
		let shimmerTravel = max(0, fillWidth - shimmerWidth)
		let shimmerX = CGFloat(seconds.truncatingRemainder(dividingBy: 1.8) / 1.8) * shimmerTravel

		Capsule()
			.fill(
				LinearGradient(
					colors: [NullSignStyle.crimson, NullSignStyle.crimson.opacity(0.88), Color.white.opacity(0.32)],
					startPoint: .leading,
					endPoint: .trailing
				)
			)
			.frame(width: fillWidth)
			.overlay(alignment: .leading) {
				LinearGradient(
					colors: [.clear, Color.white.opacity(0.42), .clear],
					startPoint: .leading,
					endPoint: .trailing
				)
				.frame(width: shimmerWidth)
				.offset(x: shimmerX)
			}
	}

	@ViewBuilder
	private func _indeterminateFill(width: CGFloat, seconds: TimeInterval) -> some View {
		let segmentWidth = min(width, max(54, width * 0.24))
		let travel = max(0, width - segmentWidth)
		let easedPosition = (sin(seconds * 2.1) + 1) / 2

		Capsule()
			.fill(
				LinearGradient(
					colors: [NullSignStyle.crimson.opacity(0.72), NullSignStyle.crimson, Color.white.opacity(0.28)],
					startPoint: .leading,
					endPoint: .trailing
				)
			)
			.frame(width: segmentWidth)
			.offset(x: travel * CGFloat(easedPosition))
			.shadow(color: NullSignStyle.crimson.opacity(0.58), radius: 7)
	}

	private func animate(to value: Double) {
		let monotonicTarget = max(displayedProgress, min(max(value, 0), 1))
		guard monotonicTarget > displayedProgress else { return }
		withAnimation(.smooth(duration: monotonicTarget == 1 ? 0.42 : 0.62)) {
			displayedProgress = monotonicTarget
		}
	}
}

#if DEBUG
struct NullSignInstallProgressBar_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: 28) {
			NullSignInstallProgressBar(progress: 0.42)
			NullSignInstallProgressBar(progress: nil)
		}
		.padding(24)
		.background(Color(red: 0.110, green: 0.110, blue: 0.118))
		.preferredColorScheme(.dark)
		.previewLayout(.sizeThatFits)
	}
}
#endif
