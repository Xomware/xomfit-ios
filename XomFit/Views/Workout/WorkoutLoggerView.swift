import SwiftUI

struct WorkoutLoggerView: View {
    @StateObject private var viewModel = WorkoutLoggerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var workoutName = "New Workout"
    @State private var showExercisePicker = false
    @FocusState private var weightFieldFocused: Bool
    @FocusState private var repsFieldFocused: Bool
    
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Timer & Stats Header
                        VStack(spacing: Theme.paddingSmall) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .foregroundColor(Theme.accent)
                                    Text(viewModel.formatTime(viewModel.elapsedTime))
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundColor(Theme.textPrimary)
                                }
                                
                                Spacer()
                                
                                let (totalSets, totalVolume) = viewModel.getWorkoutStats()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(totalSets) sets")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.accent)
                                    Text(String(format: "%.0f lbs", totalVolume))
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding(Theme.paddingMedium)
                            .background(Theme.secondaryBackground)
                            .cornerRadius(Theme.cornerRadius)
                        }
                        .padding(Theme.paddingMedium)
                        
                        // Exercises & Sets
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: Theme.paddingMedium) {
                                                // Progressive Overload Suggestion Banner
                                    if let suggestion = viewModel.currentSuggestion, !viewModel.overloadDismissed {
                                        OverloadSuggestionView(
                                            suggestion: suggestion,
                                            onTap: { viewModel.showOverloadDetail = true },
                                            onDismiss: { viewModel.dismissSuggestion() }
                                        )
                                    }
                                    
                                    if let workout = viewModel.activeWorkout {
                                        if workout.exercises.isEmpty {
                                            // Empty State
                                            VStack(spacing: Theme.paddingMedium) {
                                                Image(systemName: "dumbbell")
                                                    .font(.system(size: 48))
                                                    .foregroundColor(Theme.textSecondary)
                                                Text("No exercises yet")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(Theme.textSecondary)
                                                Text("Add an exercise to start logging")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 60)
                                        } else {
                                            // Exercises List
                                            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                                                WorkoutLoggerExerciseCard(
                                                    exercise: exercise,
                                                    exerciseIndex: index,
                                                    viewModel: viewModel,
                                                    isSelected: viewModel.currentExerciseIndex == index
                                                )
                                                .id("exercise-\(index)")
                                            }
                                        }
                                    }
                                }
                                .padding(Theme.paddingMedium)
                            }
                            .onChange(of: viewModel.currentExerciseIndex) { index in
                                if let index = index {
                                    withAnimation {
                                        proxy.scrollTo("exercise-\(index)", anchor: .center)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Quick Add Exercises
                        if !viewModel.recentExercises.isEmpty {
                            VStack(spacing: Theme.paddingSmall) {
                                HStack {
                                    Text("Quick Add")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, Theme.paddingMedium)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.recentExercises.prefix(6)) { exercise in
                                            Button(action: { viewModel.quickAddExerciseFromPrevious(exercise) }) {
                                                Text(exercise.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(Theme.accent)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Theme.accent.opacity(0.2))
                                                    .cornerRadius(6)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Theme.paddingMedium)
                                }
                            }
                        }
                        
                        // Action Buttons
                        HStack(spacing: Theme.paddingMedium) {
                            Button(action: { showExercisePicker = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle")
                                    Text("Exercise")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.accent.opacity(0.15))
                                .cornerRadius(Theme.cornerRadius)
                            }
                            
                            Button(action: {
                                viewModel.finishWorkout()
                                dismiss()
                            }) {
                                Text("Finish")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Theme.accent)
                                    .cornerRadius(Theme.cornerRadius)
                            }
                        }
                        .padding(Theme.paddingMedium)
                    }
                }
                .navigationTitle("Workout Logger")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            viewModel.cancelWorkout()
                            dismiss()
                        }
                        .foregroundColor(Theme.destructive)
                    }
                }
                .sheet(isPresented: $showExercisePicker) {
                    WorkoutExercisePickerView { exercise in
                        viewModel.addExercise(exercise)
                    }
                }
                .sheet(isPresented: $viewModel.showOverloadDetail) {
                    if let suggestion = viewModel.currentSuggestion {
                        OverloadDetailView(
                            suggestion: suggestion,
                            sessions: viewModel.recentSessions
                        )
                    }
                }
                .onAppear {
                    viewModel.startWorkout(name: workoutName)
                }
            }
            
            // Rest Timer Overlay
            if viewModel.showingRestTimer && viewModel.isRestTimerRunning {
                RestTimerOverlay(viewModel: viewModel)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Exercise Card Component
struct WorkoutLoggerExerciseCard: View {
    let exercise: WorkoutExercise
    let exerciseIndex: Int
    @ObservedObject var viewModel: WorkoutLoggerViewModel
    let isSelected: Bool
    
    @State private var editingSetIndex: Int?
    @State private var showingDeleteAlert = false
    @State private var setToDelete: Int?

    // Form Check Video
    @State private var selectedSetForVideo: WorkoutSet?
    @State private var showFormCheckVideo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Exercise Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exercise.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.accent)
                    if !exercise.exercise.muscleGroups.isEmpty {
                        Text(exercise.exercise.muscleGroups.first?.displayName ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                if !exercise.sets.isEmpty {
                    Text("\(exercise.sets.count) sets")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // Set Rows Header
            if !exercise.sets.isEmpty {
                HStack(spacing: 0) {
                    Text("SET").frame(width: 30).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textSecondary)
                    Text("WEIGHT").frame(maxWidth: .infinity).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textSecondary)
                    Text("REPS").frame(maxWidth: .infinity).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textSecondary)
                    Text("RPE").frame(maxWidth: .infinity).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textSecondary)
                    Text("").frame(width: 30)
                }
                .padding(.vertical, 6)
                
                // Logged Sets
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    SwipeToDeleteView(
                        onDelete: {
                            setToDelete = index
                            showingDeleteAlert = true
                        }
                    ) {
                        HStack(spacing: 0) {
                            Text("\(index + 1)").frame(width: 30).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                            Text(set.displayWeight).frame(maxWidth: .infinity).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textPrimary)
                            Text("\(set.reps)").frame(maxWidth: .infinity).font(.system(size: 13)).foregroundColor(Theme.textPrimary)
                            if let rpe = set.rpe {
                                Text(String(format: "%.1f", rpe)).frame(maxWidth: .infinity).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                            } else {
                                Text("—").frame(maxWidth: .infinity).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                            }
                            // PR + Form Check Camera
                            HStack(spacing: 4) {
                                if set.isPersonalRecord {
                                    Image(systemName: "trophy.fill").foregroundColor(Theme.prGold).font(.system(size: 12))
                                }
                                Button(action: {
                                    selectedSetForVideo = set
                                    showFormCheckVideo = true
                                }) {
                                    Image(systemName: set.hasFormCheckVideo ? "video.fill" : "video")
                                        .font(.system(size: 13))
                                        .foregroundColor(set.hasFormCheckVideo ? Theme.accent : .gray.opacity(0.6))
                                }
                            }
                            .frame(width: 44)
                        }
                        .padding(.vertical, 8)
                        .background(Theme.secondaryBackground.opacity(0.5))
                        .cornerRadius(6)
                    }
                }
            }
            
            // Input Row
            VStack(spacing: Theme.paddingSmall) {
                if exercise.sets.isEmpty {
                    Text("Set 1").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 8) {
                    // Weight Input
                    TextField("lbs", text: $viewModel.inputWeight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: 70)
                        .placeholder(when: viewModel.inputWeight.isEmpty) {
                            Text("lbs").foregroundColor(Theme.textSecondary.opacity(0.6))
                        }
                    
                    // Reps Input
                    TextField("reps", text: $viewModel.inputReps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: 60)
                        .placeholder(when: viewModel.inputReps.isEmpty) {
                            Text("reps").foregroundColor(Theme.textSecondary.opacity(0.6))
                        }
                    
                    // RPE Input (optional)
                    TextField("rpe", text: $viewModel.inputRPE)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: 50)
                        .placeholder(when: viewModel.inputRPE.isEmpty) {
                            Text("rpe").foregroundColor(Theme.textSecondary.opacity(0.6))
                        }
                    
                    // Quick Log Button
                    Button(action: {
                        let (valid, weight, reps) = viewModel.validateInputs()
                        if valid, let weight = weight, let reps = reps {
                            let rpe = Double(viewModel.inputRPE)
                            viewModel.addSet(to: exerciseIndex, weight: weight, reps: reps, rpe: rpe)
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.accent)
                    }
                    .disabled(viewModel.inputWeight.isEmpty || viewModel.inputReps.isEmpty)
                }
            }
            .padding(12)
            .background(
                isSelected ? Theme.accent.opacity(0.1) : Theme.secondaryBackground.opacity(0.7)
            )
            .cornerRadius(Theme.cornerRadius)
            .onTapGesture {
                viewModel.currentExerciseIndex = exerciseIndex
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .alert("Delete Set?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let index = setToDelete {
                    viewModel.deleteSet(from: exerciseIndex, setIndex: index)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        // Form Check Video recorder
        .fullScreenCover(isPresented: $showFormCheckVideo) {
            if let set = selectedSetForVideo {
                FormCheckVideoView(
                    set: set,
                    exerciseName: exercise.exercise.name
                ) { localURL, remoteURL in
                    // Store URLs back on the set via ViewModel
                    viewModel.attachFormCheckVideo(
                        to: exerciseIndex,
                        setId: set.id,
                        localURL: localURL,
                        remoteURL: remoteURL
                    )
                }
            }
        }
    }
}

