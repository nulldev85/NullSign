import SwiftUI

struct TunnelHeaderView: View {
	@State private var lastHeartbeatTime = Date()

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: "wave.3.right")
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(NullSignStyle.accent)
				.frame(width: 32, height: 32)
				.background(NullSignStyle.raisedPanel)
				.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
			VStack(alignment: .leading, spacing: 2) {
				Text("Heartbeat")
					.font(.body.weight(.medium))
				Text("Local device connection")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
			TunnelPulseRing(lastHeartbeat: $lastHeartbeatTime)
		}
		.onReceive(NotificationCenter.default.publisher(for: .heartbeat)) { _ in
			lastHeartbeatTime = Date()
		}
	}
}

struct TunnelPulseRing: View {
	@Binding var lastHeartbeat: Date

	var body: some View {
		TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
			let age = timeline.date.timeIntervalSince(lastHeartbeat)
			let color: Color = age < 5 ? NullSignStyle.accent : (age < 10 ? NullSignStyle.muted : NullSignStyle.warning)

			HStack(spacing: 6) {
				Circle()
					.fill(color)
					.frame(width: 7, height: 7)
				Text(age < 5 ? "Live" : (age < 10 ? "Waiting" : "Offline"))
					.font(.caption.weight(.medium))
					.foregroundStyle(color)
			}
		}
	}
}
