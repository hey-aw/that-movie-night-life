import SwiftUI

struct RoomsTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()

                Image(systemName: "person.2")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(AppTheme.Colors.textTertiary)

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Rooms are coming soon")
                        .font(.tmnlDisplay)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("Create a room for your Friday crew, horror club, or movie-night regulars.")
                        .font(.tmnlBody)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.Spacing.section)

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Rooms")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
