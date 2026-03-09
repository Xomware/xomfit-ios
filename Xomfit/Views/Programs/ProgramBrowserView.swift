import SwiftUI

struct ProgramsRootView: View {
    @StateObject private var service = ProgramService.shared
    @State private var showBuilder = false
    @State private var showBrowser = false
    @State private var selectedProgram: TrainingProgram?
    
    var body: some View {
        NavigationView {
            List {
                // Active Program
                if let active = service.activeProgram {
                    Section("Active Program") {
                        ActiveProgramCard(program: active, service: service)
                    }
                }
                
                // My Programs
                if !service.programs.filter({ !$0.isActive }).isEmpty {
                    Section("My Programs") {
                        ForEach(service.programs.filter { !$0.isActive }) { program in
                            ProgramRow(program: program, service: service)
                        }
                        .onDelete { indexSet in
                            let filtered = service.programs.filter { !$0.isActive }
                            indexSet.forEach { service.delete(filtered[$0]) }
                        }
                    }
                }
                
                // Community
                Section("Community Programs") {
                    Button("Browse Community Programs") {
                        showBrowser = true
                    }
                }
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showBuilder = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showBuilder) {
                ProgramBuilderView()
            }
            .sheet(isPresented: $showBrowser) {
                CommunityProgramsView()
            }
        }
    }
}

// MARK: - Active Program Card
struct ActiveProgramCard: View {
    let program: TrainingProgram
    let service: ProgramService
    
    var completionCount: Int {
        service.completionsForProgram(program.id).count
    }
    
    var progress: Double {
        service.progressForProgram(program.id, totalDays: program.totalWorkouts)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.name)
                        .font(.headline)
                    Text("\(program.difficulty.rawValue) • \(program.goal.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let week = program.currentWeek {
                    VStack(alignment: .trailing) {
                        Text("Week \(week)")
                            .font(.caption)
                            .bold()
                        Text("of \(program.durationWeeks)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ProgressView(value: progress)
                .tint(.blue)
            
            Text("\(completionCount) of \(program.totalWorkouts) sessions complete (\(Int(progress * 100))%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Program Row
struct ProgramRow: View {
    let program: TrainingProgram
    let service: ProgramService
    @State private var showActions = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                    .font(.subheadline)
                    .bold()
                Text("\(program.durationWeeks) weeks · \(program.daysPerWeek) days/week · \(program.difficulty.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Menu {
                Button("Start Program") { service.activate(program) }
                Button("Duplicate") { _ = service.duplicate(program) }
                Button("Delete", role: .destructive) { service.delete(program) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Program Builder
struct ProgramBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var service = ProgramService.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var durationWeeks = 4
    @State private var daysPerWeek = 3
    @State private var difficulty: ProgramDifficulty = .intermediate
    @State private var goal: ProgramGoal = .strength
    @State private var step = 0
    
    var body: some View {
        NavigationView {
            Form {
                if step == 0 {
                    Section("Program Details") {
                        TextField("Program name", text: $name)
                        TextField("Description (optional)", text: $description)
                        Stepper("Duration: \(durationWeeks) weeks", value: $durationWeeks, in: 1...52)
                        Stepper("Days/week: \(daysPerWeek)", value: $daysPerWeek, in: 1...7)
                    }
                    Section("Goal & Difficulty") {
                        Picker("Goal", selection: $goal) {
                            ForEach(ProgramGoal.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(ProgramDifficulty.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard !name.isEmpty else { return }
                        var program = TrainingProgram(
                            name: name, description: description,
                            durationWeeks: durationWeeks, daysPerWeek: daysPerWeek,
                            difficulty: difficulty, goal: goal
                        )
                        program.weeks = service.buildDefaultWeeks(for: program)
                        service.save(program)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Community Programs
struct CommunityProgramsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var service = ProgramService.shared
    
    var body: some View {
        NavigationView {
            List(service.communityPrograms()) { program in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(program.name)
                                .font(.subheadline)
                                .bold()
                            Text("by \(program.author)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(program.difficulty.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(difficultyColor(program.difficulty).opacity(0.15))
                                .foregroundColor(difficultyColor(program.difficulty))
                                .cornerRadius(4)
                        }
                    }
                    Text(program.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Label("\(program.durationWeeks)w", systemImage: "calendar")
                        Label("\(program.daysPerWeek)d/wk", systemImage: "figure.strengthtraining.traditional")
                        Label(program.goal.rawValue, systemImage: "target")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    Button("Import Program") {
                        var copy = program
                        copy.id = UUID()
                        copy.isPublic = false
                        service.save(copy)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Community Programs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    func difficultyColor(_ d: ProgramDifficulty) -> Color {
        switch d {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}
