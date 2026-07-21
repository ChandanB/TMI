//
//  PlanExportService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #6
//  Exports TMI plans to PDF and text formats
//

import Foundation
import SwiftUI
import PDFKit
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

/// Service for exporting TMI plans to various formats
class PlanExportService {
    private let planService = TMIPlanService.shared

    // MARK: - PDF Export

    /// Export a TMI plan to PDF
    func exportPlanToPDF(_ plan: TMIPlan) async throws -> URL {
        let pdfData = try await generatePDFData(for: plan)

        let fileName = "\(plan.title.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(date: .numeric, time: .omitted)).pdf"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        try pdfData.write(to: fileURL)
        print("[PlanExportService] Exported plan to PDF: \(fileURL.path)")

        return fileURL
    }

    /// Generate PDF data for a plan
    private func generatePDFData(for plan: TMIPlan) async throws -> Data {
        let inputs = await fetchPlanInputsForExport(plan)
        let evidenceEntries = await fetchPlanEvidenceForExport(plan)
        let evidenceSummary = summarizeEvidence(evidenceEntries)

        let pdfMetaData = [
            kCGPDFContextCreator: "TMI App",
            kCGPDFContextAuthor: plan.createdBy,
            kCGPDFContextTitle: plan.title
        ]
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let data = try makePDFData(bounds: pageRect, metadata: pdfMetaData) { context in
            var yPosition: CGFloat = 50
            let margin: CGFloat = 50
            let contentWidth = pageWidth - (margin * 2)

            // Helper to start new page if needed
            func checkPageBreak(requiredSpace: CGFloat) {
                if yPosition + requiredSpace > pageHeight - margin {
                    context.endPDFPage()
                    context.beginPDFPage(nil)
                    yPosition = 50
                }
            }

            // Start first page
            context.beginPDFPage(nil)

            // Title
            let titleFont = PlatformFont.boldSystemFont(ofSize: 24)
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
            let titleString = plan.title as NSString
            let titleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 40)
            titleString.draw(in: titleRect, withAttributes: titleAttributes)
            yPosition += 50

            // Model and Status
            let headerFont = PlatformFont.systemFont(ofSize: 12)
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: PlatformColor.gray]

            let modelText = "Model: \(plan.model.rawValue)" as NSString
            modelText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 20

            let statusText = "Status: \(plan.approvalStatus.displayName)" as NSString
            statusText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 30

