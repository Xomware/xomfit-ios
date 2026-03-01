import SwiftUI
import AVFoundation

struct VideoAnalysisView: View {
    @StateObject private var viewModel = VideoAnalysisViewModel()
    @State private var showSessionHistory = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero section
                    heroSection
                    
                    // Exercise selector
                    exerciseSelector
                    
                    // Analyze button
                    analyzeButton
                    
                    // Results
                    if let result = viewModel.analysisResult {
                        FormAnalysisResultView(result: result)
                    }
                    
                    // Session history
                    if !viewModel.sessions.isEmpty {
                        sessionHistorySection
                    }
                }
                .padding()
            }
            .navigationTitle("Video Analysis")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.loadSessions() }
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("AI Form Analysis")
                .font(.title2)
                .bold()
            Text("Record your lift and get instant coaching feedback with pose detection and bar path tracking.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var exerciseSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.headline)
            Picker("Exercise", selection: $viewModel.selectedExercise) {
                ForEach(viewModel.exercises, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var analyzeButton: some View {
        VStack(spacing: 12) {
            if viewModel.isAnalyzing {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Analyzing your form...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Button(action: { viewModel.runDemoAnalysis() }) {
                    Label("Analyze Form (Demo)", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Text("Note: In production, this records live video and uses Vision framework pose detection.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
            ForEach(viewModel.sessions.prefix(5)) { session in
                HStack {
                    Image(systemName: "video.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.exerciseName)
                            .font(.subheadline)
                            .bold()
                        Text(session.recordedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let result = session.analysisResult {
                        Text("\(result.formScore)")
                            .font(.headline)
                            .foregroundColor(result.formScore >= 75 ? .green : .orange)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Form Analysis Result View
struct FormAnalysisResultView: View {
    let result: FormAnalysisResult
    
    var scoreColor: Color {
        switch result.formScore {
        case 90...: return .green
        case 75..<90: return .blue
        case 60..<75: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Score header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.exerciseName)
                        .font(.headline)
                    Text(result.scoreLabel)
                        .font(.subheadline)
                        .foregroundColor(scoreColor)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(result.formScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text("\(result.formScore)")
                        .font(.title2)
                        .bold()
                }
            }
            
            // Breakdown bars
            VStack(spacing: 8) {
                ScoreBar(label: "Back Alignment", value: result.breakdown.backAlignment)
                ScoreBar(label: "Depth", value: result.breakdown.depthScore)
                ScoreBar(label: "Knee Tracking", value: result.breakdown.kneeTracking)
                ScoreBar(label: "Bar Path", value: result.breakdown.barPath)
                ScoreBar(label: "Tempo", value: result.breakdown.tempo)
            }
            
            // ROM
            HStack {
                Image(systemName: "ruler")
                Text("Range of Motion: \(Int(result.rangeOfMotion))°")
                    .font(.subheadline)
            }
            .foregroundColor(.secondary)
            
            // Pose Skeleton (simplified)
            PoseSkeletonView(keypoints: result.keypoints)
                .frame(height: 200)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            // Coach Notes
            if !result.coachNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coach Notes")
                        .font(.headline)
                    ForEach(result.coachNotes, id: \.self) { note in
                        Text(note)
                            .font(.subheadline)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ScoreBar: View {
    let label: String
    let value: Int
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 12)
            Text("\(value)")
                .font(.caption)
                .frame(width: 30, alignment: .trailing)
        }
    }
    
    var barColor: Color {
        switch value {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Pose Skeleton View (simplified 2D drawing)
struct PoseSkeletonView: View {
    let keypoints: [PoseKeypoint]
    
    let connections: [(String, String)] = [
        ("leftShoulder", "rightShoulder"),
        ("leftShoulder", "leftElbow"),
        ("leftElbow", "leftWrist"),
        ("rightShoulder", "rightElbow"),
        ("rightElbow", "rightWrist"),
        ("leftShoulder", "leftHip"),
        ("rightShoulder", "rightHip"),
        ("leftHip", "rightHip"),
        ("leftHip", "leftKnee"),
        ("leftKnee", "leftAnkle"),
        ("rightHip", "rightKnee"),
        ("rightKnee", "rightAnkle")
    ]
    
    func point(named name: String) -> PoseKeypoint? {
        keypoints.first { $0.name == name }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Text("Pose Detection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .position(x: geo.size.width / 2, y: 14)
                
                ForEach(connections, id: \.0) { (from, to) in
                    if let p1 = point(named: from), let p2 = point(named: to) {
                        Path { path in
                            path.move(to: CGPoint(x: p1.x * geo.size.width, y: p1.y * geo.size.height))
                            path.addLine(to: CGPoint(x: p2.x * geo.size.width, y: p2.y * geo.size.height))
                        }
                        .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                    }
                }
                
                ForEach(keypoints) { kp in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .position(x: kp.x * geo.size.width, y: kp.y * geo.size.height)
                }
            }
        }
    }
}
