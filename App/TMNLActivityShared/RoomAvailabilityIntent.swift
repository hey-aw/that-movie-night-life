import ActivityKit
import AppIntents
import CloudKit
import Foundation

struct RoomAvailabilityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Respond to movie night"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Activity identifier") var activityID: String
    @Parameter(title: "Response") var response: String
    @Parameter(title: "Delay in minutes") var minutes: Int

    init() {}
    init(activityID: String, response: NightAvailability, minutes: Int = 0) {
        self.activityID = activityID; self.response = response.rawValue; self.minutes = minutes
    }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<RoomActivityAttributes>.activities.first(where: { $0.id == activityID }),
              let status = NightAvailability(rawValue: response),
              [0, 30, 60, 180].contains(minutes),
              (status == .delayed) == (minutes > 0) else { return .result() }
        var pending = activity.content.state
        pending.pending = true
        pending.deliveryConfirmed = false
        await activity.update(ActivityContent(state: pending, staleDate: Date()))
        let configured = Bundle.main.object(forInfoDictionaryKey: "TMNLCloudKitContainerIdentifier") as? String ?? ""
        guard !configured.isEmpty, configured == activity.attributes.containerIdentifier else { return .result() }
        let client = await CloudRoomClient(container: CKContainer(identifier: configured))
        // CloudKit success is server acceptance, not another device's Live Activity delivery.
        let result = try await client.respond(at: activity.attributes.location, nightID: activity.attributes.nightID,
                                             status: status, delay: minutes > 0 ? Double(minutes * 60) : nil)
        let state = RoomActivityAttributes.ContentState(status: result.status, availableAt: result.availableAt,
                                                        lastSyncedAt: Date(), pending: false, deliveryConfirmed: false)
        await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(120)))
        return .result()
    }
}
