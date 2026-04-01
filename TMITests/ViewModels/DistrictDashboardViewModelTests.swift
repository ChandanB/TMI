import Testing
@testable import TMI

@MainActor
@Suite("District Dashboard View Model")
struct DistrictDashboardViewModelTests {
    @Test("Priority KPI titles reflect adoption and engagement evidence")
    func priorityKPIs() {
        let titles = DistrictDashboardViewModel.priorityKPITitles

        #expect(titles == ["Active Teachers", "Active Plans", "Engagement Rate", "Needs Attention"])
    }

    @Test("Pilot summary focuses on proof points for the district rollout")
    func pilotSummary() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 14,
            avgEngagementRate: 0.72,
            flaggedStudentsCount: 3,
            totalStaff: 9
        )

        #expect(
            viewModel.pilotSummary == DistrictDashboardViewModel.PilotSummary(
                activeTeachers: 9,
                activePlans: 14,
                engagementRate: "72.0%",
                needsAttention: 3
            )
        )
    }

    @Test("Active teacher count falls back to schools with active plans when staff totals are unavailable")
    func activeTeacherFallback() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 5,
            avgEngagementRate: 0.61,
            flaggedStudentsCount: 2,
            totalStaff: 0
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", activePlansCount: 3),
            SchoolMetrics(schoolId: "south", schoolName: "South", activePlansCount: 0),
            SchoolMetrics(schoolId: "west", schoolName: "West", activePlansCount: 2)
        ]

        #expect(viewModel.activeTeacherCount == 2)
    }
}
