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
		let failedDownload = downloadManager.downloads.first { $0.failure != nil }

		ZStack {
			if let failedDownload {
				VStack(alignment: .leading, spacing: 8) {
					HStack(spacing: 10) {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundStyle(NullSignStyle.danger)
						Text("Couldn't Import \(failedDownload.fileName)")
							.font(.roundedUI(.subheadline, weight: .bold))
						Spacer(minLength: 0)
						Button("Dismiss") { downloadManager.cancelDownload(failedDownload) }
							.buttonStyle(NullSignSecondaryButtonStyle(height: 34))
					}
					Text(failedDownload.failure ?? "Choose the original IPA and try again.")
						.font(.roundedUI(.caption))
						.foregroundStyle(NullSignStyle.muted)
						.fixedSize(horizontal: false, vertical: true)
				}
				.padding(14)
				.nullSignSurface(fill: NullSignStyle.groupedSurface)
				.padding(.horizontal, 20)
				.padding(.vertical, 6)
			} else if let firstDownload = manualDownloads.first {
				HStack(spacing: 12) {
					DownloadItemView(download: firstDownload)
					if manualDownloads.count > 1 {
						NullSignChip(text: "+\(manualDownloads.count - 1)")
					}
				}
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.nullSignSurface(fill: NullSignStyle.groupedSurface)
				.padding(.horizontal, 20)
				.padding(.top, 4)
				.padding(.bottom, 6)
				.transition(_reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(_reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: downloadManager.manualDownloads.count)
	}
}

struct DownloadItemView: View {
	@ObservedObject var download: Download

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				NullSignRing(progress: overallProgress, size: 32, lineWidth: 3, tint: NullSignStyle.accent)
				Image(systemName: download.onlyArchiving ? "shippingbox.fill" : "arrow.down")
					.font(.roundedUI(size: 11, weight: .bold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(download.fileName)
					.font(.roundedUI(.subheadline, weight: .bold))
					.lineLimit(1)

				HStack(spacing: 6) {
					Text(verbatim: "\(Int(overallProgress * 100))%")
					if download.totalBytes > 0 {
						Text(verbatim: "\(download.bytesDownloaded.formattedByteCount) of \(download.totalBytes.formattedByteCount)")
					} else if download.onlyArchiving {
						Text("Preparing")
					}
				}
				.font(.roundedUI(.caption))
				.monospacedDigit()
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
