import CloudKit
import UIKit

@MainActor
private enum CloudShareAcceptance {
    static func accept(_ metadata: CKShare.Metadata) {
        Task {
            let identifier = Bundle.main.object(forInfoDictionaryKey: "TMNLCloudKitContainerIdentifier") as? String ?? ""
            guard !identifier.isEmpty, metadata.containerIdentifier == identifier else { return }
            var errorMessage: String?
            do { try await CloudRoomClient(container: CKContainer(identifier: identifier)).accept(metadata) }
            catch { errorMessage = error.localizedDescription }
            NotificationCenter.default.post(name: Notification.Name("TMNLCloudShareAccepted"), object: nil,
                                            userInfo: errorMessage.map { ["error": $0] })
        }
    }
}

final class RoomShareAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = RoomShareSceneDelegate.self
        return configuration
    }
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        CloudShareAcceptance.accept(cloudKitShareMetadata)
    }
}

final class RoomShareSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        CloudShareAcceptance.accept(cloudKitShareMetadata)
    }
}
