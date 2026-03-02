import SwiftUI

struct CalendarCellView: View {
    let intensity: Int // 0-4
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    private var color: Color {
        switch intensity {
        case 0: return Color(.systemGray5)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.6)
        case 3: return Color.green
        case 4: return Color(hex: "00b4d8") // xomfit cyan
        default: return Color(.systemGray5)
        }
    }

    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isToday && pulsing ? 1.2 : 1.0)
            .animation(
                isToday ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                value: pulsing
            )
            .onAppear {
                if isToday { pulsing = true }
            }
            .onTapGesture { onTap() }
    }
}

#Preview {
    HStack(spacing: 4) {
        ForEach(0..<5) { i in
            CalendarCellView(intensity: i, isSelected: i == 2, isToday: i == 4, onTap: {})
        }
    }
    .padding()
    .background(Theme.background)
}
