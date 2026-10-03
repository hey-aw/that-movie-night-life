import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RoomActivityWidgetBundle: WidgetBundle {
    var body: some Widget { RoomActivityWidget() }
}

struct RoomActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoomActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.roomName).font(.headline)
                freshness(context)
                actions(context)
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack { Text(context.attributes.roomName); freshness(context) }
                }
                DynamicIslandExpandedRegion(.bottom) { actions(context) }
            } compactLeading: { Image(systemName: "film") }
              compactTrailing: { Image(systemName: context.state.pending || context.isStale ? "clock" : "person.2") }
              minimal: { Image(systemName: "film") }
        }
    }

    @ViewBuilder
    private func freshness(_ context: ActivityViewContext<RoomActivityAttributes>) -> some View {
        Text(context.state.status?.rawValue ?? "Room snapshot").font(.caption)
        if let ready = context.state.readyCount { Text("\(ready) ready").font(.caption) }
        if context.state.pending { Text("Pending — open the app to retry").font(.caption) }
        else if context.isStale { Text("Status may be stale").font(.caption) }
        if let synced = context.state.lastSyncedAt { Text("Last synced \(Date(timeIntervalSince1970: synced).formatted(date: .omitted, time: .shortened))").font(.caption) }
        if !context.state.deliveryConfirmed { Text("Other members may not have updated yet").font(.caption) }
        if let eta = context.state.availableAt { Text("ETA \(Date(timeIntervalSince1970: eta).formatted(date: .omitted, time: .shortened)) · tap Ready yourself").font(.caption) }
    }
    private func actions(_ context: ActivityViewContext<RoomActivityAttributes>) -> some View {
        VStack {
            HStack {
                Button("I'm in", intent: RoomAvailabilityIntent(activityID: context.activityID, response: .attending))
                Button("Not tonight", intent: RoomAvailabilityIntent(activityID: context.activityID, response: .notTonight))
                Button("Ready", intent: RoomAvailabilityIntent(activityID: context.activityID, response: .ready))
            }
            HStack {
                Button("30 min", intent: RoomAvailabilityIntent(activityID: context.activityID, response: .delayed, minutes: 30))
                Button("1 hour", intent: RoomAvailabilityIntent(activityID: context.activityID, response: .delayed, minutes: 60))
                Button("A few hours", intent: RoomAvailabilityIntent(activityID: context.activityID, response: .delayed, minutes: 180))
            }
        }.buttonStyle(.bordered)
    }
}
