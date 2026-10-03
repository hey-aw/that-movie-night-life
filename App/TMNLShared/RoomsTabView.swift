import SwiftUI
import CloudKit

struct RoomsTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    let catalog: [Movie]
    @State private var rooms = LocalRoomsStore()
    @State private var name = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(rooms.cloudClient == nil ? "Rooms are saved on this device. iCloud requires verified account configuration." : "iCloud rooms use your Apple Account. Local rooms stay on this device until you publish them.")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    if let error = rooms.errorMessage {
                        Text("Could not save or load rooms: \(error)").foregroundStyle(.red)
                    }
                    if rooms.cloudClient != nil {
                        Button("Refresh iCloud rooms") { Task { await rooms.refresh() } }
                        if let synced = rooms.lastSyncedAt { Text("Last synced \(synced.formatted())") }
                        if rooms.isSyncing { Text("Pending iCloud confirmation…") }
                    }
                    if rooms.publicListsEnabled, let client = rooms.cloudClient {
                        NavigationLink("Browse public lists") { PublicListsView(client: client, rooms: rooms) }
                    }
                    TextField("Room name", text: $name)
                    Button("Create room") {
                        rooms.save(PersistentRoom(name: name.trimmingCharacters(in: .whitespacesAndNewlines)))
                        if rooms.errorMessage == nil { name = "" }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !rooms.canSave)
                }
                ForEach(rooms.rooms) { room in
                    NavigationLink(room.name) {
                        LocalRoomDetailView(roomID: room.id, rooms: rooms, catalog: catalog)
                    }
                }
            }
            .navigationTitle("Rooms")
            .task { await rooms.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await rooms.refresh() } }
            }
            .tint(AppTheme.Colors.accent)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TMNLCloudShareAccepted"))) { notification in
                if let error = notification.userInfo?["error"] as? String { rooms.reportShareError(error) }
                else { Task { await rooms.refresh() } }
            }
        }
    }
}

private struct LocalRoomDetailView: View {
    let roomID: UUID
    @Bindable var rooms: LocalRoomsStore
    let catalog: [Movie]
    @State private var search = ""
    @State private var actionError: String?
    @State private var faceTimeDraft = ""
    @State private var region = "US"
    @State private var sharePlay = RoomSharePlay()
    @State private var confirmPublication = false
#if os(iOS)
    @State private var sharing: RoomSharePresentation?
#endif

    private var room: PersistentRoom? { rooms.rooms.first { $0.id == roomID } }
    private func title(_ slug: String) -> String { catalog.first { $0.slug == slug }?.displayName ?? slug }
    private func update(_ action: (inout PersistentRoom) -> Void) {
        guard var room else { return }
        action(&room)
        rooms.save(room)
    }

