import SwiftUI

// MARK: - Contestants

struct Contestant: Identifiable {
    let id: Int
    let name: String
    let hometown: String
    let trait: String
    let color: Color
    let nerve: Double      // appetite for risk, 0–1: the bold bet big on the Money Cards
    let speed: Double      // chance per tick of moving during excursions
    var human = false
    var chest: Int? = nil  // number (1–9) brought back from the latest excursion (0 = empty-handed)
    var chestTier: ChestTier? = nil
    var out = false
    var bank = 0           // dollars they leave the island with
    var fate = ""

    var initial: String { String(name.prefix(1)) }
    var emptyHanded: Bool { chest == 0 }
}

enum Roster {
    static func make() -> [Contestant] {
        let data: [(String, String, String, Color, Double, Double)] = [
            ("Maya",   "Honolulu, HI",    "Bartender",         .pink,   0.60, 0.62),
            ("Kenji",  "Osaka, Japan",    "Accountant",        .blue,   0.30, 0.56),
            ("Rosa",   "San Antonio, TX", "Fearless diver",    .orange, 0.90, 0.76),
            ("Deidre", "Chicago, IL",     "Poker dealer",      .teal,   0.75, 0.60),
            ("Harper", "Portland, ME",    "Sailing captain",   .indigo, 0.50, 0.70),
            ("Ellie",  "Atlanta, GA",     "Cruise Director",   .green,  0.40, 0.78),
        ]
        return data.enumerated().map { i, d in
            Contestant(id: i, name: d.0, hometown: d.1, trait: d.2, color: d.3, nerve: d.4, speed: d.5)
        }
    }
}

// MARK: - Treasure

/// Chests hold a number from 1 to 9: bronze 1–3, silver 4–6, gold 7–9.
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

    func roll() -> Int { rawValue * 3 + Int.random(in: 1...3) }
}

// MARK: - Playing cards

/// A playing card for the Money Cards. Rank 2…14 (aces high); suit 0 ♣, 1 ♦, 2 ♥, 3 ♠.
struct PCard: Hashable, Identifiable {
    let rank: Int
    let suit: Int
    var id: Int { suit * 13 + rank }
    var isRed: Bool { suit == 1 || suit == 2 }
    var suitSymbol: String { ["♣", "♦", "♥", "♠"][suit] }
    var rankText: String {
        switch rank {
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        case 14: "A"
        default: "\(rank)"
        }
    }
    var name: String { rankText + suitSymbol }
    /// "an Ace", "a 7", "an 8"
    var spoken: String {
        let n = ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace"][rank]
        return (rank == 8 || rank == 14 ? "an " : "a ") + n
    }

    static func deck() -> [PCard] {
        (0..<4).flatMap { s in (2...14).map { PCard(rank: $0, suit: s) } }
    }
}

// MARK: - Helpers

func money(_ v: Int) -> String {
    v.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }
