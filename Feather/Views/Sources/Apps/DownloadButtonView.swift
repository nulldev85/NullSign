//
//  DownloadButtonView.swift
//  Feather
//
//  Created by samsam on 7/25/25.
//

import SwiftUI
import Combine
import AltSourceKit
import NimbleViews

struct DownloadButtonView: View {
	let sourceURL: URL?
	let source: ASRepository?
	let app: ASRepository.App
	@ObservedObject private var downloadManager = DownloadManager.shared

	@State private var downloadProgress: Double = 0
	@State private var cancellable: AnyCancellable?

	var body: some View {
		Group {
			if let currentDownload = downloadManager.getDownload(by: app.currentUniqueId) {
				Button {
					guard downloadProgress <= 0.75 else { return }
					downloadManager.cancelDownload(currentDownload)
				} label: {
					ZStack {
						Circle()
							.stroke(NullSignStyle.cyan.opacity(0.18), lineWidth: 2.5)
						Circle()
							.trim(from: 0, to: max(0.03, downloadProgress))
							.stroke(NullSignStyle.cyan, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
							.rotationEffect(.degrees(-90))
						Image(systemName: downloadProgress >= 0.75 ? "archivebox" : "stop.fill")
							.font(.system(size: 9, weight: .bold))
							.foregroundStyle(NullSignStyle.cyan)
					}
					.frame(width: 33, height: 33)
				}
				.buttonStyle(.plain)
				.disabled(downloadProgress > 0.75)
				.accessibilityLabel(downloadProgress >= 0.75 ? "Preparing app" : "Cancel download")
				.compatTransition()
			} else {
				Button {
					if let url = app.currentDownloadUrl {
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
						.background(NullSignStyle.cyan)
						.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
				}
				.buttonStyle(.borderless)
				.compatTransition()
			}
		}
		.onAppear(perform: setupObserver)
		.onDisappear { cancellable?.cancel() }
		.onChange(of: downloadManager.downloads.description) { _ in
			setupObserver()
		}
		.animation(.easeInOut(duration: 0.3), value: downloadManager.getDownload(by: app.currentUniqueId) != nil)
	}

	private func setupObserver() {
		cancellable?.cancel()
		guard let download = downloadManager.getDownload(by: app.currentUniqueId) else {
			downloadProgress = 0
			return
		}
		downloadProgress = download.overallProgress

		let publisher = Publishers.CombineLatest(
			download.$progress,
			download.$unpackageProgress
		)

		cancellable = publisher.sink { _, _ in
			downloadProgress = download.overallProgress
		}
	}
	
	private func _sourceProvenance() -> SourceAppProvenance? {
		guard let source else { return nil }
		return SourceAppProvenance(sourceURL: sourceURL, repository: source, app: app)
	}
}
