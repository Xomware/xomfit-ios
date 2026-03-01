import SwiftUI

struct NutritionDashboardView: View {
    @StateObject private var viewModel = NutritionViewModel()
    @State private var showFoodSearch = false
    @State private var showBarcodeScanner = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Calorie Summary Card
                    calorieCard
                    
                    // Macro Progress Rings
                    macroRingsCard
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        Button {
                            showFoodSearch = true
                        } label: {
                            Label("Log Meal", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Label("Scan", systemImage: "barcode.viewfinder")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Meals Today
                    mealsSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Nutrition")
            .task {
                await viewModel.loadTodayData()
            }
            .refreshable {
                await viewModel.loadTodayData()
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView(viewModel: viewModel)
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Calorie Card
    
    private var calorieCard: some View {
        VStack(spacing: 12) {
            Text("Calories")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 30) {
                VStack {
                    Text("\(viewModel.dailyTotals.totalCalories)")
                        .font(.system(size: 28, weight: .bold))
                    Text("Eaten")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.caloriesBurned)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Burned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.caloriesRemaining)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(viewModel.caloriesRemaining >= 0 ? .green : .red)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(calorieBarColor)
                        .frame(width: geo.size.width * calorieProgress)
                }
            }
            .frame(height: 12)
            
            Text("Goal: \(viewModel.calorieGoal) kcal")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var calorieProgress: Double {
        guard viewModel.calorieGoal > 0 else { return 0 }
        return min(Double(viewModel.dailyTotals.totalCalories) / Double(viewModel.calorieGoal), 1.0)
    }
    
    private var calorieBarColor: Color {
        calorieProgress > 0.9 ? .red : (calorieProgress > 0.7 ? .orange : Theme.accent)
    }
    
    // MARK: - Macro Rings
    
    private var macroRingsCard: some View {
        HStack(spacing: 20) {
            macroRing(
                label: "Protein",
                current: viewModel.dailyTotals.totalProtein,
                goal: viewModel.proteinGoal,
                unit: "g",
                color: .blue
            )
            macroRing(
                label: "Carbs",
                current: viewModel.dailyTotals.totalCarbs,
                goal: viewModel.carbsGoal,
                unit: "g",
                color: .green
            )
            macroRing(
                label: "Fat",
                current: viewModel.dailyTotals.totalFat,
                goal: viewModel.fatGoal,
                unit: "g",
                color: .orange
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func macroRing(label: String, current: Double, goal: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(current / goal, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: 14, weight: .bold))
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Meals Section
    
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meals Today")
                .font(.headline)
                .padding(.horizontal)
            
            if viewModel.todayMeals.isEmpty {
                Text("No meals logged yet today")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ForEach(MealType.allCases, id: \.self) { type in
                    let meals = viewModel.mealsByType(type)
                    if !meals.isEmpty {
                        mealTypeSection(type: type, meals: meals)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func mealTypeSection(type: MealType, meals: [MealLog]) -> some View {
        DisclosureGroup {
            ForEach(meals) { meal in
                HStack {
                    VStack(alignment: .leading) {
                        Text(meal.food.name)
                            .font(.subheadline)
                        Text("\(meal.totalCalories) kcal • \(String(format: "%.0f", meal.servings))x serving")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("P:\(Int(meal.totalProtein)) C:\(Int(meal.totalCarbs)) F:\(Int(meal.totalFat))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteMeal(meal) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: type.icon)
                Text(type.displayName)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(meals.reduce(0) { $0 + $1.totalCalories }) kcal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
