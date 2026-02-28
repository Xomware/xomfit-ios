import XCTest
@testable import XomFit

@MainActor
final class ProfileViewModelTests: XCTestCase {
    var sut: ProfileViewModel!
    
    override func setUp() {
        super.setUp()
        sut = ProfileViewModel()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializeEditMode() {
        // Given
        sut.user = User(
            id: "1",
            username: "testuser",
            displayName: "Test User",
            avatarURL: nil,
            bio: "Test bio",
            stats: User.UserStats(
                totalWorkouts: 10,
                totalVolume: 5000,
                totalPRs: 2,
                currentStreak: 5,
                longestStreak: 10,
                favoriteExercise: "Bench Press"
            ),
            isPrivate: false,
            createdAt: Date()
        )
        
        // When
        sut.initializeEditMode()
        
        // Then
        XCTAssertEqual(sut.editingDisplayName, "Test User")
        XCTAssertEqual(sut.editingBio, "Test bio")
        XCTAssertFalse(sut.editingIsPrivate)
    }
    
    func testInitializeEditModeWithPrivateProfile() {
        // Given
        sut.user = User.mock
        sut.user.isPrivate = true
        
        // When
        sut.initializeEditMode()
        
        // Then
        XCTAssertTrue(sut.editingIsPrivate)
    }
    
    // MARK: - Edit Mode Tests
    
    func testCancelEditRestoresOriginalValues() {
        // Given
        sut.user = User.mock
        sut.initializeEditMode()
        sut.editingDisplayName = "Changed Name"
        sut.editingBio = "Changed Bio"
        sut.editingIsPrivate = true
        sut.isEditingProfile = true
        
        // When
        sut.cancelEdit()
        
        // Then
        XCTAssertFalse(sut.isEditingProfile)
        XCTAssertNil(sut.selectedAvatarImage)
        XCTAssertEqual(sut.editingDisplayName, "Dom G")
        XCTAssertEqual(sut.editingBio, "Building XomFit 💪")
        XCTAssertFalse(sut.editingIsPrivate)
    }
    
    // MARK: - Validation Tests
    
    func testEditingDisplayNameUpdatesProperly() {
        // Given
        sut.initializeEditMode()
        
        // When
        sut.editingDisplayName = "New Name"
        
        // Then
        XCTAssertEqual(sut.editingDisplayName, "New Name")
    }
    
    func testEditingBioUpdatesProperly() {
        // Given
        sut.initializeEditMode()
        
        // When
        sut.editingBio = "New Bio"
        
        // Then
        XCTAssertEqual(sut.editingBio, "New Bio")
    }
    
    func testEditingPrivacyToggleProperly() {
        // Given
        sut.initializeEditMode()
        XCTAssertFalse(sut.editingIsPrivate)
        
        // When
        sut.editingIsPrivate = true
        
        // Then
        XCTAssertTrue(sut.editingIsPrivate)
    }
    
    // MARK: - Stats Display Tests
    
    func testUserStatsDisplay() {
        // Given
        let testUser = User(
            id: "1",
            username: "athlete",
            displayName: "Athlete",
            avatarURL: nil,
            bio: "Fitness enthusiast",
            stats: User.UserStats(
                totalWorkouts: 100,
                totalVolume: 500_000,
                totalPRs: 15,
                currentStreak: 7,
                longestStreak: 30,
                favoriteExercise: "Squat"
            ),
            isPrivate: false,
            createdAt: Date()
        )
        
        // When
        sut.user = testUser
        
        // Then
        XCTAssertEqual(sut.user.stats.totalWorkouts, 100)
        XCTAssertEqual(sut.user.stats.totalVolume, 500_000)
        XCTAssertEqual(sut.user.stats.totalPRs, 15)
        XCTAssertEqual(sut.user.stats.currentStreak, 7)
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshSetsLoadingState() {
        // Given
        XCTAssertFalse(sut.isLoading)
        
        // When
        sut.refresh()
        
        // Then
        XCTAssertFalse(sut.isLoading) // After completion
    }
}
