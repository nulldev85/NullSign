//
//  StatusViewModel.swift
//  Feather
//
//  Created by samara on 24.04.2025.
//

import Foundation
import Combine
import IDeviceSwift

extension InstallerStatusViewModel {
	/// iOS may re-request manifests or byte ranges after installation starts.
	/// Those HTTP callbacks must not move the card back to a transfer phase.
	@MainActor func updateServerStatus(_ newStatus: InstallerStatus) {
		guard !isCompleted, installFailure == nil else { return }
		func phase(_ status: InstallerStatus) -> Int {
			switch status {
			case .none: return 0
			case .ready: return 1
			case .sendingManifest: return 2
			case .sendingPayload: return 3
			case .installing: return 4
			case .completed, .broken: return 5
			}
		}
		guard phase(newStatus) >= phase(status) else { return }
		updateStatus(newStatus)
	}

	var installSucceeded: Bool {
		if case .completed(.success) = status { return true }
		return false
	}

	var installFailure: Error? {
		switch status {
		case .broken(let error), .completed(.failure(let error)): return error
		default: return nil
		}
	}

	var statusImage: String {
		if installFailure != nil { return "exclamationmark.triangle.fill" }
		return switch status {
		case .none: "archivebox.fill"
		case .ready: "app.gift"
		case .sendingManifest, .sendingPayload: "paperplane.fill"
		case .installing: "square.and.arrow.down"
		case .completed: "app.badge.checkmark"
		case .broken: "exclamationmark.triangle.fill"
		}
	}
	
	var statusLabel: String {
		if installFailure != nil { return .localized("Error") }
		return switch status {
		case .none: .localized("Packaging")
		case .ready: .localized("Waiting for iOS Confirmation")
		case .sendingManifest: .localized("Sending Manifest")
		case .sendingPayload: .localized("Sending Payload")
		case .installing: .localized("Installing")
		case .completed: .localized("Completed")
		case .broken: .localized("Error")
		}
	}
}
