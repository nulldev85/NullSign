//
//  AllVersionsView.swift
//  NullSign
//
//  Created by Ryuk on 05.07.2026.
//

import SwiftUI
import NimbleViews

/// Every NullSign release in NullSign's app source, to update, reinstall or
/// go back to one.
struct AllVersionsView: View {
	@ObservedObject private var _manager = SelfUpdateManager.shared

	@State private var _search = ""
	@State private var _selected: SelfUpdateRelease?
	@State private var _newestFirst = true

	private var _filtered: [SelfUpdateRelease] {
		var list = _manager.releases
		if !_search.isEmpty {
			list = list.filter {
				$0.label.localizedCaseInsensitiveContains(_search) ||
				$0.notes.localizedCaseInsensitiveContains(_search)
			}
		}
		return _newestFirst ? list : Array(list.reversed())
	}

	var body: some View {
		NBList(.localized("All Versions"), type: .list) {
			ForEach(_filtered) { release in
				Button { _selected = release } label: { _row(release) }
					.tint(.primary)
					.listRowBackground(release.isInstalled ? NullSignStyle.accent.opacity(0.12) : NullSignStyle.groupedSurface)
			}
		}
		.overlay { _overlay }
		.searchable(text: $_search, placement: .navigationBarDrawer(displayMode: .always))
		.refreshable { await _manager.check() }
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Picker(.localized("Sort"), selection: $_newestFirst) {
						Text(.localized("Newest First")).tag(true)
						Text(.localized("Oldest First")).tag(false)
					}
				} label: {
					Image(systemName: "line.3.horizontal.decrease")
				}
			}
		}
		.sheet(item: $_selected) { release in
			SelfUpdateSheet(release: release, offersReminders: false)
		}
		.task {
			if _manager.releases.isEmpty { await _manager.check() }
		}
	}

	@ViewBuilder
	private var _overlay: some View {
		if _manager.releases.isEmpty {
			if _manager.isChecking {
				ProgressView()
			} else if let error = _manager.lastError {
				NBContentUnavailable(.localized("Couldn't Load Versions"), systemImage: "wifi.slash", description: error)
			}
		} else if _filtered.isEmpty {
			NBContentUnavailable(.localized("No Results"), systemImage: "magnifyingglass", description: .localized("No versions match your search."))
		}
	}

	private func _row(_ release: SelfUpdateRelease) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 2) {
				HStack(spacing: 6) {
					Text(release.label).font(.body.weight(.medium))
					if release.id == _manager.latest?.id {
						_pill(.localized("Latest"), color: NullSignStyle.accent)
					}
				}
				if let date = release.publishedAt {
					Text(date.formatted(date: .abbreviated, time: .omitted))
						.font(.caption).foregroundStyle(.secondary)
				}
			}
			Spacer()
			_badge(release)
		}
	}

	private func _pill(_ text: String, color: Color) -> some View {
		Text(text)
			.font(.caption2.bold())
			.foregroundStyle(color)
			.padding(.horizontal, 5).padding(.vertical, 1)
			.background(color.opacity(0.15)).clipShape(Capsule())
	}

	@ViewBuilder
	private func _badge(_ release: SelfUpdateRelease) -> some View {
		let order = release.orderAgainstInstalled
		if order == .orderedSame {
			Label(.localized("Installed"), systemImage: "checkmark.circle.fill")
				.labelStyle(.titleAndIcon)
				.font(.caption.bold())
				.foregroundStyle(NullSignStyle.accent)
		} else if order == .orderedDescending {
			Image(systemName: "arrow.up.circle.fill").foregroundStyle(NullSignStyle.accent)
		} else {
			Image(systemName: "arrow.down.circle").foregroundStyle(.secondary)
		}
	}
}