// MARK: - Rest Timer Overlay
struct RestTimerOverlay: View {
    @ObservedObject var viewModel: WorkoutLoggerViewModel
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: Theme.paddingMedium) {
                Text("Rest Time")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                
                Text(viewModel.formatTime(viewModel.restTimeRemaining))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accent)
                
                HStack(spacing: Theme.paddingMedium) {
                    Button(action: { viewModel.skipRestTimer() }) {
                        Text("Skip")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accent.opacity(0.15))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if viewModel.isRestTimerRunning {
                            viewModel.pauseRestTimer()
                        } else {
                            viewModel.resumeRestTimer()
                        }
                    }) {
                        Text(viewModel.isRestTimerRunning ? "Pause" : "Resume")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accent)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(Theme.paddingLarge)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .padding(Theme.paddingMedium)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .ignoresSafeArea()
    }
}

// MARK: - Swipe to Delete View
struct SwipeToDeleteView<Content: View>: View {
    let onDelete: () -> Void
    let content: () -> Content
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete Background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
                }
                .frame(width: 70)
                .background(Theme.destructive)
            }
            .cornerRadius(6)
            
            // Content
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = min(value.translation.width, 0)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -30 {
                                    offset = -70
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}

// MARK: - Exercise Picker View
struct WorkoutExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    let onSelect: (Exercise) -> Void
    
    var filteredExercises: [Exercise] {
        let allExercises = ExerciseDatabase.all
        if searchText.isEmpty { return allExercises }
        return allExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button(action: {
                    onSelect(exercise)
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        if !exercise.muscleGroups.isEmpty {
                            Text(exercise.muscleGroups.map { $0.displayName }.joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Placeholder Modifier
extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    WorkoutLoggerView()
}
