import SwiftUI
import NimbleViews
import UIKit

struct DiagnosticsView: View {
	@State private var _logExists = false

	var body: some View {
		Form {
			NBSection("Local Diagnostics") {
				LabeledContent("Signing log", value: _logExists ? "Available" : "Empty")
				Button("Export Diagnostic Log", systemImage: "square.and.arrow.up") {
					UIActivityViewController.show(activityItems: [ReliabilityCenter.shared.logURL])
				}
				.disabled(!_logExists)
				Button("Clear Diagnostic Log", systemImage: "trash", role: .destructive) {
					ReliabilityCenter.shared.clearLog()
					_logExists = false
				}
				.disabled(!_logExists)
			} footer: {
				Text("The log stays on this iPhone and records signing stages and errors. It removes the app-container path and never includes certificate passwords or private-key data.")
			}

			NBSection("What NullSign Checks") {
				Label("App structure and executable", systemImage: "checkmark.shield")
				Label("Certificate, profile, and expiration", systemImage: "checkmark.shield")
				Label("Free space and tweak file types", systemImage: "checkmark.shield")
				Label("Nested bundles and final signatures", systemImage: "checkmark.shield")
			}
		}
		.navigationTitle("Diagnostics")
		.onAppear {
			_logExists = FileManager.default.fileExists(atPath: ReliabilityCenter.shared.logURL.path)
		}
	}
}
