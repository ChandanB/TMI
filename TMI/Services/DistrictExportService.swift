//
//  DistrictExportService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import Foundation
import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#endif

/// Service for exporting district reports to various formats
class DistrictExportService {
  static let shared = DistrictExportService()
  
  private init() {}

  // MARK: - Export Methods

  /// Export district metrics as CSV
  func exportCSV(metrics: DistrictMetrics, schoolMetrics: [SchoolMetrics], districtName: String) async throws -> URL {
    print("[DistrictExportService] Exporting CSV for district: \(districtName)")

    var csvContent = ""

    // Header
    csvContent += "District Report - \(districtName)\n"
    csvContent += "Generated: \(Date().formatted(date: .long, time: .shortened))\n\n"

    // District Summary
    csvContent += "District Summary\n"
    csvContent += "Metric,Value\n"
    csvContent += "Total Students,\(metrics.totalStudents)\n"
    csvContent += "Total Schools,\(metrics.totalSchools)\n"
    csvContent += "Total Staff,\(metrics.totalStaff)\n"
    csvContent += "Active Plans,\(metrics.activePlansCount)\n"
    csvContent += "Completed Plans,\(metrics.completedPlansCount)\n"
    csvContent += "Plan Completion Rate,\(metrics.planCompletionPercentage)\n"
    csvContent += "Form Completion Rate,\(metrics.formCompletionPercentage)\n"
    csvContent += "Avg Engagement Rate,\(metrics.engagementPercentage)\n"
    csvContent += "Flagged Students,\(metrics.flaggedStudentsCount)\n\n"
    csvContent += "Plan Evidence Entries,\(metrics.planEvidenceCount)\n"
    csvContent += "Incident Logs,\(metrics.incidentCount)\n"
    csvContent += "Thought Logs,\(metrics.thoughtLogCount)\n"
    csvContent += "Ratings Logged,\(metrics.ratingCount)\n"
    csvContent += "Average Rating,\(metrics.averageRatingDisplay)\n"
    csvContent += "Checklist Completions,\(metrics.checklistCompletions)\n"
    csvContent += "Streak Completions,\(metrics.streakCompletions)\n\n"

    // School Breakdown
    csvContent += "School Breakdown\n"
    csvContent += "School Name,Students,Active Plans,Completed Plans,Engagement Rate,Form Completion,Flagged Students\n"

    for school in schoolMetrics {
      csvContent += "\(school.schoolName),"
      csvContent += "\(school.studentCount),"
      csvContent += "\(school.activePlansCount),"
      csvContent += "\(school.completedPlansCount),"
      csvContent += "\(String(format: "%.1f%%", school.engagementRate * 100)),"
      csvContent += "\(String(format: "%.1f%%", school.formCompletionRate * 100)),"
      csvContent += "\(school.flaggedStudentsCount)\n"
    }

    // Write to temp file
    let fileName = "district_report_\(Date().timeIntervalSince1970).csv"
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

    print("[DistrictExportService] CSV exported to: \(tempURL.path)")
    return tempURL
  }

  /// Export district metrics as PDF
  func exportPDF(
    metrics: DistrictMetrics,
    schoolMetrics: [SchoolMetrics],
    insights: [String],
    districtName: String
  ) async throws -> URL {
    print("[DistrictExportService] Exporting PDF for district: \(districtName)")

    // Create PDF context
    let pdfMetaData = [
      kCGPDFContextCreator: "PathFinder TMI",
      kCGPDFContextAuthor: "District Administration",
      kCGPDFContextTitle: "District Report - \(districtName)"
    ]

    let pageWidth: CGFloat = 8.5 * 72.0 // US Letter
    let pageHeight: CGFloat = 11.0 * 72.0
    let margin: CGFloat = 50.0
    let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

    let data = try makePDFData(bounds: pageRect, metadata: pdfMetaData) { context in
      context.beginPDFPage(nil)

      var currentY: CGFloat = margin

      // Title
      let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: PlatformFont.boldSystemFont(ofSize: 24),
        .foregroundColor: PlatformColor.black
      ]
      let title = "District Report"
      let titleSize = title.size(withAttributes: titleAttributes)
      title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
      currentY += titleSize.height + 10

      // District Name
      let districtAttributes: [NSAttributedString.Key: Any] = [
        .font: PlatformFont.systemFont(ofSize: 18),
        .foregroundColor: PlatformColor.darkGray
      ]
      let districtSize = districtName.size(withAttributes: districtAttributes)
      districtName.draw(at: CGPoint(x: margin, y: currentY), withAttributes: districtAttributes)
      currentY += districtSize.height + 5

      // Date
      let dateAttributes: [NSAttributedString.Key: Any] = [
        .font: PlatformFont.systemFont(ofSize: 12),
        .foregroundColor: PlatformColor.gray
      ]
      let dateString = "Generated: \(Date().formatted(date: .long, time: .shortened))"
      let dateSize = dateString.size(withAttributes: dateAttributes)
      dateString.draw(at: CGPoint(x: margin, y: currentY), withAttributes: dateAttributes)
      currentY += dateSize.height + 30

      // Key Metrics Section
      let sectionAttributes: [NSAttributedString.Key: Any] = [
        .font: PlatformFont.boldSystemFont(ofSize: 16),
        .foregroundColor: PlatformColor.black
      ]
      let bodyAttributes: [NSAttributedString.Key: Any] = [
        .font: PlatformFont.systemFont(ofSize: 12),
        .foregroundColor: PlatformColor.black
      ]

      let metricsTitle = "Key Metrics"
      let metricsTitleSize = metricsTitle.size(withAttributes: sectionAttributes)
      metricsTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttributes)
      currentY += metricsTitleSize.height + 15

