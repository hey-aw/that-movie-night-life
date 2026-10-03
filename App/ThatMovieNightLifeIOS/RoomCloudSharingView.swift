import CloudKit
import SwiftUI
import UIKit

struct RoomSharePresentation: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

struct RoomCloudSharingView: UIViewControllerRepresentable {
    let presentation: RoomSharePresentation
    let onFailure: (String) -> Void
    let onChange: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: presentation.share, container: presentation.container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let parent: RoomCloudSharingView
        init(parent: RoomCloudSharingView) { self.parent = parent }
        func itemTitle(for csc: UICloudSharingController) -> String? { "Movie night room" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) { parent.onFailure(error.localizedDescription) }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { parent.onChange() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { parent.onChange() }
    }
}
