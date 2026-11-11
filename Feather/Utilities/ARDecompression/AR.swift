//
//  SwiftAR.swift
//  SwiftAR
//
//  Created by nekohaxx on 8/18/24.
//

import Foundation

class AR: NSObject {
	private let _data: Data
	
	init(with url: URL) throws {
		self._data = try Data(contentsOf: url)
		super.init()
	}
	
	func extract() async throws -> [ARFileModel] {
		guard _data.count >= 8, _data.prefix(8) == Data("!<arch>\n".utf8) else {
			throw ARError.badArchive("Invalid magic")
		}

		var offset = 8
		var files: [ARFileModel] = []
		while offset < _data.count {
			// Validate lengths before constructing ranges: Data.subdata traps
			// rather than throwing when an archive declares bytes past EOF.
			guard _data.count - offset >= 60 else {
				throw ARError.badArchive("Truncated member header")
			}
			let contentStart = offset + 60
			let header = _data.subdata(in: offset..<contentStart)
			guard header[58] == 0x60, header[59] == 0x0a else {
				throw ARError.badArchive("Invalid member header")
			}
			let size = try _number(header, 48..<58, field: "size")
			guard size <= _data.count - contentStart else {
				throw ARError.badArchive("Truncated member content")
			}

			var name = try _text(header, 0..<16, field: "name")
			// Debian uses common ar names, optionally ending in a slash.
			if name.hasSuffix("/") { name.removeLast() }
			guard !name.isEmpty, name != ".", name != "..",
				!name.contains("/"), !name.contains("\\"), !name.contains("\0") else {
				throw ARError.badArchive("Invalid or unsupported member name")
			}
			let modified = try _number(header, 16..<28, field: "modification date")
			let owner = try _number(header, 28..<34, field: "owner")
			let group = try _number(header, 34..<40, field: "group")
			let mode = try _number(header, 40..<48, field: "mode", radix: 8)
			let contentEnd = contentStart + size
			files.append(ARFileModel(
				name: name,
				modificationDate: Date(timeIntervalSince1970: Double(modified)),
				ownerId: owner,
				groupId: group,
				mode: mode,
				size: size,
				content: _data.subdata(in: contentStart..<contentEnd)
			))
			offset = contentEnd
			if size % 2 != 0 {
				guard offset < _data.count, _data[offset] == 0x0a else {
					throw ARError.badArchive("Missing member padding")
				}
				offset += 1
			}
		}
		return files
	}

	private func _text(_ header: Data, _ range: Range<Int>, field: String) throws -> String {
		guard let value = String(data: header.subdata(in: range), encoding: .ascii) else {
			throw ARError.badArchive("Invalid \(field)")
		}
		return value.trimmingCharacters(in: CharacterSet(charactersIn: " "))
	}

	private func _number(_ header: Data, _ range: Range<Int>, field: String, radix: Int = 10) throws -> Int {
		let text = try _text(header, range, field: field)
		let digitLimit = UInt8(0x30 + radix)
		guard !text.isEmpty,
			text.utf8.allSatisfy({ $0 >= 0x30 && $0 < digitLimit }),
			let number = Int(text, radix: radix) else {
			throw ARError.badArchive("Invalid \(field)")
		}
		return number
	}
}

enum ARError: LocalizedError {
	case badArchive(String)

	var errorDescription: String? {
		switch self {
		case .badArchive(let reason):
			return "Invalid Debian package: \(reason). Import a complete, unmodified .deb file and try again."
		}
	}
}