      let metricsData = [
        ("Total Students", "\(metrics.totalStudents)"),
        ("Total Schools", "\(metrics.totalSchools)"),
        ("Total Staff", "\(metrics.totalStaff)"),
        ("Active TMI Plans", "\(metrics.activePlansCount)"),
        ("Completed TMI Plans", "\(metrics.completedPlansCount)"),
        ("Plan Completion Rate", metrics.planCompletionPercentage),
        ("Form Completion Rate", metrics.formCompletionPercentage),
        ("Average Engagement", metrics.engagementPercentage),
        ("Students Needing Attention", "\(metrics.flaggedStudentsCount)"),
        ("Plan Evidence Entries", "\(metrics.planEvidenceCount)"),
        ("Incident Logs", "\(metrics.incidentCount)"),
        ("Thought Logs", "\(metrics.thoughtLogCount)"),
        ("Ratings Logged", "\(metrics.ratingCount)"),
        ("Average Rating", metrics.averageRatingDisplay),
        ("Checklist Completions", "\(metrics.checklistCompletions)"),
        ("Streak Completions", "\(metrics.streakCompletions)")
      ]

      for (label, value) in metricsData {
        let metricString = "\(label): \(value)"
        let metricSize = metricString.size(withAttributes: bodyAttributes)
        metricString.draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttributes)
        currentY += metricSize.height + 5
      }

      currentY += 20

      // Insights Section
      let insightsTitle = "Key Insights"
      let insightsTitleSize = insightsTitle.size(withAttributes: sectionAttributes)
      insightsTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttributes)
      currentY += insightsTitleSize.height + 15

      for (index, insight) in insights.enumerated() {
        let insightString = "\(index + 1). \(insight)"
        let insightSize = insightString.size(withAttributes: bodyAttributes)

        // Check if we need a new page
        if currentY + insightSize.height > pageHeight - margin {
          context.beginPDFPage(nil)
          currentY = margin
        }

        insightString.draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttributes)
        currentY += insightSize.height + 5
      }

      currentY += 20

      // School Breakdown Section
      if currentY + 100 > pageHeight - margin {
        context.beginPDFPage(nil)
        currentY = margin
      }

      let schoolsTitle = "School Breakdown"
      let schoolsTitleSize = schoolsTitle.size(withAttributes: sectionAttributes)
      schoolsTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttributes)
      currentY += schoolsTitleSize.height + 15

      for school in schoolMetrics {
        // Check if we need a new page
        if currentY + 80 > pageHeight - margin {
          context.beginPDFPage(nil)
          currentY = margin
        }

        let schoolNameAttributes: [NSAttributedString.Key: Any] = [
          .font: PlatformFont.boldSystemFont(ofSize: 12),
          .foregroundColor: PlatformColor.black
        ]

        let schoolNameSize = school.schoolName.size(withAttributes: schoolNameAttributes)
        school.schoolName.draw(at: CGPoint(x: margin, y: currentY), withAttributes: schoolNameAttributes)
        currentY += schoolNameSize.height + 5

        let schoolData = [
          "  Students: \(school.studentCount)",
          "  Active Plans: \(school.activePlansCount)",
          "  Completed Plans: \(school.completedPlansCount)",
          "  Engagement: \(String(format: "%.0f%%", school.engagementRate * 100))",
          "  Form Completion: \(String(format: "%.0f%%", school.formCompletionRate * 100))",
          "  Flagged Students: \(school.flaggedStudentsCount)"
        ]

        for dataLine in schoolData {
          let dataSize = dataLine.size(withAttributes: bodyAttributes)
          dataLine.draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttributes)
          currentY += dataSize.height + 3
        }

        currentY += 10
      }

      // Footer
      let footerAttributes: [NSAttributedString.Key: Any] = [
        .font: PlatformFont.systemFont(ofSize: 10),
        .foregroundColor: PlatformColor.gray
      ]
      let footer = "Generated with PathFinder TMI | https://claude.com/claude-code"
      let footerSize = footer.size(withAttributes: footerAttributes)
      footer.draw(at: CGPoint(x: margin, y: pageHeight - margin - footerSize.height), withAttributes: footerAttributes)

      context.endPDFPage()
    }

    // Write to temp file
    let fileName = "district_report_\(Date().timeIntervalSince1970).pdf"
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    try data.write(to: tempURL)

    print("[DistrictExportService] PDF exported to: \(tempURL.path)")
    return tempURL
  }

  /// Export district metrics as JSON
  func exportJSON(
    metrics: DistrictMetrics,
    schoolMetrics: [SchoolMetrics],
    insights: [String],
    districtName: String
  ) async throws -> URL {
    print("[DistrictExportService] Exporting JSON for district: \(districtName)")

    let exportData: [String: Any] = [
      "district": districtName,
      "generatedAt": ISO8601DateFormatter().string(from: Date()),
      "metrics": [
        "totalStudents": metrics.totalStudents,
        "totalSchools": metrics.totalSchools,
        "totalStaff": metrics.totalStaff,
        "activePlansCount": metrics.activePlansCount,
        "completedPlansCount": metrics.completedPlansCount,
        "planCompletionRate": metrics.planCompletionRate,
        "formCompletionRate": metrics.formCompletionRate,
        "avgEngagementRate": metrics.avgEngagementRate,
        "flaggedStudentsCount": metrics.flaggedStudentsCount,
        "planEvidenceCount": metrics.planEvidenceCount,
        "incidentCount": metrics.incidentCount,
        "thoughtLogCount": metrics.thoughtLogCount,
        "ratingCount": metrics.ratingCount,
        "averageRating": metrics.averageRating,
        "checklistCompletions": metrics.checklistCompletions,
        "streakCompletions": metrics.streakCompletions
      ],
      "schools": schoolMetrics.map { school in
        [
          "schoolId": school.schoolId,
          "schoolName": school.schoolName,
          "studentCount": school.studentCount,
          "activePlansCount": school.activePlansCount,
          "completedPlansCount": school.completedPlansCount,
          "engagementRate": school.engagementRate,
          "formCompletionRate": school.formCompletionRate,
          "flaggedStudentsCount": school.flaggedStudentsCount
        ]
      },
      "insights": insights
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])

    // Write to temp file
    let fileName = "district_report_\(Date().timeIntervalSince1970).json"
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    try jsonData.write(to: tempURL)

    print("[DistrictExportService] JSON exported to: \(tempURL.path)")
    return tempURL
  }

  #if canImport(UIKit)
  /// Share exported file using UIActivityViewController
  func shareFile(url: URL, from viewController: UIViewController?) {
    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

    if let popoverController = activityVC.popoverPresentationController {
      popoverController.sourceView = viewController?.view
      popoverController.sourceRect = CGRect(
        x: UIScreen.main.bounds.width / 2,
        y: UIScreen.main.bounds.height / 2,
        width: 0,
        height: 0
      )
      popoverController.permittedArrowDirections = []
    }

    viewController?.present(activityVC, animated: true)
  }
  #endif
}
private extension DistrictExportService {
  func makePDFData(
    bounds: CGRect,
    metadata: [CFString: Any],
    draw: (CGContext) -> Void
  ) throws -> Data {
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
      throw CocoaError(.fileWriteUnknown)
    }

    var mediaBox = bounds
    guard let context = CGContext(
      consumer: consumer,
      mediaBox: &mediaBox,
      metadata as CFDictionary
    ) else {
      throw CocoaError(.fileWriteUnknown)
    }

    draw(context)
    context.closePDF()

    return data as Data
  }
}

