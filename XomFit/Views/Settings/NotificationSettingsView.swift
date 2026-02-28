import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var notifService = NotificationService.shared
    @State private var showingTimePicker = false
    @State private var isSaving = false
    @State private var saveError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if notifService.isLoading {
                    ProgressView("Loading settings...")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.paddingLarge) {
                            // Permission status
                            permissionSection
                            
                            if notifService.authStatus == .authorized,
                               let prefs = notifService.preferences {
                                // Master toggle
                                masterToggleSection(prefs: prefs)
                                
                                if prefs.isEnabled {
                                    // Category toggles
                                    categorySection(prefs: prefs)
                                    
                                    // Workout reminder schedule
                                    reminderSection(prefs: prefs)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        .padding(.bottom, Theme.paddingLarge)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK") { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
        .task {
            await notifService.checkAuthStatus()
            if let userId = authService.currentUser?.id {
                await notifService.loadPreferences(userId: userId)
            }
        }
    }
    
    // MARK: - Permission Section
    
    @ViewBuilder private var permissionSection: some View {
        switch notifService.authStatus {
        case .authorized:
            // All good — no banner needed
            EmptyView()
            
        case .denied:
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.destructive)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications Disabled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Enable in Settings to receive alerts")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                
                Spacer()
                
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }
            .padding(Theme.paddingMedium)
            .background(Theme.destructive.opacity(0.1))
            .cornerRadius(Theme.cornerRadius)
            
        case .notDetermined:
            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent)
                
                Text("Stay in the loop")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                
                Text("Get notified when friends hit PRs, when it's time to train, and more.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    Task { await notifService.requestPermission() }
                } label: {
                    Text("Enable Notifications")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(.black)
                        .background(Theme.accent)
                        .cornerRadius(Theme.cornerRadius)
                }
            }
            .padding(Theme.paddingLarge)
            .cardStyle()
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Master Toggle
    
    @ViewBuilder private func masterToggleSection(prefs: NotificationPreferences) -> some View {
        Toggle(isOn: Binding(
            get: { prefs.isEnabled },
            set: { newVal in
                guard var updated = notifService.preferences else { return }
                updated = NotificationPreferences(
                    userId: updated.userId,
                    isEnabled: newVal,
                    friendActivity: updated.friendActivity,
                    personalRecords: updated.personalRecords,
                    workoutReminders: updated.workoutReminders,
                    challenges: updated.challenges,
                    social: updated.social,
                    reminderHour: updated.reminderHour,
                    reminderMinute: updated.reminderMinute,
                    reminderDays: updated.reminderDays
                )
                save(updated)
            }
        )) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Theme.accent)
                Text("All Notifications")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .tint(Theme.accent)
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Category Section
    
    @ViewBuilder private func categorySection(prefs: NotificationPreferences) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notification Types")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            VStack(spacing: 0) {
                ForEach(Array(NotificationCategory.allCases.enumerated()), id: \.element) { idx, category in
                    if category != .system {
                        CategoryToggleRow(
                            category: category,
                            isEnabled: prefs.isEnabled(for: category)
                        ) { newValue in
                            guard var updated = notifService.preferences else { return }
                            switch category {
                            case .friendActivity: updated = mutate(updated, friendActivity: newValue)
                            case .personalRecords: updated = mutate(updated, personalRecords: newValue)
                            case .workoutReminders: updated = mutate(updated, workoutReminders: newValue)
                            case .challenges: updated = mutate(updated, challenges: newValue)
                            case .social: updated = mutate(updated, social: newValue)
                            case .system: break
                            }
                            save(updated)
                        }
                        
                        if idx < NotificationCategory.allCases.count - 2 {
                            Divider()
                                .background(Theme.background)
                        }
                    }
                }
            }
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
    }
    
    // MARK: - Reminder Schedule
    
    @ViewBuilder private func reminderSection(prefs: NotificationPreferences) -> some View {
        if prefs.workoutReminders {
            VStack(alignment: .leading, spacing: 8) {
                Text("Workout Reminder Schedule")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                VStack(spacing: 0) {
                    // Time
                    NavigationLink {
                        ReminderTimePickerView(
                            hour: prefs.reminderHour,
                            minute: prefs.reminderMinute
                        ) { h, m in
                            guard var updated = notifService.preferences else { return }
                            updated = mutate(updated, reminderHour: h, reminderMinute: m)
                            save(updated)
                        }
                    } label: {
                        HStack {
                            Label("Time", systemImage: "clock.fill")
                                .foregroundStyle(Theme.textPrimary)
                                .font(Theme.fontBody)
                            Spacer()
                            Text(prefs.reminderTimeDescription)
                                .foregroundStyle(Theme.accent)
                                .font(Theme.fontBody)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(Theme.paddingMedium)
                    }
                    
                    Divider().background(Theme.background)
                    
                    // Days
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Days", systemImage: "calendar")
                            .foregroundStyle(Theme.textPrimary)
                            .font(Theme.fontBody)
                        
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { day in
                                let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
                                let isSelected = prefs.reminderDays.contains(day)
                                
                                Button {
                                    guard var updated = notifService.preferences else { return }
                                    var days = updated.reminderDays
                                    if isSelected { days.removeAll { $0 == day } } else { days.append(day) }
                                    days.sort()
                                    updated = mutate(updated, reminderDays: days)
                                    save(updated)
                                } label: {
                                    Text(dayNames[day])
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .background(isSelected ? Theme.accent : Theme.secondaryBackground)
                                        .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                                        .cornerRadius(18)
                                }
                            }
                        }
                        
                        Text(prefs.reminderDaysDescription)
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(Theme.paddingMedium)
                }
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadius)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func save(_ prefs: NotificationPreferences) {
        Task {
            isSaving = true
            do {
                try await notifService.savePreferences(prefs)
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }
    
    private func mutate(
        _ p: NotificationPreferences,
        friendActivity: Bool? = nil,
        personalRecords: Bool? = nil,
        workoutReminders: Bool? = nil,
        challenges: Bool? = nil,
        social: Bool? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        reminderDays: [Int]? = nil
    ) -> NotificationPreferences {
        NotificationPreferences(
            userId: p.userId,
            isEnabled: p.isEnabled,
            friendActivity: friendActivity ?? p.friendActivity,
            personalRecords: personalRecords ?? p.personalRecords,
            workoutReminders: workoutReminders ?? p.workoutReminders,
            challenges: challenges ?? p.challenges,
            social: social ?? p.social,
            reminderHour: reminderHour ?? p.reminderHour,
            reminderMinute: reminderMinute ?? p.reminderMinute,
            reminderDays: reminderDays ?? p.reminderDays
        )
    }
}

// MARK: - Category Toggle Row

private struct CategoryToggleRow: View {
    let category: NotificationCategory
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Toggle(isOn: Binding(get: { isEnabled }, set: onToggle)) {
            HStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(category.description)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .tint(Theme.accent)
        .padding(Theme.paddingMedium)
    }
}

// MARK: - Reminder Time Picker View

struct ReminderTimePickerView: View {
    @State var hour: Int
    @State var minute: Int
    let onSave: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var selectedDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour, minute: minute, second: 0, of: Date()
                ) ?? Date()
            },
            set: { newDate in
                hour = Calendar.current.component(.hour, from: newDate)
                minute = Calendar.current.component(.minute, from: newDate)
            }
        )
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: Theme.paddingLarge) {
                DatePicker("Reminder Time", selection: selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(Theme.accent)
                
                Button("Save") {
                    onSave(hour, minute)
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.black)
                .background(Theme.accent)
                .cornerRadius(Theme.cornerRadius)
                .padding(.horizontal, Theme.paddingMedium)
            }
        }
        .navigationTitle("Reminder Time")
        .navigationBarTitleDisplayMode(.inline)
    }
}
