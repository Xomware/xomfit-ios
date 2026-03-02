import Foundation
import Supabase

class NutritionService {
    static let shared = NutritionService()
    
    private var foodDatabase: [Food] = []
    
    private init() {
        loadFoodDatabase()
    }
    
    // MARK: - Food Database
    
    private func loadFoodDatabase() {
        guard let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ FoodDatabase.json not found, using empty database")
            return
        }
        
        let decoder = JSONDecoder()
        foodDatabase = (try? decoder.decode([Food].self, from: data)) ?? []
    }
    
    func searchFood(query: String) -> [Food] {
        guard !query.isEmpty else { return foodDatabase }
        let lowered = query.lowercased()
        return foodDatabase.filter {
            $0.name.lowercased().contains(lowered) ||
            ($0.brand?.lowercased().contains(lowered) ?? false)
        }
    }
    
    func lookupBarcode(_ barcode: String) -> Food? {
        foodDatabase.first { $0.barcode == barcode }
    }
    
    // MARK: - Meal Logging (Supabase)
    
    func logMeal(food: Food, servings: Double, mealType: MealType) async throws {
        guard let user = try? await supabase.auth.session.user else {
            throw NutritionError.notAuthenticated
        }
        
        let row = MealLogRow(
            id: nil,
            user_id: user.id.uuidString,
            food_name: food.name,
            calories: Int(Double(food.calories) * servings),
            protein_g: food.protein * servings,
            carbs_g: food.carbs * servings,
            fat_g: food.fat * servings,
            servings: servings,
            meal_type: mealType.rawValue,
            logged_at: nil
        )
        
        try await supabase
            .from("meal_logs")
            .insert(row)
            .execute()
    }
    
    func fetchTodayMeals() async throws -> [MealLog] {
        guard let user = try? await supabase.auth.session.user else {
            throw NutritionError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        
        let rows: [MealLogRow] = try await supabase
            .from("meal_logs")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .gte("logged_at", value: formatter.string(from: startOfDay))
            .order("logged_at", ascending: false)
            .execute()
            .value
        
        return rows.map { row in
            let food = Food(
                id: UUID(),
                name: row.food_name,
                brand: nil,
                calories: row.calories,
                protein: row.protein_g ?? 0,
                carbs: row.carbs_g ?? 0,
                fat: row.fat_g ?? 0,
                fiber: 0,
                servingSize: 1,
                servingUnit: "serving",
                barcode: nil
            )
            return MealLog(
                id: row.id ?? UUID(),
                userId: row.user_id,
                food: food,
                servings: row.servings,
                mealType: MealType(rawValue: row.meal_type) ?? .snack,
                loggedAt: formatter.date(from: row.logged_at ?? "") ?? Date()
            )
        }
    }
    
    func deleteMeal(id: UUID) async throws {
        try await supabase
            .from("meal_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

enum NutritionError: LocalizedError {
    case notAuthenticated
    case foodNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be logged in to log meals."
        case .foodNotFound: return "Food item not found."
        }
    }
}
