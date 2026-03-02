import Foundation

enum MealType: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "leaf.fill"
        }
    }
}

struct MealLog: Codable, Identifiable {
    let id: UUID
    var userId: String
    var food: Food
    var servings: Double
    var mealType: MealType
    var loggedAt: Date
    
    var totalCalories: Int {
        Int(Double(food.calories) * servings)
    }
    
    var totalProtein: Double { food.protein * servings }
    var totalCarbs: Double { food.carbs * servings }
    var totalFat: Double { food.fat * servings }
}

/// Supabase row representation for meal_logs table
struct MealLogRow: Codable {
    let id: UUID?
    let user_id: String
    let food_name: String
    let calories: Int
    let protein_g: Double?
    let carbs_g: Double?
    let fat_g: Double?
    let servings: Double
    let meal_type: String
    let logged_at: String?
}
