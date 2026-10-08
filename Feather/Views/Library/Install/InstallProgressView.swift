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
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

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
			Circle()
				.strokeBorder(
					viewModel.isCompleted ? NullSignStyle.success.opacity(0.6) : NullSignStyle.accent.opacity(0.55),
					lineWidth: 1.5
				)
				.frame(width: 76, height: 76)
				.scaleEffect(_isPulsing && !_reduceMotion ? 1.08 : 1)
				.opacity(_isPulsing && !_reduceMotion ? 0.35 : 1)
				.animation(
					viewModel.isCompleted || _reduceMotion
						? .easeOut(duration: 0.2)
						: .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
					value: _isPulsing
				)

			FRAppIconView(app: app, size: 56, glow: true)

			if viewModel.isCompleted {
				Image(systemName: "checkmark.circle.fill")
					.font(.system(size: 20, weight: .bold))
					.symbolRenderingMode(.palette)
					.foregroundStyle(.black, NullSignStyle.success)
					.background(Circle().fill(.black).padding(2))
					.offset(x: 26, y: 26)
					.transition(.scale.combined(with: .opacity))
			}
		}
		.frame(width: 78, height: 78)
		.animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isCompleted)
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

	private var targetProgress: Double {
		min(max(progress ?? 0, 0), 1)
	}

	var body: some View {
		VStack(alignment: .trailing, spacing: 6) {
			Text("\(Int(targetProgress * 100))%")
				.font(NullSignStyle.mono(10, weight: .bold))
				.foregroundStyle(NullSignStyle.muted)
				.contentTransition(.numericText())
				.opacity(showsPercentage && progress != nil && targetProgress > 0 && targetProgress < 1 ? 1 : 0)
				.frame(height: 12)

			TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: progress != nil)) { timeline in
				GeometryReader { proxy in
					let width = max(proxy.size.width, 1)
					let seconds = timeline.date.timeIntervalSinceReferenceDate

					ZStack(alignment: .leading) {
						Capsule()
							.fill(Color.white.opacity(0.08))
							.overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))

						if progress == nil {
							_indeterminateFill(width: width, seconds: seconds)
						} else {
							_determinateFill(width: width)
						}
					}
					.frame(width: width, height: 8, alignment: .leading)
					.clipShape(Capsule())
				}
				.frame(height: 8)
			}
		}
	}

	@ViewBuilder
	private func _determinateFill(width: CGFloat) -> some View {
		let fillWidth = min(width, max(0, width * targetProgress))

		Capsule()
			.fill(NullSignStyle.signal)
			.overlay(alignment: .trailing) {
				Circle()
					.fill(Color.white)
					.frame(width: 4, height: 4)
					.padding(.trailing, 2)
					.opacity(targetProgress > 0.02 && targetProgress < 1 ? 0.9 : 0)
			}
			.frame(width: fillWidth)
			.shadow(color: NullSignStyle.accent.opacity(0.6), radius: 6)
			.animation(.linear(duration: 0.2), value: targetProgress)
	}

	@ViewBuilder
	private func _indeterminateFill(width: CGFloat, seconds: TimeInterval) -> some View {
		let segmentWidth = min(width, max(54, width * 0.26))
		let travel = max(0, width - segmentWidth)
		let easedPosition = (sin(seconds * 2.1) + 1) / 2

		Capsule()
			.fill(
				LinearGradient(
					colors: [NullSignStyle.accent.opacity(0.2), NullSignStyle.accentHighlight, NullSignStyle.accent.opacity(0.2)],
					startPoint: .leading,
					endPoint: .trailing
				)
			)
			.frame(width: segmentWidth)
			.offset(x: travel * CGFloat(easedPosition))
			.shadow(color: NullSignStyle.accent.opacity(0.6), radius: 7)
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
		.background(Color.black)
		.preferredColorScheme(.dark)
		.previewLayout(.sizeThatFits)
	}
}
#endif
