import SwiftUI

struct ProgramDetailView: View {
    let program: WorkoutProgram
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var reviews: [ProgramReview] = []
    @State private var isLoadingReviews = false
    @State private var isImporting = false
    @State private var importSuccess = false
    @State private var showReviewSheet = false
    @State private var showImportConfirmation = false
    @State private var selectedTab: DetailTab = .overview

    private var isImported: Bool { viewModel.isImported(program) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        tabBar
                        switch selectedTab {
                        case .overview:  overviewSection
                        case .exercises: exercisesSection
                        case .reviews:   reviewsSection
                        }
                    }
                }

                // Floating import button
                VStack {
                    Spacer()
                    importButton
                        .padding(.horizontal, Theme.paddingMedium)
                        .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: "Check out \(program.title) on XomFit!") {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showReviewSheet) {
                ReviewSheet(programId: program.id) { rating, body in
                    await submitReview(rating: rating, body: body)
                }
            }
            .task {
                await loadReviews()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    DifficultyBadge(difficulty: program.difficulty)
                    Text(program.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                if program.isFeatured {
                    VStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(Theme.warning)
                        Text("Featured")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.warning)
                    }
                }
            }

            // Creator
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(program.creatorName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accent)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(program.creatorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Creator")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                DetailStatBox(title: "Days/Week", value: "\(program.daysPerWeek)", icon: "calendar")
                DetailStatBox(title: "Duration", value: "\(program.durationWeeks) wks", icon: "clock")
                DetailStatBox(title: "Rating", value: program.formattedRating, icon: "star.fill")
                DetailStatBox(title: "Exercises", value: "\(program.exercises.count)", icon: "dumbbell.fill")
                DetailStatBox(title: "Imports", value: "\(program.importCount)", icon: "arrow.down.circle")
                DetailStatBox(title: "Reviews", value: "\(program.reviewCount)", icon: "text.bubble")
            }

            // Goals
            if !program.goals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(program.goals, id: \.self) { goal in
                            HStack(spacing: 4) {
                                Image(systemName: goal.icon)
                                    .font(.system(size: 11))
                                Text(goal.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.accent.opacity(0.12))
                            .cornerRadius(20)
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
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
        .background(Theme.background)
        .overlay(Divider().foregroundColor(Color.white.opacity(0.08)), alignment: .bottom)
        .padding(.bottom, 8)
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("About this program")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(program.description)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(4)
            }

            // Tags
            if !program.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    FlowLayout(spacing: 6) {
                        ForEach(program.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.cardBackground)
                                .cornerRadius(20)
                        }
                    }
                }
            }

            Spacer(minLength: 80) // Space for floating button
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.bottom, 16)
    }

    // MARK: - Exercises

    @ViewBuilder
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if program.exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textSecondary)
                    Text("Exercise list not available")
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                let grouped = Dictionary(grouping: program.exercises, by: { "Day \($0.weekDay)" })
                ForEach(grouped.keys.sorted(), id: \.self) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.accent)
                        ForEach(grouped[day] ?? []) { ex in
                            ProgramExerciseRow(exercise: ex)
                        }
                    }
                }
            }
            Spacer(minLength: 80)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Reviews

    @ViewBuilder
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rating summary
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(program.formattedRating)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= program.rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.warning)
                        }
                    }
                    Text("\(program.reviewCount) reviews")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Button {
                    showReviewSheet = true
                } label: {
                    Label("Write Review", systemImage: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accent)
                        .cornerRadius(Theme.cornerRadiusSmall)
                }
            }
            .padding(Theme.paddingMedium)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)

            if isLoadingReviews {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if reviews.isEmpty {
                Text("No reviews yet. Be the first!")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(30)
            } else {
                ForEach(reviews) { review in
                    ReviewCard(review: review)
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Import Button

    @ViewBuilder
    private var importButton: some View {
        if isImported {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Added to Your Programs")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent.opacity(0.12))
            .cornerRadius(Theme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1)
            )
        } else {
            Button {
                Task { await handleImport() }
            } label: {
                HStack(spacing: 8) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.black)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(isImporting ? "Importing…" : "Import Program — Free")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent)
                .cornerRadius(Theme.cornerRadius)
            }
            .disabled(isImporting)
        }
    }

    // MARK: - Actions

    private func handleImport() async {
        isImporting = true
        let success = await viewModel.importProgram(program)
        isImporting = false
        if success {
            withAnimation { importSuccess = true }
        }
    }

    private func loadReviews() async {
        isLoadingReviews = true
        do {
            reviews = try await MarketplaceService.shared.fetchReviews(programId: program.id)
        } catch {
            // Use empty state
        }
        isLoadingReviews = false
    }

    private func submitReview(rating: Int, body: String) async {
        do {
            try await MarketplaceService.shared.submitReview(programId: program.id, rating: rating, body: body)
            await loadReviews()
        } catch {
            // Silently fail
        }
    }
}

// MARK: - Detail Tab

enum DetailTab: String, CaseIterable, Identifiable {
    case overview  = "Overview"
    case exercises = "Exercises"
    case reviews   = "Reviews"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Detail Stat Box

struct DetailStatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.accent)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}

// MARK: - Exercise Row

struct ProgramExerciseRow: View {
    let exercise: ProgramExercise

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text("\(exercise.order)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(exercise.sets) sets × \(exercise.reps) reps · \(exercise.restSeconds)s rest")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            if let notes = exercise.notes, !notes.isEmpty {
                Image(systemName: "info.circle")
                    .foregroundColor(Theme.textSecondary)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: ProgramReview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(Theme.secondaryBackground)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(review.userName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.warning)
                        }
                    }
                }
                Spacer()
                Text(review.createdAt, style: .relative)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            Text(review.body)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Review Sheet

struct ReviewSheet: View {
    let programId: String
    let onSubmit: (Int, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 5
    @State private var reviewBody: String = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    // Star rating
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Rating")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundColor(star <= rating ? Theme.warning : Theme.textSecondary)
                                    .onTapGesture { rating = star }
                            }
                        }
                    }

                    // Body
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        TextEditor(text: $reviewBody)
                            .frame(minHeight: 120)
                            .padding(10)
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadiusSmall)
                            .foregroundColor(Theme.textPrimary)
                            .font(Theme.fontBody)
                    }

                    Spacer()

                    Button {
                        Task {
                            isSubmitting = true
                            await onSubmit(rating, reviewBody)
                            isSubmitting = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().tint(.black) }
                            Text(isSubmitting ? "Submitting…" : "Submit Review")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(reviewBody.isEmpty ? Theme.accent.opacity(0.4) : Theme.accent)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    .disabled(reviewBody.isEmpty || isSubmitting)
                }
                .padding(Theme.paddingMedium)
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Flow Layout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    ProgramDetailView(
        program: WorkoutProgram.mockPrograms[0],
        viewModel: MarketplaceViewModel()
    )
}
