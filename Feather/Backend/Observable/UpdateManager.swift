//
//  UpdateManager.swift
//  Feather
//
//  Created by Dominic on 24.05.2026.
//

import AltSourceKit
import CoreData
import Foundation
import NimbleJSON

struct AppUpdate: Identifiable, Equatable {
	let id: String
	let localUUID: String
	let localVersion: String?
	let remoteVersion: String
	let appName: String
	let bundleIdentifier: String
	let downloadURL: URL
	let sourceURL: URL
	let sourceProvenance: SourceAppProvenance
}

@MainActor
final class UpdateManager: ObservableObject {
	static let shared = UpdateManager()

	typealias RepositoryDataHandler = Result<ASRepository, Error>

	@Published private(set) var updates: [String: AppUpdate] = [:]
	@Published private(set) var isChecking = false
	@Published private(set) var lastCheckedDate: Date?

	private let _dataService = NBFetchService()

	private init() {}

	func update(for app: AppInfoPresentable) -> AppUpdate? {
		guard let uuid = app.uuid else { return nil }
		return updates[uuid]
	}

	func checkForUpdates(
		sources: [AltSource],
		localApps: [AppInfoPresentable]
	) async {
		guard !isChecking else { return }

		isChecking = true
		defer {
			isChecking = false
			lastCheckedDate = Date()
		}

		// Everything needed from Core Data is read before the network fetch
		// suspends this task: apps and sources can be deleted while it runs.
		let sourceURLs = sources.compactMap(\.sourceURL)
		let snapshots = localApps.compactMap(LocalAppSnapshot.init)

		let repositories = await _fetchRepositories(from: sourceURLs)
		updates = _findUpdates(repositories: repositories, localApps: snapshots)
	}

	private func _fetchRepositories(from urls: [URL]) async -> [(URL, ASRepository)] {
		let requests = Array(urls.enumerated())
		var fetched: [(Int, ASRepository?)] = []

		// Keep checks quick without opening an unbounded number of connections for
		// users who have a large catalog list.
		for startIndex in stride(from: 0, to: requests.count, by: 4) {
			let endIndex = min(startIndex + 4, requests.count)
			let batch = requests[startIndex..<endIndex]
			let batchResults = await withTaskGroup(of: (Int, ASRepository?).self) { group in
				for (index, url) in batch {
					group.addTask {
						(index, await self._fetchRepository(from: url))
					}
				}

				var results: [(Int, ASRepository?)] = []
				for await result in group {
					results.append(result)
				}
				return results
			}
			fetched.append(contentsOf: batchResults)
		}

		return fetched
			.sorted { $0.0 < $1.0 }
			.compactMap { index, repository in
				guard let repository else { return nil }
				return (urls[index], repository)
			}
	}

	private func _fetchRepository(from url: URL) async -> ASRepository? {
		await withCheckedContinuation { continuation in
			_dataService.fetch(from: url) { (result: RepositoryDataHandler) in
				switch result {
				case .success(let repository):
					continuation.resume(returning: repository)
				case .failure:
					continuation.resume(returning: nil)
				}
			}
		}
	}

