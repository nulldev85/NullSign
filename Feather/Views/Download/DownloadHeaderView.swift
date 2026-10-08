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
			if let firstDownload = manualDownloads.first {
				HStack(spacing: 12) {
					DownloadItemView(download: firstDownload)
					if manualDownloads.count > 1 {
						NullSignChip(text: "+\(manualDownloads.count - 1)", tint: NullSignStyle.accentHighlight)
					}
				}
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.background(Capsule().fill(.ultraThinMaterial))
				.background(Capsule().fill(Color.black.opacity(0.35)))
				.overlay(Capsule().strokeBorder(NullSignStyle.edge, lineWidth: 1))
				.shadow(color: .black.opacity(0.5), radius: 14, y: 6)
				.padding(.horizontal, 14)
				.padding(.top, 4)
				.padding(.bottom, 6)
				.transition(_reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(_reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82), value: downloadManager.manualDownloads.count)
	}
}

struct DownloadItemView: View {
	@ObservedObject var download: Download

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				NullSignRing(progress: overallProgress, size: 34, lineWidth: 3.5, tint: .white, showsSignalDot: overallProgress > 0)
				Image(systemName: download.onlyArchiving ? "shippingbox.fill" : "arrow.down")
					.font(.system(size: 11, weight: .heavy))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text(download.fileName)
					.font(.system(size: 13, weight: .semibold))
					.lineLimit(1)

				HStack(spacing: 6) {
					Text(verbatim: "\(Int(overallProgress * 100))%")
						.contentTransition(.numericText())
					if download.totalBytes > 0 {
						Text(verbatim: "\(download.bytesDownloaded.formattedByteCount) / \(download.totalBytes.formattedByteCount)")
							.contentTransition(.numericText())
					} else if download.onlyArchiving {
						Text("Preparing")
					}
				}
				.font(NullSignStyle.mono(10, weight: .medium))
				.foregroundStyle(NullSignStyle.muted)
				.lineLimit(1)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .combine)
		.accessibilityValue("\(Int(overallProgress * 100)) percent")
	}

	private var overallProgress: Double {
		min(max(download.overallProgress, 0), 1)
	}
}
