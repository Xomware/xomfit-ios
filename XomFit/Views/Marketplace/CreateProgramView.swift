import SwiftUI

// MARK: - Create Program View (multi-step wizard)

struct CreateProgramView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: CreateStep = .basics
    @State private var isPublishing = false

    // Form state — carried across steps
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var daysPerWeek: Int = 4
    @State private var durationWeeks: Int = 8
    @State private var difficulty: ProgramDifficulty = .intermediate
    @State private var selectedGoals: Set<ProgramGoal> = []
    @State private var exercises: [ProgramExercise] = []
    @State private var tags: String = ""
    @State private var isPublic: Bool = true

    private var progressFraction: Double {
        Double(CreateStep.allCases.firstIndex(of: currentStep)! + 1) / Double(CreateStep.allCases.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    progressBar

                    // Step content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            stepHeader
                            stepContent
                        }
                        .padding(Theme.paddingMedium)
                        .padding(.bottom, 100)
                    }

                    // Navigation buttons
                    navigationRow
                }
            }
            .navigationTitle("Create Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("Step \(currentStep.stepNumber) of \(CreateStep.allCases.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.cardBackground)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * progressFraction)
                    .animation(.spring(response: 0.4), value: progressFraction)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Step Header

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(currentStep.icon)
                Text(currentStep.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            Text(currentStep.subtitle)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .basics:    basicsStep
        case .goals:     goalsStep
        case .exercises: exercisesStep
        case .details:   detailsStep
        case .review:    reviewStep
        }
    }

    // MARK: - Step 1: Basics

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            FormField(label: "Program Name") {
                TextField("e.g. 5/3/1 Powerbuilding", text: $title)
                    .formStyle()
            }

            FormField(label: "Description") {
                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Describe your program, who it's for, and what results to expect…")
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .foregroundColor(Theme.textPrimary)
                        .font(Theme.fontBody)
                        .scrollContentBackground(.hidden)
                }
                .padding(10)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadiusSmall)
            }

            FormField(label: "Difficulty") {
                HStack(spacing: 8) {
                    ForEach(ProgramDifficulty.allCases, id: \.self) { diff in
                        Button {
                            difficulty = diff
                        } label: {
                            Text(diff.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(difficulty == diff ? .black : Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(difficulty == diff ? Theme.accent : Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadiusSmall)
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                FormField(label: "Days/Week") {
                    Stepper("\(daysPerWeek)", value: $daysPerWeek, in: 1...7)
                        .foregroundColor(Theme.textPrimary)
                }
                FormField(label: "Duration (weeks)") {
                    Stepper("\(durationWeeks)", value: $durationWeeks, in: 1...52)
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
    }

    // MARK: - Step 2: Goals

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ProgramGoal.allCases, id: \.self) { goal in
                    let isSelected = selectedGoals.contains(goal)
                    Button {
                        if isSelected {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? .black : Theme.accent)
                            Text(goal.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isSelected ? .black : Theme.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(12)
                        .background(isSelected ? Theme.accent : Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                }
            }

            if selectedGoals.isEmpty {
                Label("Select at least one goal", systemImage: "exclamationmark.circle")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.warning)
            }
        }
    }

    // MARK: - Step 3: Exercises

    private var exercisesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add exercise form
            AddExerciseInline { exercise in
                exercises.append(exercise)
            }

            if exercises.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.textSecondary)
                    Text("Add exercises to your program above.")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s") added")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)

                ForEach(exercises) { ex in
                    ExerciseRow(exercise: ex)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                exercises.removeAll { $0.id == ex.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    // MARK: - Step 4: Details

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            FormField(label: "Tags (comma-separated)") {
                TextField("e.g. 4-day, barbell, PPL", text: $tags)
                    .formStyle()
            }

            FormField(label: "Visibility") {
                VStack(spacing: 8) {
                    visibilityOption(
                        title: "Public",
                        subtitle: "Anyone on the marketplace can find and import this program.",
                        icon: "globe",
                        isSelected: isPublic,
                        action: { isPublic = true }
                    )
                    visibilityOption(
                        title: "Private",
                        subtitle: "Only you can see and use this program.",
                        icon: "lock.fill",
                        isSelected: !isPublic,
                        action: { isPublic = false }
                    )
                }
            }
        }
    }

    private func visibilityOption(
        title: String, subtitle: String, icon: String,
        isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitle)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
            }
            .padding(12)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Step 5: Review & Publish

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary card
            VStack(alignment: .leading, spacing: 12) {
                Text(title.isEmpty ? "Untitled Program" : title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text(description.isEmpty ? "No description" : description)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(4)

                Divider().foregroundColor(Color.white.opacity(0.1))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ReviewRow(label: "Difficulty", value: difficulty.displayName)
                    ReviewRow(label: "Days/Week",  value: "\(daysPerWeek)")
                    ReviewRow(label: "Duration",   value: "\(durationWeeks) weeks")
                    ReviewRow(label: "Exercises",  value: "\(exercises.count)")
                    ReviewRow(label: "Visibility", value: isPublic ? "Public" : "Private")
                    ReviewRow(label: "Goals",      value: "\(selectedGoals.count)")
                }

                if !selectedGoals.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(selectedGoals), id: \.self) { goal in
                                Text(goal.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.accent.opacity(0.12))
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
            }
            .padding(Theme.paddingMedium)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)

            // Validation warnings
            if !isValid {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Please complete before publishing:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.warning)
                    ForEach(validationErrors, id: \.self) { err in
                        Label(err, systemImage: "exclamationmark.circle")
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.warning)
                    }
                }
                .padding(12)
                .background(Theme.warning.opacity(0.1))
                .cornerRadius(Theme.cornerRadiusSmall)
            }

            // Publish button
            Button {
                Task { await publish() }
            } label: {
                HStack(spacing: 8) {
                    if isPublishing {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(isPublishing ? "Publishing…" : (isPublic ? "Publish to Marketplace" : "Save Program"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid ? Theme.accent : Theme.accent.opacity(0.4))
                .cornerRadius(Theme.cornerRadius)
            }
            .disabled(!isValid || isPublishing)
        }
    }

    // MARK: - Navigation Row

    private var navigationRow: some View {
        HStack(spacing: 12) {
            if currentStep != .basics {
                Button {
                    withAnimation { currentStep = currentStep.previous }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                }
            }

            if currentStep != .review {
                Button {
                    withAnimation { currentStep = currentStep.next }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canAdvance ? Theme.accent : Theme.accent.opacity(0.4))
                    .cornerRadius(Theme.cornerRadius)
                }
                .disabled(!canAdvance)
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, 12)
        .background(Theme.background.opacity(0.95))
    }

    // MARK: - Validation

    private var canAdvance: Bool {
        switch currentStep {
        case .basics:    return !title.trimmingCharacters(in: .whitespaces).isEmpty && !description.isEmpty
        case .goals:     return !selectedGoals.isEmpty
        case .exercises: return true  // Optional step
        case .details:   return true
        case .review:    return isValid
        }
    }

    private var isValid: Bool {
        !title.isEmpty && !description.isEmpty && !selectedGoals.isEmpty
    }

    private var validationErrors: [String] {
        var errors: [String] = []
        if title.isEmpty      { errors.append("Program name is required") }
        if description.isEmpty { errors.append("Description is required") }
        if selectedGoals.isEmpty { errors.append("Select at least one goal") }
        return errors
    }

    // MARK: - Publish

    private func publish() async {
        isPublishing = true
        let tagList = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let program = WorkoutProgram(
            id: UUID().uuidString,
            title: title,
            description: description,
            creatorId: "",   // Filled in by backend via auth context
            creatorName: "", // Filled in by backend
            creatorAvatarUrl: nil,
            daysPerWeek: daysPerWeek,
            durationWeeks: durationWeeks,
            difficulty: difficulty,
            goals: Array(selectedGoals),
            exercises: exercises,
            price: 0,
            rating: 0,
            reviewCount: 0,
            importCount: 0,
            isFeatured: false,
            isPublic: isPublic,
            tags: tagList,
            createdAt: Date(),
            updatedAt: Date()
        )

        let success = await viewModel.publishProgram(program)
        isPublishing = false
        if success { dismiss() }
    }
}

