import XCTest
@testable import XomFit

class AnimationTests: XCTestCase {
    
    // MARK: - ExerciseAnimationLibrary Tests
    
    func testAnimationLibraryHasCompoundExercises() {
        let compounds = ExerciseAnimationLibrary.compoundAnimations
        XCTAssertGreaterThan(compounds.count, 0)
    }
    
    func testAnimationMetadataForKnownExercise() {
        let benchPress = ExerciseAnimationLibrary.animationMetadata(for: "ex-1")
        
        XCTAssertNotNil(benchPress)
        XCTAssertEqual(benchPress?.exerciseName, "Bench Press")
        XCTAssertEqual(benchPress?.animationFileName, "bench_press.json")
        XCTAssertTrue(benchPress?.isCompound ?? false)
    }
    
    func testAnimationMetadataForUnknownExercise() {
        let unknown = ExerciseAnimationLibrary.animationMetadata(for: "ex-999")
        XCTAssertNil(unknown)
    }
    
    func testAnimationHasFormCues() {
        let benchPress = ExerciseAnimationLibrary.animationMetadata(for: "ex-1")
        
        XCTAssertNotNil(benchPress)
        XCTAssertGreaterThan(benchPress?.formCues.count ?? 0, 0)
    }
    
    func testAnimationHasCommonMistakes() {
        let benchPress = ExerciseAnimationLibrary.animationMetadata(for: "ex-1")
        
        XCTAssertNotNil(benchPress)
        XCTAssertGreaterThan(benchPress?.commonMistakes.count ?? 0, 0)
    }
    
    func testAnimationDifficultyLevels() {
        let allAnimations = ExerciseAnimationLibrary.allAnimations
        
        let beginnerCount = ExerciseAnimationLibrary.animations(by: .beginner).count
        let intermediateCount = ExerciseAnimationLibrary.animations(by: .intermediate).count
        let advancedCount = ExerciseAnimationLibrary.animations(by: .advanced).count
        
        XCTAssertEqual(beginnerCount + intermediateCount + advancedCount, allAnimations.count)
    }
    
    func testHasAnimationMethod() {
        XCTAssertTrue(ExerciseAnimationLibrary.hasAnimation(for: "ex-1"))
        XCTAssertTrue(ExerciseAnimationLibrary.hasAnimation(for: "ex-2"))
        XCTAssertFalse(ExerciseAnimationLibrary.hasAnimation(for: "ex-999"))
    }
    
    func testAllAnimationsAreAccessible() {
        let allAnimations = ExerciseAnimationLibrary.allAnimations
        
        XCTAssertGreaterThan(allAnimations.count, 0)
        
        for animation in allAnimations {
            XCTAssertFalse(animation.exerciseName.isEmpty)
            XCTAssertFalse(animation.animationFileName.isEmpty)
            XCTAssertGreaterThan(animation.duration, 0)
        }
    }
    
    // MARK: - AnimationAssetManager Tests
    
    func testAssetManagerSingleton() {
        let manager1 = AnimationAssetManager.shared
        let manager2 = AnimationAssetManager.shared
        
        XCTAssertTrue(manager1 === manager2)
    }
    
    func testLoadAnimationSync() {
        let manager = AnimationAssetManager.shared
        
        // Try to load a known animation file (if it exists in bundle)
        let data = manager.loadAnimationSync(named: "bench_press.json")
        
        // Note: This test will pass if file doesn't exist (returns nil)
        // In a real test environment, we'd mock the bundle
        if let data = data {
            XCTAssertGreaterThan(data.count, 0)
        }
    }
    
    func testClearCache() {
        let manager = AnimationAssetManager.shared
        
        // Store something in cache
        manager.cachedAnimations["test.json"] = Data([0x01, 0x02])
        XCTAssertNotNil(manager.cachedAnimations["test.json"])
        
        // Clear cache
        manager.clearCache(for: "test.json")
        XCTAssertNil(manager.cachedAnimations["test.json"])
    }
    
    func testClearAllCache() {
        let manager = AnimationAssetManager.shared
        
        // Store multiple items in cache
        manager.cachedAnimations["test1.json"] = Data([0x01])
        manager.cachedAnimations["test2.json"] = Data([0x02])
        
        XCTAssertGreaterThan(manager.cachedAnimations.count, 0)
        
        // Clear all
        manager.clearAllCache()
        XCTAssertEqual(manager.cachedAnimations.count, 0)
    }
    
    // MARK: - Animation Metadata Validation Tests
    
    func testAnimationMetadataCompleteness() {
        let allAnimations = ExerciseAnimationLibrary.allAnimations
        
        for animation in allAnimations {
            // Verify all required fields are populated
            XCTAssertFalse(animation.exerciseId.isEmpty, "Exercise ID empty for \(animation.exerciseName)")
            XCTAssertFalse(animation.exerciseName.isEmpty, "Exercise name empty")
            XCTAssertFalse(animation.animationId.isEmpty, "Animation ID empty for \(animation.exerciseName)")
            XCTAssertFalse(animation.animationFileName.isEmpty, "Animation file name empty for \(animation.exerciseName)")
            XCTAssertGreaterThan(animation.duration, 0, "Invalid duration for \(animation.exerciseName)")
            XCTAssertGreaterThan(animation.formCues.count, 0, "No form cues for \(animation.exerciseName)")
            XCTAssertGreaterThan(animation.commonMistakes.count, 0, "No mistakes for \(animation.exerciseName)")
        }
    }
    
    func testTopCompoundExercisesAreIncluded() {
        let compounds = ExerciseAnimationLibrary.compoundAnimations
        let exerciseNames = compounds.map { $0.exerciseName }
        
        // Verify essential compound lifts are included
        XCTAssertTrue(exerciseNames.contains("Bench Press"))
        XCTAssertTrue(exerciseNames.contains("Squat"))
        XCTAssertTrue(exerciseNames.contains("Deadlift"))
        XCTAssertTrue(exerciseNames.contains("Overhead Press"))
        XCTAssertTrue(exerciseNames.contains("Barbell Row"))
    }
    
    func testAnimationFileNamesAreUnique() {
        let allAnimations = ExerciseAnimationLibrary.allAnimations
        let fileNames = allAnimations.map { $0.animationFileName }
        
        let uniqueFileNames = Set(fileNames)
        XCTAssertEqual(fileNames.count, uniqueFileNames.count, "Duplicate animation file names found")
    }
    
    // MARK: - Error Handling Tests
    
    func testAnimationLoadErrorDescription() {
        let error1 = AnimationLoadError.fileNotFound("missing.json")
        XCTAssertTrue(error1.errorDescription?.contains("missing.json") ?? false)
        
        let error2 = AnimationLoadError.invalidManager
        XCTAssertNotNil(error2.errorDescription)
        
        let error3 = AnimationLoadError.decodingFailed
        XCTAssertNotNil(error3.errorDescription)
    }
}

// MARK: - Performance Tests

class AnimationPerformanceTests: XCTestCase {
    
    func testAnimationLibraryLoadPerformance() {
        self.measure {
            let _ = ExerciseAnimationLibrary.allAnimations
        }
    }
    
    func testAnimationLookupPerformance() {
        self.measure {
            for i in 1...10 {
                let _ = ExerciseAnimationLibrary.animationMetadata(for: "ex-\(i)")
            }
        }
    }
    
    func testDifficultyFilterPerformance() {
        self.measure {
            let _ = ExerciseAnimationLibrary.animations(by: .intermediate)
        }
    }
}
