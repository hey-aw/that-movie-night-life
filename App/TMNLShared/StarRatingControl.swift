import SwiftUI

struct StarRatingControl: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var starSize: CGFloat = 32

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundStyle(star <= rating ? AppTheme.Colors.accent : AppTheme.Colors.textTertiary)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            rating = star == rating ? 0 : star
                        }
                    }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) out of \(maxRating) stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(rating + 1, maxRating)
            case .decrement:
                rating = max(rating - 1, 0)
            @unknown default:
                break
            }
        }
    }
}
