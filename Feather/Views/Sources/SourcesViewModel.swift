//
//  SourcesViewModel.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import Foundation
import AltSourceKit
import SwiftUI
import NimbleJSON

// MARK: - Class
/// Main-actor isolated: sources are Core Data objects owned by the main
/// context, so their URLs are read here and only plain URLs cross over to
/// the network tasks.
@MainActor
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()

	typealias RepositoryDataHandler = Result<ASRepository, Error>

	private let _dataService = NBFetchService()
	private var _pendingRefresh = false
	private var _pendingSources: [AltSource]?
	private var _isFinished = true

	@Published var sources: [AltSource: ASRepository] = [:]
	@Published private(set) var isFetching = false
	@Published private(set) var failedSourceURLs: Set<URL> = []

	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		await fetchSources(Array(sources), refresh: refresh, batchSize: batchSize)
	}

	func fetchSources(_ sources: [AltSource], refresh: Bool = false, batchSize: Int = 4) async {
		// One fetch at a time; the latest request is replayed when it finishes.
		guard _isFinished else {
			_pendingSources = sources
			_pendingRefresh = _pendingRefresh || refresh
			return
		}

		let liveSources = sources.filter { !$0.isDeleted && $0.managedObjectContext != nil }

		// check if sources to be fetched are the same as before, if yes, return
		// also skip check if refresh is true
		if !refresh, liveSources.allSatisfy({ self.sources[$0] != nil }) { return }

		_isFinished = false
		isFetching = true
		failedSourceURLs = []

		let requests = liveSources.map { (source: $0, url: $0.sourceURL) }
		let dataService = _dataService
		let step = max(batchSize, 1)

		for startIndex in stride(from: 0, to: requests.count, by: step) {
			let endIndex = min(startIndex + step, requests.count)
			let batch = Array(requests[startIndex..<endIndex])
			let urls = batch.map { $0.url }

			let batchResults = await withTaskGroup(of: (Int, Result<ASRepository, Error>).self) { group in
				for (index, url) in urls.enumerated() {
					group.addTask {
						guard let url else {
							return (index, .failure(URLError(.badURL)))
						}

						return await withCheckedContinuation { continuation in
							dataService.fetch(from: url) { (result: Result<ASRepository, Error>) in
								continuation.resume(returning: (index, result))
							}
						}
					}
				}

				var results: [(Int, Result<ASRepository, Error>)] = []
				for await result in group {
					results.append(result)
				}
				return results
			}

			for (index, result) in batchResults {
				let request = batch[index]
				switch result {
				case .success(let repo):
					self.sources[request.source] = repo
					if let url = request.url {
						failedSourceURLs.remove(url)
					}
				case .failure:
					if let url = request.url {
						failedSourceURLs.insert(url)
					}
				}
			}
		}

		_isFinished = true
		isFetching = false

		if let pendingSources = _pendingSources {
			let shouldRefreshAgain = _pendingRefresh
			_pendingSources = nil
			_pendingRefresh = false
			await fetchSources(pendingSources, refresh: shouldRefreshAgain, batchSize: batchSize)
		}
	}
}
