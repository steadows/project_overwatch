import Testing
@testable import Overwatch

@Test func appStateInitialization() async throws {
    let state = await AppState()
    #expect(await state.whoopSyncStatus == .idle)
    #expect(await state.isOnboarded == false)
}
