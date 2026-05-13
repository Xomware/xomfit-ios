import SwiftUI

// MARK: - ToolsView
//
// Tools destination surfaced via the hamburger drawer (#372). Lists the
// existing utility tools — Plate Calculator and 1RM Estimator — extracted
// from the Settings → Tools section so they're discoverable as their own
// drawer entry. The tool screens themselves remain unchanged and continue
// to present as sheets.

struct ToolsView: View {
    @State private var showPlateCalculator = false
    @State private var showOneRMEstimator = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    Button {
                        Haptics.selection()
                        showPlateCalculator = true
                    } label: {
                        toolRow(icon: "circle.hexagongrid.fill", label: "Plate Calculator")
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.selection()
                        showOneRMEstimator = true
                    } label: {
                        toolRow(icon: "function", label: "1RM Estimator")
                    }
                    .buttonStyle(.plain)
                } header: {
                    XomMetricLabel("Tools")
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.hairline)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPlateCalculator) {
            PlateCalculatorView().presentationDetents([.large])
        }
        .sheet(isPresented: $showOneRMEstimator) {
            OneRMEstimatorView().presentationDetents([.large])
        }
    }

    private func toolRow(icon: String, label: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .frame(width: Theme.Spacing.lg)
                .foregroundStyle(Theme.accent)
            Text(label)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ToolsView()
    }
    .preferredColorScheme(.dark)
}
#endif
