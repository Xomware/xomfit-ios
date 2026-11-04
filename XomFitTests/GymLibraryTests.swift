import XCTest
@testable import Xomfit

@MainActor
final class GymLibraryTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "GymLibraryTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private let leg = "arsenal-reloaded-linear-leg-press"

    func testSettingsSurviveReload() {
        let library = GymLibrary(defaults: defaults)
        library.load(userId: "u1")
        library.setSettings(MachineSettings(seat: "4", pad: "", handles: "neutral", notes: "feet high"), for: leg)

        let reloaded = GymLibrary(defaults: defaults)
        reloaded.load(userId: "u1")
        XCTAssertEqual(reloaded.settings(for: leg).seat, "4")
        XCTAssertEqual(reloaded.settings(for: leg).notes, "feet high")
        XCTAssertEqual(reloaded.settings(for: leg).summary, "Seat 4 · Handles neutral · feet high")
    }

    func testSettingsAreScopedPerUser() {
        let library = GymLibrary(defaults: defaults)
        library.load(userId: "u1")
        library.setSettings(MachineSettings(seat: "4"), for: leg)

        library.load(userId: "u2")
        XCTAssertNil(library.settings(for: leg).summary)

        library.load(userId: "u1")
        XCTAssertEqual(library.settings(for: leg).seat, "4")
    }

    func testClearingSettingsRemovesEntry() {
        let library = GymLibrary(defaults: defaults)
        library.load(userId: "u1")
        library.setSettings(MachineSettings(seat: "4"), for: leg)
        library.setSettings(MachineSettings(), for: leg)
        XCTAssertTrue(library.machineSettings.isEmpty)
    }

    func testFirstGymBecomesActiveAndPersists() {
        let library = GymLibrary(defaults: defaults)
        library.load(userId: "u1")
        let carbon = GymProfile(name: "Carbon Performance", machineIds: [leg])
        library.saveGym(carbon)
        library.saveGym(GymProfile(name: "Home", equipment: [.dumbbell]))

        let reloaded = GymLibrary(defaults: defaults)
        reloaded.load(userId: "u1")
        XCTAssertEqual(reloaded.gyms.map(\.name), ["Carbon Performance", "Home"])
        XCTAssertEqual(reloaded.activeGym?.id, carbon.id)
        XCTAssertEqual(reloaded.activeGym?.machineIds, [leg])
    }

    func testDeletingActiveGymClearsIt() {
        let library = GymLibrary(defaults: defaults)
        library.load(userId: "u1")
        let gym = GymProfile(name: "Carbon")
        library.saveGym(gym)
        library.deleteGym(id: gym.id)
        XCTAssertNil(library.activeGym)
        XCTAssertTrue(library.gyms.isEmpty)
    }

    func testMachineOptionsPreferActiveGymsMachines() {
        let library = GymLibrary(defaults: defaults)
        library.load(userId: "u1")
        XCTAssertGreaterThan(library.machineOptions(for: "ex-leg-press").count, 1)

        library.saveGym(GymProfile(name: "Carbon", machineIds: [leg]))
        XCTAssertEqual(library.machineOptions(for: "ex-leg-press").map(\.id), [leg])
        // Nothing at this gym for the lift → fall back to the catalog.
        XCTAssertFalse(library.machineOptions(for: "ex-hack-squat").isEmpty)
    }

    func testCatalogMapsOnlyToRealExercises() {
        for machine in MachineCatalog.all {
            for id in machine.exerciseIds {
                XCTAssertNotNil(ExerciseDatabase.byId[id], "\(machine.id) maps to unknown exercise \(id)")
            }
        }
    }
}
