//
//  DownloadHeaderView.swift
//  Feather
//
//  Created by samara on 16.05.2025.
//

import SwiftUI
import Combine
import NimbleExtensions

struct DownloadHeaderView: View {
	@ObservedObject var downloadManager: DownloadManager
	
	var body: some View {
		ZStack {
			if !downloadManager.manualDownloads.isEmpty {
				VStack(spacing: 0) {
					if let firstDownload = downloadManager.manualDownloads.first {
						HStack(spacing: 12) {
							Image(systemName: "arrow.down")
								.font(.system(size: 13, weight: .bold))
								.foregroundStyle(.black)
								.frame(width: 28, height: 28)
								.background(NullSignStyle.accent)
								.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
							DownloadItemView(download: firstDownload)
							if downloadManager.manualDownloads.count > 1 {
								Text(verbatim: "+\(downloadManager.manualDownloads.count - 1)")
									.font(.caption.weight(.semibold))
									.foregroundStyle(NullSignStyle.accent)
							}
						}
						.padding(12)
						.background(NullSignStyle.panel)
						.overlay(alignment: .bottom) {
							Rectangle().fill(NullSignStyle.hairline).frame(height: 1)
						}
					}
				}
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(.spring(), value: downloadManager.manualDownloads.count)
	}
}

struct DownloadItemView: View {
	let download: Download
	@State private var progress: Double = 0
	@State private var bytesDownloaded: Int64 = 0
	@State private var totalBytes: Int64 = 0
	@State private var unpackageProgress: Double = 0
	
	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			Text(download.fileName)
				.font(.subheadline.weight(.semibold))
				.lineLimit(1)
			
			ProgressView(value: overallProgress)
				.progressViewStyle(.linear)
				.tint(NullSignStyle.accent)
			
			HStack {
				Text(verbatim: "\(Int(overallProgress * 100))%")
					.contentTransition(.numericText())
				Spacer()
				if totalBytes > 0 {
					Text(verbatim: "\($bytesDownloaded.wrappedValue.formattedByteCount) / \(totalBytes.formattedByteCount)")
						.contentTransition(.numericText())
				}
			}
			.font(.caption)
			.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity)
		.onReceive(download.$progress) { self.progress = $0 }
		.onReceive(download.$bytesDownloaded) { self.bytesDownloaded = $0 }
		.onReceive(download.$totalBytes) { self.totalBytes = $0 }
		.onReceive(download.$unpackageProgress) { self.unpackageProgress = $0 }
	}
	
	private var overallProgress: Double {
		download.onlyArchiving
			? unpackageProgress
			: (0.3 * unpackageProgress) + (0.7 * progress)
	}
}