    var body: some View {
        if let room {
            List {
                if let error = rooms.errorMessage { Text(error).foregroundStyle(.red) }
                if let actionError { Text(actionError).foregroundStyle(.red) }
                if rooms.cloudClient != nil && room.cloudLocation == nil {
                    Button("Publish this room to iCloud") { Task { await rooms.publish(room) } }
                }
                if room.cloudLocation != nil { Text("iCloud room · refresh to receive remote changes") }
#if os(iOS)
                if let location = room.cloudLocation, !location.isShared, let client = rooms.cloudClient {
                    Button("Invite with iCloud") {
                        Task {
                            do {
                                let share = try await client.prepareShare(location)
                                let identifier = Bundle.main.object(forInfoDictionaryKey: "TMNLCloudKitContainerIdentifier") as? String ?? ""
                                sharing = RoomSharePresentation(share: share, container: CKContainer(identifier: identifier))
                            } catch { actionError = error.localizedDescription }
                        }
                    }
                }
#endif
                if rooms.publicListsEnabled, let client = rooms.cloudClient {
                    Button("Publish movie list publicly") { confirmPublication = true }
                        .confirmationDialog("Publish this list name and movies for everyone to see? History, attendance and the FaceTime link stay private.", isPresented: $confirmPublication) {
                            Button("Publish publicly") {
                                Task {
                                    do { try await client.publishPublicList(PublicMovieList(room: room)) }
                                    catch { actionError = error.localizedDescription }
                                }
                            }
                        }
                }
                Section("Selection") {
                    Picker("Pick mode", selection: Binding(get: { self.room?.selectionMode ?? .random }, set: { mode in update { $0.selectionMode = mode } })) {
                        Text("Random").tag(RoomSelectionMode.random)
                        Text("List order").tag(RoomSelectionMode.listOrder)
                    }
                    if let slug = room.currentMovieSlug {
                        Text(title(slug)).font(.tmnlDisplay)
                        Button("Mark watched") { update { $0.markWatched() } }.buttonStyle(.borderedProminent)
                        Button("Clear selection") { update { $0.clearSelection() } }.buttonStyle(.bordered)
                    } else {
                        Button("Pick next unwatched") { update { $0.pick() } }.buttonStyle(.borderedProminent)
                        Text("\(room.movieSlugs.filter { slug in !room.history.contains { $0.movieSlug == slug } }.count) unwatched movies")
                    }
                }
#if os(iOS)
                if room.cloudLocation != nil && room.night != nil {
                    Button("Show room Live Activity") {
                        do { try RoomActivityCoordinator.start(room: room, lastSyncedAt: rooms.lastSyncedAt) }
                        catch { actionError = error.localizedDescription }
                    }
                }
#endif
                Section("Join and watch") {
                    if room.cloudLocation != nil && room.night != nil {
                        Button("SharePlay movie night lobby") { Task { await sharePlay.start(room: room) } }
                        if sharePlay.connected {
                            Text("SharePlay lobby connected. Participant signals are temporary; refresh iCloud for saved room state.")
                            Button("Send saved pick and readiness") { Task { await sharePlay.send(room: room) } }
                            ForEach(Array(sharePlay.hints.keys).sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                                if let hint = sharePlay.hints[id] {
                                    Text("Participant: \(statusLabel(hint.availability)) · \(hint.movieSlug.map(title) ?? "No pick") · \(hint.sentAt.formatted())")
                                }
                            }
                            Button("Leave SharePlay lobby") { sharePlay.leave() }
                        }
                        if let error = sharePlay.error { Text(error).foregroundStyle(.red) }
                    }
                    TextField("FaceTime link from your call", text: $faceTimeDraft)
                    Button("Save FaceTime shortcut") {
                        guard RoomLinks.faceTime(faceTimeDraft) != nil else { actionError = "Paste an HTTPS link created in FaceTime."; return }
                        update { $0.faceTimeLink = faceTimeDraft }
                    }
                    if let link = room.faceTimeLink.flatMap(RoomLinks.faceTime) {
                        Link("Open room FaceTime call", destination: link)
                        Button("Remove shortcut") { update { $0.faceTimeLink = nil } }
                    }
                    TextField("Country code for watch options", text: $region)
                    if let slug = room.currentMovieSlug {
                        ForEach(RoomLinks.watchSearch(title: title(slug), region: region), id: \.name) { option in
                            Link(option.name, destination: option.url)
                        }
                        Text("Check availability and rental prices for your region. Provider playback and SharePlay happen in the provider app.")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Section("Movie night") {
                    if let night = room.night {
                        Text(statusLabel(night.status))
                        Text("Updated \(night.updatedAt.formatted())").foregroundStyle(AppTheme.Colors.textSecondary)
                        if let eta = night.availableAt { Text("Estimated availability: \(eta.formatted()). Tap Ready when you are ready.") }
                        Button("I'm in") { respond(.attending) }
                        Button("Not tonight") { respond(.notTonight) }
                        Button("Ready") { respond(.ready) }
                        Menu("Give me…") {
                            Button("30 minutes") { respond(.delayed, delay: 1800) }
                            Button("1 hour") { respond(.delayed, delay: 3600) }
                            Button("A few hours") { respond(.delayed, delay: 10800) }
                        }
                        Button("Start a new night") { update { $0.night = RoomNight() } }
                    } else {
                        Button("Start movie night") { update { $0.night = RoomNight() } }
                    }
                }
                Section("One movie list") {
                    ForEach(room.movieSlugs, id: \.self) { Text(title($0)) }
                    TextField("Search catalog to add a movie", text: $search)
                    if !search.isEmpty {
                        ForEach(Array(catalog.filter { $0.displayName.localizedCaseInsensitiveContains(search) && !room.movieSlugs.contains($0.slug) }.prefix(20))) { movie in
                            Button("Add \(movie.displayName)") {
                                update { $0.addMovie(movie.slug) }
                                search = ""
                            }
                        }
                    }
                }
                Section("Watch history") {
                    if room.history.isEmpty { Text("No watches recorded yet") }
                    ForEach(room.history.reversed()) { watch in
                        VStack(alignment: .leading) {
                            Text(title(watch.movieSlug))
                            Text(watch.watchedAt.formatted()).foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle(room.name)
            .task { await sharePlay.listen { self.room } }
            .onChange(of: room.night?.id) { _, _ in sharePlay.leave() }
            .onDisappear { sharePlay.leave() }
            .disabled(rooms.isSyncing)
#if os(iOS)
            .sheet(item: $sharing) { presentation in
                RoomCloudSharingView(presentation: presentation,
                                     onFailure: { actionError = $0 },
                                     onChange: { Task { await rooms.refresh() } })
            }
#endif
        }
    }

    private func respond(_ status: NightAvailability, delay: TimeInterval? = nil) {
        update { $0.night?.respond(status, delay: delay) }
    }

    private func statusLabel(_ status: NightAvailability) -> String {
        switch status {
        case .undecided: "No response yet"
        case .attending: "I'm in"
        case .notTonight: "Not tonight"
        case .ready: "Ready"
        case .delayed: "Need more time"
        }
    }
}
