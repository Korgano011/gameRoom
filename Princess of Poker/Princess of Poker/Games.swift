import Foundation

struct PayRow: Identifiable {
    let hand: VPHand
    let name: String
    /// Credits paid per credit bet.
    let pays: Int
    /// What 5 credits pays, when it isn't simply 5 × `pays` (the royal's max-bet bonus).
    var maxPays: Int? = nil

    var id: VPHand { hand }

    func payout(bet: Int) -> Int {
        if bet == 5, let maxPays { return maxPays }
        return pays * bet
    }
}

/// The first nine games on the Princess of Poker's machine, in the order she plays them.
/// Games 1–4 are Double Down Stud (four cards up, double your bet before the fifth if you like — no draws);
/// games 5–9 are Pick'em (two cards, then pick one of two three-card piles).
enum VPGame: Int, CaseIterable, Codable {
    case jacks, joker, deuces, sneaky, pickJacks, pickJoker, pickDeuces, pickDeucesJoker, pickSneaky

    var number: Int { rawValue + 1 }

    var title: String {
        switch self {
        case .jacks: "Double Down Stud"
        case .joker: "Joker Poker"
        case .deuces: "Deuces Wild"
        case .sneaky: "Sneaky Queens"
        case .pickJacks: "Pick'em Nines or Better"
        case .pickJoker: "Pick'em Joker Poker"
        case .pickDeuces: "Pick'em Deuces Wild"
        case .pickDeucesJoker: "Pick'em Deuces Joker Wild"
        case .pickSneaky: "Pick'em Sneaky Queens"
        }
    }

    var pickEm: Bool { rawValue >= VPGame.pickJacks.rawValue }
    var doubleDown: Bool { !pickEm }

    var sneakyQueens: Bool { self == .sneaky || self == .pickSneaky }

    var rules: WildRules {
        switch self {
        case .jacks: .natural(minPair: 11)
        case .sneaky: .natural(minPair: 12)
        case .joker: .joker(minPair: 8)
        case .pickSneaky: .natural(minPair: 10)
        case .pickJacks: .natural(minPair: 9)
        case .pickJoker: .joker(minPair: 11)
        case .deuces, .pickDeuces: .deuces
        case .pickDeucesJoker: .deucesJoker
        }
    }

    var usesJoker: Bool {
        switch rules {
        case .joker, .deucesJoker: true
        default: false
        }
    }

    func isWild(_ c: Card) -> Bool { rules.isWild(c) }

    /// Double Down Jacks or Better also pays even money (a push) on a pair of 6s through 10s;
    /// Double Down Sneaky Queens does the same on a pair of 8s through jacks.
    func evaluate(_ cards: [Card]) -> VPHand {
        let h = HandEval.videoPoker(cards, rules)
        let lowPairs: ClosedRange<Int>? = switch self {
        case .jacks: 6...10
        case .sneaky: 8...11
        default: nil
        }
        if h == .nothing, let lowPairs {
            let counts = Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
            if counts.contains(where: { $0.value == 2 && lowPairs.contains($0.key) }) { return .lowPair }
        }
        return h
    }

