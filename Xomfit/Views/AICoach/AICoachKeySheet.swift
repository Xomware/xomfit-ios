import SwiftUI

/// Key entry, reachable from the Coach's own error banner.
///
/// The Coach already told lifters a setting existed — "Add one in Settings →
/// Anthropic API Key" — which is not the same as letting them get there.
/// Reading an instruction, leaving the screen, and hunting a settings tree is
/// three steps too many for the one error the user can actually fix.
struct AICoachKeySheet: View {
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss

    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("The Coach runs on Anthropic's API. Paste a key and it works immediately — the key stays on this device and is never sent anywhere but Anthropic.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    SecureField("sk-ant-...", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(Theme.fontBody)
                        .padding(Theme.Spacing.md)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))

                    Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                        Label("Get a key from Anthropic", systemImage: "arrow.up.right.square")
                            .font(Theme.fontCaption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(minHeight: 44)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        apiKey = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .foregroundStyle(Theme.accent)
                    .fontWeight(.semibold)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            // Pre-filled so this doubles as "check what I have" rather than only
            // "set one for the first time".
            .onAppear { draft = apiKey }
        }
    }
}
