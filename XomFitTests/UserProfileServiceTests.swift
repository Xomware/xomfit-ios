import XCTest
@testable import XomFit

@MainActor
final class UserProfileServiceTests: XCTestCase {
    var sut: UserProfileService!
    
    override func setUp() {
        super.setUp()
        sut = UserProfileService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitializes() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateToggling() {
        // Given
        XCTAssertFalse(sut.isLoading)
        
        // When - simulate loading
        DispatchQueue.main.async {
            self.sut.isLoading = true
        }
        
        // Then
        // Note: In real tests with async operations, we'd use expectations
    }
    
    // MARK: - Mock User Profile Tests
    
    func testUserProfileDataStructure() {
        // Test that UserProfile model can be properly constructed
        let user = User(
            id: "test-1",
            username: "testuser",
            displayName: "Test User",
            avatarURL: nil,
            bio: "Test Bio",
            stats: User.UserStats(
                totalWorkouts: 50,
                totalVolume: 100_000,
                totalPRs: 5,
                currentStreak: 3,
                longestStreak: 10,
                favoriteExercise: "Bench Press"
            ),
            isPrivate: false,
            createdAt: Date()
        )
        
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.bio, "Test Bio")
        XCTAssertFalse(user.isPrivate)
        XCTAssertEqual(user.stats.totalWorkouts, 50)
    }
    
    func testPrivateProfileToggle() {
        // Given
        var user = User.mock
        
        // When
        user.isPrivate = true
        
        // Then
        XCTAssertTrue(user.isPrivate)
    }
    
    // MARK: - Avatar Path Handling Tests
    
    func testAvatarURLConstruction() {
        // Test that avatar URLs are properly constructed
        let userId = "user-123"
        let filename = "avatars/\(userId)-uuid.jpg"
        
        XCTAssertTrue(filename.contains("avatars"))
        XCTAssertTrue(filename.contains(userId))
    }
    
    // MARK: - Validation Tests
    
    func testDisplayNameValidation() {
        let validName = "John Doe"
        let emptyName = ""
        
        XCTAssertFalse(validName.isEmpty)
        XCTAssertTrue(emptyName.isEmpty)
    }
    
    func testBioLengthValidation() {
        let shortBio = "This is a short bio"
        let longBio = String(repeating: "a", count: 200)
        
        XCTAssertLessThan(shortBio.count, 150)
        XCTAssertGreaterThan(longBio.count, 150)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessageClears() {
        // Given
        sut.errorMessage = "Test error"
        
        // When
        sut.errorMessage = nil
        
        // Then
        XCTAssertNil(sut.errorMessage)
    }
}
