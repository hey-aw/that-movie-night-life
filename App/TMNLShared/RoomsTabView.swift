import SwiftUI
#if os(iOS)
import UIKit
#endif

struct RoomsTabView: View {
    @Bindable var store: MovieNightStore

    @State private var selectedMovie: Movie?
    @State private var copiedRoomID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                    if store.rooms.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.rooms) { room in
                            RoomCard(
                                room: room,
                                isActive: room.id == store.activeRoomID,
                                isCopied: copiedRoomID == room.id,
                                currentPick: store.currentPickMovie(for: room.id),
                                candidateCount: store.roomCandidateCount(for: room.id),
                                roomCode: store.roomCode(for: room),
                                onActivate: { store.activateRoom(room.id) },
                                onModeChange: { store.setSelectionMode($0, for: room.id) },
                                onNewPick: { store.makeNewPick(for: room.id) },
                                onCopyInvite: { copyInvite(for: room) },
                                onViewDetails: { selectedMovie = $0 },
                                onMarkWatched: {
                                    store.activateRoom(room.id)
                                    store.markCurrentPickAsWatched()
                                },
                                onMarkSeen: {
                                    store.activateRoom(room.id)
                                    store.markCurrentPickAsSeen()
                                },
                                onMarkNotInterested: {
                                    store.activateRoom(room.id)
                                    store.markCurrentPickAsNotInterested()
                                }
                            )
                            .padding(.horizontal, AppTheme.Spacing.section)
                        }
                    }
                }
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.section + 44)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Rooms")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $selectedMovie) { movie in
                ChosenFilmView(movie: movie, store: store)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            Text("No rooms yet")
                .font(.tmnlTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.section)
    }

    private func copyInvite(for room: Room) {
        #if os(iOS)
        UIPasteboard.general.string = store.roomInviteLink(for: room)
        #endif
        copiedRoomID = room.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if copiedRoomID == room.id {
                copiedRoomID = nil
            }
        }
    }
}

private struct RoomCard: View {
    let room: Room
    let isActive: Bool
    let isCopied: Bool
    let currentPick: Movie?
    let candidateCount: Int
    let roomCode: String
    let onActivate: () -> Void
    let onModeChange: (RoomSelectionMode) -> Void
    let onNewPick: () -> Void
    let onCopyInvite: () -> Void
    let onViewDetails: (Movie) -> Void
    let onMarkWatched: () -> Void
    let onMarkSeen: () -> Void
    let onMarkNotInterested: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            header
            modePicker
            inviteRow

            Divider().overlay(Color.white.opacity(0.06))

            if let currentPick {
                currentPickSection(currentPick)
            } else {
                Button(action: onNewPick) {
                    Label("New Pick", systemImage: "shuffle")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .disabled(candidateCount == 0)
            }

            if !room.history.isEmpty {
                Divider().overlay(Color.white.opacity(0.06))
                historySection
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .strokeBorder(isActive ? AppTheme.Colors.accent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(room.name)
                        .font(.tmnlTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if isActive {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }
                Text(room.source.list.displayName)
                    .font(.tmnlCaption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("\(candidateCount) eligible of \(room.source.list.orderedTitleIDs.count) titles")
                    .font(.tmnlCaption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }

            Spacer()

            if !isActive {
                Button("Activate", action: onActivate)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var modePicker: some View {
        Picker("Selection mode", selection: Binding(get: { room.selectionMode }, set: onModeChange)) {
            Text("Random").tag(RoomSelectionMode.random)
            Text("Next Unwatched").tag(RoomSelectionMode.nextUnwatched)
        }
        .pickerStyle(.segmented)
    }

    private var inviteRow: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Label(roomCode, systemImage: "number")
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Button(isCopied ? "Copied" : "Copy Invite") {
                onCopyInvite()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(isCopied ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
        }
    }

    private func currentPickSection(_ movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Current Pick")
                .font(.tmnlCaption)
                .foregroundStyle(AppTheme.Colors.accent)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                AsyncImage(url: movie.posterURLValue) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                        .fill(AppTheme.Colors.surfaceRaised)
                }
                .frame(width: 64, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(movie.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("#\(movie.number)")
                        .font(.tmnlCaption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                Spacer()
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Watch", action: onMarkWatched)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.accent)
                    Button("Details") { onViewDetails(movie) }
                        .buttonStyle(.bordered)
                }
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Seen", action: onMarkSeen)
                        .buttonStyle(.bordered)
                    Button("Not Interested", action: onMarkNotInterested)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Recent Picks")
                .font(.tmnlCaption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            ForEach(Array(room.history.prefix(5))) { entry in
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("#\(entry.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .frame(width: 48, alignment: .leading)
                    Text(entry.displayName)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.disposition.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(entry.disposition.badgeColor)
                }
            }
        }
    }
}

private extension RoomHistoryDisposition {
    var label: String {
        switch self {
        case .watched:
            return "Watched"
        case .seen:
            return "Seen"
        case .passed:
            return "Pass"
        }
    }

    var badgeColor: Color {
        switch self {
        case .watched:
            return AppTheme.Colors.accent
        case .seen:
            return AppTheme.Colors.textSecondary
        case .passed:
            return .orange
        }
    }
}
