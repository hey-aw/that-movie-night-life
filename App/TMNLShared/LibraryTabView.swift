import SwiftUI

struct LibraryTabView: View {
    @Bindable var store: MovieNightStore
    @State private var isImportPickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Letterboxd") {
                    Button {
                        isImportPickerPresented = true
                    } label: {
                        Label("Import Watched Data", systemImage: "square.and.arrow.down")
                    }

                    HStack {
                        Text("Watched Titles")
                        Spacer()
                        Text("\(store.session.watchedSlugs.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Import Status")
                        Spacer()
                        Text(store.importStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Catalog") {
                    HStack {
                        Text("Total Films")
                        Spacer()
                        Text("\(store.catalog.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Eligible Films")
                        Spacer()
                        Text("\(store.eligibleMovies.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Filters") {
                    Toggle("Exclude Watched", isOn: Binding(
                        get: { store.session.filterSettings.excludeWatched },
                        set: { store.setExcludeWatched($0) }
                    ))

                    Picker("Minimum Rating", selection: Binding(
                        get: { store.session.filterSettings.minimumAverageRating },
                        set: { store.setMinimumAverageRating($0) }
                    )) {
                        ForEach(MinimumAverageRating.allCases, id: \.self) { rating in
                            Text(rating.title).tag(rating)
                        }
                    }
                }

                if !store.availableBuzzKillTags.isEmpty {
                    Section("Buzz Kills") {
                        ForEach(store.availableBuzzKillTags, id: \.rawValue) { tag in
                            Toggle("Exclude \(tag.rawValue.capitalized)", isOn: Binding(
                                get: { store.session.filterSettings.excludedBuzzKillTags.contains(tag) },
                                set: { _ in store.toggleBuzzKillTag(tag) }
                            ))
                        }
                    }
                }

                Section("Streaming Services") {
                    Text("Connect your streaming services to filter availability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Spoiler Settings") {
                    Text("Spoiler preferences will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Library")
#if !os(tvOS)
            .fileImporter(
                isPresented: $isImportPickerPresented,
                allowedContentTypes: [.commaSeparatedText, .zip]
            ) { result in
                switch result {
                case .success(let url):
                    Task { await store.importWatched(from: url) }
                case .failure:
                    store.importStatus = "Import cancelled."
                }
            }
#endif
        }
    }
}