	private func _findUpdates(
		repositories: [(URL, ASRepository)],
		localApps: [LocalAppSnapshot]
	) -> [String: AppUpdate] {
		var foundUpdates: [String: AppUpdate] = [:]
		let metadataByUUID = Storage.shared.getSourceMetadata().reduce(into: [String: AppSourceMetadata]()) {
			$0[$1.appUUID] = $1
		}
		let metadataCandidates = localApps.compactMap { app -> SourceMetadataCandidate? in
			guard let metadata = metadataByUUID[app.uuid] else {
				return nil
			}
			return SourceMetadataCandidate(app: app, metadata: metadata)
		}

		for localApp in localApps {
			let localUUID = localApp.uuid

			let sourceAppIdentifier: String
			let sourceAppVersion: String?
			let storedSourceURL: URL
			if let directMetadata = metadataByUUID[localUUID] {
				guard
					let metadataSourceAppIdentifier = directMetadata.sourceAppIdentifier,
					let metadataSourceURL = directMetadata.sourceRepositoryURL
				else {
					continue
				}

				sourceAppIdentifier = metadataSourceAppIdentifier
				sourceAppVersion = directMetadata.sourceAppVersion
				storedSourceURL = metadataSourceURL
			} else if let fallback = _fallbackMetadataCandidate(
				for: localApp,
				candidates: metadataCandidates
			) {
				guard
					let metadataSourceAppIdentifier = fallback.metadata.sourceAppIdentifier,
					let metadataSourceURL = fallback.metadata.sourceRepositoryURL
				else {
					continue
				}

				sourceAppIdentifier = metadataSourceAppIdentifier
				sourceAppVersion = fallback.metadata.sourceAppVersion
				storedSourceURL = metadataSourceURL
				Storage.shared.copySourceMetadata(
					from: fallback.app.uuid,
					to: localUUID,
					kind: localApp.isSigned ? .signed : .imported
				)
			} else if
				let localSourceURL = localApp.source,
				let localIdentifier = localApp.identifier
			{
				sourceAppIdentifier = localIdentifier
				sourceAppVersion = localApp.version
				storedSourceURL = localSourceURL
			} else {
				continue
			}

			for (sourceURL, repository) in repositories {
				guard _matchesStoredRepository(storedSourceURL: storedSourceURL, sourceURL: sourceURL) else {
					continue
				}

				guard let remoteApp = repository.apps.first(where: { $0.id == sourceAppIdentifier }) else {
					continue
				}

				guard let remoteVersion = remoteApp.currentVersion, !remoteVersion.isEmpty else {
					continue
				}

				guard
					let installedVersion = sourceAppVersion ?? localApp.version,
					_isVersion(remoteVersion, newerThan: installedVersion)
				else {
					continue
				}

				guard let downloadURL = remoteApp.currentDownloadUrl else {
					continue
				}

				guard let provenance = SourceAppProvenance(
					sourceURL: sourceURL,
					repository: repository,
					app: remoteApp
				) else {
					continue
				}

				foundUpdates[localUUID] = AppUpdate(
					id: localUUID,
					localUUID: localUUID,
					localVersion: sourceAppVersion ?? localApp.version,
					remoteVersion: remoteVersion,
					appName: remoteApp.currentName,
					bundleIdentifier: sourceAppIdentifier,
					downloadURL: downloadURL,
					sourceURL: sourceURL,
					sourceProvenance: provenance
				)
				break
			}
		}

		return foundUpdates
	}

	private func _matchesStoredRepository(
		storedSourceURL: URL,
		sourceURL: URL
	) -> Bool {
		_normalizedSourceURL(storedSourceURL) == _normalizedSourceURL(sourceURL)
	}

	private func _normalizedSourceURL(_ url: URL) -> String {
		var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
		let scheme = components?.scheme?.lowercased()
		let host = components?.host?.lowercased()
		components?.scheme = scheme
		components?.host = host
		components?.fragment = nil

		let normalized = components?.url ?? url
		let absoluteString = normalized.absoluteString
		return absoluteString.hasSuffix("/") ? String(absoluteString.dropLast()) : absoluteString
	}

	private func _isVersion(_ candidate: String, newerThan installed: String) -> Bool {
		candidate.compare(installed, options: [.numeric, .caseInsensitive]) == .orderedDescending
	}

	private func _fallbackMetadataCandidate(
		for localApp: LocalAppSnapshot,
		candidates: [SourceMetadataCandidate]
	) -> SourceMetadataCandidate? {
		guard
			localApp.isSigned,
			let localIdentifier = localApp.identifier,
			let localVersion = localApp.version
		else {
			return nil
		}

		return candidates.first {
			$0.app.uuid != localApp.uuid &&
			!$0.app.isSigned &&
			$0.app.identifier == localIdentifier &&
			$0.app.version == localVersion
		}
	}
}

/// Plain values copied out of a managed object before any suspension point.
private struct LocalAppSnapshot {
	let uuid: String
	let identifier: String?
	let version: String?
	let source: URL?
	let isSigned: Bool

	init?(_ app: AppInfoPresentable) {
		guard let uuid = app.uuid else { return nil }
		self.uuid = uuid
		self.identifier = app.identifier
		self.version = app.version
		self.source = app.source
		self.isSigned = app.isSigned
	}
}

private struct SourceMetadataCandidate {
	let app: LocalAppSnapshot
	let metadata: AppSourceMetadata
}
