import CoreGraphics
import CoreText
import Foundation

/// One rendered page.
///
/// Pagination is decided here rather than inside the drawing code, so what a
/// page carries can be asserted directly instead of by reading PDF bytes.
nonisolated struct PlanExportPage: Sendable, Equatable {
    let heading: String
    let lines: [String]
    /// Repeated on every page. A page that gets separated from the rest still
    /// says what it is, who it is about, and which export produced it.
    let footer: String
    let pageNumber: Int
    let pageCount: Int
}

/// Turns an authorized export document into stable pages.
///
/// The renderer can only draw what the projection gave it. Anything the reader
/// was not entitled to was never placed in the document, so there is nothing
/// here to redact and no way for a layout decision to reveal something.
nonisolated enum PlanExportRenderer {
    /// US Letter at 72dpi.
    static let pageSize = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 54
    static let lineHeight: CGFloat = 16
    /// Lines of body text that fit between the heading and the footer.
    static let linesPerPage = 36

    static func pages(for document: PlanExportDocument) -> [PlanExportPage] {
        var body: [String] = []

        body.append("Student: \(document.studentDisplayName)")
        body.append("Model: \(document.model.rawValue)")
        body.append("Completion: \(document.completionPercentage)% of due actions")
        body.append("")

        if !document.rationale.isEmpty {
            body.append("Why this model")
            body.append(contentsOf: document.rationale.map { "  \($0)" })
            body.append("")
        }

        if !document.goals.isEmpty {
            body.append("Goals")
            for goal in document.goals {
                body.append("  \(goal.title)")
                body.append("    From: \(goal.baseline)")
                body.append("    To: \(goal.target)")
                body.append(
                    "    \(goal.status.displayName) · due \(Self.date(goal.dueDate))"
                )
            }
            body.append("")
        }

        if !document.progress.isEmpty {
            body.append("Progress")
            for line in document.progress {
                body.append("  \(Self.date(line.recordedAt)): \(line.summary)")
            }
            body.append("")
        }

        // A document with no body still produces one page, because an export
        // that renders nothing at all is indistinguishable from a failure.
        let chunks = body.isEmpty ? [[]] : Self.chunk(body, size: linesPerPage)
        let footer = "\(document.classification) · audit \(document.auditID)"

        return chunks.enumerated().map { index, lines in
            PlanExportPage(
                heading: document.kind.title,
                lines: lines,
                footer: footer,
                pageNumber: index + 1,
                pageCount: chunks.count
            )
        }
    }

    /// Draws the pages into a PDF.
    ///
    /// CoreGraphics rather than UIKit, because this ships on macOS too.
    static func pdfData(for document: PlanExportDocument) -> Data? {
        let pages = pages(for: document)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil as CFDictionary?)
        else { return nil }

        for page in pages {
            context.beginPDFPage(nil as CFDictionary?)
            var y = pageSize.height - margin
            draw(page.heading, in: context, at: CGPoint(x: margin, y: y), size: 18, bold: true)
            y -= lineHeight * 2
            for line in page.lines {
                draw(line, in: context, at: CGPoint(x: margin, y: y), size: 11, bold: false)
                y -= lineHeight
            }
            draw(
                "\(page.footer) · page \(page.pageNumber) of \(page.pageCount)",
                in: context,
                at: CGPoint(x: margin, y: margin),
                size: 9,
                bold: false
            )
            context.endPDFPage()
        }

        context.closePDF()
        return data as Data
    }

    // MARK: - Plumbing

    static func chunk(_ lines: [String], size: Int) -> [[String]] {
        guard size > 0 else { return [lines] }
        return stride(from: 0, to: lines.count, by: size).map {
            Array(lines[$0..<min($0 + size, lines.count)])
        }
    }

    /// Fixed format, so the same document renders identically anywhere.
    static func date(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    private static func draw(
        _ text: String,
        in context: CGContext,
        at point: CGPoint,
        size: CGFloat,
        bold: Bool
    ) {
        guard !text.isEmpty else { return }
        let font = CTFontCreateWithName(
            (bold ? "Helvetica-Bold" : "Helvetica") as CFString,
            size,
            nil
        )
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: CGColor(gray: 0, alpha: 1),
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = point
        CTLineDraw(line, context)
    }
}
