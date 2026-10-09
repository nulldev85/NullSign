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
						.frame(minWidth: 36)
				}
				.buttonStyle(NullSignSecondaryButtonStyle(height: 30))
				.frame(minHeight: 44)
				.disabled(app.currentDownloadUrl == nil)
				.compatTransition()
			}
		}
		.animation(.easeInOut(duration: 0.2), value: downloadManager.getDownload(by: app.currentUniqueId)?.id)
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
				NullSignRing(progress: max(0.03, progress), size: 30, lineWidth: 3, tint: NullSignStyle.accent)
				Image(systemName: progress >= 0.75 ? "archivebox.fill" : "stop.fill")
					.font(.system(size: 9, weight: .bold))
					.foregroundStyle(.white)
			}
			.frame(width: 44, height: 44)
		}
		.buttonStyle(.plain)
		.disabled(progress > 0.75)
		.accessibilityLabel(progress >= 0.75 ? "Preparing app" : "Cancel download")
		.accessibilityValue("\(Int(progress * 100)) percent")
	}
}
