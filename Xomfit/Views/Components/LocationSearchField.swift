import SwiftUI
import MapKit

struct LocationSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search for a place..."

    @State private var completer = LocationCompleter()
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "location.fill")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                TextField(placeholder, text: $text)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .focused($isFocused)
                    .accessibilityLabel("Workout location")
                if !text.isEmpty {
                    Button {
                        text = ""
                        completer.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
            )

            if showSuggestions && !completer.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.results.prefix(5), id: \.self) { result in
                        Button {
                            text = result.title
                            showSuggestions = false
                            isFocused = false
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                                Text(result.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(Theme.fontCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.sm)
                        }
                        .buttonStyle(.plain)

                        if result != completer.results.prefix(5).last {
                            Divider().padding(.leading, Theme.Spacing.sm)
                        }
                    }
                }
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.top, Theme.Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: text) { _, newValue in
            completer.search(query: newValue)
            showSuggestions = isFocused && !newValue.isEmpty
        }
        .onChange(of: isFocused) { _, focused in
            showSuggestions = focused && !text.isEmpty && !completer.results.isEmpty
        }
        .animation(.xomChill, value: showSuggestions)
    }
}

@MainActor
@Observable
private final class LocationCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter = {
        let c = MKLocalSearchCompleter()
        c.resultTypes = .pointOfInterest
        return c
    }()

    override init() {
        super.init()
        completer.delegate = self
    }

    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}
