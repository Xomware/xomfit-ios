import Foundation

// MARK: - Body Composition Entry
struct BodyCompositionEntry: Identifiable, Codable {
    let id: UUID
    var userId: String
    var recordedAt: Date
    
    // Weight
    var weightLbs: Double?
    
    // Body measurements (all in inches)
    var chest: Double?
    var waist: Double?
    var hips: Double?
    var bicepLeft: Double?
    var bicepRight: Double?
    var thighLeft: Double?
    var thighRight: Double?
    var calf: Double?
    var neck: Double?
    var shoulders: Double?
    
    // Body fat (if known/measured)
    var bodyFatPercent: Double?
    
    // Optional photo URL (stored in Supabase Storage)
    var photoUrl: String?
    
    // Notes
    var notes: String?
    
    // Privacy
    var isPrivate: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recordedAt = "recorded_at"
        case weightLbs = "weight_lbs"
        case chest, waist, hips, neck, shoulders
        case bicepLeft = "bicep_left"
        case bicepRight = "bicep_right"
        case thighLeft = "thigh_left"
        case thighRight = "thigh_right"
        case calf
        case bodyFatPercent = "body_fat_percent"
        case photoUrl = "photo_url"
        case notes
        case isPrivate = "is_private"
    }
    
    // Convenience init
    init(
        id: UUID = UUID(),
        userId: String,
        recordedAt: Date = Date(),
        weightLbs: Double? = nil,
        chest: Double? = nil,
        waist: Double? = nil,
        hips: Double? = nil,
        bicepLeft: Double? = nil,
        bicepRight: Double? = nil,
        thighLeft: Double? = nil,
        thighRight: Double? = nil,
        calf: Double? = nil,
        neck: Double? = nil,
        shoulders: Double? = nil,
        bodyFatPercent: Double? = nil,
        photoUrl: String? = nil,
        notes: String? = nil,
        isPrivate: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.recordedAt = recordedAt
        self.weightLbs = weightLbs
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.bicepLeft = bicepLeft
        self.bicepRight = bicepRight
        self.thighLeft = thighLeft
        self.thighRight = thighRight
        self.calf = calf
        self.neck = neck
        self.shoulders = shoulders
        self.bodyFatPercent = bodyFatPercent
        self.photoUrl = photoUrl
        self.notes = notes
        self.isPrivate = isPrivate
    }
}

// MARK: - Measurement Metric
enum BodyMeasurement: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case chest = "Chest"
    case waist = "Waist"
    case hips = "Hips"
    case bicepLeft = "Left Bicep"
    case bicepRight = "Right Bicep"
    case thighLeft = "Left Thigh"
    case thighRight = "Right Thigh"
    case calf = "Calf"
    case neck = "Neck"
    case shoulders = "Shoulders"
    case bodyFat = "Body Fat %"
    
    var id: String { rawValue }
    
    var unit: String {
        self == .weight ? "lbs" : self == .bodyFat ? "%" : "in"
    }
    
    var systemImage: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .chest: return "figure.arms.open"
        case .waist: return "figure.stand"
        case .hips: return "figure.stand"
        case .bicepLeft, .bicepRight: return "figure.strengthtraining.traditional"
        case .thighLeft, .thighRight: return "figure.walk"
        case .calf: return "figure.walk"
        case .neck: return "figure.stand"
        case .shoulders: return "figure.arms.open"
        case .bodyFat: return "percent"
        }
    }
    
    func value(from entry: BodyCompositionEntry) -> Double? {
        switch self {
        case .weight: return entry.weightLbs
        case .chest: return entry.chest
        case .waist: return entry.waist
        case .hips: return entry.hips
        case .bicepLeft: return entry.bicepLeft
        case .bicepRight: return entry.bicepRight
        case .thighLeft: return entry.thighLeft
        case .thighRight: return entry.thighRight
        case .calf: return entry.calf
        case .neck: return entry.neck
        case .shoulders: return entry.shoulders
        case .bodyFat: return entry.bodyFatPercent
        }
    }
}

// MARK: - Mock Data
extension BodyCompositionEntry {
    static func mockHistory(userId: String) -> [BodyCompositionEntry] {
        let now = Date()
        return (0..<12).map { weeksAgo in
            let date = Calendar.current.date(byAdding: .weekOfYear, value: -weeksAgo, to: now)!
            let baseWeight = 185.0
            let variation = Double.random(in: -3...3)
            let trend = Double(weeksAgo) * 0.5  // trending down over time
            return BodyCompositionEntry(
                userId: userId,
                recordedAt: date,
                weightLbs: baseWeight + variation - trend,
                chest: 42.0 + Double.random(in: -0.5...0.5),
                waist: 33.0 + Double.random(in: -0.5...0.5) - Double(weeksAgo) * 0.05,
                hips: 40.0 + Double.random(in: -0.5...0.5),
                bicepLeft: 15.5 + Double.random(in: -0.2...0.2),
                bicepRight: 15.8 + Double.random(in: -0.2...0.2),
                bodyFatPercent: 18.0 - Double(weeksAgo) * 0.1 + Double.random(in: -0.5...0.5),
                isPrivate: true
            )
        }.reversed()
    }
}
