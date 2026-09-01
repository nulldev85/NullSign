//
//  DylibToggleView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//


import SwiftUI

struct SigningToggleCellView<T>: View {
	let title: String
	@Binding var options: T?
	let arrayKeyPath: WritableKeyPath<T, [String]>
	var displayTitle: String? = nil
	var detail: String? = nil
	var systemImage: String = "link"
	var readOnlyLabel: String = "Included"
	
	@ViewBuilder
	var body: some View {
		if options == nil {
			HStack(spacing: 12) {
				_rowLabel
				Spacer(minLength: 10)
				Text(readOnlyLabel)
					.font(.caption.weight(.semibold))
					.foregroundStyle(.secondary)
			}
		} else {
			Toggle(isOn: Binding(
				get: {
					guard let options = options else { return false }
					return !options[keyPath: arrayKeyPath].contains(title)
				},
				set: { isOn in
					if isOn {
						_removeItem()
					} else {
						_addItem()
					}
				}
			)) {
				_rowLabel
			}
			.tint(NullSignStyle.cyan)
		}
	}

	private var _rowLabel: some View {
		HStack(spacing: 12) {
			SigningRowIcon(systemImage: systemImage)
			VStack(alignment: .leading, spacing: detail == nil ? 0 : 2) {
				Text(displayTitle ?? title)
					.font(.body.weight(.medium))
					.lineLimit(2)
				if let detail {
					Text(detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
			}
		}
	}
	
	private func _removeItem() {
		guard var opts = options else { return }
		opts[keyPath: arrayKeyPath].removeAll { $0 == title }
		options = opts
	}
	
	private func _addItem() {
		guard var opts = options else { return }
		if !opts[keyPath: arrayKeyPath].contains(title) {
			opts[keyPath: arrayKeyPath].append(title)
		}
		options = opts
	}
}
