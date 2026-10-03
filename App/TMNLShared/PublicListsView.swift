import SwiftUI

struct PublicListsView: View {
    let client: CloudRoomClient
    @Bindable var rooms: LocalRoomsStore
    @State private var lists: [PublicMovieList] = []
    @State private var error: String?
    @State private var deleting: PublicMovieList?
    var body: some View {
        List {
            Text("Published lists are visible to everyone. Importing makes a separate local room.")
            if let error { Text(error).foregroundStyle(.red) }
            Button("Refresh public lists") { Task { await refresh() } }
            ForEach(lists) { list in
                VStack(alignment: .leading) {
                    Text(list.name).font(.headline)
                    Text("\(list.movieSlugs.count) movies")
                    Button("Import to a local room") {
                        var room = PersistentRoom(name: list.name)
                        room.movieSlugs = list.movieSlugs
                        rooms.save(room)
                    }
                    Button("Unpublish my list", role: .destructive) { deleting = list }
                }
            }
        }
        .navigationTitle("Public lists")
        .task { await refresh() }
        .confirmationDialog("Remove this publication? CloudKit only permits the creator to delete it.", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Unpublish", role: .destructive) {
                guard let list = deleting else { return }; deleting = nil
                Task {
                    do { try await client.unpublishPublicList(list.id); await refresh() }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }
    private func refresh() async {
        do { lists = try await client.publicLists(); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