    /// Double Down Stud pays on your whole bet, doubled or not (1 = your bet back).
    /// Pick'em tables pay more because you only choose between two piles instead of drawing.
    /// The pick'em tables (except Sneaky Queens) come from the revised paytables in the claude folder.
    var paytable: [PayRow] {
        switch self {
        case .jacks:
            [PayRow(hand: .royal, name: "Royal Flush", pays: 2000),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 200),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 50),
             PayRow(hand: .fullHouse, name: "Full House", pays: 12),
             PayRow(hand: .flush, name: "Flush", pays: 9),
             PayRow(hand: .straight, name: "Straight", pays: 8),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 4),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 3),
             PayRow(hand: .highPair, name: "Jacks or Better", pays: 2),
             PayRow(hand: .lowPair, name: "6s through 10s", pays: 1)]
        case .sneaky:
            [PayRow(hand: .royal, name: "Royal Flush", pays: 2000),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 200),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 50),
             PayRow(hand: .fullHouse, name: "Full House", pays: 12),
             PayRow(hand: .flush, name: "Flush", pays: 9),
             PayRow(hand: .straight, name: "Straight", pays: 8),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 5),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 3),
             PayRow(hand: .highPair, name: "Queens or Better", pays: 2),
             PayRow(hand: .lowPair, name: "8s through Jacks", pays: 1)]
        case .joker:
            [PayRow(hand: .royal, name: "Natural Royal", pays: 2000),
             PayRow(hand: .fiveKind, name: "5 of a Kind", pays: 400),
             PayRow(hand: .wildRoyal, name: "Wild Royal", pays: 200),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 100),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 30),
             PayRow(hand: .fullHouse, name: "Full House", pays: 12),
             PayRow(hand: .flush, name: "Flush", pays: 8),
             PayRow(hand: .straight, name: "Straight", pays: 6),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 4),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 3),
             PayRow(hand: .highPair, name: "8s or Better", pays: 1)]
        case .deuces:
            [PayRow(hand: .royal, name: "Natural Royal", pays: 2000),
             PayRow(hand: .fourDeuces, name: "4 Deuces", pays: 400),
             PayRow(hand: .wildRoyal, name: "Wild Royal", pays: 100),
             PayRow(hand: .fiveKind, name: "5 of a Kind", pays: 40),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 25),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 8),
             PayRow(hand: .fullHouse, name: "Full House", pays: 6),
             PayRow(hand: .flush, name: "Flush", pays: 4),
             PayRow(hand: .straight, name: "Straight", pays: 4),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 2),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 1),
             PayRow(hand: .highPair, name: "Pair of Aces", pays: 1)]
        case .pickJacks:
            [PayRow(hand: .royal, name: "Royal Flush", pays: 1000, maxPays: 6000),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 200),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 100),
             PayRow(hand: .fullHouse, name: "Full House", pays: 18),
             PayRow(hand: .flush, name: "Flush", pays: 15),
             PayRow(hand: .straight, name: "Straight", pays: 11),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 5),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 3),
             PayRow(hand: .highPair, name: "9s or Better", pays: 2)]
        case .pickSneaky:
            [PayRow(hand: .royal, name: "Royal Flush", pays: 1000, maxPays: 6000),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 200),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 100),
             PayRow(hand: .fullHouse, name: "Full House", pays: 20),
             PayRow(hand: .flush, name: "Flush", pays: 15),
             PayRow(hand: .straight, name: "Straight", pays: 10),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 5),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 3),
             PayRow(hand: .highPair, name: "10s or Better", pays: 2)]
        case .pickJoker:
            [PayRow(hand: .royal, name: "Natural Royal", pays: 1000, maxPays: 6000),
             PayRow(hand: .fiveKind, name: "5 of a Kind", pays: 200, maxPays: 2000),
             PayRow(hand: .wildRoyal, name: "Wild Royal", pays: 200),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 100),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 50),
             PayRow(hand: .fullHouse, name: "Full House", pays: 10),
             PayRow(hand: .flush, name: "Flush", pays: 7),
             PayRow(hand: .straight, name: "Straight", pays: 5),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 4),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 3),
             PayRow(hand: .highPair, name: "Jacks or Better", pays: 2)]
        case .pickDeuces:
            [PayRow(hand: .royal, name: "Natural Royal", pays: 1000, maxPays: 6000),
             PayRow(hand: .fourDeuces, name: "4 Deuces", pays: 500),
             PayRow(hand: .wildRoyal, name: "Wild Royal", pays: 50),
             PayRow(hand: .fiveKind, name: "5 of a Kind", pays: 20),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 15),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 10),
             PayRow(hand: .fullHouse, name: "Full House", pays: 7),
             PayRow(hand: .flush, name: "Flush", pays: 5),
             PayRow(hand: .straight, name: "Straight", pays: 4),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 3),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 2),
             PayRow(hand: .highPair, name: "Pair of Aces", pays: 1)]
        case .pickDeucesJoker:
            [PayRow(hand: .fiveWilds, name: "4 Deuces + Joker", pays: 5000),
             PayRow(hand: .royal, name: "Natural Royal", pays: 1000, maxPays: 5000),
             PayRow(hand: .fourDeuces, name: "4 Deuces", pays: 100),
             PayRow(hand: .wildRoyal, name: "Wild Royal", pays: 20),
             PayRow(hand: .fiveKind, name: "5 of a Kind", pays: 15),
             PayRow(hand: .straightFlush, name: "Straight Flush", pays: 10),
             PayRow(hand: .quads, name: "4 of a Kind", pays: 4),
             PayRow(hand: .fullHouse, name: "Full House", pays: 4),
             PayRow(hand: .flush, name: "Flush", pays: 4),
             PayRow(hand: .straight, name: "Straight", pays: 3),
             PayRow(hand: .trips, name: "3 of a Kind", pays: 2),
             PayRow(hand: .twoPair, name: "Two Pair", pays: 1),
             PayRow(hand: .highPair, name: "Pair of Aces", pays: 1)]
        }
    }

    func row(for hand: VPHand) -> PayRow? { paytable.first { $0.hand == hand } }
}
