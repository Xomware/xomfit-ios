import Foundation

struct Food: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var brand: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var servingSize: Double
    var servingUnit: String
    var barcode: String?
    
    static func == (lhs: Food, rhs: Food) -> Bool {
        lhs.id == rhs.id
    }
}
