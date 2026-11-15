import SwiftUI

struct NullSignFileMenuTarget: Identifiable {
	let url: URL
	var id: String { url.absoluteString }
}

struct NullSignFileMenu: View {
	let url: URL
	let onDelete: () -> Void

	var body: some View {
		NullSignMenuSheet(title: url.lastPathComponent, systemImage: "doc", detail: "Remove this file from the signing session.") {
			NullSignSettingsCard {
				NullSignMenuAction(title: "Delete", systemImage: "trash", isDestructive: true, action: onDelete)
			}
		}
	}
}
