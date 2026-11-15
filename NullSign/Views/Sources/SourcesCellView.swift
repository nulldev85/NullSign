//
//  SourcesCellView.swift
//  NullSign
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import AltSourceKit

// MARK: - View
/// A repository as a NullSign card: its icon, name, host and how many apps it
/// lists, with NullSign's favorite, hide-from-All, copy and delete actions.
struct SourcesCellView: View {
	@ObservedObject private var _viewModel = SourcesViewModel.shared
	@ObservedObject private var _favorites = SourceFavorites.shared

	var source: AltSource
	var isEditMode: Bool = false

	@State private var _isExcluded: Bool = false

	private var _sourceIdentifier: String {
		source.identifier ?? source.sourceURL?.absoluteString ?? ""
	}

	private var _repository: ASRepository? {
		_viewModel.sources[source]
	}

	// MARK: Body
	var body: some View {
		let card = HStack(spacing: 12) {
			SourceRemoteIcon(
				url: _repository?.currentIconURL ?? source.iconURL,
				relativeTo: source.sourceURL,
				size: 46,
				fallbackAssetName: SourceBundledIcon.assetName(for: _repository)
			)

			VStack(alignment: .leading, spacing: 2) {
				HStack(spacing: 6) {
					Text(source.name ?? _repository?.name ?? .localized("Unknown"))
						.font(.roundedUI(.headline))
						.foregroundStyle(.white)
						.lineLimit(1)
					if _favorites.contains(source) {
						Image(systemName: "star.fill")
							.font(.roundedUI(size: 11, weight: .bold))
							.foregroundStyle(NullSignStyle.yellow)
							.accessibilityLabel(.localized("Favorite"))
					}
				}

				Text(_displayHost)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)

				_status
					.padding(.top, 2)
			}

			Spacer(minLength: 8)

			if !isEditMode {
				Image(systemName: "chevron.right")
					.font(.roundedUI(.footnote, weight: .semibold))
					.foregroundStyle(NullSignStyle.faint)
			}
		}
		.padding(16)
		.nullSignSurface()
		.contentShape(RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous))
		.onAppear { _isExcluded = SourceExclusions.isExcluded(_sourceIdentifier) }

		if isEditMode {
			card
		} else {
			card
				.swipeActions(edge: .leading) {
					_favoriteAction()
				}
				.swipeActions {
					_actions(for: source)
					_excludeAction()
					_contextActions(for: source)
				}
				.contextMenu {
					_favoriteAction()
					_contextActions(for: source)
					_excludeAction()
					Divider()
					_actions(for: source)
				}
		}
	}
}

// MARK: - Extension: View
extension SourcesCellView {
	@ViewBuilder
	private var _status: some View {
		HStack(spacing: 6) {
			if _repository == nil && !_viewModel.isFinished {
				ProgressView()
					.controlSize(.mini)
			} else {
				Circle()
					.fill(_repository == nil ? NullSignStyle.danger : NullSignStyle.success)
					.frame(width: 6, height: 6)
			}
			Text(_statusText)
				.font(.roundedUI(.caption))
				.foregroundStyle(_repository == nil && _viewModel.isFinished ? NullSignStyle.danger : NullSignStyle.muted)
				.lineLimit(1)
			if _isExcluded {
				Text("· \(String.localized("Hidden from All"))")
					.font(.roundedUI(.caption))
					.foregroundStyle(NullSignStyle.faint)
					.lineLimit(1)
			}
		}
	}

	private var _statusText: String {
		guard let repository = _repository else {
			return _viewModel.isFinished ? "Couldn't load · pull to retry" : "Updating…"
		}
		return repository.apps.count == 1 ? "1 app" : "\(repository.apps.count.formatted()) apps"
	}

	private var _displayHost: String {
		guard let url = source.sourceURL else { return .localized("Repository") }
		return url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
	}

	private func _favoriteAction() -> some View {
		let isFavorite = _favorites.contains(source)
		return Button {
			_favorites.toggle(source)
		} label: {
			Label(
				isFavorite ? .localized("Unfavorite") : .localized("Favorite"),
				systemImage: isFavorite ? "star.slash" : "star"
			)
		}
		.tint(NullSignStyle.yellow)
	}

	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
		.tint(NullSignStyle.danger)
	}

	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy Source URL"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
			UINotificationFeedbackGenerator().notificationOccurred(.success)
		}
		.tint(NullSignStyle.accent)
	}

	@ViewBuilder
	private func _excludeAction() -> some View {
		Button {
			let newValue = !_isExcluded
			SourceExclusions.setExcluded(_sourceIdentifier, excluded: newValue)
			_isExcluded = newValue
		} label: {
			Label(
				_isExcluded ? .localized("Show in All") : .localized("Hide from All"),
				systemImage: _isExcluded ? "eye" : "eye.slash"
			)
		}
		.tint(NullSignStyle.warning)
	}
}
