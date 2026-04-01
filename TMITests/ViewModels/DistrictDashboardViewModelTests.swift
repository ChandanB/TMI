import Foundation
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
            avgEngagementRate: 0.70,
            flaggedStudentsCount: 3
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", studentCount: 100, activePlansCount: 4, engagementRate: 0.80),
            SchoolMetrics(schoolId: "south", schoolName: "South", activePlansCount: 0),
            SchoolMetrics(schoolId: "west", schoolName: "West", studentCount: 50, activePlansCount: 2, engagementRate: 0.60)
        ]

        #expect(
            viewModel.pilotSummary == DistrictDashboardViewModel.PilotSummary(
                participatingSchools: "2",
                activePlans: 14,
                engagementRate: "73.3%",
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

    @Test("Pilot readout uses truthful school adoption and engagement wording")
    func pilotReadout() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 8,
            avgEngagementRate: 0.64,
            flaggedStudentsCount: 1
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", studentCount: 80, activePlansCount: 5, engagementRate: 0.70),
            SchoolMetrics(schoolId: "south", schoolName: "South", activePlansCount: 0),
            SchoolMetrics(schoolId: "west", schoolName: "West", studentCount: 20, activePlansCount: 3, engagementRate: 0.40)
        ]

        #expect(viewModel.pilotReadout.first == "2 schools are actively participating in the TMI pilot.")
        #expect(viewModel.pilotReadout[2] == "64.0% average student engagement across participating schools with active plans.")
    }

    @Test("Pilot summary honors a school filter for promoted evidence")
    func filteredPilotSummary() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.filter.schoolId = "west"
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 14,
            avgEngagementRate: 0.70,
            flaggedStudentsCount: 3
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", studentCount: 100, activePlansCount: 4, engagementRate: 0.80, flaggedStudentsCount: 2),
            SchoolMetrics(schoolId: "west", schoolName: "West", studentCount: 50, activePlansCount: 2, engagementRate: 0.60, flaggedStudentsCount: 1)
        ]

        #expect(
            viewModel.pilotSummary == DistrictDashboardViewModel.PilotSummary(
                participatingSchools: "1",
                activePlans: 2,
                engagementRate: "60.0%",
                needsAttention: 1
            )
        )
        #expect(viewModel.pilotReadout.first == "1 school is actively participating in the TMI pilot.")
    }

    @Test("Date-filtered summary degrades participating-school evidence instead of using unfiltered school metrics")
    func dateFilteredPilotSummary() {
        let viewModel = DistrictDashboardViewModel()
        viewModel.filter.dateRange = .thisMonth
        viewModel.metrics = DistrictMetrics(
            activePlansCount: 6,
            avgEngagementRate: 0.55,
            flaggedStudentsCount: 2
        )
        viewModel.schoolMetrics = [
            SchoolMetrics(schoolId: "north", schoolName: "North", studentCount: 100, activePlansCount: 4, engagementRate: 0.80, flaggedStudentsCount: 1),
            SchoolMetrics(schoolId: "west", schoolName: "West", studentCount: 50, activePlansCount: 2, engagementRate: 0.60, flaggedStudentsCount: 1)
        ]

        #expect(
            viewModel.pilotSummary == DistrictDashboardViewModel.PilotSummary(
                participatingSchools: "Unavailable",
                activePlans: 6,
                engagementRate: "55.0%",
                needsAttention: 2
            )
        )
        #expect(viewModel.pilotReadout.first == "Participating school count is unavailable for the selected date range.")
        #expect(viewModel.pilotReadout[2] == "55.0% average student engagement for the selected date range.")
    }

    @Test("Last updated display uses stored timestamp instead of the current date")
    func lastUpdatedDisplay() {
        let viewModel = DistrictDashboardViewModel()
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        viewModel.lastUpdatedAt = referenceDate

        #expect(viewModel.lastUpdatedDisplayText == "Last updated: \(referenceDate.formatted(date: .abbreviated, time: .shortened))")
    }
}
