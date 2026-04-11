import SwiftUI

struct StartNightSheet: View {
    @Bindable var store: MovieNightStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: StartNightViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    stepContent(viewModel)
                } else {
                    ProgressView()
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Start a Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = StartNightViewModel(
                        catalog: store.catalog,
                        eligibleMovies: store.eligibleMovies
                    )
                }
            }
        }
    }

    private func stepContent(_ vm: StartNightViewModel) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                stepIndicator(vm)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                        switch vm.currentStep {
                        case .audience:
                            audienceStep(vm)
                        case .mode:
                            modeStep(vm)
                        case .shortlist:
                            shortlistStep(vm)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.xl)
                    .padding(.bottom, vm.currentStep == .shortlist ? AppTheme.Spacing.section : AppTheme.Spacing.xl)
                }

                if vm.currentStep != .shortlist {
                    bottomActions(vm)
                }
            }
        }
    }

    private func stepIndicator(_ vm: StartNightViewModel) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            ForEach(0..<vm.stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= vm.stepIndex ? AppTheme.Colors.accent : AppTheme.Colors.surfaceRaised)
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.sm)
    }

    // MARK: - Audience

    private func audienceStep(_ vm: StartNightViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Who's watching?")
                .font(.tmnlDisplay)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            ForEach(StartNightViewModel.Audience.allCases, id: \.self) { audience in
                let selected = vm.selectedAudience == audience
                Button {
                    vm.selectedAudience = audience
                } label: {
                    HStack {
                        Text(audience.rawValue)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.md)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .fill(selected ? AppTheme.Colors.surface : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .strokeBorder(
                                selected ? AppTheme.Colors.accent.opacity(0.4) : Color.white.opacity(0.08),
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Mode

    private func modeStep(_ vm: StartNightViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("How do you want to pick?")
                .font(.tmnlDisplay)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            ForEach(StartNightViewModel.SelectionMode.allCases, id: \.self) { mode in
                let selected = vm.selectedMode == mode
                Button {
                    vm.selectedMode = mode
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(mode.rawValue)
                                .font(.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(modeDescription(mode))
                                .font(.tmnlCaption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.md)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .fill(selected ? AppTheme.Colors.surface : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .strokeBorder(
                                selected ? AppTheme.Colors.accent.opacity(0.4) : Color.white.opacity(0.08),
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func modeDescription(_ mode: StartNightViewModel.SelectionMode) -> String {
        switch mode {
        case .watchlistDraw: return "Random picks from your watchlist"
        case .under2Hours: return "Quick watches under two hours"
        case .highlyRated: return "Top-rated films only"
        case .wildCard: return "Anything goes"
        }
    }

    // MARK: - Shortlist

    private func shortlistStep(_ vm: StartNightViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Your shortlist")
                .font(.tmnlDisplay)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Tap a film to lock it in.")
                .font(.tmnlBody)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if vm.shortlist.isEmpty {
                Text("No films match the current filters. Try a different mode.")
                    .font(.tmnlBody)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .padding(.vertical, AppTheme.Spacing.section)
            } else {
                ForEach(vm.shortlist) { movie in
                    Button {
                        vm.lockPick(movie)
                        store.recordSelectionFromSheet(movie)
                        dismiss()
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            AsyncImage(url: movie.posterURLValue) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                                    .fill(AppTheme.Colors.surfaceRaised)
                            }
                            .frame(width: 52, height: 78)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(movie.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                HStack(spacing: AppTheme.Spacing.sm) {
                                    if let runtime = movie.runtimeMinutes {
                                        Text("\(runtime) min")
                                    }
                                    if !movie.genres.isEmpty {
                                        Text(movie.genres.prefix(2).joined(separator: ", "))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textTertiary)

                                if let rating = movie.aggregateRating {
                                    HStack(spacing: 3) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(AppTheme.Colors.accent)
                                        Text(rating, format: .number.precision(.fractionLength(1)))
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                        .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .buttonStyle(PressableButtonStyle())

                    if movie.id != vm.shortlist.last?.id {
                        Divider().overlay(Color.white.opacity(0.04))
                    }
                }
            }
        }
    }

    // MARK: - Bottom Actions

    private func bottomActions(_ vm: StartNightViewModel) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if vm.currentStep != .audience {
                Button("Back") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        vm.goBack()
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Button("Next") {
                withAnimation(.easeOut(duration: 0.2)) {
                    vm.advance()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.accent)
            .disabled(!vm.canAdvance)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.vertical, AppTheme.Spacing.lg)
    }
}
