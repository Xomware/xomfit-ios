import SwiftUI

struct TemplateListView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (WorkoutTemplate) -> Void

    @State private var templates: [WorkoutTemplate] = []

    private var groupedTemplates: [(WorkoutTemplate.TemplateCategory, [WorkoutTemplate])] {
        let grouped = Dictionary(grouping: templates, by: \.category)
        return WorkoutTemplate.TemplateCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    ForEach(groupedTemplates, id: \.0) { category, items in
                        Section {
                            ForEach(items) { template in
                                templateRow(template)
                                    .listRowBackground(Theme.surface)
                                    .listRowSeparator(.hidden)
                            }
                            .onDelete { indexSet in
                                deleteCustom(from: items, at: indexSet)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(Theme.accent)
                                Text(category.displayName)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .font(.subheadline.weight(.bold))
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .onAppear { templates = TemplateService.shared.allTemplates() }
    }

    // MARK: - Row

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button {
            onSelect(template)
            dismiss()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: template.category.icon)
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(template.description)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(template.exercises.count) exercises")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                    Text("~\(template.estimatedDuration)m")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, Theme.Spacing.tight)
        }
        .buttonStyle(.plain)
        .deleteDisabled(!template.isCustom)
        .accessibilityLabel("\(template.name), \(template.description), \(template.exercises.count) exercises, about \(template.estimatedDuration) minutes")
    }

    // MARK: - Delete

    private func deleteCustom(from items: [WorkoutTemplate], at indexSet: IndexSet) {
        for idx in indexSet {
            let template = items[idx]
            guard template.isCustom else { continue }
            TemplateService.shared.deleteCustomTemplate(id: template.id)
        }
        templates = TemplateService.shared.allTemplates()
    }
}
