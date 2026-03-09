import SwiftUI

struct ShareView: View {
    @StateObject private var viewModel = ExportViewModel()
    @State private var selectedCardType = 0
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    let cardTypes = ["PR Card", "Workout Summary", "Streak Milestone"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Card type selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share Card Type")
                            .font(.headline)
                        Picker("Card Type", selection: $selectedCardType) {
                            ForEach(0..<cardTypes.count, id: \.self) {
                                Text(cardTypes[$0]).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Card preview
                    Group {
                        switch selectedCardType {
                        case 0: PRShareCard(summary: viewModel.summary)
                        case 1: WorkoutSummaryCard(summary: viewModel.summary)
                        default: StreakCard(streak: viewModel.streak)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Share buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            shareCurrentCard()
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    // Export section
                    ExportSection(viewModel: viewModel)
                }
                .padding(.vertical)
            }
            .navigationTitle("Share & Export")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }
    
    func shareCurrentCard() {
        let text: String
        switch selectedCardType {
        case 0:
            text = "💪 Just hit a new PR on \(viewModel.summary.topExercise)! #XomFit #Gains"
        case 1:
            text = "🏋️ \(viewModel.summary.weeklyWorkouts) workouts this week, \(viewModel.summary.totalVolumeLbs)lbs total volume. Let's go! #XomFit"
        default:
            text = "🔥 \(viewModel.streak) day workout streak on XomFit! #XomFit #Consistency"
        }
        shareItems = [text]
        showShareSheet = true
    }
}

// MARK: - Share Cards
struct PRShareCard: View {
    let summary: WorkoutSummaryData
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                          startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(20)
            
            VStack(spacing: 16) {
                Text("🏆")
                    .font(.system(size: 64))
                Text("NEW PR!")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                Text(summary.topExercise)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                HStack {
                    Spacer()
                    Text("XomFit")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(24)
        }
        .frame(height: 300)
    }
}

struct WorkoutSummaryCard: View {
    let summary: WorkoutSummaryData
    
    var body: some View {
        ZStack {
            Color(.systemGray6).cornerRadius(20)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Weekly Summary")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Text("💪")
                        .font(.title)
                }
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.weeklyWorkouts)")
                            .font(.system(size: 40, weight: .black))
                        Text("Workouts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.totalVolumeLbs)")
                            .font(.system(size: 40, weight: .black))
                        Text("Total lbs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Spacer()
                    Text("XomFit • \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
        }
        .frame(height: 220)
    }
}

struct StreakCard: View {
    let streak: Int
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]),
                          startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(20)
            
            VStack(spacing: 12) {
                Text("🔥")
                    .font(.system(size: 64))
                Text("\(streak)")
                    .font(.system(size: 72, weight: .black))
                    .foregroundColor(.white)
                Text("Day Streak")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white.opacity(0.9))
                Text("XomFit")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
        }
        .frame(height: 300)
    }
}

// MARK: - Export Section
struct ExportSection: View {
    @ObservedObject var viewModel: ExportViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Data")
                .font(.headline)
                .padding(.horizontal)
            
            // Date range
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Range")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    DatePicker("From", selection: $viewModel.exportStartDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("to")
                    DatePicker("To", selection: $viewModel.exportEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .padding(.horizontal)
            
            // Export buttons
            VStack(spacing: 10) {
                ExportButton(title: "Export CSV", icon: "tablecells", color: .green) {
                    viewModel.exportCSV()
                }
                ExportButton(title: "Export JSON", icon: "curlybraces", color: .orange) {
                    viewModel.exportJSON()
                }
                ExportButton(title: "PDF Training Log", icon: "doc.fill", color: .red) {
                    viewModel.exportPDF()
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
