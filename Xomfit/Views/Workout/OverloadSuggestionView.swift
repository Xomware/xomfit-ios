import SwiftUI

/// Compact inline banner showing the current progressive overload suggestion.
/// Displayed above the set input area in WorkoutLoggerView.
struct OverloadSuggestionView: View {
    let suggestion: OverloadSuggestion
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    private let cyanAccent = Color(hex: "#00b4d8")
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)
                
                Text(bannerText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(height: 40)
            .background(cyanAccent.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        switch suggestion.type {
        case .increaseWeight: return "arrow.up.circle.fill"
        case .increaseReps: return "plus.circle.fill"
        case .deload: return "arrow.down.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .volumeStagnant: return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch suggestion.type {
        case .increaseWeight: return cyanAccent
        case .increaseReps: return .green
        case .deload: return .orange
        case .maintain: return Theme.textSecondary
        case .volumeStagnant: return .yellow
        }
    }
    
    private var bannerText: String {
        switch suggestion.type {
        case .increaseWeight(_, let to):
            return "↑ Try \(to.formattedWeight) lbs today  (was \(suggestion.lastWeight.formattedWeight) × \(suggestion.lastReps))"
        case .increaseReps(let by):
            return "↑ Try +\(by) rep at \(suggestion.lastWeight.formattedWeight) lbs"
        case .deload(let to, _):
            return "↓ Deload to \(to.formattedWeight) lbs — recovery needed"
        case .maintain(let reason):
            return "→ \(reason)"
        case .volumeStagnant(let suggestion):
            return "⚠ Volume stagnant — \(suggestion)"
        }
    }
}

// Color.init(hex:) is defined in Utils/Extensions.swift
