import Foundation
import Combine

@MainActor
class NutritionViewModel: ObservableObject {
    @Published var todayMeals: [MealLog] = []
    @Published var dailyTotals: DailyNutrition = .zero
    @Published var calorieGoal: Int = 2000
    @Published var caloriesBurned: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: [Food] = []
    @Published var searchQuery = ""
    
    private let nutritionService = NutritionService.shared
    private let healthKitService = HealthKitService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var netCalories: Int {
        dailyTotals.totalCalories - caloriesBurned
    }
    
    var caloriesRemaining: Int {
        calorieGoal - netCalories
    }
    
    var proteinGoal: Double { 150 }
    var carbsGoal: Double { 250 }
    var fatGoal: Double { 65 }
    
    init() {
        setupSearchDebounce()
    }
    
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.searchResults = self?.nutritionService.searchFood(query: query) ?? []
            }
            .store(in: &cancellables)
    }
    
    func loadTodayData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            todayMeals = try await nutritionService.fetchTodayMeals()
            dailyTotals = DailyNutrition.from(meals: todayMeals)
            caloriesBurned = healthKitService.activeCaloriesToday
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logMeal(food: Food, servings: Double, mealType: MealType) async {
        do {
            try await nutritionService.logMeal(food: food, servings: servings, mealType: mealType)
            await loadTodayData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteMeal(_ meal: MealLog) async {
        do {
            try await nutritionService.deleteMeal(id: meal.id)
            await loadTodayData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func mealsByType(_ type: MealType) -> [MealLog] {
        todayMeals.filter { $0.mealType == type }
    }
}
