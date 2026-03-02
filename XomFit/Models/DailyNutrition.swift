import Foundation

struct DailyNutrition: Equatable {
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var totalFiber: Double
    
    static var zero: DailyNutrition {
        DailyNutrition(totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, totalFiber: 0)
    }
    
    static func from(meals: [MealLog]) -> DailyNutrition {
        var result = DailyNutrition.zero
        for meal in meals {
            result.totalCalories += meal.totalCalories
            result.totalProtein += meal.totalProtein
            result.totalCarbs += meal.totalCarbs
            result.totalFat += meal.totalFat
            result.totalFiber += meal.food.fiber * meal.servings
        }
        return result
    }
}
