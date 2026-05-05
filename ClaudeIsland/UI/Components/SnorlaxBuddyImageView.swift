import SwiftUI

/// High-resolution Snorlax buddy backed by a PNG asset.
/// Used in settings and larger display areas; scales down gracefully.
struct SnorlaxBuddyImageView: View {
    var body: some View {
        Image("SnorlaxBuddy")
            .resizable()
            .interpolation(.none)
            .antialiased(false)
    }
}

#Preview {
    SnorlaxBuddyImageView()
        .frame(width: 200, height: 200)
}
