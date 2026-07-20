import Testing
@testable import TMI

@Suite("Main Tab View")
struct MainTabViewTests {
    @Test("Teacher sees only the MVP teacher tabs")
    func teacherTabs() {
        let tabs = MainTabView.Tab.mvpTabs(for: .teacher)

        #expect(tabs == [.dashboard, .students, .tmiPlans])
    }

    @Test("District admin sees district evidence tab in addition to teacher workflow")
    func districtAdminTabs() {
        let tabs = MainTabView.Tab.mvpTabs(for: .districtAdministrator)

        #expect(tabs == [.dashboard, .students, .tmiPlans, .district])
    }

    @Test("Nil or unsupported role falls back to dashboard only")
    func fallbackTabs() {
        #expect(MainTabView.Tab.mvpTabs(for: nil) == [.dashboard])
    }
}
