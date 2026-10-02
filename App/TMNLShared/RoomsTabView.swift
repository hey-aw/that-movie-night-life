import SwiftUI

struct RoomsTabView: View {
    let catalog: [Movie]
    @State private var rooms = LocalRoomsStore()
    @State private var name = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Rooms are saved on this device. Sharing and iCloud sync are coming later.")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    if let error = rooms.errorMessage {
                        Text("Could not save or load rooms: \(error)").foregroundStyle(.red)
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
            .tint(AppTheme.Colors.accent)
        }
    }
}

private struct LocalRoomDetailView: View {
    let roomID: UUID
    @Bindable var rooms: LocalRoomsStore
    let catalog: [Movie]
    @State private var search = ""

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
