import Foundation
import AVFoundation

/// A small, ordinary PCM file lets AVAudioPlayer handle device audio formats.
/// No custom render callback or hardware-dependent engine graph is needed.
enum SilentAudio {
	static func makePlayer() throws -> AVAudioPlayer {
		let player = try AVAudioPlayer(data: wavData())
		player.numberOfLoops = -1
		player.volume = 0
		return player
	}

	static func wavData() -> Data {
		let sampleRate: UInt32 = 44_100
		let bytesPerSample: UInt16 = 2
		let payloadSize = sampleRate * UInt32(bytesPerSample)
		var data = Data()
		func append<T: FixedWidthInteger>(_ value: T) {
			var encoded = value.littleEndian
			withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
		}
		data.append(contentsOf: "RIFF".utf8)
		append(UInt32(36) + payloadSize)
		data.append(contentsOf: "WAVEfmt ".utf8)
		append(UInt32(16))
		append(UInt16(1)) // PCM
		append(UInt16(1)) // mono
		append(sampleRate)
		append(sampleRate * UInt32(bytesPerSample))
		append(bytesPerSample)
		append(UInt16(16))
		data.append(contentsOf: "data".utf8)
		append(payloadSize)
		data.append(Data(count: Int(payloadSize)))
		return data
	}
}
