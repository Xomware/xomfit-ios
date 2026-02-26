import SwiftUI

struct DateRangeFilter: View {
    @Binding var selectedPreset: DateRangePreset
    @Binding var startDate: Date
    @Binding var endDate: Date
    @State private var showCustomDatePicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Preset buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateRangePreset.allCases, id: \.self) { preset in
                        Button(action: {
                            selectedPreset = preset
                            let (start, end) = preset.dateRange
                            startDate = start
                            endDate = end
                        }) {
                            Text(preset.rawValue)
                                .font(.caption)
                                .foregroundColor(selectedPreset == preset ? .white : Theme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedPreset == preset ? Theme.accent : Theme.secondaryBackground)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
            }
            
            // Custom date range
            if selectedPreset != .allTime && selectedPreset != .lastWeek && selectedPreset != .lastMonth &&
               selectedPreset != .last3Months && selectedPreset != .lastYear {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Date")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Button(action: { showCustomDatePicker.toggle() }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Theme.accent)
                                
                                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.secondaryBackground)
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("End Date")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Button(action: { showCustomDatePicker.toggle() }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Theme.accent)
                                
                                Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.secondaryBackground)
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Theme.paddingMedium)
            }
            
            // Date range summary
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Theme.accent)
                    .font(.caption)
                
                Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                Text("\(days) days")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.vertical, 8)
            .background(Theme.secondaryBackground)
            .cornerRadius(8)
        }
        .padding(.vertical, Theme.paddingMedium)
    }
}

#Preview {
    @State var preset: DateRangePreset = .lastMonth
    @State var start = Date().addingTimeInterval(-30 * 24 * 3600)
    @State var end = Date()
    
    return DateRangeFilter(selectedPreset: $preset, startDate: $start, endDate: $end)
        .background(Theme.background)
        .padding()
}
