import Foundation

@main struct ARDecompressionTests {
	static let magic = Data("!<arch>\n".utf8)

	static func field(_ text: String, width: Int) -> Data {
		let bytes = Data(text.utf8)
		precondition(bytes.count <= width)
		return bytes + Data(repeating: 0x20, count: width - bytes.count)
	}

	static func member(_ name: String, _ content: Data, size: String? = nil) -> Data {
		var bytes = field(name, width: 16)
		bytes += field("1724181645", width: 12)
		bytes += field("123", width: 6)
		bytes += field("456", width: 6)
		bytes += field("100644", width: 8)
		bytes += field(size ?? String(content.count), width: 10)
		bytes += Data([0x60, 0x0a])
		bytes += content
		if content.count % 2 != 0 { bytes.append(0x0a) }
		return bytes
	}

	static func parse(_ bytes: Data, in directory: URL) async throws -> [ARFileModel] {
		let url = directory.appendingPathComponent(UUID().uuidString + ".deb")
		try bytes.write(to: url)
		defer { try? FileManager.default.removeItem(at: url) }
		let reader = try AR(with: url)
		return try await reader.extract()
	}

	static func expectInvalid(_ bytes: Data, in directory: URL) async throws {
		do {
			_ = try await parse(bytes, in: directory)
			preconditionFailure("Malformed archive must throw instead of succeeding or trapping")
		} catch let error as ARError {
			precondition(error.localizedDescription.contains("Invalid Debian package:"))
		}
	}

	static func main() async throws {
		precondition(CommandLine.arguments.count > 1, "Pass the real bundled ellekit.deb")
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }

		for path in CommandLine.arguments.dropFirst() {
			let reader = try AR(with: URL(fileURLWithPath: path))
			let files = try await reader.extract()
			precondition(files.map(\.name) == ["debian-binary", "control.tar.xz", "data.tar.xz"])
			precondition(files.map(\.size) == [4, 296, 113800])
			precondition(files.map { $0.content.count } == files.map(\.size))
			precondition(files[0].content == Data("2.0\n".utf8))
			for file in files.dropFirst() {
				precondition(file.content.prefix(6) == Data([0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00]))
			}
		}
		print("PASS real bundled ElleKit members and complete compressed payloads")

		let first = member("odd", Data([1, 2, 3]))
		let second = member("empty", Data())
		let third = member("data.tar.xz/", Data([4, 5]))
		let valid = magic + first + second + third
		let files = try await parse(valid, in: directory)
		precondition(files.map(\.name) == ["odd", "empty", "data.tar.xz"])
		precondition(files.map(\.size) == [3, 0, 2])
		precondition(files[0].content == Data([1, 2, 3]) && files[2].content == Data([4, 5]))
		precondition(files[0].ownerId == 123 && files[0].groupId == 456)
		precondition(files[0].mode == 0o100644)
		precondition(files[0].modificationDate.timeIntervalSince1970 == 1724181645)
		print("PASS common ar metadata, odd padding, empty members and optional name slash")

		for length in 0..<8 {
			try await expectInvalid(Data(magic.prefix(length)), in: directory)
		}
		try await expectInvalid(Data("garbage!".utf8), in: directory)
		let empty = try await parse(magic, in: directory)
		precondition(empty.isEmpty)
		for length in 1..<60 {
			try await expectInvalid(magic + first.prefix(length), in: directory)
		}
		print("PASS short magic and every partial member-header length throw normally")

		// Preserve the captured failure's exact declared range: the old parser
		// removed the 8-byte magic then read 612..<114432 from 114428 bytes.
		var captured = magic
		captured += member("first", Data(repeating: 0, count: 28))
		captured += member("second", Data(repeating: 0, count: 28))
		captured += member("control.tar.xz", Data(repeating: 0, count: 316))
		precondition(captured.count == 560)
		captured += member("data.tar.xz", Data(repeating: 0, count: 113816), size: "113820")
		precondition(captured.count - 8 == 114428)
		try await expectInvalid(captured, in: directory)
		for length in 60..<first.count {
			try await expectInvalid(magic + first.prefix(length), in: directory)
		}
		for size in ["-1", "abc", "", "1 2", "9999999999"] {
			try await expectInvalid(magic + member("data", Data([1, 2]), size: size), in: directory)
		}
		print("PASS exact captured four-byte overread, truncated content and invalid sizes")

		for (range, value) in [(16..<28, "bad"), (28..<34, "-1"), (34..<40, ""), (40..<48, "888")] {
			var bad = member("data", Data([1, 2]))
			bad.replaceSubrange(range, with: field(value, width: range.count))
			try await expectInvalid(magic + bad, in: directory)
		}
		var nonASCII = member("data", Data([1, 2]))
		nonASCII[16] = 0xff
		try await expectInvalid(magic + nonASCII, in: directory)
		print("PASS malformed numeric metadata and non-ASCII fields throw without forced conversions")

		for name in ["", ".", "..", "../data", "/tmp/data", "a\\b", "#1/20", "a\0b"] {
			try await expectInvalid(magic + member(name, Data([1, 2])), in: directory)
		}
		var badTrailer = member("data", Data([1, 2]))
		badTrailer[58] = 0
		try await expectInvalid(magic + badTrailer, in: directory)
		var badPadding = first
		badPadding[badPadding.count - 1] = 0
		try await expectInvalid(magic + badPadding, in: directory)
		try await expectInvalid(valid + Data([0]), in: directory)
		print("PASS unsupported or unsafe names, bad header trailers, padding and trailing partial headers")

		// Truncation at a complete member boundary is still a valid ar archive;
		// every other prefix of this multi-member fixture must be rejected.
		let boundaries: Set<Int> = [8, 8 + first.count, 8 + first.count + second.count]
		for length in 0..<valid.count where !boundaries.contains(length) {
			try await expectInvalid(Data(valid.prefix(length)), in: directory)
		}
		print("PASS exhaustive truncation of the multi-member archive")

		do {
			_ = try AR(with: directory.appendingPathComponent("missing.deb"))
			preconditionFailure("Unreadable input must throw instead of aborting")
		} catch is CocoaError {
			print("PASS unreadable package returns a file error")
		}
	}
}