// MARK: - Create Steps

enum CreateStep: CaseIterable, Equatable {
    case basics, goals, exercises, details, review

    var stepNumber: Int { CreateStep.allCases.firstIndex(of: self)! + 1 }

    var title: String {
        switch self {
        case .basics:    return "Basics"
        case .goals:     return "Goals"
        case .exercises: return "Exercises"
        case .details:   return "Details"
        case .review:    return "Review & Publish"
        }
    }

    var subtitle: String {
        switch self {
        case .basics:    return "Give your program a name, description, and difficulty."
        case .goals:     return "What are the primary training goals of this program?"
        case .exercises: return "Add the exercises that make up your program."
        case .details:   return "Add tags and set visibility options."
        case .review:    return "Review your program and publish it to the marketplace."
        }
    }

    var icon: String {
        switch self {
        case .basics:    return "📝"
        case .goals:     return "🎯"
        case .exercises: return "🏋️"
        case .details:   return "⚙️"
        case .review:    return "🚀"
        }
    }

    var next: CreateStep {
        let all = CreateStep.allCases
        let idx = all.firstIndex(of: self)!
        return idx + 1 < all.count ? all[idx + 1] : self
    }

    var previous: CreateStep {
        let all = CreateStep.allCases
        let idx = all.firstIndex(of: self)!
        return idx > 0 ? all[idx - 1] : self
    }
}

