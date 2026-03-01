import Foundation

struct GarminActivity: Identifiable, Codable {
    var id: UUID
    var activityId: String
    var name: String
    var activityType: String
    var startTimeLocal: Date
    var duration: Double // seconds
    var calories: Int
    var averageHR: Int?
    var steps: Int?
    var distance: Double? // meters
    var xomfitMapped: Bool // whether it's been imported to XomFit
    
    init(id: UUID = UUID(), activityId: String, name: String, activityType: String,
         startTimeLocal: Date, duration: Double, calories: Int) {
        self.id = id
        self.activityId = activityId
        self.name = name
        self.activityType = activityType
        self.startTimeLocal = startTimeLocal
        self.duration = duration
        self.calories = calories
        self.xomfitMapped = false
    }
    
    var durationFormatted: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return "\(mins)m \(secs)s"
    }
    
    var isStrengthActivity: Bool {
        ["strength_training", "weight_training", "functional_strength"].contains(activityType.lowercased())
    }
}

struct GarminDailySummary: Codable {
    var date: Date
    var steps: Int
    var activeCalories: Int
    var bodyBattery: Int // 0-100 Garmin energy metric
    var averageStress: Int // 0-100
    var sleepScore: Int? // Garmin sleep score
    var vo2Max: Double?
}

class GarminService: ObservableObject {
    static let shared = GarminService()
    
    @Published var isConnected = false
    @Published var connectedEmail = ""
    @Published var recentActivities: [GarminActivity] = []
    @Published var dailySummary: GarminDailySummary?
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private let connectedKey = "xomfit_garmin_connected"
    private let emailKey = "xomfit_garmin_email"
    
    init() {
        isConnected = UserDefaults.standard.bool(forKey: connectedKey)
        connectedEmail = UserDefaults.standard.string(forKey: emailKey) ?? ""
        if isConnected { loadMockData() }
    }
    
    // MARK: - OAuth Flow (Mock)
    func connect(email: String, completion: @escaping (Bool) -> Void) {
        // In production: OAuth2 to Garmin Connect API
        // https://connect.garmin.com/en-US/signin
        isSyncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isConnected = true
            self.connectedEmail = email
            UserDefaults.standard.set(true, forKey: self.connectedKey)
            UserDefaults.standard.set(email, forKey: self.emailKey)
            self.loadMockData()
            self.isSyncing = false
            completion(true)
        }
    }
    
    func disconnect() {
        isConnected = false
        connectedEmail = ""
        recentActivities = []
        dailySummary = nil
        UserDefaults.standard.removeObject(forKey: connectedKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
    }
    
    // MARK: - Sync
    func sync(completion: @escaping () -> Void) {
        guard isConnected else { completion(); return }
        isSyncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadMockData()
            self.isSyncing = false
            self.lastSyncDate = Date()
            completion()
        }
    }
    
    // MARK: - Import Activity
    func importActivity(_ activity: GarminActivity) {
        if let idx = recentActivities.firstIndex(where: { $0.id == activity.id }) {
            recentActivities[idx].xomfitMapped = true
        }
    }
    
    // MARK: - Mock Data
    private func loadMockData() {
        let now = Date()
        recentActivities = [
            makeActivity("Morning Strength", "strength_training", daysAgo: 0, duration: 3600, calories: 320, hr: 128),
            makeActivity("5K Run", "running", daysAgo: 1, duration: 1800, calories: 280, hr: 155),
            makeActivity("Upper Body Lift", "strength_training", daysAgo: 2, duration: 4200, calories: 380, hr: 135),
            makeActivity("Cycling", "cycling", daysAgo: 3, duration: 5400, calories: 450, hr: 142),
            makeActivity("Lower Body Lift", "strength_training", daysAgo: 4, duration: 3900, calories: 355, hr: 130)
        ]
        
        dailySummary = GarminDailySummary(
            date: now,
            steps: Int.random(in: 6000...12000),
            activeCalories: Int.random(in: 400...800),
            bodyBattery: Int.random(in: 45...90),
            averageStress: Int.random(in: 20...50),
            sleepScore: Int.random(in: 60...85),
            vo2Max: Double.random(in: 40...55)
        )
        lastSyncDate = now
    }
    
    private func makeActivity(_ name: String, _ type: String, daysAgo: Int, duration: Double, calories: Int, hr: Int) -> GarminActivity {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        var activity = GarminActivity(activityId: UUID().uuidString, name: name, activityType: type,
                                       startTimeLocal: date, duration: duration, calories: calories)
        activity.averageHR = hr
        return activity
    }
    
    // MARK: - Deduplication
    func isDuplicate(_ activity: GarminActivity, in workouts: [Workout]) -> Bool {
        let activityDay = Calendar.current.startOfDay(for: activity.startTimeLocal)
        return workouts.contains { workout in
            let workoutDay = Calendar.current.startOfDay(for: workout.startDate)
            let timeDiff = abs(workout.startDate.timeIntervalSince(activity.startTimeLocal))
            return workoutDay == activityDay && timeDiff < 3600 // Within 1 hour = duplicate
        }
    }
}
