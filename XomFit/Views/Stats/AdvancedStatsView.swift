import SwiftUI

struct AdvancedStatsView: View {
    @StateObject private var viewModel = AdvancedStatsViewModel()
    @State private var selectedTab = 0
    @State private var showExportSheet = false
    @State private var csvContent = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Stats", selection: $selectedTab) {
                    Text("Heatmap").tag(0)
                    Text("Strength").tag(1)
                    Text("Balance").tag(2)
                    Text("Frequency").tag(3)
                    Text("PRs").tag(4)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Crunching numbers...")
                    Spacer()
                } else {
                    TabView(selection: $selectedTab) {
                        MuscleHeatmapTab(data: viewModel.heatmapData).tag(0)
                        StrengthCurveTab(viewModel: viewModel).tag(1)
                        BalanceTab(ratios: viewModel.balanceRatios).tag(2)
                        FrequencyHeatmapTab(data: viewModel.frequencyData).tag(3)
                        PRsTab(prs: viewModel.allTimePRs).tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Advanced Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        csvContent = viewModel.exportCSV()
                        showExportSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear { viewModel.loadAll() }
            .sheet(isPresented: $showExportSheet) {
                ShareSheet(items: [csvContent])
            }
        }
    }
}

// MARK: - Muscle Heatmap Tab
struct MuscleHeatmapTab: View {
    let data: [MuscleHeatmapData]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Weekly Volume Heatmap")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(data) { muscle in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(heatColor(for: muscle.intensity))
                                .frame(height: 60)
                                .overlay(
                                    VStack {
                                        Text("\(muscle.weeklyVolume)")
                                            .font(.title3)
                                            .bold()
                                            .foregroundColor(.white)
                                        Text("sets")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                )
                            Text(muscle.muscleGroup)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Legend
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .blue, .orange, .red]),
                                  startPoint: .leading, endPoint: .trailing)
                        .frame(height: 8)
                        .cornerRadius(4)
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .padding(.vertical)
        }
    }
    
    func heatColor(for intensity: Double) -> Color {
        switch intensity {
        case 0..<0.25: return .blue.opacity(0.4)
        case 0.25..<0.5: return .blue
        case 0.5..<0.75: return .orange
        default: return .red
        }
    }
}

// MARK: - Strength Curve Tab
struct StrengthCurveTab: View {
    @ObservedObject var viewModel: AdvancedStatsViewModel
    @State private var showExercisePicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Strength Curve")
                        .font(.headline)
                    Spacer()
                    Button(viewModel.selectedExercise.isEmpty ? "Select Exercise" : viewModel.selectedExercise) {
                        showExercisePicker = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                if viewModel.strengthCurveData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No data for this exercise.\nLog some workouts first.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    // Simple line chart using rects
                    SimpleLineChartView(dataPoints: viewModel.strengthCurveData.map { $0.estimated1RM })
                        .frame(height: 200)
                        .padding()
                    
                    // Data table
                    VStack(spacing: 8) {
                        ForEach(viewModel.strengthCurveData.suffix(10).reversed()) { point in
                            HStack {
                                Text(point.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(point.value))lbs × \(point.reps)")
                                    .font(.caption)
                                Text("e1RM: \(Int(point.estimated1RM))")
                                    .font(.caption)
                                    .bold()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showExercisePicker) {
            NavigationView {
                List(viewModel.availableExercises, id: \.self) { exercise in
                    Button(exercise) {
                        viewModel.loadStrengthCurve(for: exercise)
                        showExercisePicker = false
                    }
                }
                .navigationTitle("Select Exercise")
            }
        }
    }
}

struct SimpleLineChartView: View {
    let dataPoints: [Double]
    
    var body: some View {
        GeometryReader { geo in
            if dataPoints.isEmpty {
                EmptyView()
            } else {
                let min = dataPoints.min() ?? 0
                let max = dataPoints.max() ?? 1
                let range = max - min
                
                Path { path in
                    for (index, point) in dataPoints.enumerated() {
                        let x = geo.size.width * CGFloat(index) / CGFloat(Swift.max(dataPoints.count - 1, 1))
                        let y = geo.size.height * (1 - CGFloat((point - min) / Swift.max(range, 1)))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
    }
}

// MARK: - Balance Tab
struct BalanceTab: View {
    let ratios: [MusclePairBalance]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Muscle Balance (30 days)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ForEach(ratios) { pair in
                    BalanceBarView(pair: pair)
                        .padding(.horizontal)
                }
                
                if ratios.isEmpty {
                    Text("Log more workouts to see balance data.")
                        .foregroundColor(.secondary)
                        .padding(40)
                }
            }
            .padding(.vertical)
        }
    }
}

struct BalanceBarView: View {
    let pair: MusclePairBalance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(pair.primaryMuscle) vs \(pair.antagonistMuscle)")
                    .font(.subheadline)
                    .bold()
                Spacer()
                Text(pair.imbalanceDescription)
                    .font(.caption)
                    .foregroundColor(pair.isBalanced ? .green : .orange)
            }
            
            GeometryReader { geo in
                HStack(spacing: 2) {
                    let total = pair.primaryVolume + pair.antagonistVolume
                    let primaryWidth = total > 0 ? geo.size.width * CGFloat(pair.primaryVolume) / CGFloat(total) : geo.size.width / 2
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: primaryWidth)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                }
            }
            .frame(height: 20)
            
            HStack {
                Text("\(pair.primaryMuscle): \(pair.primaryVolume) sets")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Text("\(pair.antagonistMuscle): \(pair.antagonistVolume) sets")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Frequency Heatmap Tab
struct FrequencyHeatmapTab: View {
    let data: [WorkoutFrequencyDay]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Training Frequency (Last Year)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(14), spacing: 3), count: 7), spacing: 3) {
                        ForEach(paddedDays(), id: \.date) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.count > 0 ? Color.green.opacity(0.3 + day.intensity * 0.7) : Color(.systemGray5))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    Text("Less")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach([0.1, 0.3, 0.5, 0.7, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green.opacity(0.3 + intensity * 0.7))
                            .frame(width: 14, height: 14)
                    }
                    Text("More")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    func paddedDays() -> [WorkoutFrequencyDay] {
        // Pad to start on Sunday
        guard let first = data.first else { return data }
        let weekday = Calendar.current.component(.weekday, from: first.date) - 1
        var padded: [WorkoutFrequencyDay] = (0..<weekday).map { _ in
            WorkoutFrequencyDay(date: Date.distantPast, count: 0, maxCount: 1)
        }
        padded.append(contentsOf: data)
        return padded
    }
}

// MARK: - PRs Tab
struct PRsTab: View {
    let prs: [ExercisePR]
    @State private var searchText = ""
    
    var filtered: [ExercisePR] {
        searchText.isEmpty ? prs : prs.filter { $0.exerciseName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack {
            TextField("Search exercises...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top)
            
            List(filtered) { pr in
                VStack(alignment: .leading, spacing: 4) {
                    Text(pr.exerciseName)
                        .font(.subheadline)
                        .bold()
                    HStack {
                        Text("\(Int(pr.weight))lbs × \(pr.reps) reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("e1RM: \(Int(pr.estimated1RM))lbs")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.blue)
                        Text(pr.date, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
