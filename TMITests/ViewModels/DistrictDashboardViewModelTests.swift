import Testing
@testable import TMI

@MainActor
@Suite("District Dashboard View Model")
struct DistrictDashboardViewModelTests {
    @Test("Priority KPI titles reflect adoption and engagement evidence")
    func priorityKPIs() {
        let titles = DistrictDashboardViewModel.priorityKPITitles

        #expect(titles == ["Participating Schools", "Active Plans", "Engagement Rate", "Needs Attention"])
    }

    @Test("Pilot summary focuses on proof points for the district rollout")
    func pilotSummary() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 14,
            avgEngagementRate: 0.72,
            flaggedStudentsCount: 3
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", activePlansCount: 4),
            SchoolMetrics(schoolId: "south", schoolName: "South", activePlansCount: 0),
            SchoolMetrics(schoolId: "west", schoolName: "West", activePlansCount: 2)
        )

        #expect(
            viewModel.pilotSummary == DistrictDashboardViewModel.PilotSummary(
                participatingSchools: 2,
                activePlans: 14,
                engagementRate: "72.0%",
                needsAttention: 3
            )
        )
    }

    @Test("Participating schools count includes only schools with active plans")
    func participatingSchoolsCount() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 5,
            avgEngagementRate: 0.61,
            flaggedStudentsCount: 2
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", activePlansCount: 3),
            SchoolMetrics(schoolId: "south", schoolName: "South", activePlansCount: 0),
            SchoolMetrics(schoolId: "west", schoolName: "West", activePlansCount: 2)
        ]

        #expect(viewModel.participatingSchoolsCount == 2)
    }

    @Test("Pilot readout uses truthful school adoption copy")
    func pilotReadout() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 8,
            avgEngagementRate: 0.64,
            flaggedStudentsCount: 1
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", activePlansCount: 5),
            SchoolMetrics(schoolId: "south", schoolName: "South", activePlansCount: 0),
            SchoolMetrics(schoolId: "west", schoolName: "West", activePlansCount: 3)
        ]

        #expect(viewModel.pilotReadout.first == "2 schools are actively participating in the TMI pilot.")
    }
}
