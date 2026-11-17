// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import VoltaLanguageCore

/// One continuous stretch of the history line: either on battery or charging.
/// Each stretch starts at the previous point so the line stays connected. Where no samples were written
/// for a while (the Mac slept or Volta wasn't running), the bridge is coloured by what must have happened:
/// a rising level means it was charging, a falling one that it ran on battery.
struct TrendSegment: Identifiable, Equatable {
    let id: Int
    let charging: Bool
    var points: [Mark]

    static func split(_ marks: [Mark], maxGap: TimeInterval) -> [TrendSegment] {
        guard let first = marks.first else { return [] }
        guard marks.count > 1 else { return [TrendSegment(id: 0, charging: first.ac, points: [first])] }
        var out: [TrendSegment] = []
        for (a, b) in zip(marks, marks.dropFirst()) {
            let charging = b.t - a.t > maxGap && a.p != b.p ? b.p > a.p : b.ac
            if var current = out.last, current.charging == charging {
                current.points.append(b)
                out[out.count - 1] = current
            } else {
                out.append(TrendSegment(id: out.count, charging: charging, points: [a, b]))
            }
        }
        return out
    }
}

/// The small label shown while the pointer rests on the history chart: "14:05 Uhr · 63 %".
enum TrendReadout {
    static func text(level: Int, at date: Date, span: ChartSpan, language: AppLanguage) -> String {
        let german = language == .german
        let locale = Locale(identifier: german ? "de_DE" : "en_US")
        var time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
            .replacingOccurrences(of: "\u{202F}", with: " ")
        if german { time += " Uhr" }
        if span == .week {
            let day = date.formatted(Date.FormatStyle(locale: Locale(identifier: language.localeIdentifier)).weekday(.abbreviated))
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            time = "\(day) \(time)"
        }
        return german ? "\(time) · \(level) %" : "\(time) · \(level)%"
    }
}
