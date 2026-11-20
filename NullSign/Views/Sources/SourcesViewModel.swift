//
//  SourcesViewModel.swift
//  NullSign
//
//  Created by samara on 30.04.2025.
//

import Foundation
import AltSourceKit
import SwiftUI
import NimbleJSON
import OSLog

// MARK: - Class
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()

	typealias RepositoryDataHandler = Result<ASRepository, Error>

	private let _dataService = NBFetchService()

	/// `true` when no load is in progress (idle).
	@Published var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	/// Sources (by URL) whose last refresh failed. Their saved copy is still
	/// shown, so the card says it's out of date.
	@Published private(set) var refreshFailures: Set<String> = []

	/// The single in-flight load. All loads are serialized through this.
	private var currentFetchTask: Task<Void, Never>?
	/// Source URLs of the last completed load; skips re-fetching an identical set.
	private var lastLoadedKey: Set<String>?
	private var backgroundTaskManager: BackgroundTaskManager?

	private func key(for sources: [AltSource]) -> Set<String> {
		Set(sources.compactMap { $0.sourceURL?.absoluteString })
	}

	@MainActor
	func refreshStale(_ sources: [AltSource]) async {
		if currentFetchTask == nil {
			lastLoadedKey = nil
		}
		await fetchSources(sources)
	}

	/// Loads every source's repository. Concurrent calls are serialized and coalesced.
	@MainActor
	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		await fetchSources(Array(sources), refresh: refresh, batchSize: batchSize)
	}

	@MainActor
	func fetchSources(_ sourcesArray: [AltSource], refresh: Bool = false, batchSize: Int = 4) async {
		let newKey = key(for: sourcesArray)

		// Coalesce: wait out any in-flight load. The task self-clears in its own
		// defer so awaiters exit instead of busy-spinning the main actor (0x8BADF00D).
		while let running = currentFetchTask {
			await running.value
		}

		// Same source set already loaded — skip (pull-to-refresh bypasses this).
		if !refresh, newKey == lastLoadedKey {
			return
		}

		let task = Task {
			defer { self.currentFetchTask = nil }
			await self._performFetch(sourcesArray, key: newKey, force: refresh, batchSize: batchSize)
		}
		currentFetchTask = task
		await task.value
	}

	@MainActor
	private func _performFetch(_ sourcesArray: [AltSource], key: Set<String>, force: Bool, batchSize: Int) async {
		let startedAt = Date()
		isFinished = false

		if backgroundTaskManager == nil {
			backgroundTaskManager = BackgroundTaskManager(
				taskName: "SourcesViewModel",
				expirationTitle: "Loading repositories",
				expirationBody: "Repository loading will continue when you reopen the app"
			)
			backgroundTaskManager?.start()
		}

		defer {
			lastLoadedKey = key
			isFinished = true
			backgroundTaskManager?.stop()
			backgroundTaskManager = nil
		}

		// Read CoreData (AltSource) fields on the main actor — it's not thread-safe.
		struct FetchItem {
			let source: AltSource
			let url: URL
			var cachedAt: Date?
		}

		var items: [FetchItem] = sourcesArray.compactMap { source in
			guard let url = source.sourceURL else {
				Logger.misc.error("Source has no URL: \(source.name ?? "Unknown", privacy: .public)")
				return nil
			}
			return FetchItem(source: source, url: url)
		}

		Logger.misc.info("fetchSources START: \(items.count, privacy: .public) sources")

		let service = _dataService
		// Publish into a working copy cumulatively so `sources` is never blanked mid-load.
		var working: [AltSource: ASRepository] = [:]

		let cacheEnabled = SourceCache.isEnabled

		for item in items {
			working[item.source] = sources[item.source]
		}

		if cacheEnabled {
			// Small sources shouldn't wait on huge catalogs.
			await withTaskGroup(of: (index: Int, date: Date, repo: ASRepository)?.self) { group in
				for (index, item) in items.enumerated() {
					let url = item.url
					group.addTask(priority: .userInitiated) {
						guard
							let hit = SourceCache.data(for: url),
							let repo = try? JSONDecoder().decode(ASRepository.self, from: hit.data)
						else {
							return nil
						}
						return (index, hit.date, repo)
					}
				}

				for await hit in group {
					guard let hit else { continue }
					let source = items[hit.index].source
					items[hit.index].cachedAt = hit.date
					if working[source] == nil {
						working[source] = hit.repo
						sources = working
					}
				}
			}
		}
		sources = working

		if cacheEnabled {
			items = items.filter { item in
				force || item.cachedAt.map(SourceCache.isStale) ?? true
			}
		}

		// Keep a few requests in flight at all times, so one slow or large
		// source never holds the rest back, and publish each as it lands.
		let maxInFlight = max(batchSize, 6)
		let requests: [(url: URL, requestURL: URL, headers: [String: String], cacheURL: URL?)] = items.map { item in
			(
				url: item.url,
				// A pull to refresh asks for a fresh file, past any server cache.
				requestURL: force ? SourceRefresh.freshURL(for: item.url) : item.url,
				headers: force ? SourceRefresh.noCacheHeaders : [:],
				cacheURL: cacheEnabled ? item.url : nil
			)
		}

		await withTaskGroup(of: (Int, ASRepository?).self) { group in
			var next = 0

			func apply(_ index: Int, _ repo: ASRepository?) {
				let key = items[index].url.absoluteString
				if let repo {
					working[items[index].source] = repo
					refreshFailures.remove(key)
				} else {
					refreshFailures.insert(key)
				}
				sources = working
			}

			while next < requests.count {
				// Child tasks touch only Sendable values, never the NSManagedObject.
				let index = next
				let request = requests[index]
				next += 1

				group.addTask {
					let repo: ASRepository? = await withCheckedContinuation { continuation in
						service.fetch(from: request.requestURL, headers: request.headers, onData: { data in
							if let cacheURL = request.cacheURL { SourceCache.store(data, for: cacheURL) }
						}) { (result: RepositoryDataHandler) in
							switch result {
							case .success(let repo):
								continuation.resume(returning: repo)
							case .failure(let error):
								Logger.misc.error("Source fetch FAILED \(request.url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
								continuation.resume(returning: nil)
							}
						}
					}
					return (index, repo)
				}

				// Wait for one to finish before starting another.
				guard next >= maxInFlight, let finished = await group.next() else { continue }
				apply(finished.0, finished.1)
			}

			for await finished in group {
				apply(finished.0, finished.1)
			}
		}

		Logger.misc.info("fetchSources DONE: \(working.count, privacy: .public)/\(items.count, privacy: .public) loaded")

		// Keep manual pull-to-refresh feedback visible briefly on fast repos so
		// the spinner and updating status don't flash and disappear immediately.
		if force {
			let elapsed = Date().timeIntervalSince(startedAt)
			let minimumDwell: TimeInterval = 0.45
			if elapsed < minimumDwell {
				try? await Task.sleep(nanoseconds: UInt64((minimumDwell - elapsed) * 1_000_000_000))
			}
		}
	}
}

// MARK: - Fresh refreshes
/// Servers and CDNs can hand back a cached source for minutes after it
/// changed. A pull to refresh asks past that.
enum SourceRefresh {
	static let noCacheHeaders = ["Cache-Control": "no-cache", "Pragma": "no-cache"]

	/// GitHub's raw files, Gists and Pages are cached by their full address
	/// and ignore a no-cache request, so a throwaway query gets a fresh copy.
	/// Other hosts keep their address: some sign it, and a changed one fails.
	static func freshURL(for url: URL) -> URL {
		guard
			let host = url.host?.lowercased(),
			host == "raw.githubusercontent.com" || host == "gist.githubusercontent.com" || host.hasSuffix(".github.io"),
			var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
		else {
			return url
		}
		var items = components.queryItems ?? []
		items.append(URLQueryItem(name: "nullsign-refresh", value: String(Int(Date().timeIntervalSince1970))))
		components.queryItems = items
		return components.url ?? url
	}
}
