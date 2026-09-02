import SwiftUI

/// A search field styled to match system toolbar chrome — `.bar` material in
/// a capsule, so it automatically renders as whatever the navigation bar
/// itself uses on the current OS (including Liquid Glass on iOS 26), with no
/// custom glass imitation. Shared by Journal and History so both search bars
/// look and behave identically; each screen supplies its own outer padding
/// and any sibling controls (e.g. Journal's "+" button next to it).
struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .frame(height: 44)
        .background(.bar, in: Capsule())
    }
}
