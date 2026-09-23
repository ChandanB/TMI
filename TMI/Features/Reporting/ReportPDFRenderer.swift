import CoreGraphics
import SwiftUI

/// Renders a district report as a paged US Letter PDF. The PDF is made from
/// the same server report the CSV and dashboard use, so the figures match.
@MainActor
enum ReportPDFRenderer {
    static let pageSize = CGSize(width: 612, height: 792)
    private static let sitesPerPage = 14

    static func render(result: DistrictReportResult, organizationName: String, to url: URL) throws {
        var pages: [AnyView] = [AnyView(ReportPDFSummaryPage(result: result, organizationName: organizationName))]
        let sites = result.report.sites
        for start in stride(from: 0, to: sites.count, by: sitesPerPage) {
            let slice = Array(sites[start..<min(start + sitesPerPage, sites.count)])
            pages.append(AnyView(ReportPDFSitesPage(sites: slice, isFirst: start == 0)))
        }
        pages.append(AnyView(ReportPDFDefinitionsPage(result: result)))

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, [
            kCGPDFContextTitle as String: "TMI report \(result.report.scope.from) to \(result.report.scope.to)",
            kCGPDFContextCreator as String: "TMI",
        ] as CFDictionary) else {
            throw CocoaError(.fileWriteUnknown)
        }
        for (index, page) in pages.enumerated() {
            let renderer = ImageRenderer(content:
                ReportPDFPage(pageNumber: index + 1, pageCount: pages.count, scope: result.report.scope) { page }
                    .frame(width: pageSize.width, height: pageSize.height)
                    .environment(\.colorScheme, .light)
            )
            renderer.proposedSize = ProposedViewSize(pageSize)
            context.beginPDFPage(nil)
            // ImageRenderer draws PDF-ready (already oriented for CoreGraphics).
            renderer.render { _, draw in draw(context) }
            context.endPDFPage()
        }
        context.closePDF()
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path(percentEncoded: false))
    }
}

private struct ReportPDFPage<Content: View>: View {
    let pageNumber: Int
    let pageCount: Int
    let scope: ReportScope
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Spacer(minLength: 0)
            HStack {
                Text("Confidential — aggregate figures. Rates for groups under the minimum sample are withheld.")
                Spacer()
                Text("Page \(pageNumber) of \(pageCount)")
            }
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
        }
        .padding(40)
        .background(Color.white)
        .foregroundStyle(Color.black)
    }
}

private struct ReportPDFSummaryPage: View {
    let result: DistrictReportResult
    let organizationName: String

    var body: some View {
        let report = result.report
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(organizationName).font(.system(size: 22, weight: .bold))
                Text("Intervention report · \(report.scope.from) to \(report.scope.to)")
                    .font(.system(size: 12))
                Text("Computed \(report.computedDate?.formatted(date: .abbreviated, time: .shortened) ?? report.computedAt) · \(report.scope.schoolIDs.count) site(s) · Metric dictionary v\(report.dictionaryVersion)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                if report.isPartial {
                    Text("Partial: this scope exceeds the report limits; some records were not counted.")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Measure").bold()
                    Text("Value").bold()
                    Text("Basis").bold()
                }
                .font(.system(size: 10))
                ForEach(result.definitions.filter { report.metric($0.id) != nil }) { definition in
                    if let metric = report.metric(definition.id) {
                        GridRow {
                            Text(definition.label)
                            Text(MetricFormatting.value(metric, unit: definition.unit)).monospacedDigit()
                            Text(MetricFormatting.caption(metric, definition: definition, minimumSample: result.minimumSample))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 10))
                    }
                }
            }
            Divider()
            Text("Plans by status").font(.system(size: 12, weight: .semibold))
            Text(report.plansByStatus.sorted { $0.key < $1.key }
                .map { "\(MetricFormatting.statusName($0.key)): \($0.value)" }
                .joined(separator: "   "))
                .font(.system(size: 10))
        }
    }
}

private struct ReportPDFSitesPage: View {
    let sites: [ReportSite]
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isFirst ? "By site" : "By site (continued)").font(.system(size: 16, weight: .bold))
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Site").bold()
                    Text("Served").bold()
                    Text("Active plans").bold()
                    Text("With a plan").bold()
                    Text("Surveyed").bold()
                    Text("Overdue").bold()
                }
                ForEach(sites) { site in
                    GridRow {
                        Text(site.name).lineLimit(2)
                        Text(MetricFormatting.value(site.studentsServed, unit: .count))
                        Text(MetricFormatting.value(site.activePlans, unit: .count))
                        Text(MetricFormatting.value(site.planCoverage, unit: .rate))
                        Text(MetricFormatting.value(site.surveyCoverage, unit: .rate))
                        Text(MetricFormatting.value(site.overdueTasks, unit: .count))
                    }
                }
            }
            .font(.system(size: 10))
        }
    }
}

private struct ReportPDFDefinitionsPage: View {
    let result: DistrictReportResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How each figure is calculated").font(.system(size: 16, weight: .bold))
            Text("Window: \(result.report.scope.from) to \(result.report.scope.to), \(result.report.scope.timeZone). Rates are withheld for groups smaller than \(result.minimumSample).")
                .font(.system(size: 9))
            ForEach(result.definitions) { definition in
                VStack(alignment: .leading, spacing: 1) {
                    Text(definition.label).font(.system(size: 10, weight: .semibold))
                    Text(definition.formula).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
    }
}
