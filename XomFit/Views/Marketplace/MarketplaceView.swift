import SwiftUI

struct MarketplaceView: View {
    @StateObject private var viewModel = MarketplaceViewModel()
    @State private var selectedProgram: WorkoutProgram? = nil
    @State private var showCreateProgram = false
    @State private var showFilters = false
    @State private var selectedTab: MarketplaceTab = .browse

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab selector
                    tabSelector

                    // Content
                    switch selectedTab {
                    case .browse: browseContent
                    case .myPrograms: myProgramsContent
                    case .imported: importedContent
                    }
                }
            }
            .navigationTitle("Marketplace")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    createButton
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search programs…")
            .sheet(item: $selectedProgram) { prog in
                ProgramDetailView(program: prog, viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateProgram) {
                CreateProgramView(viewModel: viewModel)
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadInitial()
                await viewModel.loadMyContent()
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(MarketplaceTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.displayName)
                            .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? Theme.accent : Theme.textSecondary)
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == tab ? Theme.accent : .clear)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .background(Theme.background)
        .overlay(Divider().foregroundColor(Color.white.opacity(0.08)), alignment: .bottom)
    }

    // MARK: - Browse

    @ViewBuilder
    private var browseContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Filter chips
                if viewModel.activeFilterCount > 0 {
                    activeFilterChips
                }

                // Featured carousel (only when not filtering)
                if viewModel.selectedFilter == .all && viewModel.searchQuery.isEmpty && !viewModel.featuredPrograms.isEmpty {
                    featuredSection
                }

                // Programs grid
                programsGrid
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .refreshable { await viewModel.loadInitial() }
        .overlay {
            if viewModel.isLoading && viewModel.programs.isEmpty {
                loadingOverlay
            }
        }
    }

    // MARK: - Featured

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "⭐ Featured", subtitle: "Curated by the community")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.featuredPrograms) { prog in
                        FeaturedProgramCard(program: prog, isImported: viewModel.isImported(prog))
                            .onTapGesture { selectedProgram = prog }
                    }
                }
            }
        }
    }

    // MARK: - Programs Grid

    @ViewBuilder
    private var programsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: sortTitle, subtitle: "\(viewModel.programs.count) programs")
                Spacer()
                sortMenu
            }

            if viewModel.programs.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(viewModel.programs) { prog in
                        ProgramCard(program: prog, isImported: viewModel.isImported(prog))
                            .onTapGesture { selectedProgram = prog }
                            .onAppear {
                                if prog.id == viewModel.programs.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
    }

    // MARK: - Active Filter Chips

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.selectedFilter != .all {
                    FilterChip(label: viewModel.selectedFilter.displayName) {
                        viewModel.selectedFilter = .all
                    }
                }
                if let goal = viewModel.selectedGoal {
                    FilterChip(label: goal.displayName) { viewModel.selectedGoal = nil }
                }
                if let diff = viewModel.selectedDifficulty {
                    FilterChip(label: diff.displayName) { viewModel.selectedDifficulty = nil }
                }
                Button("Clear all") { viewModel.clearFilters() }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
        }
    }

    // MARK: - My Programs

    @ViewBuilder
    private var myProgramsContent: some View {
        Group {
            if viewModel.myPrograms.isEmpty {
                emptyMyPrograms
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(viewModel.myPrograms) { prog in
                            ProgramCard(program: prog)
                                .onTapGesture { selectedProgram = prog }
                        }
                    }
                    .padding(Theme.paddingMedium)
                }
            }
        }
    }

    // MARK: - Imported

    @ViewBuilder
    private var importedContent: some View {
        Group {
            if viewModel.importedPrograms.isEmpty {
                emptyImported
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(viewModel.importedPrograms) { prog in
                            ProgramCard(program: prog, isImported: true)
                                .onTapGesture { selectedProgram = prog }
                        }
                    }
                    .padding(Theme.paddingMedium)
                }
            }
        }
    }

    // MARK: - Toolbar

    private var filterButton: some View {
        Button { showFilters = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(viewModel.activeFilterCount > 0 ? Theme.accent : Theme.textSecondary)
                if viewModel.activeFilterCount > 0 {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    private var createButton: some View {
        Button { showCreateProgram = true } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(Theme.accent)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(MarketplaceSortOrder.allCases, id: \.self) { order in
                Button {
                    viewModel.sortOrder = order
                } label: {
                    HStack {
                        Text(order.displayName)
                        if viewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.sortOrder.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accent)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.accent)
            }
        }
    }

    // MARK: - Computed

    private var sortTitle: String {
        switch viewModel.selectedFilter {
        case .all:      return "All Programs"
        case .featured: return "Featured"
        case .new:      return "New"
        case .popular:  return "Popular"
        case .free:     return "Free Programs"
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("No programs found")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            Text("Try adjusting your filters or search query.")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Clear Filters") { viewModel.clearFilters() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    private var emptyMyPrograms: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("No programs yet")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            Text("Create your first workout program and share it with the community.")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Create Program") { showCreateProgram = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
    }

    private var emptyImported: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("No imported programs")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            Text("Browse the marketplace and import programs to your workout plan.")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Browse Programs") { selectedTab = .browse }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Theme.accent)
            Text("Loading programs…")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Marketplace Tab

enum MarketplaceTab: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case myPrograms = "My Programs"
    case imported = "Imported"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            if let sub = subtitle {
                Text(sub)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    // Browse filter
                    Section("Browse") {
                        ForEach(MarketplaceFilter.allCases, id: \.self) { filter in
                            HStack {
                                Text(filter.displayName)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                if viewModel.selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.selectedFilter = filter }
                        }
                    }
                    .listRowBackground(Theme.cardBackground)

                    // Goal filter
                    Section("Goal") {
                        ForEach(ProgramGoal.allCases, id: \.self) { goal in
                            HStack {
                                Image(systemName: goal.icon)
                                    .foregroundColor(Theme.accent)
                                    .frame(width: 20)
                                Text(goal.displayName)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                if viewModel.selectedGoal == goal {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedGoal = (viewModel.selectedGoal == goal) ? nil : goal
                            }
                        }
                    }
                    .listRowBackground(Theme.cardBackground)

                    // Difficulty filter
                    Section("Difficulty") {
                        ForEach(ProgramDifficulty.allCases, id: \.self) { diff in
                            HStack {
                                DifficultyBadge(difficulty: diff)
                                Spacer()
                                if viewModel.selectedDifficulty == diff {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedDifficulty = (viewModel.selectedDifficulty == diff) ? nil : diff
                            }
                        }
                    }
                    .listRowBackground(Theme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { viewModel.clearFilters() }
                        .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    MarketplaceView()
        .preferredColorScheme(.dark)
}
