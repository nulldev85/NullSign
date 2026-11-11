import AVFoundation

@main
struct BackgroundAudioTests {
	static func main() throws {
		let data = SilentAudio.wavData()
		func u16(_ offset: Int) -> UInt16 {
			UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
		}
		func u32(_ offset: Int) -> UInt32 {
			UInt32(u16(offset)) | (UInt32(u16(offset + 2)) << 16)
		}
		precondition(data.count == 88_244)
		precondition(String(decoding: data[0..<4], as: UTF8.self) == "RIFF")
		precondition(Int(u32(4)) + 8 == data.count)
		precondition(String(decoding: data[8..<16], as: UTF8.self) == "WAVEfmt ")
		precondition(u32(16) == 16 && u16(20) == 1 && u16(22) == 1)
		precondition(u32(24) == 44_100 && u32(28) == 88_200)
		precondition(u16(32) == 2 && u16(34) == 16)
		precondition(String(decoding: data[36..<40], as: UTF8.self) == "data")
		precondition(Int(u32(40)) == data.count - 44)
		precondition(data[44...].allSatisfy { $0 == 0 })
		print("PASS silent PCM file structure and every sample")

		// Use the actual Apple decoder, not a substitute AVFoundation module.
		for _ in 0..<3 {
			let player = try SilentAudio.makePlayer()
			precondition(abs(player.duration - 1) < 0.001)
			precondition(player.numberOfChannels == 1)
			precondition(abs(player.format.sampleRate - 44_100) < 0.001)
			precondition(player.numberOfLoops == -1 && player.volume == 0)
			player.stop()
		}
		print("PASS real AVAudioPlayer decoding, duration, channel count, looping and silence")

		// Playback may be unavailable on a headless runner; either result must
		// leave the process alive. This does not emulate an iPhone audio route.
		for _ in 0..<3 {
			BackgroundAudioManager.shared.start()
			BackgroundAudioManager.shared.start()
			BackgroundAudioManager.shared.stop()
		}
		print("PASS repeated background-audio startup/stop does not abort the native process")
	}
}
