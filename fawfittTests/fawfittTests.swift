import XCTest
@testable import fawfitt

final class fawfittTests: XCTestCase {
    func testRecommendationEngineAdaptsToMuscleGoal() async {
        let engine = WorkoutRecommendationEngine()
        var profile = UserFitnessProfile()
        profile.target = .gainMuscle

        let plans = await engine.recommendations(profile: profile, health: .mock)

        XCTAssertEqual(plans.count, 3)
        XCTAssertEqual(plans.first?.category, .strength)
        XCTAssertTrue(plans.contains { $0.category == .muscle })
    }

    @MainActor
    func testDashboardProgressIsClamped() {
        let viewModel = AppViewModel()

        XCTAssertGreaterThanOrEqual(viewModel.calorieProgress, 0)
        XCTAssertLessThanOrEqual(viewModel.calorieProgress, 1)
    }

    func testMockCoachPluginReturnsPremiumGuidance() async throws {
        let plugin = MockCoachPlugin()

        let reply = try await plugin.run(prompt: "Need a recovery day")

        XCTAssertTrue(reply.contains("Neural coach"))
        XCTAssertTrue(reply.contains("recovery"))
    }
}
