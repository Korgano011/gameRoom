import SwiftUI

// MARK: - Contestants

struct Contestant: Identifiable {
    let id: Int
    let name: String
    let hometown: String
    let trait: String
    let color: Color
    let nerve: Double      // appetite for risk, 0–1: the bold keep saying "No deal"
    let speed: Double      // chance per tick of moving during excursions
    var human = false
    var chest: Int? = nil  // amount brought back from the latest excursion (0 = empty-handed)
    var chestTier: ChestTier? = nil
    var treasure = 0       // every amount brought back, added up
    var out = false
    var bank = 0.0         // dollars they leave the island with
    var fate = ""

    var initial: String { String(name.prefix(1)) }
    /// What goes on the board: coming back empty-handed counts as the minimum amount.
    var boardAmount: Int { max(chest ?? 0, ChestTier.minimum) }
    var emptyHanded: Bool { chest == 0 }
}

enum Roster {
    static func make() -> [Contestant] {
        let data: [(String, String, String, Color, Double, Double)] = [
            ("Maya",   "Honolulu, HI",    "Bartender",         .pink,   0.60, 0.62),
            ("Kenji",  "Osaka, Japan",    "Accountant",        .blue,   0.30, 0.56),
            ("Rosa",   "San Antonio, TX", "Fearless diver",    .orange, 0.90, 0.76),
            ("Dev",    "Chicago, IL",     "Poker dealer",      .teal,   0.75, 0.60),
            ("Harper", "Portland, ME",    "Sailing captain",   .indigo, 0.50, 0.70),
            ("Theo",   "Atlanta, GA",     "Marathon runner",   .green,  0.40, 0.78),
        ]
        return data.enumerated().map { i, d in
            Contestant(id: i, name: d.0, hometown: d.1, trait: d.2, color: d.3, nerve: d.4, speed: d.5)
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

    /// The smallest amount a chest can hold — also what an empty-handed player puts on the board.
    static let minimum = 1_250

    /// Excursion amounts sit on the right side of the board, above the fixed $1,000.
    func roll() -> Int {
        switch self {
        case .bronze: Int.random(in: 5...20) * 250       // $1,250 – $5,000
        case .silver: Int.random(in: 21...50) * 250      // $5,250 – $12,500
        case .gold:   Int.random(in: 51...100) * 250     // $12,750 – $25,000
        }
    }
}

// MARK: - Helpers

func money(_ v: Int) -> String {
    v.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

/// Board amounts can be pennies: $0.01, $0.25 … then whole dollars from $1 up.
func money(_ v: Double) -> String {
    if v < 1, v > 0 { return v.formatted(.currency(code: "USD").precision(.fractionLength(2))) }
    return v.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }
