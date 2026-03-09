import SwiftUI

struct FoodSearchView: View {
    @ObservedObject var viewModel: NutritionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFood: Food?
    @State private var servings: Double = 1.0
    @State private var selectedMealType: MealType = .lunch
    @State private var showServingPicker = false
    
    private let servingOptions: [Double] = [0.5, 1.0, 1.5, 2.0]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search foods...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                if let food = selectedFood {
                    servingSelectionView(food: food)
                } else {
                    // Results List
                    List(viewModel.searchResults) { food in
                        Button {
                            selectedFood = food
                            showServingPicker = true
                        } label: {
                            foodRow(food)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func foodRow(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(food.name)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(food.calories) kcal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                if let brand = food.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("P:\(Int(food.protein))g  C:\(Int(food.carbs))g  F:\(Int(food.fat))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(String(format: "%.0f", food.servingSize)) \(food.servingUnit)")
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private func servingSelectionView(food: Food) -> some View {
        VStack(spacing: 20) {
            // Food info
            VStack(spacing: 8) {
                Text(food.name)
                    .font(.title3.bold())
                if let brand = food.brand {
                    Text(brand)
                        .foregroundColor(.secondary)
                }
                Text("\(food.calories) kcal per \(String(format: "%.0f", food.servingSize)) \(food.servingUnit)")
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Serving picker
            VStack(alignment: .leading) {
                Text("Servings")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ForEach(servingOptions, id: \.self) { option in
                        Button {
                            servings = option
                        } label: {
                            Text("\(String(format: "%.1f", option))x")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(servings == option ? Theme.accent : Color(.systemGray5))
                                .foregroundColor(servings == option ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                
                HStack {
                    Text("Custom:")
                    TextField("", value: $servings, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.decimalPad)
                }
            }
            .padding()
            
            // Meal type picker
            VStack(alignment: .leading) {
                Text("Meal Type")
                    .font(.headline)
                Picker("Meal Type", selection: $selectedMealType) {
                    ForEach(MealType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            // Totals preview
            VStack(spacing: 4) {
                Text("Total: \(Int(Double(food.calories) * servings)) kcal")
                    .font(.headline)
                Text("P:\(Int(food.protein * servings))g  C:\(Int(food.carbs * servings))g  F:\(Int(food.fat * servings))g")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Log button
            Button {
                Task {
                    await viewModel.logMeal(food: food, servings: servings, mealType: selectedMealType)
                    dismiss()
                }
            } label: {
                Text("Log Meal")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding()
        }
    }
}
