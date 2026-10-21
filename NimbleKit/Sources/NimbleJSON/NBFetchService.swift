//
//  FetchService.swift
//  Loader
//
//  Created by samara on 14.03.2025.
//

import Foundation

// MARK: - Class
public class NBFetchService {
	
	public enum NBFetchServiceError: Error, LocalizedError {
		case invalidURL
		case networkError(Error)
		case noData
		case parsingError(Error)
		
		public var errorDescription: String? {
			switch self {
			case .invalidURL: "The URL is invalid."
			case .networkError(let error): "Network error: \(error.localizedDescription)"
			case .noData: "No data received."
			case .parsingError(let error): "Failed to parse data: \(Self._describe(error))"
			}
		}

		/// Names the field that failed, e.g. "“caption” is missing in news[0].",
		/// so a source's author can find it.
		private static func _describe(_ error: any Error) -> String {
			guard let error = error as? DecodingError else {
				return error.localizedDescription
			}

			switch error {
			case .keyNotFound(let key, let context):
				return "“\(key.stringValue)” is missing in \(_path(context.codingPath))."
			case .valueNotFound(_, let context):
				return "\(_path(context.codingPath)) is empty or null."
			case .typeMismatch(_, let context):
				return "\(_path(context.codingPath)) has the wrong type."
			case .dataCorrupted(let context):
				return context.codingPath.isEmpty
					? "The response isn't valid JSON. Make sure the link points straight to the file, not a download page."
					: "\(_path(context.codingPath)) is invalid."
			@unknown default:
				return error.localizedDescription
			}
		}

		private static func _path(_ codingPath: [any CodingKey]) -> String {
			guard !codingPath.isEmpty else { return "the response" }
			return codingPath.reduce(into: "") { path, key in
				if let index = key.intValue {
					path += "[\(index)]"
				} else {
					path += path.isEmpty ? key.stringValue : ".\(key.stringValue)"
				}
			}
		}
	}
	
	public init() {}
}

// MARK: - Class extension: fetch
extension NBFetchService {
	public func fetch<T: Decodable>(
		from urlString: String,
		completion: @escaping (Result<T, Error>) -> Void
	) {
		guard let url = URL(string: urlString) else {
			completion(.failure(NBFetchServiceError.invalidURL))
			return
		}
		
		fetch(from: url, completion: completion)
	}
	
	public func fetch<T: Decodable>(
		from url: URL,
		completion: @escaping (Result<T, Error>) -> Void
	) {
		DispatchQueue.global(qos: .userInitiated).async {
			let task = URLSession.shared.dataTask(with: url) { data, response, error in
				if let error = error {
					completion(.failure(NBFetchServiceError.networkError(error)))
					return
				}
				
				guard let data = data else {
					completion(.failure(NBFetchServiceError.noData))
					return
				}
				
				do {
					let decoder = JSONDecoder()
					let decodedData = try decoder.decode(T.self, from: data)
					completion(.success(decodedData))
				} catch {
					completion(.failure(NBFetchServiceError.parsingError(error)))
				}
			}
			
			task.resume()
		}
	}
}
