import SwiftUI

// MARK: - Contestants

struct Contestant: Identifiable {
    let id: Int
    let name: String
    let hometown: String
    let trait: String
    let color: Color
    let memory: Double     // how well they remember where cards are, 0.6–0.95
    let nerve: Double      // appetite for risk, 0–1
    let speed: Double      // chance per tick of moving during excursions
    var human = false
    var chest: Int? = nil  // money card from the latest excursion
    var out = false
    var bank = 0           // Pay Cards and bonus-round money they will leave with
    var fate = ""

    var initial: String { String(name.prefix(1)) }
}

enum Roster {
    static func make() -> [Contestant] {
        let data: [(String, String, String, Color, Double, Double, Double)] = [
            ("Maya",   "Honolulu, HI",    "Card shark",        .pink,   0.88, 0.60, 0.60),
            ("Kenji",  "Osaka, Japan",    "Memory champion",   .blue,   0.95, 0.45, 0.58),
            ("Rosa",   "San Antonio, TX", "Fearless diver",    .orange, 0.72, 0.90, 0.74),
            ("Dev",    "Chicago, IL",     "Puzzle solver",     .teal,   0.90, 0.35, 0.60),
            ("Harper", "Portland, ME",    "Sailing captain",   .indigo, 0.78, 0.65, 0.70),
            ("Theo",   "Atlanta, GA",     "Marathon runner",   .green,  0.70, 0.75, 0.78),
            ("Aiko",   "Seattle, WA",     "Opera singer",      .purple, 0.84, 0.50, 0.56),
            ("Lena",   "Denver, CO",      "Rock climber",      .mint,   0.76, 0.70, 0.74),
            ("Sam",    "Boston, MA",      "Cautious saver",    .brown,  0.82, 0.15, 0.57),
        ]
        return data.enumerated().map { i, d in
            Contestant(id: i, name: d.0, hometown: d.1, trait: d.2, color: d.3,
                       memory: d.4, nerve: d.5, speed: d.6)
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

// MARK: - Playing cards

struct PlayingCard: Hashable, Identifiable {
    let rank: Int      // 2...14 (11 J, 12 Q, 13 K, 14 A); 0 = joker
    let suit: Int      // 0 ♠, 1 ♥, 2 ♦, 3 ♣

    var id: Int { rank * 4 + suit }
    var isJoker: Bool { rank == 0 }
    var isRed: Bool { suit == 1 || suit == 2 }

    var rankText: String {
        switch rank {
        case 0: "★"
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        case 14: "A"
        default: "\(rank)"
        }
    }

    var suitText: String { isJoker ? "JOKER" : ["♠", "♥", "♦", "♣"][suit] }

    var name: String {
        if isJoker { return "Joker" }
        return "\(PlayingCard.rankName(rank)) of \(["Spades", "Hearts", "Diamonds", "Clubs"][suit])"
    }

    static func rankName(_ r: Int) -> String {
        switch r {
        case 11: "Jack"
        case 12: "Queen"
        case 13: "King"
        case 14: "Ace"
        default: "\(r)"
        }
    }

    static func plural(_ r: Int) -> String { r == 6 ? "Sixes" : rankName(r) + "s" }

    /// The Pay Cards deck: Jacks through Aces in four suits — 16 cards — plus any jokers.
    static func payDeck(jokers: Int) -> [PlayingCard] {
        var d: [PlayingCard] = []
        for r in 11...14 { for s in 0..<4 { d.append(PlayingCard(rank: r, suit: s)) } }
        for j in 0..<jokers { d.append(PlayingCard(rank: 0, suit: j)) }
        return d
    }

    static func fullDeck() -> [PlayingCard] {
        (2...14).flatMap { r in (0..<4).map { PlayingCard(rank: r, suit: $0) } }
    }
}

// MARK: - Hands

struct HandValue: Comparable {
    let category: Int      // 0 nothing … 6 five of a kind
    let groups: [Int]      // ranks, biggest group first, then higher rank first

    static let names = ["No pair", "One pair", "Two pair", "Three of a kind", "Full house", "Four of a kind", "Five of a kind"]
    static let payouts = [0, 20, 40, 50, 100, 200, 300]

    var name: String { HandValue.names[category] }
    var payout: Int { HandValue.payouts[category] }

    var detail: String {
        guard let top = groups.first else { return name }
        switch category {
        case 1: return "Pair of \(PlayingCard.plural(top))"
        case 2: return "Two pair, \(PlayingCard.plural(top)) and \(PlayingCard.plural(groups[1]))"
        case 3: return "Three \(PlayingCard.plural(top))"
        case 4: return "Full house, \(PlayingCard.plural(top)) over \(PlayingCard.plural(groups[1]))"
        case 5: return "Four \(PlayingCard.plural(top))"
        case 6: return "Five \(PlayingCard.plural(top))!"
        default: return "\(PlayingCard.rankName(top)) high"
        }
    }

    static func < (a: HandValue, b: HandValue) -> Bool {
        if a.category != b.category { return a.category < b.category }
        return a.groups.lexicographicallyPrecedes(b.groups)
    }
}

enum Hands {
    /// Best reading of a hand of any size. Jokers become whichever rank helps most.
    static func evaluate(_ cards: [PlayingCard]) -> HandValue {
        let naturals = cards.filter { !$0.isJoker }.map(\.rank)
        let jokers = cards.count - naturals.count
        guard jokers > 0 else { return plain(naturals) }
        var best: HandValue?
        func tryRanks(_ extra: [Int]) {
            if extra.count == jokers {
                let v = plain(naturals + extra)
                if best == nil || best! < v { best = v }
                return
            }
            for r in 11...14 { tryRanks(extra + [r]) }
        }
        tryRanks([])
        return best!
    }

    private static func plain(_ ranks: [Int]) -> HandValue {
        var counts: [Int: Int] = [:]
        for r in ranks { counts[r, default: 0] += 1 }
        let groups = counts.sorted { ($0.value, $0.key) > ($1.value, $1.key) }
        let c = groups.map(\.value)
        let cat: Int
        if c.first ?? 0 >= 5 { cat = 6 }
        else if c.first == 4 { cat = 5 }
        else if c.first == 3 && c.count > 1 && c[1] >= 2 { cat = 4 }
        else if c.first == 3 { cat = 3 }
        else if c.first == 2 && c.count > 1 && c[1] == 2 { cat = 2 }
        else if c.first == 2 { cat = 1 }
        else { cat = 0 }
        return HandValue(category: cat, groups: groups.map(\.key))
    }

    /// Rough worth of an unfinished hand, for the computer players' choices.
    static func potential(_ cards: [PlayingCard]) -> Double {
        let v = evaluate(cards)
        var counts: [Int: Int] = [:]
        for c in cards where !c.isJoker { counts[c.rank, default: 0] += 1 }
        let squares = counts.values.reduce(0) { $0 + $1 * $1 }
        let jokers = cards.filter(\.isJoker).count
        return Double(v.category * 100 + squares * 10 + jokers * 25) + Double(v.groups.first ?? 0) * 0.1
    }
}

// MARK: - Helpers

func money(_ v: Int) -> String {
    v.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }

func ordinal(_ n: Int) -> String { ["first", "second", "third", "fourth", "fifth"][min(max(n - 1, 0), 4)] }
