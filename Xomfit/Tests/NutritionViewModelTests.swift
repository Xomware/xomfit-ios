import XCTest
@testable import XomFit

final class NutritionViewModelTests: XCTestCase {
    
    // MARK: - Test Food Model
    
    private func makeFood(
        calories: Int = 200,
        protein: Double = 20,
        carbs: Double = 25,
        fat: Double = 8,
        fiber: Double = 3
    ) -> Food {
        Food(
            id: UUID(),
            name: "Test Food",
            brand: "Test",
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            servingSize: 100,
            servingUnit: "g",
            barcode: nil
        )
    }
    
    private func makeMealLog(
        food: Food? = nil,
        servings: Double = 1.0,
        mealType: MealType = .lunch
    ) -> MealLog {
        let f = food ?? makeFood()
        return MealLog(
            id: UUID(),
            userId: "test-user",
            food: f,
            servings: servings,
            mealType: mealType,
            loggedAt: Date()
        )
    }
    
    // MARK: - MealLog Macro Calculations
    
    func testMealLogTotalCalories() {
        let meal = makeMealLog(food: makeFood(calories: 200), servings: 2.0)
        XCTAssertEqual(meal.totalCalories, 400)
    }
    
    func testMealLogTotalProtein() {
        let meal = makeMealLog(food: makeFood(protein: 30), servings: 1.5)
        XCTAssertEqual(meal.totalProtein, 45.0, accuracy: 0.01)
    }
    
    func testMealLogTotalCarbs() {
        let meal = makeMealLog(food: makeFood(carbs: 40), servings: 0.5)
        XCTAssertEqual(meal.totalCarbs, 20.0, accuracy: 0.01)
    }
    
    func testMealLogTotalFat() {
        let meal = makeMealLog(food: makeFood(fat: 10), servings: 2.0)
        XCTAssertEqual(meal.totalFat, 20.0, accuracy: 0.01)
    }
    
    // MARK: - DailyNutrition Aggregation
    
    func testDailyNutritionFromEmptyMeals() {
        let totals = DailyNutrition.from(meals: [])
        XCTAssertEqual(totals, DailyNutrition.zero)
    }
    
    func testDailyNutritionAggregation() {
        let meals = [
            makeMealLog(food: makeFood(calories: 300, protein: 25, carbs: 30, fat: 10, fiber: 5), servings: 1.0),
            makeMealLog(food: makeFood(calories: 500, protein: 40, carbs: 50, fat: 15, fiber: 3), servings: 1.0),
            makeMealLog(food: makeFood(calories: 200, protein: 10, carbs: 20, fat: 8, fiber: 2), servings: 2.0),
        ]
        
        let totals = DailyNutrition.from(meals: meals)
        
        XCTAssertEqual(totals.totalCalories, 1200) // 300 + 500 + 400
        XCTAssertEqual(totals.totalProtein, 85.0, accuracy: 0.01) // 25 + 40 + 20
        XCTAssertEqual(totals.totalCarbs, 120.0, accuracy: 0.01) // 30 + 50 + 40
        XCTAssertEqual(totals.totalFat, 41.0, accuracy: 0.01) // 10 + 15 + 16
        XCTAssertEqual(totals.totalFiber, 12.0, accuracy: 0.01) // 5 + 3 + 4
    }
    
    func testDailyNutritionWithFractionalServings() {
        let meals = [
            makeMealLog(food: makeFood(calories: 100, protein: 10, carbs: 10, fat: 5, fiber: 1), servings: 0.5),
        ]
        
        let totals = DailyNutrition.from(meals: meals)
        XCTAssertEqual(totals.totalCalories, 50)
        XCTAssertEqual(totals.totalProtein, 5.0, accuracy: 0.01)
    }
    
    // MARK: - Net Calorie Calculation
    
    @MainActor
    func testNetCaloriesCalculation() {
        let vm = NutritionViewModel()
        vm.dailyTotals = DailyNutrition(
            totalCalories: 1800,
            totalProtein: 120,
            totalCarbs: 200,
            totalFat: 60,
            totalFiber: 25
        )
        vm.caloriesBurned = 500
        
        XCTAssertEqual(vm.netCalories, 1300) // 1800 - 500
    }
    
    @MainActor
    func testCaloriesRemainingCalculation() {
        let vm = NutritionViewModel()
        vm.calorieGoal = 2000
        vm.dailyTotals = DailyNutrition(
            totalCalories: 1200,
            totalProtein: 80,
            totalCarbs: 150,
            totalFat: 40,
            totalFiber: 20
        )
        vm.caloriesBurned = 300
        
        // remaining = goal - netCalories = 2000 - (1200 - 300) = 1100
        XCTAssertEqual(vm.caloriesRemaining, 1100)
    }
    
    // MARK: - Food Search
    
    func testFoodSearchReturnsResults() {
        let service = NutritionService.shared
        let results = service.searchFood(query: "chicken")
        XCTAssertFalse(results.isEmpty, "Should find chicken in food database")
    }
    
    func testFoodSearchEmptyQueryReturnsAll() {
        let service = NutritionService.shared
        let results = service.searchFood(query: "")
        XCTAssertGreaterThanOrEqual(results.count, 100, "Empty query should return all foods")
    }
    
    func testBarcodeLookupsWork() {
        let service = NutritionService.shared
        let food = service.lookupBarcode("0012345600007")
        XCTAssertNotNil(food)
        XCTAssertEqual(food?.name, "Whey Protein Shake")
    }
    
    // MARK: - MealType
    
    func testMealTypeDisplayNames() {
        XCTAssertEqual(MealType.breakfast.displayName, "Breakfast")
        XCTAssertEqual(MealType.lunch.displayName, "Lunch")
        XCTAssertEqual(MealType.dinner.displayName, "Dinner")
        XCTAssertEqual(MealType.snack.displayName, "Snack")
    }
}
