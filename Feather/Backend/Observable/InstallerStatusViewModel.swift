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
