//
//  BackgroundAudioManager.swift
//  Feather
//
//  Created by Nagata Asami on 12/10/25.
//

#if !targetEnvironment(macCatalyst)

import AVFoundation
import OSLog

final class BackgroundAudioManager {
	static let shared = BackgroundAudioManager()
	private var _player: AVAudioPlayer?
	private let _logger = Logger(subsystem: "com.elmat.NullSign", category: "BackgroundAudio")

	private init() {}

	func start() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async { self.start() }
			return
		}
		guard _player?.isPlaying != true else { return }

		do {
			#if os(iOS)
			let session = AVAudioSession.sharedInstance()
			try session.setCategory(.playback, options: [.mixWithOthers])
			try session.setActive(true)
			#endif

			let player = try SilentAudio.makePlayer()
			guard player.prepareToPlay(), player.play() else {
				// Background keep-alive is optional. An unavailable audio route
				// must never prevent the signing/install screen from opening.
				player.stop()
				_logger.error("Background audio is unavailable; continuing without it")
				stop()
				return
			}
			_player = player
		} catch {
			_logger.error("Background audio could not start: \(error.localizedDescription, privacy: .public)")
			stop()
		}
	}

	func stop() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async { self.stop() }
			return
		}
		_player?.stop()
		_player = nil
		#if os(iOS)
		try? AVAudioSession.sharedInstance().setActive(false)
		#endif
	}
}

#endif