// MARK: - Form Field

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Form Text Field Style

extension TextField {
    func formStyle() -> some View {
        self
            .font(Theme.fontBody)
            .foregroundColor(Theme.textPrimary)
            .padding(12)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadiusSmall)
    }
}

// MARK: - Review Summary Row

struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - Add Exercise Inline

struct AddExerciseInline: View {
    let onAdd: (ProgramExercise) -> Void

    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var reps: String = "8-12"
    @State private var restSeconds: Int = 90
    @State private var weekDay: Int = 1
    @State private var exerciseCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Exercise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)

            TextField("Exercise name", text: $name)
                .formStyle()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sets").font(Theme.fontCaption).foregroundColor(Theme.textSecondary)
                    Stepper("\(sets)", value: $sets, in: 1...20)
                        .foregroundColor(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reps").font(Theme.fontCaption).foregroundColor(Theme.textSecondary)
                    TextField("8-12", text: $reps)
                        .formStyle()
                        .frame(width: 80)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rest (sec)").font(Theme.fontCaption).foregroundColor(Theme.textSecondary)
                    Stepper("\(restSeconds)s", value: $restSeconds, in: 30...300, step: 15)
                        .foregroundColor(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Day").font(Theme.fontCaption).foregroundColor(Theme.textSecondary)
                    Stepper("Day \(weekDay)", value: $weekDay, in: 1...7)
                        .foregroundColor(Theme.textPrimary)
                }
            }

            Button {
                guard !name.isEmpty else { return }
                exerciseCount += 1
                onAdd(ProgramExercise(
                    id: UUID().uuidString,
                    exerciseName: name,
                    muscleGroups: [],
                    sets: sets,
                    reps: reps,
                    restSeconds: restSeconds,
                    notes: nil,
                    weekDay: weekDay,
                    order: exerciseCount
                ))
                name = ""
                sets = 3
                reps = "8-12"
                restSeconds = 90
            } label: {
                Label("Add Exercise", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(name.isEmpty ? Theme.textSecondary : Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .strokeBorder(
                                name.isEmpty ? Color.white.opacity(0.06) : Theme.accent.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            }
            .disabled(name.isEmpty)
        }
        .padding(Theme.paddingMedium)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Preview

#Preview {
    CreateProgramView(viewModel: MarketplaceViewModel())
}
