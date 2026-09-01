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
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()
	
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	
	private let _dataService = NBFetchService()
	private var _pendingRefresh = false
	private var _pendingSources: [AltSource]?
	
	var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	@Published private(set) var isFetching = false
	@Published private(set) var failedSourceURLs: Set<URL> = []
	
	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		await fetchSources(Array(sources), refresh: refresh, batchSize: batchSize)
	}

	func fetchSources(_ sources: [AltSource], refresh: Bool = false, batchSize: Int = 4) async {
		guard isFinished else {
			_pendingSources = sources
			_pendingRefresh = _pendingRefresh || refresh
			return
		}
		
		// check if sources to be fetched are the same as before, if yes, return
		// also skip check if refresh is true
		if !refresh, sources.allSatisfy({ self.sources[$0] != nil }) { return }
		
		// isfinished is used to prevent multiple fetches at the same time
		isFinished = false
		await MainActor.run {
			self.isFetching = true
			self.failedSourceURLs = []
		}
		defer {
			isFinished = true
			let pendingSources = _pendingSources
			let shouldRefreshAgain = _pendingRefresh
			_pendingSources = nil
			_pendingRefresh = false
			Task { @MainActor in
				self.isFetching = false
				if let pendingSources {
					await self.fetchSources(pendingSources, refresh: shouldRefreshAgain, batchSize: batchSize)
				}
			}
		}
		
		let sourcesArray = sources
		
		for startIndex in stride(from: 0, to: sourcesArray.count, by: batchSize) {
			let endIndex = min(startIndex + batchSize, sourcesArray.count)
			let batch = Array(sourcesArray[startIndex..<endIndex])
			let requests = batch.enumerated().map { (index: $0.offset, url: $0.element.sourceURL) }
			
			let batchResults = await withTaskGroup(of: (Int, Result<ASRepository, Error>).self) { group in
				for request in requests {
					group.addTask {
						guard let url = request.url else {
							return (request.index, .failure(URLError(.badURL)))
						}
						
						return await withCheckedContinuation { continuation in
							self._dataService.fetch(from: url) { (result: RepositoryDataHandler) in
								continuation.resume(returning: (request.index, result))
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
			
			await MainActor.run {
				for (index, result) in batchResults {
					let source = batch[index]
					switch result {
					case .success(let repo):
						self.sources[source] = repo
						if let url = source.sourceURL {
							self.failedSourceURLs.remove(url)
						}
					case .failure:
						if let url = source.sourceURL {
							self.failedSourceURLs.insert(url)
						}
					}
				}
			}
		}
	}
}
