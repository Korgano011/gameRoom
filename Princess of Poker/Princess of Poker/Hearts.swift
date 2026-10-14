import SwiftUI

/// A friendly game of Hearts at the salon's card table: you, the Princess and two newcomers.
/// Nobody bets — hearts is just for fun, so it makes the salon no money.
@Observable final class HeartsTable {
    struct Player: Identifiable {
        let id: Int
        var name: String
        /// Who she was before the salon's adjustment.
        var wasName: String
        var skin: Color
        var look: GirlLook
        var isHuman = false
        var isPrincess = false
        var isKid = false
        var hand: [Card] = []
        /// Points over the whole game (lowest wins).
        var score = 0
        /// Points taken in tricks this hand.
        var handPoints = 0
        var note = ""
    }

    /// The game ends when somebody reaches this many points.
    static let gameOver = 50

    /// Seated clockwise: 0 you (bottom), 1 left, 2 the Princess (top), 3 right.
    var players: [Player]
    var trick: [(seat: Int, card: Card)] = []
    var turn: Int?
    var handNumber = 0
    var message = "Shuffle up and deal!"
    var banner: String?
    var finished = false
    /// Passing three cards before the hand: true while you're choosing.
    var passing = false
    var selected: Set<Int> = []
    /// The cards passed to you this hand, highlighted until the first trick.
    var received: Set<Int> = []
    var passTarget: String?
    var trickWinner: Int?

    private(set) var heartsBroken = false
    private var firstTrick = true
    private var queenPlayed = false
    private var deck: [Card] = []
    private var playCont: CheckedContinuation<Card, Never>?
    private var passCont: CheckedContinuation<[Card], Never>?
    let sound: Sound
    let pace: Double
    var onFinished: (() -> Void)?

    init(players: [Player], sound: Sound, pace: Double) {
        self.players = players
        self.sound = sound
        self.pace = pace
    }

    var human: Player { players[0] }
    var humanToPlay: Bool { turn == 0 && playCont != nil }
    var legalForHuman: Set<Int> { humanToPlay ? Set(legal(0).map(\.id)) : [] }
    /// Lowest score so far — the leader (or, at the end, the winner).
    var leaders: [Int] {
        let low = players.map(\.score).min() ?? 0
        return players.indices.filter { players[$0].score == low }
    }

    // MARK: Flow

    func run() async {
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled {
            await playHand()
            if players.contains(where: { $0.score >= Self.gameOver }) { break }
        }
        turn = nil
        let w = leaders
        message = "Game over! " + w.map { players[$0].name }.joined(separator: " & ")
            + " win\(w.count == 1 ? "s" : "") with \(players[w[0]].score) points."
        sound.chime()
        finished = true
        try? await Task.sleep(for: .seconds(3.0))
        onFinished?()
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s / pace))
    }

    private func playHand() async {
        handNumber += 1
        heartsBroken = false
        firstTrick = true
        queenPlayed = false
        received = []
        trick = []
        trickWinner = nil
        deck = Deck.shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].handPoints = 0
            players[i].note = ""
        }
        message = "Hand \(handNumber). The Princess deals."
        for _ in 0..<13 {
            for i in players.indices { players[i].hand.append(deck.removeFirst()) }
            sound.card()
            await wait(0.07)
        }
        for i in players.indices { players[i].hand.sort(by: Self.handOrder) }

        // Pass left, right, across, then hold — and around again.
        let dir = [1, 3, 2, 0][(handNumber - 1) % 4]
        if dir != 0 {
            let to = players[dir].name
            passTarget = to
            message = "Lavender chooses three cards to pass to \(dir == 2 ? "the Princess" : to)."
            selected = []
            passing = true
            let mine = await withCheckedContinuation { passCont = $0 }
            passing = false
            passTarget = nil
            var passes = [[Card]](repeating: [], count: 4)
            passes[0] = mine
            for i in 1..<4 { passes[i] = choosePass(i) }
            for i in players.indices {
                let ids = Set(passes[i].map(\.id))
                players[i].hand.removeAll { ids.contains($0.id) }
            }
            for i in players.indices {
                players[(i + dir) % 4].hand += passes[i]
            }
            for i in players.indices { players[i].hand.sort(by: Self.handOrder) }
            received = Set(passes[(4 - dir) % 4].map(\.id))
            sound.card()
            message = "Cards passed. Lavender got " + passes[(4 - dir) % 4].map(\.text).joined(separator: " ") + "."
            await wait(1.6)
        }

        var leader = players.indices.first { players[$0].hand.contains { $0.rank == 2 && $0.suit == .clubs } } ?? 0
        for _ in 0..<13 {
            trick = []
            trickWinner = nil
            for k in 0..<4 {
                let i = (leader + k) % 4
                turn = i
                let card: Card
                if players[i].isHuman {
                    message = trick.isEmpty
                        ? (firstTrick ? "Lavender leads the 2♣." : "Lavender's lead.")
                        : "Lavender's turn — follow \(trick[0].card.suit.symbol) if she can."
                    card = await withCheckedContinuation { playCont = $0 }
                } else {
                    await wait(0.7)
                    card = choose(i)
                }
                play(i, card)
            }
            turn = nil
            received = []
            let led = trick[0].card.suit
            let w = trick.filter { $0.card.suit == led }.max { $0.card.rank < $1.card.rank }!.seat
            let pts = trick.reduce(0) { $0 + Self.points($1.card) }
            players[w].handPoints += pts
            trickWinner = w
            message = "\(players[w].name) takes the trick" + (pts > 0 ? " — \(pts) point\(pts == 1 ? "" : "s")." : ".")
            await wait(1.3)
            leader = w
            firstTrick = false
        }
        trick = []
        trickWinner = nil

        if let moon = players.indices.first(where: { players[$0].handPoints == 26 }) {
            for i in players.indices { players[i].score += i == moon ? 0 : 26 }
            banner = "\(players[moon].name) shot the moon! Everyone else takes 26 points."
            sound.chime()
        } else {
            for i in players.indices { players[i].score += players[i].handPoints }
            banner = "Hand \(handNumber): " + players.map { "\($0.name) +\($0.handPoints)" }.joined(separator: " · ")
        }
        await wait(2.8)
        banner = nil
    }

    private func play(_ i: Int, _ card: Card) {
        players[i].hand.removeAll { $0.id == card.id }
        trick.append((i, card))
        if card.suit == .hearts { heartsBroken = true }
        sound.card()
        if Self.isQueen(card) {
            queenPlayed = true
            sound.razz()
        }
    }

    func tap(_ card: Card) {
        if passing {
            if selected.contains(card.id) { selected.remove(card.id) } else if selected.count < 3 { selected.insert(card.id) }
            return
        }
        guard let c = playCont, legalForHuman.contains(card.id) else { return }
        playCont = nil
        c.resume(returning: card)
    }

    func confirmPass() {
        guard passing, selected.count == 3, let c = passCont else { return }
        passCont = nil
        c.resume(returning: human.hand.filter { selected.contains($0.id) })
        selected = []
    }

    /// Leaving mid-game: plays your first legal card (or passes your first three) so the game can wind down.
    func abandon() {
        if let c = passCont {
            passCont = nil
            c.resume(returning: Array(human.hand.prefix(3)))
        }
        if let c = playCont {
            playCont = nil
            c.resume(returning: legal(0)[0])
        }
    }

    // MARK: Rules

    static func points(_ c: Card) -> Int { c.suit == .hearts ? 1 : (isQueen(c) ? 13 : 0) }
    static func isQueen(_ c: Card) -> Bool { c.rank == 12 && c.suit == .spades }
    /// Sorted by suit (♣ ♦ ♠ ♥) then rank, the way you'd hold them.
    static func handOrder(_ a: Card, _ b: Card) -> Bool {
        let order: [Suit: Int] = [.clubs: 0, .diamonds: 1, .spades: 2, .hearts: 3]
        return order[a.suit]! != order[b.suit]! ? order[a.suit]! < order[b.suit]! : a.rank < b.rank
    }

    func legal(_ i: Int) -> [Card] {
        let hand = players[i].hand
        if trick.isEmpty {
            if firstTrick, let two = hand.first(where: { $0.rank == 2 && $0.suit == .clubs }) { return [two] }
            let nonHearts = hand.filter { $0.suit != .hearts }
            return heartsBroken || nonHearts.isEmpty ? hand : nonHearts
        }
        let follow = hand.filter { $0.suit == trick[0].card.suit }
        if !follow.isEmpty { return follow }
        // No points on the first trick unless that's all you have.
        if firstTrick {
            let safe = hand.filter { Self.points($0) == 0 }
            if !safe.isEmpty { return safe }
        }
        return hand
    }

    // MARK: Newcomer AI

    private func danger(_ c: Card) -> Int {
        if Self.isQueen(c) { return 100 }
        if c.suit == .spades && c.rank > 12 { return 90 + c.rank - 13 }
        return c.rank + (c.suit == .hearts ? 20 : 0)
    }

    private func choosePass(_ i: Int) -> [Card] {
        Array(players[i].hand.sorted { danger($0) > danger($1) }.prefix(3))
    }

    private func choose(_ i: Int) -> Card {
        let options = legal(i)
        if options.count == 1 { return options[0] }
        let high = { (cards: [Card]) in cards.max { $0.rank < $1.rank } }
        let low = { (cards: [Card]) in cards.min { $0.rank < $1.rank } }
        let notQueen = options.filter { !Self.isQueen($0) }

        if trick.isEmpty {
            // Lead low; stay away from the top spades while the queen is still out.
            let safe = notQueen.filter { !(queenPlayed == false && $0.suit == .spades && $0.rank > 12) }
            return low(safe.isEmpty ? options : safe)!
        }
        let led = trick[0].card.suit
        let winning = trick.filter { $0.card.suit == led }.map(\.card.rank).max()!
        let trickPoints = trick.reduce(0) { $0 + Self.points($1.card) }
        if options[0].suit == led {
            if trick.count == 3 && trickPoints == 0 && !(led == .spades && !queenPlayed) {
                return high(notQueen) ?? high(options)!
            }
            if let duck = high(options.filter { $0.rank < winning }) { return duck }
            return high(notQueen) ?? high(options)!
        }
        // Can't follow: dump the queen, then the top spades, then the highest heart, then the highest card.
        if let q = options.first(where: Self.isQueen) { return q }
        if !queenPlayed, let s = high(options.filter { $0.suit == .spades && $0.rank > 12 }) { return s }
        if let h = high(options.filter { $0.suit == .hearts }) { return h }
        return high(options)!
    }
}
