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
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var body: some View {
		let manualDownloads = downloadManager.manualDownloads

		ZStack {
			if !manualDownloads.isEmpty {
				VStack(spacing: 0) {
					if let firstDownload = manualDownloads.first {
						HStack(spacing: 12) {
							Image(systemName: "arrow.down")
								.font(.system(size: 13, weight: .bold))
								.foregroundStyle(.black)
								.frame(width: 28, height: 28)
								.background(NullSignStyle.accent)
								.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
							DownloadItemView(download: firstDownload)
							if manualDownloads.count > 1 {
								Text(verbatim: "+\(manualDownloads.count - 1)")
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
				.transition(_reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(_reduceMotion ? nil : .spring(), value: downloadManager.manualDownloads.count)
	}
}

struct DownloadItemView: View {
	@ObservedObject var download: Download
	
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
				if download.totalBytes > 0 {
					Text(verbatim: "\(download.bytesDownloaded.formattedByteCount) / \(download.totalBytes.formattedByteCount)")
						.contentTransition(.numericText())
				}
			}
			.font(.caption)
			.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity)
		.accessibilityValue("\(Int(overallProgress * 100)) percent")
	}
	
	private var overallProgress: Double {
		min(max(download.overallProgress, 0), 1)
	}
}
