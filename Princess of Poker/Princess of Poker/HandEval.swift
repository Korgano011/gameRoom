import Foundation

/// Video poker hand results, weakest to strongest. Which ones pay depends on the game.
enum VPHand: Int, CaseIterable, Comparable {
    case nothing, lowPair, highPair, twoPair, trips, straight, flush, fullHouse, quads,
         straightFlush, fiveKind, wildRoyal, fourDeuces, fiveWilds, royal

    static func < (a: VPHand, b: VPHand) -> Bool { a.rawValue < b.rawValue }
}

enum WildRules {
    /// No wild cards; a pair pays from `minPair` (11 = jacks) up.
    case natural(minPair: Int)
    /// The joker is wild; a pair pays from `minPair` (13 = kings) up.
    case joker(minPair: Int)
    case deuces
    case deucesJoker

    func isWild(_ c: Card) -> Bool {
        switch self {
        case .natural: false
        case .joker: c.isJoker
        case .deuces: c.rank == 2
        case .deucesJoker: c.isJoker || c.rank == 2
        }
    }

    var minPair: Int {
        switch self {
        case .natural(let m), .joker(let m): m
        default: 14   // deuces games: pair of aces
        }
    }
}

enum HandEval {
    /// Ranks a 5-card video poker hand under the game's wild-card rules.
    static func videoPoker(_ cards: [Card], _ rules: WildRules) -> VPHand {
        let w = cards.filter(rules.isWild).count
        let nat = cards.filter { !rules.isWild($0) }
        let ranks = nat.map(\.rank)
        var counts: [Int: Int] = [:]
        for r in ranks { counts[r, default: 0] += 1 }
        let shape = counts.values.sorted(by: >)
        let maxCount = shape.first ?? 0
        let sameSuit = Set(nat.map(\.suit)).count <= 1
        let distinct = Set(ranks).count == ranks.count
        let deuces = cards.filter { $0.rank == 2 }.count

        func fits(_ highs: [Int]) -> Bool {
            guard distinct else { return false }
            return highs.contains { high in
                let low = high - 4
                return ranks.allSatisfy { r in (low...high).contains(r) || (r == 14 && low == 1) }
            }
        }
        let royalShape = fits([14])
        let straight = fits(Array(5...14))

        if w == 0 && sameSuit && royalShape { return .royal }
        if case .deucesJoker = rules, w == 5 { return .fiveWilds }
        switch rules {
        case .deuces, .deucesJoker: if deuces == 4 { return .fourDeuces }
        default: break
        }
        if w > 0 && sameSuit && royalShape { return .wildRoyal }
        if w > 0 && maxCount + w >= 5 { return .fiveKind }
        if sameSuit && straight { return .straightFlush }
        if maxCount + w >= 4 { return .quads }
        if shape == [3, 2] || (w == 1 && shape == [2, 2]) { return .fullHouse }
        if sameSuit { return .flush }
        if straight { return .straight }
        if maxCount + w >= 3 { return .trips }
        if w == 0 && shape.starts(with: [2, 2]) { return .twoPair }
        if w == 0, let pair = counts.first(where: { $0.value == 2 })?.key, pair >= rules.minPair { return .highPair }
        if w == 1, let top = ranks.max(), top >= rules.minPair { return .highPair }
        return .nothing
    }

    // MARK: Texas Hold'em

    static let categoryNames = ["High Card", "Pair", "Two Pair", "Three of a Kind", "Straight",
                                "Flush", "Full House", "Four of a Kind", "Straight Flush"]

    /// A comparable score for exactly five cards (bigger wins).
    static func score5(_ c: [Card]) -> Int {
        var counts = [Int](repeating: 0, count: 15)
        for card in c { counts[card.rank] += 1 }
        let flush = c.allSatisfy { $0.suit == c[0].suit }
        let order = (2...14).filter { counts[$0] > 0 }.sorted {
            counts[$0] != counts[$1] ? counts[$0] > counts[$1] : $0 > $1
        }
        var straightHigh = 0
        if order.count == 5 {
            let hi = order.max()!, lo = order.min()!
            if hi - lo == 4 { straightHigh = hi }
            if Set(order) == [14, 2, 3, 4, 5] { straightHigh = 5 }
        }
        let category: Int
        var tiebreak = order
        if straightHigh > 0 && flush { category = 8; tiebreak = [straightHigh] }
        else if counts[order[0]] == 4 { category = 7 }
        else if counts[order[0]] == 3 && order.count == 2 { category = 6 }
        else if flush { category = 5 }
        else if straightHigh > 0 { category = 4; tiebreak = [straightHigh] }
        else if counts[order[0]] == 3 { category = 3 }
        else if counts[order[0]] == 2 && order.count == 3 { category = 2 }
        else if counts[order[0]] == 2 { category = 1 }
        else { category = 0 }
        var s = category
        for i in 0..<5 { s = s * 15 + (i < tiebreak.count ? tiebreak[i] : 0) }
        return s
    }

    /// The best five-card score out of up to seven cards.
    static func best(_ cards: [Card]) -> Int {
        let n = cards.count
        guard n >= 5 else { return 0 }
        var top = 0
        func pick(_ start: Int, _ chosen: inout [Card]) {
            if chosen.count == 5 { top = max(top, score5(chosen)); return }
            guard start < n, n - start >= 5 - chosen.count else { return }
            for i in start..<n {
                chosen.append(cards[i])
                pick(i + 1, &chosen)
                chosen.removeLast()
            }
        }
        var chosen: [Card] = []
        pick(0, &chosen)
        return top
    }

    /// Omaha: the best hand using exactly two hole cards and three board cards.
    static func bestOmaha(_ hole: [Card], _ board: [Card]) -> Int {
        guard hole.count >= 2, board.count >= 3 else { return 0 }
        var top = 0
        for a in 0..<hole.count { for b in (a + 1)..<hole.count {
            for i in 0..<board.count { for j in (i + 1)..<board.count { for k in (j + 1)..<board.count {
                top = max(top, score5([hole[a], hole[b], board[i], board[j], board[k]]))
            } } }
        } }
        return top
    }

    static func name(of score: Int) -> String {
        categoryNames[score / 759375]   // 15^5
    }
}
