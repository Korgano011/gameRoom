import SwiftUI

// MARK: - Contestants

struct Contestant: Identifiable {
    let id: Int
    let name: String
    let hometown: String
    let trait: String
    let color: Color
    let smarts: Double     // how quickly they piece clues together as a Spoiler, 0.8–1.2
    let nerve: Double      // appetite for risk, 0–1
    let speed: Double      // chance per tick of moving during excursions
    var human = false
    var chest: Int? = nil  // money card from the latest excursion
    var chestTier: ChestTier? = nil
    var treasure = 0       // every money card brought back, added up — decides who takes the final hot seat
    var out = false
    var bank = 0           // Spoilers money they will leave with
    var fate = ""

    var initial: String { String(name.prefix(1)) }
}

enum Roster {
    static func make() -> [Contestant] {
        let data: [(String, String, String, Color, Double, Double, Double)] = [
            ("Maya",   "Honolulu, HI",    "Trivia night host", .pink,   1.05, 0.60, 0.60),
            ("Kenji",  "Osaka, Japan",    "History professor", .blue,   1.20, 0.45, 0.56),
            ("Rosa",   "San Antonio, TX", "Fearless diver",    .orange, 0.85, 0.90, 0.76),
            ("Dev",    "Chicago, IL",     "Crossword setter",  .teal,   1.15, 0.35, 0.58),
            ("Harper", "Portland, ME",    "Sailing captain",   .indigo, 0.95, 0.65, 0.70),
            ("Theo",   "Atlanta, GA",     "Marathon runner",   .green,  0.85, 0.75, 0.78),
            ("Aiko",   "Seattle, WA",     "Librarian",         .purple, 1.10, 0.50, 0.56),
            ("Lena",   "Denver, CO",      "Rock climber",      .mint,   0.90, 0.70, 0.74),
        ]
        return data.enumerated().map { i, d in
            Contestant(id: i, name: d.0, hometown: d.1, trait: d.2, color: d.3,
                       smarts: d.4, nerve: d.5, speed: d.6)
        }
    }
}

// MARK: - Treasure

enum ChestTier: Int, CaseIterable {
    case bronze, silver, gold

    var name: String { ["Bronze", "Silver", "Gold"][rawValue] }

    var color: Color {
        switch self {
        case .bronze: Color(red: 0.72, green: 0.45, blue: 0.20)
        case .silver: Color(red: 0.75, green: 0.78, blue: 0.82)
        case .gold:   Color(red: 0.98, green: 0.78, blue: 0.18)
        }
    }

    func roll() -> Int {
        switch self {
        case .bronze: Int.random(in: 1...10) * 100       // $100 – $1,000
        case .silver: Int.random(in: 5...12) * 250       // $1,250 – $3,000
        case .gold:   Int.random(in: 7...20) * 500       // $3,500 – $10,000
        }
    }
}

// MARK: - Helpers

func money(_ v: Int) -> String {
    v.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }
