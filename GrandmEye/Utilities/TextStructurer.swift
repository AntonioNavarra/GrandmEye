import CoreGraphics
import Foundation

/// One line of text found by OCR, with its position (normalized, origin bottom-left like Vision).
nonisolated struct RecognizedLine {
    let text: String
    let box: CGRect
}

/// Rebuilds paragraphs, lists and headings from OCR lines, so the text reads (and sounds) like the page.
/// Paragraphs are separated by a blank line ("\n\n"); list items start on their own line ("\n").
nonisolated enum TextStructurer {

    static func structure(_ lines: [RecognizedLine]) -> String {
        let rows = makeRows(from: lines)
        guard !rows.isEmpty else { return "" }

        let heights = rows.map { $0.box.height }.sorted()
        let median = heights[heights.count / 2]

        var output = ""
        var forceBreak = false
        var previous: RecognizedLine?

        for row in rows {
            let text = row.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let heading = isHeading(text)

            guard let prev = previous else {
                output = text
                previous = row
                forceBreak = heading
                continue
            }

            let gap = prev.box.minY - row.box.maxY          // empty space between the two rows
            let bigGap = gap > 0.8 * median

            if forceBreak || heading || bigGap {
                output += "\n\n" + text
            } else if isListItem(text) {
                output += "\n" + text
            } else if joinsHyphenation(output, next: text) {
                output.removeLast()                          // "compres-" + "sa" -> "compressa"
                output += text
            } else {
                output += " " + text
            }
            forceBreak = heading
            previous = row
        }
        return output
    }

    // MARK: - Rows

    /// Sorts lines top to bottom and merges the pieces that sit on the same row (left to right).
    private static func makeRows(from lines: [RecognizedLine]) -> [RecognizedLine] {
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }
        var groups: [[RecognizedLine]] = []
        for line in sorted {
            if var last = groups.last, let ref = last.first,
               abs(line.box.midY - ref.box.midY) < 0.5 * min(line.box.height, ref.box.height) {
                last.append(line)
                groups[groups.count - 1] = last
            } else {
                groups.append([line])
            }
        }
        return groups.map { group in
            let ordered = group.sorted { $0.box.minX < $1.box.minX }
            let box = ordered.dropFirst().reduce(ordered[0].box) { $0.union($1.box) }
            return RecognizedLine(text: ordered.map(\.text).joined(separator: " "), box: box)
        }
    }

    // MARK: - Rules

    private static func isListItem(_ text: String) -> Bool {
        text.range(of: #"^(\d{1,2}[.)]|[•\-–*·])\s+"#, options: .regularExpression) != nil
    }

    /// Short line written in capitals, e.g. "POSOLOGIA".
    private static func isHeading(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter)
        return text.count <= 50 && letters.count >= 3 && letters == letters.uppercased()
    }

    private static func joinsHyphenation(_ output: String, next: String) -> Bool {
        guard output.hasSuffix("-"), output.count >= 2,
              let beforeHyphen = output.dropLast().last, beforeHyphen.isLetter,
              let first = next.first else { return false }
        return first.isLowercase
    }
}
