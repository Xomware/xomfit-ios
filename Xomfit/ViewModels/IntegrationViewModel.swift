import Foundation
import Combine

@MainActor
class IntegrationViewModel: ObservableObject {
    @Published var healthKitAuthorized = false
    @Published var healthKitAvailable = false
    @Published var stepsToday = 0
    @Published var restingHR: Double = 0
    @Published var activeCalories = 0
    @Published var hrv: Double = 0
    
    @Published var garminConnected = false
    @Published var garminEmail = ""
    @Published var garminActivities: [GarminActivity] = []
    @Published var garminSummary: GarminDailySummary?
    @Published var garminEmailInput = ""
    @Published var isConnecting = false
    @Published var isSyncing = false
    
    private let healthKit = HealthKitService.shared
    private let garmin = GarminService.shared
    
    func loadAll() {
        healthKitAvailable = healthKit.isAvailable
        healthKitAuthorized = healthKit.isAuthorized
        stepsToday = healthKit.stepsToday
        restingHR = healthKit.restingHR
        activeCalories = healthKit.activeCaloriesToday
        
        garminConnected = garmin.isConnected
        garminEmail = garmin.connectedEmail
        garminActivities = garmin.recentActivities
        garminSummary = garmin.dailySummary
    }
    
    func connectHealthKit() {
        healthKit.requestAuthorization { success, _ in
            self.healthKitAuthorized = success
            if success {
                self.stepsToday = self.healthKit.stepsToday
                self.restingHR = self.healthKit.restingHR
                self.activeCalories = self.healthKit.activeCaloriesToday
            }
        }
    }
    
    func connectGarmin() {
        isConnecting = true
        garmin.connect(email: garminEmailInput) { success in
            self.garminConnected = success
            self.garminEmail = self.garmin.connectedEmail
            self.garminActivities = self.garmin.recentActivities
            self.garminSummary = self.garmin.dailySummary
            self.isConnecting = false
        }
    }
    
    func disconnectGarmin() {
        garmin.disconnect()
        garminConnected = false
        garminEmail = ""
        garminActivities = []
        garminSummary = nil
    }
    
    func syncGarmin() {
        isSyncing = true
        garmin.sync {
            self.garminActivities = self.garmin.recentActivities
            self.garminSummary = self.garmin.dailySummary
            self.isSyncing = false
        }
    }
    
    func importGarminActivity(_ activity: GarminActivity) {
        garmin.importActivity(activity)
        garminActivities = garmin.recentActivities
    }
}
