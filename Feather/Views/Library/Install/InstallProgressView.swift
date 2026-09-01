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
			.onAppear { _updateAnimation() }
			.onChange(of: viewModel.isCompleted) { _ in _updateAnimation() }
	}
	
	@ViewBuilder
	private func _appIcon() -> some View {
		ZStack {
			Circle()
				.stroke(NullSignStyle.cyan.opacity(0.16), lineWidth: 4)
			Circle()
				.trim(from: 0, to: max(0.035, min(viewModel.overallProgress, 1)))
				.stroke(NullSignStyle.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
				.rotationEffect(.degrees(-90))
				.animation(.smooth, value: viewModel.overallProgress)
			FRAppIconView(app: app, size: 58)
				.scaleEffect(viewModel.isCompleted ? 1 : (_isPulsing ? 0.92 : 0.86))
				.animation(
					viewModel.isCompleted ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
					value: _isPulsing
				)
			if viewModel.isCompleted {
				Image(systemName: "checkmark.circle.fill")
					.font(.system(size: 20, weight: .bold))
					.symbolRenderingMode(.palette)
					.foregroundStyle(.black, NullSignStyle.cyan)
					.background(Circle().fill(.black).padding(2))
					.offset(x: 31, y: 31)
			}
		}
		.frame(width: 82, height: 82)
	}

	private func _updateAnimation() {
		if viewModel.isCompleted {
			_isPulsing = false
		} else {
			_isPulsing = true
		}
	}
}