            // Description
            if let description = plan.description, !description.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = PlatformFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Description".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = PlatformFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]
                let descString = description as NSString
                let descSize = descString.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil)
                descString.draw(in: CGRect(x: margin, y: yPosition, width: contentWidth, height: descSize.height), withAttributes: bodyAttributes)
                yPosition += descSize.height + 20
            }

            if !inputs.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = PlatformFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Plan Inputs".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = PlatformFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                for input in inputs {
                    checkPageBreak(requiredSpace: 20)
                    let value = input.value.isEmpty ? "[Not provided]" : input.value
                    let inputText = "\(input.label): \(value)" as NSString
                    let inputSize = inputText.boundingRect(
                        with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin,
                        attributes: bodyAttributes,
                        context: nil
                    )
                    inputText.draw(in: CGRect(x: margin + 10, y: yPosition, width: contentWidth - 20, height: inputSize.height), withAttributes: bodyAttributes)
                    yPosition += inputSize.height + 8
                }

                yPosition += 10
            }

            if evidenceSummary.totalEntries > 0 {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = PlatformFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Evidence Summary".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = PlatformFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                let summaryLines = [
                    "Total entries: \(evidenceSummary.totalEntries)",
                    "Checklist completions: \(evidenceSummary.checklistCompletions)",
                    "Streak completions: \(evidenceSummary.streakCompletions)",
                    "Incidents logged: \(evidenceSummary.incidentCount)",
                    "Thought logs: \(evidenceSummary.thoughtLogCount)",
                    "Ratings logged: \(evidenceSummary.ratingCount)",
                    "Average rating: \(String(format: "%.1f", evidenceSummary.averageRating))"
                ]

                for line in summaryLines {
                    checkPageBreak(requiredSpace: 18)
                    (line as NSString).draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 18
                }

                yPosition += 10
            }

            // Students
            if !plan.students.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = PlatformFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Students".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = PlatformFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                for student in plan.students {
                    checkPageBreak(requiredSpace: 20)
                    let studentText = "• \(student.name) (Grade \(student.grade))" as NSString
                    studentText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 20
                }
                yPosition += 10
            }

            // Goals
            if !plan.goals.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = PlatformFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Goals".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = PlatformFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                for (index, goal) in plan.goals.enumerated() {
                    checkPageBreak(requiredSpace: 40)

                    let goalHeader = "\(index + 1). \(goal.description)" as NSString
                    let goalSize = goalHeader.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil)
                    goalHeader.draw(in: CGRect(x: margin + 10, y: yPosition, width: contentWidth - 20, height: goalSize.height), withAttributes: bodyAttributes)
                    yPosition += goalSize.height + 5

                    let statusText = "Status: \(goal.status.rawValue) | Progress: \(Int(goal.progress * 100))%" as NSString
                    let statusAttributes: [NSAttributedString.Key: Any] = [.font: PlatformFont.systemFont(ofSize: 10), .foregroundColor: PlatformColor.gray]
                    statusText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: statusAttributes)
                    yPosition += 20
                }
                yPosition += 10
            }

            // Interests
            if !plan.interests.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = PlatformFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Interests & Hobbies".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = PlatformFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                let interestNames = plan.interests.map { $0.name }.joined(separator: ", ")
                let interestString = interestNames as NSString
                let interestSize = interestString.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil)
                interestString.draw(in: CGRect(x: margin + 10, y: yPosition, width: contentWidth - 20, height: interestSize.height), withAttributes: bodyAttributes)
                yPosition += interestSize.height + 20
            }

            // Approval History
            if !plan.approvalHistory.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = PlatformFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Approval History".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = PlatformFont.systemFont(ofSize: 11)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                for entry in plan.approvalHistory {
                    checkPageBreak(requiredSpace: 40)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short

                    let historyText = "• \(entry.action.displayName) on \(dateFormatter.string(from: entry.timestamp))" as NSString
                    historyText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 18

                    if let comment = entry.comment, !comment.isEmpty {
                        let commentAttributes: [NSAttributedString.Key: Any] = [.font: italicSystemFont(ofSize: 10), .foregroundColor: PlatformColor.gray]
                        let commentText = "  \"\(comment)\"" as NSString
                        let commentSize = commentText.boundingRect(with: CGSize(width: contentWidth - 30, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: commentAttributes, context: nil)
                        commentText.draw(in: CGRect(x: margin + 20, y: yPosition, width: contentWidth - 30, height: commentSize.height), withAttributes: commentAttributes)
                        yPosition += commentSize.height + 5
                    }

                    yPosition += 10
                }
            }

            // Footer
            checkPageBreak(requiredSpace: 30)
            yPosition = pageHeight - 40
            let footerFont = PlatformFont.systemFont(ofSize: 10)
            let footerAttributes: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: PlatformColor.lightGray]
            let footerText = "Generated by TMI App on \(Date().formatted())" as NSString
            footerText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: footerAttributes)

            context.endPDFPage()
        }

        return data
    }

    private struct EvidenceSummary {
        let totalEntries: Int
        let checklistCompletions: Int
        let streakCompletions: Int
        let incidentCount: Int
        let thoughtLogCount: Int
        let ratingCount: Int
        let averageRating: Double
    }

    private func fetchPlanInputsForExport(_ plan: TMIPlan) async -> [PlanInputField] {
        guard let planId = plan.id else { return [] }
        return (try? await planService.fetchPlanInputs(planId: planId)) ?? []
    }

    private func fetchPlanEvidenceForExport(_ plan: TMIPlan) async -> [PlanEvidenceEntry] {
        guard let planId = plan.id else { return [] }
        return (try? await planService.fetchPlanEvidence(planId: planId)) ?? []
    }

    private func summarizeEvidence(_ entries: [PlanEvidenceEntry]) -> EvidenceSummary {
        let checklistCompletions = entries.filter { $0.type == .checklist }.count
        let streakCompletions = entries.filter { $0.type == .streak }.count
        let incidentCount = entries.filter { $0.type == .incident }.count
        let thoughtLogCount = entries.filter { $0.type == .thoughtLog }.count
        let ratingEntries = entries.filter { $0.type == .rating }
        let totalRating = ratingEntries.reduce(0.0) { $0 + ($1.numericValue ?? 0.0) }
        let averageRating = ratingEntries.isEmpty ? 0.0 : totalRating / Double(ratingEntries.count)

        return EvidenceSummary(
            totalEntries: entries.count,
            checklistCompletions: checklistCompletions,
            streakCompletions: streakCompletions,
            incidentCount: incidentCount,
            thoughtLogCount: thoughtLogCount,
            ratingCount: ratingEntries.count,
            averageRating: averageRating
        )
    }

    // MARK: - Text Export

    /// Export a TMI plan to plain text
    func exportPlanToText(_ plan: TMIPlan) async throws -> URL {
        let textContent = await generateTextContent(for: plan)

        let fileName = "\(plan.title.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(date: .numeric, time: .omitted)).txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
        print("[PlanExportService] Exported plan to text: \(fileURL.path)")

        return fileURL
    }

    /// Generate plain text content for a plan
    private func generateTextContent(for plan: TMIPlan) async -> String {
        var lines: [String] = []
        let inputs = await fetchPlanInputsForExport(plan)
        let evidenceSummary = summarizeEvidence(await fetchPlanEvidenceForExport(plan))

        // Header
        lines.append("TMI PLAN")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")

        // Title
        lines.append("TITLE: \(plan.title)")
        lines.append("")

        // Model and Status
        lines.append("MODEL: \(plan.model.rawValue)")
        lines.append("STATUS: \(plan.approvalStatus.displayName)")
        lines.append("CREATED: \(plan.creationDate.formatted())")
        lines.append("LAST UPDATED: \(plan.lastUpdated.formatted())")
        lines.append("")

        // Description
        if let description = plan.description, !description.isEmpty {
            lines.append("DESCRIPTION:")
            lines.append(description)
            lines.append("")
        }

        if !inputs.isEmpty {
            lines.append("PLAN INPUTS:")
            for input in inputs {
                let value = input.value.isEmpty ? "[Not provided]" : input.value
                lines.append("- \(input.label): \(value)")
            }
            lines.append("")
        }

        if evidenceSummary.totalEntries > 0 {
            lines.append("EVIDENCE SUMMARY:")
            lines.append("- Total entries: \(evidenceSummary.totalEntries)")
            lines.append("- Checklist completions: \(evidenceSummary.checklistCompletions)")
            lines.append("- Streak completions: \(evidenceSummary.streakCompletions)")
            lines.append("- Incidents logged: \(evidenceSummary.incidentCount)")
            lines.append("- Thought logs: \(evidenceSummary.thoughtLogCount)")
            lines.append("- Ratings logged: \(evidenceSummary.ratingCount)")
            lines.append("- Average rating: \(String(format: "%.1f", evidenceSummary.averageRating))")
            lines.append("")
        }

        // Students
        if !plan.students.isEmpty {
            lines.append("STUDENTS:")
            for student in plan.students {
                lines.append("  • \(student.name) (Grade \(student.grade))")
            }
            lines.append("")
        }

        // Goals
        if !plan.goals.isEmpty {
            lines.append("GOALS:")
            for (index, goal) in plan.goals.enumerated() {
                lines.append("  \(index + 1). \(goal.description)")
                lines.append("     Status: \(goal.status.rawValue)")
                lines.append("     Progress: \(Int(goal.progress * 100))%")
                if let dueDate = goal.dueDate {
                    lines.append("     Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                }
                if let notes = goal.notes, !notes.isEmpty {
                    lines.append("     Notes: \(notes)")
                }
                lines.append("")
            }
        }

        // Interests
        if !plan.interests.isEmpty {
            lines.append("INTERESTS & HOBBIES:")
            lines.append("  \(plan.interests.map { $0.name }.joined(separator: ", "))")
            lines.append("")
        }

        // Strategies
        if let strategies = plan.strategies, !strategies.isEmpty {
            lines.append("STRATEGIES:")
            for strategy in strategies {
                lines.append("  • \(strategy)")
            }
            lines.append("")
        }

        // Notes
        if !plan.notes.isEmpty {
            lines.append("NOTES:")
            lines.append(plan.notes)
            lines.append("")
        }

        // Approval History
        if !plan.approvalHistory.isEmpty {
            lines.append("APPROVAL HISTORY:")
            for entry in plan.approvalHistory {
                lines.append("  • \(entry.action.displayName) on \(entry.timestamp.formatted())")
                if let comment = entry.comment, !comment.isEmpty {
                    lines.append("    \"\(comment)\"")
                }
            }
            lines.append("")
        }

        // Footer
        lines.append(String(repeating: "=", count: 60))
        lines.append("Generated by TMI App on \(Date().formatted())")

        return lines.joined(separator: "\n")
    }
    
    // MARK: - MTSS Export
    
    /// Export a TMI plan in MTSS (Multi-Tiered System of Supports) format
    /// This format is designed for district compliance and intervention documentation
    func exportPlanToMTSS(_ plan: TMIPlan) async throws -> URL {
        let mtssContent = await generateMTSSContent(for: plan)
        
        let fileName = "MTSS_\(plan.primaryStudent?.name.replacingOccurrences(of: " ", with: "_") ?? "Student")_\(Date().formatted(date: .numeric, time: .omitted)).txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try mtssContent.write(to: fileURL, atomically: true, encoding: .utf8)
        print("[PlanExportService] Exported MTSS document: \(fileURL.path)")
        
        return fileURL
    }
    
    /// Generate MTSS-compliant content for documentation
    private func generateMTSSContent(for plan: TMIPlan) async -> String {
        var lines: [String] = []
        let divider = String(repeating: "─", count: 70)
        let headerDivider = String(repeating: "═", count: 70)
        let evidenceSummary = summarizeEvidence(await fetchPlanEvidenceForExport(plan))
        let inputs = await fetchPlanInputsForExport(plan)
        
        // Header
        lines.append(headerDivider)
        lines.append("MULTI-TIERED SYSTEM OF SUPPORTS (MTSS)")
        lines.append("INTERVENTION PLAN DOCUMENTATION")
        lines.append(headerDivider)
        lines.append("")
        
        // Student Information Section
        lines.append("┌" + String(repeating: "─", count: 68) + "┐")
        lines.append("│ SECTION 1: STUDENT INFORMATION" + String(repeating: " ", count: 37) + "│")
        lines.append("└" + String(repeating: "─", count: 68) + "┘")
        lines.append("")
        
        if let student = plan.primaryStudent {
            lines.append("Student Name:     \(student.name)")
            lines.append("Grade Level:      \(student.grade)")
            if !student.school.isEmpty {
                lines.append("School:           \(student.school)")
            }
        } else {
            lines.append("Student Name:     [Not specified]")
        }
        
        lines.append("Plan Created:     \(plan.creationDate.formatted(date: .long, time: .omitted))")
        lines.append("Last Updated:     \(plan.lastUpdated.formatted(date: .long, time: .omitted))")
        lines.append("Plan Status:      \(plan.approvalStatus.displayName)")
        lines.append("")
        
        // Tier Classification Section
        lines.append(divider)
        lines.append("┌" + String(repeating: "─", count: 68) + "┐")
        lines.append("│ SECTION 2: TIER CLASSIFICATION & INTERVENTION MODEL" + String(repeating: " ", count: 16) + "│")
        lines.append("└" + String(repeating: "─", count: 68) + "┘")
        lines.append("")
        
        // Map TMI Model to MTSS Tier
        let (tier, tierDescription) = mapModelToMTSSTier(plan.model)
        lines.append("MTSS Tier:        \(tier)")
        lines.append("TMI Model:        \(plan.model.rawValue)")
        lines.append("")
        lines.append("Tier Description:")
        lines.append("  \(tierDescription)")
        lines.append("")
        
        lines.append("Intervention Model Description:")
        lines.append("  \(plan.model.description)")
        lines.append("")
        
        // Area of Concern Section
        lines.append(divider)
        lines.append("┌" + String(repeating: "─", count: 68) + "┐")
        lines.append("│ SECTION 3: AREA OF CONCERN & BASELINE DATA" + String(repeating: " ", count: 24) + "│")
        lines.append("└" + String(repeating: "─", count: 68) + "┘")
        lines.append("")
        
        lines.append("Primary Concern Area: \(concernAreaFor(plan.model))")
        lines.append("")
        
        if let description = plan.description, !description.isEmpty {
            lines.append("Problem Statement:")
            lines.append("  \(description)")
            lines.append("")
        }

        if !inputs.isEmpty {
            lines.append("Plan Inputs:")
            for input in inputs {
                let value = input.value.isEmpty ? "[Not provided]" : input.value
                lines.append("  - \(input.label): \(value)")
            }
            lines.append("")
        }
        
        // Baseline from interests/profile
        lines.append("Student Profile Indicators:")
        if !plan.interests.isEmpty {
            lines.append("  Identified Interests: \(plan.interests.map { $0.name }.joined(separator: ", "))")
        } else {
            lines.append("  Identified Interests: [Interest survey not completed]")
        }
        lines.append("")
        
        lines.append("Current Progress Level: \(plan.progressPercentage)%")
        lines.append("")
        
        // Intervention Strategies Section
        lines.append(divider)
        lines.append("┌" + String(repeating: "─", count: 68) + "┐")
        lines.append("│ SECTION 4: INTERVENTION STRATEGIES" + String(repeating: " ", count: 32) + "│")
        lines.append("└" + String(repeating: "─", count: 68) + "┘")
        lines.append("")
        
        lines.append("Evidence-Based Strategies:")
        let modelStrategies = getModelStrategies(for: plan.model)
        for (index, strategy) in modelStrategies.enumerated() {
            lines.append("  \(index + 1). \(strategy)")
        }
        lines.append("")
        
        if let strategies = plan.strategies, !strategies.isEmpty {
            lines.append("Customized Strategies for This Student:")
            for (index, strategy) in strategies.enumerated() {
                lines.append("  \(index + 1). \(strategy)")
            }
            lines.append("")
        }
        
        lines.append("Intervention Frequency: [To be determined by educator]")
        lines.append("Intervention Duration:  [To be determined by educator]")
        lines.append("Person Responsible:     \(plan.createdBy)")
        lines.append("")
        
        // Goals & Progress Monitoring Section
        lines.append(divider)
        lines.append("┌" + String(repeating: "─", count: 68) + "┐")
        lines.append("│ SECTION 5: GOALS & PROGRESS MONITORING" + String(repeating: " ", count: 28) + "│")
        lines.append("└" + String(repeating: "─", count: 68) + "┘")
        lines.append("")
        
        if plan.goals.isEmpty {
            lines.append("Goals: [No goals set - add goals to track progress]")
        } else {
            lines.append("SMART Goals:")
            for (index, goal) in plan.goals.enumerated() {
                lines.append("")
                lines.append("Goal \(index + 1):")
                lines.append("  Description:  \(goal.description)")
                lines.append("  Status:       \(goal.status.rawValue)")
                lines.append("  Progress:     \(Int(goal.progress * 100))%")
                if let dueDate = goal.dueDate {
                    lines.append("  Target Date:  \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                }
                if let notes = goal.notes, !notes.isEmpty {
                    lines.append("  Notes:        \(notes)")
                }
            }
        }
        lines.append("")
        
        lines.append("Progress Monitoring Schedule:")
        lines.append("  □ Weekly check-in with student")
        lines.append("  □ Bi-weekly data collection")
        lines.append("  □ Monthly progress review meeting")
        lines.append("")

        if evidenceSummary.totalEntries > 0 {
            lines.append("Evidence Summary:")
            lines.append("  Total entries: \(evidenceSummary.totalEntries)")
            lines.append("  Checklist completions: \(evidenceSummary.checklistCompletions)")
            lines.append("  Streak completions: \(evidenceSummary.streakCompletions)")
            lines.append("  Incidents logged: \(evidenceSummary.incidentCount)")
            lines.append("  Thought logs: \(evidenceSummary.thoughtLogCount)")
            lines.append("  Ratings logged: \(evidenceSummary.ratingCount)")
            lines.append("  Average rating: \(String(format: "%.1f", evidenceSummary.averageRating))")
            lines.append("")
        }
        
        // Decision Rules Section
        lines.append(divider)
        lines.append("┌" + String(repeating: "─", count: 68) + "┐")
        lines.append("│ SECTION 6: DECISION RULES" + String(repeating: " ", count: 42) + "│")
        lines.append("└" + String(repeating: "─", count: 68) + "┘")
        lines.append("")
        
        lines.append("Response to Intervention Criteria:")
        lines.append("")
        lines.append("  ✓ POSITIVE RESPONSE (Continue/Fade):")
        lines.append("    - Goal progress ≥ 75% within expected timeframe")
        lines.append("    - Consistent engagement with intervention activities")
        lines.append("    - Student demonstrates skill generalization")
        lines.append("")
        lines.append("  ⚠ QUESTIONABLE RESPONSE (Intensify/Modify):")
        lines.append("    - Goal progress 50-74% with inconsistent gains")
        lines.append("    - Sporadic engagement requiring additional support")
        lines.append("    - Review and modify intervention strategies")
        lines.append("")
        lines.append("  ✗ POOR RESPONSE (Refer/Intensify Tier):")
        lines.append("    - Goal progress < 50% after 6-8 weeks")
        lines.append("    - Limited response to current intervention tier")
        lines.append("    - Consider referral to next tier or specialist")
        lines.append("")
        
        // Collaboration & Approval Section
        lines.append(divider)
        lines.append("┌" + String(repeating: "─", count: 68) + "┐")
        lines.append("│ SECTION 7: COLLABORATION & APPROVAL" + String(repeating: " ", count: 31) + "│")
        lines.append("└" + String(repeating: "─", count: 68) + "┘")
        lines.append("")
        
        if !plan.approvalHistory.isEmpty {
            lines.append("Approval History:")
            for entry in plan.approvalHistory {
                lines.append("  • \(entry.action.displayName) on \(entry.timestamp.formatted(date: .abbreviated, time: .shortened))")
                if let comment = entry.comment, !comment.isEmpty {
                    lines.append("    Comment: \"\(comment)\"")
                }
            }
            lines.append("")
        }
        
        if !plan.notes.isEmpty {
            lines.append("Team Collaboration Notes:")
            lines.append("  \(plan.notes)")
            lines.append("")
        }
        
        lines.append("Required Signatures:")
        lines.append("")
        lines.append("  Educator: ______________________ Date: __________")
        lines.append("")
        lines.append("  Counselor: _____________________ Date: __________")
        lines.append("")
        lines.append("  Administrator: _________________ Date: __________")
        lines.append("")
        lines.append("  Parent/Guardian: _______________ Date: __________")
        lines.append("")
        
        // Footer
        lines.append(headerDivider)
        lines.append("Generated by TMI App - PathFinder | \(Date().formatted())")
        lines.append("This document is intended for MTSS documentation and compliance purposes.")
        lines.append(headerDivider)
        
        return lines.joined(separator: "\n")
    }

    // MARK: - IEP Contribution Export

    /// Export a TMI plan in IEP contribution format
    func exportPlanToIEPContribution(_ plan: TMIPlan) async throws -> URL {
        let iepContent = await generateIEPContent(for: plan)

        let fileName = "IEP_\(plan.primaryStudent?.name.replacingOccurrences(of: " ", with: "_") ?? "Student")_\(Date().formatted(date: .numeric, time: .omitted)).txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        try iepContent.write(to: fileURL, atomically: true, encoding: .utf8)
        print("[PlanExportService] Exported IEP contribution: \(fileURL.path)")

        return fileURL
    }

    /// Generate IEP-compliant contribution content
    private func generateIEPContent(for plan: TMIPlan) async -> String {
        var lines: [String] = []
        let divider = String(repeating: "─", count: 70)
        let headerDivider = String(repeating: "═", count: 70)
        let inputs = await fetchPlanInputsForExport(plan)
        let evidenceSummary = summarizeEvidence(await fetchPlanEvidenceForExport(plan))

        lines.append(headerDivider)
        lines.append("INDIVIDUALIZED EDUCATION PROGRAM (IEP)")
        lines.append("SUPPORTING DOCUMENTATION - TMI CONTRIBUTION")
        lines.append(headerDivider)
        lines.append("")

        // Student Information
        lines.append("SECTION 1: STUDENT INFORMATION")
        lines.append(divider)
        if let student = plan.primaryStudent {
            lines.append("Student Name:     \(student.name)")
            lines.append("Grade Level:      \(student.grade)")
            if let school = student.school.isEmpty ? nil : student.school {
                lines.append("School:           \(school)")
            }
        } else {
            lines.append("Student Name:     [Not specified]")
        }
        lines.append("Plan Created:     \(plan.creationDate.formatted(date: .long, time: .omitted))")
        lines.append("Last Updated:     \(plan.lastUpdated.formatted(date: .long, time: .omitted))")
        lines.append("")

        // Present Levels of Performance
        lines.append("SECTION 2: PRESENT LEVELS OF ACADEMIC & FUNCTIONAL PERFORMANCE")
        lines.append(divider)
        if let description = plan.description, !description.isEmpty {
            lines.append("Summary:")
            lines.append("  \(description)")
        } else {
            lines.append("Summary: [No narrative summary provided]")
        }
        lines.append("")
        lines.append("Interests & Strengths:")
        if plan.interests.isEmpty {
            lines.append("  [No interests captured]")
        } else {
            lines.append("  \(plan.interests.map { $0.name }.joined(separator: ", "))")
        }
        lines.append("")

        // Measurable Annual Goals
        lines.append("SECTION 3: MEASURABLE ANNUAL GOALS")
        lines.append(divider)
        if plan.goals.isEmpty {
            lines.append("Goals: [No goals set - add measurable goals to align with IEP]")
        } else {
            for (index, goal) in plan.goals.enumerated() {
                lines.append("Goal \(index + 1): \(goal.description)")
                lines.append("  Status: \(goal.status.rawValue)")
                lines.append("  Progress: \(Int(goal.progress * 100))%")
                if let dueDate = goal.dueDate {
                    lines.append("  Target Date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                }
                if let notes = goal.notes, !notes.isEmpty {
                    lines.append("  Notes: \(notes)")
                }
                lines.append("")
            }
        }

        // Services and Supports
        lines.append("SECTION 4: SERVICES, ACCOMMODATIONS, AND SUPPORTS")
        lines.append(divider)
        lines.append("Intervention Model: \(plan.model.rawValue)")
        lines.append("Model Description: \(plan.model.description)")
        lines.append("")

        if evidenceSummary.totalEntries > 0 {
            lines.append("Evidence Summary:")
            lines.append("  Total entries: \(evidenceSummary.totalEntries)")
            lines.append("  Checklist completions: \(evidenceSummary.checklistCompletions)")
            lines.append("  Streak completions: \(evidenceSummary.streakCompletions)")
            lines.append("  Incidents logged: \(evidenceSummary.incidentCount)")
            lines.append("  Thought logs: \(evidenceSummary.thoughtLogCount)")
            lines.append("  Ratings logged: \(evidenceSummary.ratingCount)")
            lines.append("  Average rating: \(String(format: "%.1f", evidenceSummary.averageRating))")
            lines.append("")
        }

        if let strategies = plan.strategies, !strategies.isEmpty {
            lines.append("Instructional/Behavioral Strategies:")
            for strategy in strategies {
                lines.append("  • \(strategy)")
            }
        } else {
            lines.append("Instructional/Behavioral Strategies: [Not specified]")
        }
        lines.append("")

        if !inputs.isEmpty {
            lines.append("Plan Inputs:")
            for input in inputs {
                let value = input.value.isEmpty ? "[Not provided]" : input.value
                lines.append("  - \(input.label): \(value)")
            }
            lines.append("")
        }

        if !plan.resources.isEmpty {
            lines.append("Supplementary Resources:")
            for resource in plan.resources {
                lines.append("  • \(resource.title) (\(resource.category.rawValue))")
            }
            lines.append("")
        }

        // Progress Monitoring
        lines.append("SECTION 5: PROGRESS MONITORING")
        lines.append(divider)
        lines.append("Progress Monitoring Schedule:")
        lines.append("  • Weekly student check-ins")
        lines.append("  • Bi-weekly goal review")
        lines.append("  • Monthly team review")
        lines.append("")
        lines.append("Current Progress Summary:")
        lines.append("  Overall Progress: \(plan.progressPercentage)%")
        lines.append("  Approval Status: \(plan.approvalStatus.displayName)")
        lines.append("")

        // Team Notes
        lines.append("SECTION 6: TEAM NOTES & RECOMMENDATIONS")
        lines.append(divider)
        if plan.notes.isEmpty {
            lines.append("Notes: [No team notes captured]")
        } else {
            lines.append("Notes:")
            lines.append("  \(plan.notes)")
        }
        lines.append("")

        lines.append(headerDivider)
        lines.append("Generated by TMI App - PathFinder | \(Date().formatted())")
        lines.append("This document is intended to support IEP documentation.")
        lines.append(headerDivider)

        return lines.joined(separator: "\n")
    }
    
    /// Map TMI intervention model to MTSS tier classification
    private func mapModelToMTSSTier(_ model: TMIPlanModel) -> (tier: String, description: String) {
        switch model {
        case .alignYourMind:
            return ("Tier 2 - Targeted Intervention", 
                    "Targeted social-emotional support for students needing more than universal instruction")
        case .chaseYourSpace:
            return ("Tier 1/2 - Universal/Targeted", 
                    "Self-regulation and identity exploration appropriate for all students with targeted deepening")
        case .meekToProtector:
            return ("Tier 2 - Targeted Intervention", 
                    "Building confidence and leadership skills for students who need encouragement")
        case .acknowledgeInterests:
            return ("Tier 1 - Universal Instruction", 
                    "Interest exploration and engagement strategies for all students")
        case .directAndCorrect:
            return ("Tier 2/3 - Targeted/Intensive", 
                    "Behavioral intervention requiring individualized support and coping skills")
        case .bullyToBoss:
            return ("Tier 3 - Intensive Intervention", 
                    "Intensive behavior modification and leadership redirection for high-needs students")
        }
    }
    
    /// Get evidence-based strategies for each model
    private func getModelStrategies(for model: TMIPlanModel) -> [String] {
        switch model {
        case .alignYourMind:
            return [
                "Mindfulness and grounding exercises",
                "Cognitive reframing techniques",
                "Emotional regulation skill-building",
                "Weekly reflection journaling"
            ]
        case .chaseYourSpace:
            return [
                "Career pathway mapping",
                "Personal goal visualization",
                "Self-advocacy role-playing",
                "Professional mentor connections"
            ]
        case .meekToProtector:
            return [
                "Strength identification exercises",
                "Progressive leadership opportunities",
                "Peer mentoring connections",
                "Confidence-building challenges"
            ]
        case .acknowledgeInterests:
            return [
                "Interest inventory exploration",
                "Hobby-based learning connections",
                "Passion project development",
                "Career-interest alignment activities"
            ]
        case .directAndCorrect:
            return [
                "Coping skills development",
                "Scenario-based learning",
                "Social worker collaboration",
                "Interest-connected behavior redirection"
            ]
        case .bullyToBoss:
            return [
                "Leadership role identification",
                "Positive influence training",
                "Interest-driven mentorship",
                "Conflict resolution skill-building"
            ]
        }
    }
    
    /// Get the primary concern area for MTSS documentation
    private func concernAreaFor(_ model: TMIPlanModel) -> String {
        switch model {
        case .alignYourMind:
            return "Focus & Self-Regulation"
        case .chaseYourSpace:
            return "Career & Academic Direction"
        case .meekToProtector:
            return "Confidence & Self-Advocacy"
        case .acknowledgeInterests:
            return "Engagement & Motivation"
        case .directAndCorrect:
            return "Behavioral Regulation"
        case .bullyToBoss:
            return "Social-Emotional & Leadership"
        }
    }

    // MARK: - Bulk Export

    /// Export multiple plans to a single PDF
    func exportMultiplePlans(_ plans: [TMIPlan], title: String) async throws -> URL {
        // For simplicity, we'll create separate PDFs and note this in documentation
        // A full implementation would merge PDFs or create one multi-plan PDF
        throw PlanExportError.notImplemented("Bulk export coming in future release")
    }
}

private extension PlanExportService {
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

    func italicSystemFont(ofSize size: CGFloat) -> PlatformFont {
        #if canImport(UIKit)
        return PlatformFont.italicSystemFont(ofSize: size)
        #elseif canImport(AppKit)
        let baseFont = PlatformFont.systemFont(ofSize: size)
        return NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        #endif
    }
}

// MARK: - Error Handling

enum PlanExportError: Error, LocalizedError {
    case exportFailed(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .notImplemented(let message):
            return message
        }
    }
}
