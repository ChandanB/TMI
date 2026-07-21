import Testing
@testable import TMI

@Suite("Main Tab View")
struct MainTabViewTests {
    @Test("Teacher sees only the MVP teacher tabs")
    func teacherTabs() {
        let tabs = AppNavigationPolicy(role: .teacher).availableTabs

        #expect(tabs == [.dashboard, .students, .plans])
    }

    @Test("District admin sees district evidence tab in addition to teacher workflow")
    func districtAdminTabs() {
        let tabs = AppNavigationPolicy(role: .districtAdministrator).availableTabs

        #expect(tabs == [.dashboard, .students, .plans, .district])
    }

    @Test("Nil or unsupported role falls back to dashboard only")
    func fallbackTabs() {
        #expect(AppNavigationPolicy(role: nil).availableTabs == [.dashboard])
    }
}
