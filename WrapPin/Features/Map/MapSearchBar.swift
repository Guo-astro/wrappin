import SwiftUI

struct MapSearchBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let isSearching: Bool
    /// Nil when this build has no overseas search service configured.
    var isOverseasSearch: Bool?
    var onToggleOverseasSearch: () -> Void = {}
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    searchFieldRow

                    if isFocused {
                        Divider()
                        dismissKeyboardButton
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    searchFieldRow

                    if isFocused {
                        Divider()
                            .frame(height: 24)
                        dismissKeyboardButton
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 4)
        .frame(minHeight: 52)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }

    private var searchFieldRow: some View {
        HStack(spacing: 12) {
            Image(systemName: isOverseasSearch == true ? "globe.asia.australia.fill" : "magnifyingglass")
                .foregroundStyle(isOverseasSearch == true ? AnyShapeStyle(.blue) : AnyShapeStyle(.secondary))
                .accessibilityHidden(true)

            TextField(
                isOverseasSearch == true
                    ? LocalizedStringKey("Search overseas places or coordinates")
                    : LocalizedStringKey("Search places or coordinates"),
                text: $query
            )
                .focused($isFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    isFocused = false
                    onSubmit()
                }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            if let isOverseasSearch {
                Button(action: onToggleOverseasSearch) {
                    Text(isOverseasSearch ? "Overseas" : "Domestic")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isOverseasSearch ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isOverseasSearch ? AnyShapeStyle(.blue) : AnyShapeStyle(.quaternary),
                            in: Capsule()
                        )
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Overseas search")
                .accessibilityHint("Switches between domestic and overseas place search")
                .accessibilityAddTraits(isOverseasSearch ? .isSelected : [])
            }
        }
        .frame(minHeight: 44)
    }

    private var dismissKeyboardButton: some View {
        Button("Done") {
            isFocused = false
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Dismiss keyboard")
        .accessibilityHint("Dismisses the keyboard")
    }
}
