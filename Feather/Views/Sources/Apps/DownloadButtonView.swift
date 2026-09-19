//
//  DownloadButtonView.swift
//  Feather
//
//  Created by samsam on 7/25/25.
//

import SwiftUI
import AltSourceKit
import NimbleViews

struct DownloadButtonView: View {
	let sourceURL: URL?
	let source: ASRepository?
	let app: ASRepository.App
	@ObservedObject private var downloadManager = DownloadManager.shared

	var body: some View {
		Group {
			if let currentDownload = downloadManager.getDownload(by: app.currentUniqueId) {
				DownloadProgressButton(download: currentDownload) {
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					downloadManager.cancelDownload(currentDownload)
				}
				.compatTransition()
			} else {
				Button {
					if let url = app.currentDownloadUrl {
						UIImpactFeedbackGenerator(style: .light).impactOccurred()
						_ = downloadManager.startDownload(
							from: url,
							id: app.currentUniqueId,
							sourceProvenance: _sourceProvenance()
						)
					}
				} label: {
					Text(.localized("Get"))
						.font(.caption.weight(.bold))
						.foregroundStyle(.black)
						.frame(width: 54, height: 32)
						.background(NullSignStyle.accent)
						.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
						.frame(minHeight: 44)
				}
				.buttonStyle(.borderless)
				.compatTransition()
			}
		}
		.animation(.easeInOut(duration: 0.22), value: downloadManager.getDownload(by: app.currentUniqueId)?.id)
	}
	
	private func _sourceProvenance() -> SourceAppProvenance? {
		guard let source else { return nil }
		return SourceAppProvenance(sourceURL: sourceURL, repository: source, app: app)
	}
}

private struct DownloadProgressButton: View {
	@ObservedObject var download: Download
	let cancel: () -> Void

	private var progress: Double {
		min(max(download.overallProgress, 0), 1)
	}

	var body: some View {
		Button(action: cancel) {
			ZStack {
				Circle()
					.stroke(NullSignStyle.accent.opacity(0.18), lineWidth: 2.5)
				Circle()
					.trim(from: 0, to: max(0.03, progress))
					.stroke(NullSignStyle.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
					.rotationEffect(.degrees(-90))
				Image(systemName: progress >= 0.75 ? "archivebox" : "stop.fill")
					.font(.system(size: 9, weight: .bold))
					.foregroundStyle(NullSignStyle.accent)
			}
			.frame(width: 33, height: 33)
			.frame(width: 44, height: 44)
		}
		.buttonStyle(.plain)
		.disabled(progress > 0.75)
		.accessibilityLabel(progress >= 0.75 ? "Preparing app" : "Cancel download")
		.accessibilityValue("\(Int(progress * 100)) percent")
	}
}
