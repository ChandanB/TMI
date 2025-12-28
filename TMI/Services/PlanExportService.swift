//
//  PlanExportService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #6
//  Exports TMI plans to PDF and text formats
//

import Foundation
import UIKit
import PDFKit

/// Service for exporting TMI plans to various formats
class PlanExportService {

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
        let pdfMetaData = [
            kCGPDFContextCreator: "TMI App",
            kCGPDFContextAuthor: plan.createdBy,
            kCGPDFContextTitle: plan.title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            var yPosition: CGFloat = 50
            let margin: CGFloat = 50
            let contentWidth = pageWidth - (margin * 2)

            // Helper to start new page if needed
            func checkPageBreak(requiredSpace: CGFloat) {
                if yPosition + requiredSpace > pageHeight - margin {
                    context.beginPage()
                    yPosition = 50
                }
            }

            // Start first page
            context.beginPage()

            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
            let titleString = plan.title as NSString
            let titleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 40)
            titleString.draw(in: titleRect, withAttributes: titleAttributes)
            yPosition += 50

            // Model and Status
            let headerFont = UIFont.systemFont(ofSize: 12)
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.gray]

            let modelText = "Model: \(plan.model.rawValue)" as NSString
            modelText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 20

            let statusText = "Status: \(plan.approvalStatus.displayName)" as NSString
            statusText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 30

            // Description
            if let description = plan.description, !description.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = UIFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Description".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = UIFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]
                let descRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 200)
                let descString = description as NSString
                let descSize = descString.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil)
                descString.draw(in: CGRect(x: margin, y: yPosition, width: contentWidth, height: descSize.height), withAttributes: bodyAttributes)
                yPosition += descSize.height + 20
            }

            // Students
            if !plan.students.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = UIFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Students".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = UIFont.systemFont(ofSize: 12)
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

                let sectionFont = UIFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Goals".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = UIFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                for (index, goal) in plan.goals.enumerated() {
                    checkPageBreak(requiredSpace: 40)

                    let goalHeader = "\(index + 1). \(goal.description)" as NSString
                    let goalRect = CGRect(x: margin + 10, y: yPosition, width: contentWidth - 20, height: 100)
                    let goalSize = goalHeader.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil)
                    goalHeader.draw(in: CGRect(x: margin + 10, y: yPosition, width: contentWidth - 20, height: goalSize.height), withAttributes: bodyAttributes)
                    yPosition += goalSize.height + 5

                    let statusText = "Status: \(goal.status.rawValue) | Progress: \(Int(goal.progress * 100))%" as NSString
                    let statusAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray]
                    statusText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: statusAttributes)
                    yPosition += 20
                }
                yPosition += 10
            }

            // Interests
            if !plan.interests.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = UIFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Interests & Hobbies".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = UIFont.systemFont(ofSize: 12)
                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                let interestNames = plan.interests.map { $0.name }.joined(separator: ", ")
                let interestRect = CGRect(x: margin + 10, y: yPosition, width: contentWidth - 20, height: 100)
                let interestString = interestNames as NSString
                let interestSize = interestString.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil)
                interestString.draw(in: CGRect(x: margin + 10, y: yPosition, width: contentWidth - 20, height: interestSize.height), withAttributes: bodyAttributes)
                yPosition += interestSize.height + 20
            }

            // Approval History
            if !plan.approvalHistory.isEmpty {
                checkPageBreak(requiredSpace: 60)

                let sectionFont = UIFont.boldSystemFont(ofSize: 16)
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont]
                "Approval History".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
                yPosition += 25

                let bodyFont = UIFont.systemFont(ofSize: 11)
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
                        let commentAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 10), .foregroundColor: UIColor.gray]
                        let commentText = "  \"\(comment)\"" as NSString
                        let commentRect = CGRect(x: margin + 20, y: yPosition, width: contentWidth - 30, height: 100)
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
            let footerFont = UIFont.systemFont(ofSize: 10)
            let footerAttributes: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.lightGray]
            let footerText = "Generated by TMI App on \(Date().formatted())" as NSString
            footerText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: footerAttributes)
        }

        return data
    }

    // MARK: - Text Export

    /// Export a TMI plan to plain text
    func exportPlanToText(_ plan: TMIPlan) async throws -> URL {
        let textContent = generateTextContent(for: plan)

        let fileName = "\(plan.title.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(date: .numeric, time: .omitted)).txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
        print("[PlanExportService] Exported plan to text: \(fileURL.path)")

        return fileURL
    }

    /// Generate plain text content for a plan
    private func generateTextContent(for plan: TMIPlan) -> String {
        var lines: [String] = []

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
            let interestNames = plan.interests.map { $0.name }.joined(separator: ", ")
            lines.append("  \(interestNames)")
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

    // MARK: - Bulk Export

    /// Export multiple plans to a single PDF
    func exportMultiplePlans(_ plans: [TMIPlan], title: String) async throws -> URL {
        // For simplicity, we'll create separate PDFs and note this in documentation
        // A full implementation would merge PDFs or create one multi-plan PDF
        throw PlanExportError.notImplemented("Bulk export coming in future release")
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
