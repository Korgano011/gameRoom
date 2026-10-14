import SwiftUI

/// One choice in an auction: what the button says and what it means.
struct BidOption: Hashable {
    let label: String
    let value: Int
}

/// Spades, Pepper, Domino Hearts and Call It Right at the salon's card table, just for fun — nobody bets.
/// Four-handed: you (bottom), a newcomer on the left, the Princess across, a newcomer on the right.
/// In Spades and Pepper you and the Princess are partners; Domino Hearts and Call It Right are everyone for herself.
@Observable final class TrickTable {
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
        var tricks = 0
        var bid: Int?
        var note = ""
        /// Domino Hearts: hearts taken over the whole game (lowest wins). Call It Right: points (highest wins).
        var score = 0
        /// Cards won in tricks this hand.
        var taken: [Card] = []
        /// Domino Hearts: out of cards with the stock empty — out of this hand.
        var out = false
    }

    /// What the table is waiting on you for.
    enum Ask: Equatable {
        case none, play, bid([BidOption]), suit
    }

    let game: HoldemTable.Game
    var players: [Player]
    /// Partnership games: team 0 is you and the Princess (seats 0 and 2), team 1 the newcomers (1 and 3).
    var teamScore = [0, 0]
    var teamBags = [0, 0]
    var trick: [(seat: Int, card: Card)] = []
    var trickWinner: Int?
    var turn: Int?
    var dealer = 3
    var trump: Suit?
    /// Call It Right: the card turned up after the deal — its suit is trumps.
    var upCard: Card?
    /// The auction's winner and what she's playing for, in words.
    var contract: String?
    var maker: Int?
    var stock: [Card] = []
    var spadesBroken = false
    var handNumber = 0
    var message = "Shuffle up and deal!"
    var banner: String?
    var finished = false
    var winnerText = ""

    var ask = Ask.none
    private var cont: CheckedContinuation<Int, Never>?

    let sound: Sound
    let pace: Double
    var onFinished: (() -> Void)?

    init(game: HoldemTable.Game, players: [Player], sound: Sound, pace: Double) {
        self.game = game
        self.players = players
        self.sound = sound
        self.pace = pace
        dealer = Int.random(in: 0..<4)
    }

    var human: Player { players[0] }
    var partnerships: Bool { game != .dominoHearts && game != .callItRight }
    func team(_ seat: Int) -> Int { seat % 2 }
    var teamNames: [String] { ["Lavender & Princess", "\(players[1].name) & \(players[3].name)"] }

    var target: Int {
        switch game {
        case .spades: 200
        case .pepper: 30
        case .callItRight: 50
        default: 31
        }
    }

    var goalText: String {
        switch game {
        case .dominoHearts: "Lowest wins · game ends at 31"
        case .callItRight: "Make your call exactly · first to 50"
        default: "First to \(target)"
        }
    }

    var humanToPlay: Bool { ask == .play && cont != nil }
    var legalForHuman: Set<Int> { humanToPlay ? Set(legal(0).map(\.id)) : [] }
    /// Domino Hearts: lowest score so far; Call It Right: highest — the leader (or, at the end, the winner).
    var leaders: [Int] {
        let scores = players.map(\.score)
        let best = (game == .callItRight ? scores.max() : scores.min()) ?? 0
        return players.indices.filter { players[$0].score == best }
    }

    // MARK: Your answers

    func tap(_ card: Card) {
        guard humanToPlay, legalForHuman.contains(card.id) else { return }
        answer(card.id)
    }

    func answer(_ value: Int) {
        guard let c = cont else { return }
        cont = nil
        ask = .none
        c.resume(returning: value)
    }

    /// Leaving mid-game: answers whatever is pending with a safe default so the game can wind down.
    func abandon() {
        switch ask {
        case .play: answer(legal(0).first?.id ?? 0)
        case .bid(let options): answer(options.first?.value ?? 0)
        case .suit: answer(Suit.spades.rawValue)
        case .none: break
        }
    }

    private func ask(_ a: Ask, _ text: String) async -> Int {
        message = text
        ask = a
        return await withCheckedContinuation { cont = $0 }
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s / pace))
    }

    // MARK: Cards and trumps

    /// Pepper is played with the 24-card euchre deck (9s up); the others use all 52.
    private func deck() -> [Card] {
        game == .pepper ? Deck.shuffled().filter { $0.rank >= 9 } : Deck.shuffled()
    }

    private var bowers: Bool { game == .pepper }

    private func isRightBower(_ c: Card) -> Bool { bowers && trump != nil && c.rank == 11 && c.suit == trump }
    private func isLeftBower(_ c: Card) -> Bool {
        guard bowers, let t = trump, c.rank == 11 else { return false }
        return c.suit != t && c.suit.isRed == t.isRed
    }

    /// The suit a card counts as: in Pepper the left bower is a trump.
    func suitOf(_ c: Card) -> Suit { isLeftBower(c) ? trump! : c.suit }

    private func isTrump(_ c: Card) -> Bool { trump != nil && suitOf(c) == trump }

    /// Rank within its suit, with the bowers on top.
    private func strength(_ c: Card) -> Int {
        if isRightBower(c) { return 31 }
        if isLeftBower(c) { return 30 }
        return c.rank
    }

    /// Who's winning a trick so far.
    private func winning(_ t: [(seat: Int, card: Card)]) -> Int {
        let led = suitOf(t[0].card)
        func power(_ c: Card) -> Int {
            if isTrump(c) { return 500 + strength(c) }
            if suitOf(c) == led { return 100 + strength(c) }
            return 0
        }
        return t.max { power($0.card) < power($1.card) }!.seat
    }

    func legal(_ i: Int) -> [Card] {
        let hand = players[i].hand
        guard !hand.isEmpty else { return [] }
        if trick.isEmpty {
            if game == .spades && !spadesBroken {
                let other = hand.filter { $0.suit != .spades }
                if !other.isEmpty { return other }
            }
            return hand
        }
        let led = suitOf(trick[0].card)
        let follow = hand.filter { suitOf($0) == led }
        return follow.isEmpty ? hand : follow
    }

    private func sortHand(_ i: Int) {
        let order: [Suit: Int] = [.clubs: 0, .diamonds: 1, .spades: 2, .hearts: 3]
        players[i].hand.sort { a, b in
            let ta = isTrump(a) ? 10 : 0, tb = isTrump(b) ? 10 : 0
            return (ta + order[suitOf(a)]!, strength(a)) < (tb + order[suitOf(b)]!, strength(b))
        }
    }

    // MARK: Flow

    func run() async {
        await wait(1.2)
        sound.speak("\(game.name), girls! Just for fun. Let's begin.", as: .princess)
        while !Task.isCancelled {
            handNumber += 1
            await playHand()
            if Task.isCancelled { return }
            if gameOver() { break }
            dealer = (dealer + 1) % 4
        }
        turn = nil
        trick = []
        message = "Game over! " + winnerText
        sound.chime()
        finished = true
        try? await Task.sleep(for: .seconds(3.0))
        onFinished?()
    }

    private func gameOver() -> Bool {
        if partnerships {
            let over = teamScore.contains { $0 >= target } || (game == .spades && handNumber >= 10)
            if over {
                let w = teamScore[0] >= teamScore[1] ? 0 : 1
                winnerText = "\(teamNames[w]) win, \(teamScore[w]) to \(teamScore[1 - w])."
            }
            return over
        }
        guard players.contains(where: { $0.score >= target }) else { return false }
        let w = leaders
        winnerText = w.map { players[$0].name }.joined(separator: " & ") + " win\(w.count == 1 ? "s" : "") with \(players[w[0]].score) points."
        return true
    }

    private func deal(_ count: Int, from d: inout [Card]) async {
        for _ in 0..<count {
            for k in 1...4 {
                let i = (dealer + k) % 4
                players[i].hand.append(d.removeFirst())
            }
            sound.card()
            await wait(0.06)
        }
        for i in players.indices { sortHand(i) }
    }

    private func playHand() async {
        trump = nil
        upCard = nil
        contract = nil
        maker = nil
        stock = []
        spadesBroken = false
        trick = []
        trickWinner = nil
        for i in players.indices {
            players[i].hand = []
            players[i].tricks = 0
            players[i].bid = nil
            players[i].note = ""
            players[i].taken = []
            players[i].out = false
        }
        var d = deck()
        message = "Hand \(handNumber). \(players[dealer].name) deals."
        var leader = (dealer + 1) % 4

        switch game {
        case .spades:
            trump = .spades
            await deal(13, from: &d)
            await spadesBidding()
        case .pepper:
            await deal(6, from: &d)
            guard let m = await pepperBidding() else { return }
            leader = m
        case .callItRight:
            await deal(5, from: &d)
            await callItRightBidding(from: &d)
        default:
            await deal(6, from: &d)
            stock = d
            contract = "Domino Hearts · \(stock.count) in the stock"
        }
        if Task.isCancelled { return }
        for i in players.indices { sortHand(i) }
        await playTricks(leader: leader)
        if Task.isCancelled { return }
        scoreHand()
        await wait(3.2)
        banner = nil
    }

    private func playTricks(leader first: Int) async {
        var leader = first
        while !Task.isCancelled {
            let active = (0..<4).map { (leader + $0) % 4 }.filter { !players[$0].out }
            if game == .dominoHearts {
                if active.count <= 1 { break }
            } else if players[leader].hand.isEmpty {
                break
            }
            trick = []
            trickWinner = nil
            for i in active {
                turn = i
                if game == .dominoHearts {
                    if players[i].hand.isEmpty {
                        if stock.isEmpty { continue }
                        players[i].hand.append(stock.removeFirst())
                        sound.card()
                    }
                    await drawToFollow(i)
                }
                let card: Card
                if players[i].isHuman {
                    let options = legal(0)
                    let lead = trick.isEmpty
                    let id = await ask(.play, lead ? "Lavender's lead." : "Lavender's turn — follow \(suitOf(trick[0].card).symbol) if she can.")
                    card = human.hand.first { $0.id == id } ?? options[0]
                } else {
                    await wait(0.7)
                    card = choose(i)
                }
                play(i, card)
            }
            turn = nil
            guard !trick.isEmpty else { break }
            let w = winning(trick)
            trickWinner = w
            players[w].tricks += 1
            players[w].taken += trick.map(\.card)
            let hearts = trick.filter { $0.card.suit == .hearts }.count
            message = "\(players[w].name) takes the trick" + (game == .dominoHearts && hearts > 0 ? " — \(hearts) heart\(hearts == 1 ? "" : "s")." : ".")
            await wait(1.3)
            leader = w
            if game == .dominoHearts {
                for i in players.indices where players[i].hand.isEmpty && stock.isEmpty { players[i].out = true }
                contract = "Domino Hearts · \(stock.count) in the stock"
                // The last one holding cards takes her own hearts.
                let left = players.indices.filter { !players[$0].out }
                if left.count == 1 {
                    let i = left[0]
                    players[i].taken += players[i].hand
                    players[i].hand = []
                    players[i].out = true
                    break
                }
                if players[leader].out {
                    leader = (1...4).map { (w + $0) % 4 }.first { !players[$0].out } ?? w
                }
            }
        }
        trick = []
        trickWinner = nil
    }

    private func play(_ i: Int, _ card: Card) {
        players[i].hand.removeAll { $0.id == card.id }
        trick.append((i, card))
        if card.suit == .spades { spadesBroken = true }
        sound.card()
    }

    /// Domino Hearts: can't follow suit? Draw from the stock until you can (or it runs out).
    private func drawToFollow(_ i: Int) async {
        guard let first = trick.first else { return }
        let led = suitOf(first.card)
        var drew = 0
        while !stock.isEmpty && !players[i].hand.contains(where: { suitOf($0) == led }) {
            players[i].hand.append(stock.removeFirst())
            drew += 1
            sound.card()
            message = "\(players[i].name) can't follow \(led.symbol) — drawing from the stock (\(drew))…"
            await wait(0.35)
        }
        if drew > 0 {
            sortHand(i)
            players[i].note = "Drew \(drew)"
            contract = "Domino Hearts · \(stock.count) in the stock"
        }
    }

    // MARK: Scoring

    private func scoreHand() {
        switch game {
        case .spades:
            var lines: [String] = []
            for t in 0..<2 {
                var pts = 0
                var bid = 0, tricks = 0
                for s in [t, t + 2] {
                    if players[s].bid == 0 {
                        pts += players[s].tricks == 0 ? 100 : -100
                        teamBags[t] += players[s].tricks
                    } else {
                        bid += players[s].bid ?? 0
                        tricks += players[s].tricks
                    }
                }
                if bid > 0 {
                    if tricks >= bid {
                        pts += bid * 10 + (tricks - bid)
                        teamBags[t] += tricks - bid
                    } else {
                        pts -= bid * 10
                    }
                }
                if teamBags[t] >= 10 {
                    teamBags[t] -= 10
                    pts -= 100
                }
                teamScore[t] += pts
                lines.append("\(teamNames[t]) \(pts >= 0 ? "+" : "")\(pts)")
            }
            banner = "Hand \(handNumber): " + lines.joined(separator: " · ")
        case .pepper:
            guard let m = maker, let bid = players[m].bid else { return }
            let t = team(m)
            let tricks = players[t].tricks + players[t + 2].tricks
            let made = tricks >= bid
            teamScore[t] += made ? (bid == 6 ? 12 : tricks) : -(bid == 6 ? 12 : bid)
            teamScore[1 - t] += 6 - tricks
            banner = "\(teamNames[t]) \(made ? "made" : "went set on") \(bid == 6 ? "Pepper" : "\(bid)") · \(teamNames[0]) \(teamScore[0]) · \(teamNames[1]) \(teamScore[1])"
            if made { sound.chime() }
        case .callItRight:
            for i in players.indices {
                let bid = players[i].bid ?? 0
                let pts = callItRightPoints(bid: bid, tricks: players[i].tricks)
                players[i].score += pts
                players[i].note = pts > 0 ? "Made it! +\(pts)" : "Missed \(bid)"
            }
            if callItRightPoints(bid: human.bid ?? 0, tricks: human.tricks) > 0 { sound.chime() }
            banner = "Hand \(handNumber): " + players.map { "\($0.name) \($0.score)" }.joined(separator: " · ")
        default:
            for i in players.indices {
                let pts = players[i].taken.filter { $0.suit == .hearts }.count
                players[i].score += pts
                players[i].note = pts > 0 ? "+\(pts)♥" : ""
            }
            banner = "Hand \(handNumber): " + players.map { "\($0.name) \($0.score)" }.joined(separator: " · ")
        }
    }

    // MARK: Call It Right

    /// Exactly your call scores 10 plus the call (a nil call that takes nothing scores 10); anything else scores zero.
    func callItRightPoints(bid: Int, tricks: Int) -> Int { tricks == bid ? 10 + bid : 0 }

    /// Turn up the next card for trumps, then everyone calls 0 to 5 tricks, starting at the dealer's left.
    private func callItRightBidding(from d: inout [Card]) async {
        let up = d.removeFirst()
        upCard = up
        trump = up.suit
        for i in players.indices { sortHand(i) }
        contract = "Trumps: \(up.suit.symbol)"
        message = "\(players[dealer].name) turns up the \(up.text) — \(up.suit.symbol) are trumps."
        sound.card()
        await wait(1.2)
        for k in 1...4 {
            let i = (dealer + k) % 4
            turn = i
            let bid: Int
            if players[i].isHuman {
                let options = [BidOption(label: "Nil", value: 0)] + (1...5).map { BidOption(label: "\($0)", value: $0) }
                let called = players.indices.compactMap { players[$0].bid }.reduce(0, +)
                bid = await ask(.bid(options), "Lavender's call — how many of the 5 tricks will she take? (Called so far: \(called))")
            } else {
                await wait(0.7)
                bid = min(5, max(0, Int(estimate(i, trump: up.suit).rounded())))
            }
            players[i].bid = bid
            players[i].note = bid == 0 ? "Nil" : "Call \(bid)"
            message = "\(players[i].name) calls \(bid == 0 ? "nil" : "\(bid)")."
            sound.card()
        }
        turn = nil
        let total = players.compactMap(\.bid).reduce(0, +)
        contract = "Trumps: \(up.suit.symbol) · \(total) called for 5"
    }

    // MARK: Spades

    private func spadesBidding() async {
        for k in 1...4 {
            let i = (dealer + k) % 4
            turn = i
            let bid: Int
            if players[i].isHuman {
                let options = [BidOption(label: "Nil", value: 0)] + (1...13).map { BidOption(label: "\($0)", value: $0) }
                bid = await ask(.bid(options), "Lavender's bid — how many tricks will she take? (Partner bid: \(players[2].bid.map(String.init) ?? "–"))")
            } else {
                await wait(0.7)
                let est = estimate(i, trump: .spades)
                bid = est < 0.6 && players[i].hand.filter({ $0.suit == .spades && $0.rank >= 12 }).isEmpty ? 0 : max(1, Int(est.rounded()))
            }
            players[i].bid = bid
            players[i].note = bid == 0 ? "Nil" : "Bid \(bid)"
            message = "\(players[i].name) bids \(bid == 0 ? "nil" : "\(bid)")."
            sound.card()
        }
        turn = nil
        contract = "Spades are trumps"
    }

    // MARK: Pepper

    /// Bids of 3 to 6 tricks (6 is "Pepper"); the dealer is stuck with 3 if everyone passes. Returns the high bidder.
    private func pepperBidding() async -> Int? {
        var high = 2, who: Int?
        for k in 1...4 {
            let i = (dealer + k) % 4
            turn = i
            let stuck = k == 4 && who == nil
            var bid = 0
            if players[i].isHuman {
                let lowest = max(3, high + 1)
                var options = lowest <= 6 ? (lowest...6).map { BidOption(label: $0 == 6 ? "Pepper (6)" : "\($0)", value: $0) } : []
                if !stuck { options.insert(BidOption(label: "Pass", value: 0), at: 0) }
                if options.count > 1 || stuck {
                    bid = await ask(.bid(options), stuck ? "Everyone passed — the dealer is stuck. Lavender's bid?"
                                                         : "Lavender's bid — how many of the 6 tricks? (High bid: \(who == nil ? "none" : "\(high)"))")
                }
            } else {
                await wait(0.7)
                let est = Int(bestSuit(i).1.rounded())
                bid = est > high && est >= 3 ? min(6, est) : (stuck ? 3 : 0)
            }
            if bid > high {
                high = bid
                who = i
                players[i].bid = bid
                players[i].note = bid == 6 ? "Pepper!" : "Bid \(bid)"
                message = "\(players[i].name) bids \(bid == 6 ? "Pepper" : "\(bid)")."
            } else {
                players[i].note = "Pass"
                message = "\(players[i].name) passes."
            }
            sound.card()
        }
        guard let m = who else { return nil }
        maker = m
        turn = m
        let suit: Suit
        if players[m].isHuman {
            suit = Suit(rawValue: await ask(.suit, "Lavender won the bid with \(high == 6 ? "Pepper" : "\(high)"). Name trumps."))!
        } else {
            await wait(0.6)
            suit = bestSuit(m).0
        }
        trump = suit
        contract = "\(players[m].name) bid \(high == 6 ? "Pepper" : "\(high)") · Trumps: \(suit.symbol)"
        message = "\(players[m].name) names \(suit.symbol) trumps."
        turn = nil
        return m
    }

    // MARK: Newcomer AI

    /// Roughly how many tricks a hand should take with these trumps.
    private func estimate(_ i: Int, trump t: Suit) -> Double {
        let hand = players[i].hand
        var e = 0.0
        for c in hand {
            if c.suit == t || (bowers && c.rank == 11 && c.suit.isRed == t.isRed) {
                if bowers && c.rank == 11 { e += 1; continue }
                e += c.rank >= 13 ? 0.9 : (c.rank >= 11 ? 0.6 : 0.35)
            } else {
                let suitCount = hand.filter { $0.suit == c.suit }.count
                if c.rank == 14 { e += suitCount <= 4 ? 0.9 : 0.6 }
                else if c.rank == 13 && suitCount >= 2 { e += 0.5 }
            }
        }
        if game != .spades {
            let voids = Suit.allCases.filter { s in s != t && !hand.contains { $0.suit == s } }.count
            e += Double(voids) * 0.3 * Double(hand.filter { $0.suit == t }.count > 1 ? 1 : 0)
        }
        return e
    }

    private func bestSuit(_ i: Int) -> (Suit, Double) {
        let saved = trump
        defer { trump = saved }
        return Suit.allCases.map { s -> (Suit, Double) in
            trump = s
            return (s, estimate(i, trump: s))
        }.max { $0.1 < $1.1 }!
    }

    /// Does this player want to win tricks? (Nil bidders, made Spades bids and Domino Hearts all duck.)
    private func wantsTricks(_ i: Int) -> Bool {
        switch game {
        case .dominoHearts: return false
        case .callItRight: return players[i].tricks < (players[i].bid ?? 0)
        case .spades:
            if players[i].bid == 0 { return false }
            let t = team(i)
            let bid = [t, t + 2].reduce(0) { $0 + (players[$1].bid ?? 0) }
            return players[t].tricks + players[t + 2].tricks < bid
        default:
            return true
        }
    }

    private func choose(_ i: Int) -> Card {
        let options = legal(i)
        if options.count == 1 { return options[0] }
        let rank = { (c: Card) in (self.isTrump(c) ? 100 : 0) + self.strength(c) }
        let low = { (cards: [Card]) in cards.min { rank($0) < rank($1) }! }
        let high = { (cards: [Card]) in cards.max { rank($0) < rank($1) }! }
        let want = wantsTricks(i)

        if trick.isEmpty {
            if !want {
                // Lead low, and (in Domino Hearts) keep hearts out of it.
                let safe = options.filter { game != .dominoHearts || $0.suit != .hearts }
                return low(safe.isEmpty ? options : safe)
            }
            // Cash a top card, or lead low from a side suit.
            if let ace = options.first(where: { !isTrump($0) && $0.rank == 14 }) { return ace }
            if let top = options.filter(isTrump).max(by: { strength($0) < strength($1) }), strength(top) >= 30 { return top }
            let side = options.filter { !isTrump($0) }
            return low(side.isEmpty ? options : side)
        }

        let current = winning(trick)
        let partnerWinning = partnerships && team(current) == team(i) && current != i
        let winners = options.filter { c in winning(trick + [(i, c)]) == i }
        if !want {
            // Duck: the highest card that still loses, otherwise dump hearts and big cards.
            let losers = options.filter { c in winning(trick + [(i, c)]) != i }
            if !losers.isEmpty {
                if game == .dominoHearts, let h = losers.filter({ $0.suit == .hearts }).max(by: { $0.rank < $1.rank }) { return h }
                return high(losers)
            }
            return low(options)
        }
        if partnerWinning || winners.isEmpty { return low(options) }
        return low(winners)
    }
}

// MARK: - View

struct TrickView: View {
    @Bindable var table: TrickTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color

    /// Where each seat sits around the table (fractions of the table area), clockwise from you.
    private let spots: [CGPoint] = [CGPoint(x: 0.5, y: 0.88), CGPoint(x: 0.13, y: 0.47), CGPoint(x: 0.5, y: 0.12), CGPoint(x: 0.87, y: 0.47)]
    /// Where each seat's card lands in the trick, toward that seat.
    private let trickSpots: [CGPoint] = [CGPoint(x: 0.5, y: 0.6), CGPoint(x: 0.36, y: 0.47), CGPoint(x: 0.5, y: 0.34), CGPoint(x: 0.64, y: 0.47)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · \(table.game.name) · Hand \(table.handNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text("Just for fun")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.pink)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            scoreboard
                .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    CasinoFelt(felt: felt, size: size)

                    if let c = table.contract {
                        Text(c)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: size.width * 0.5)
                            .position(x: size.width * 0.5, y: size.height * 0.24)
                    }

                    if let up = table.upCard {
                        VStack(spacing: 2) {
                            CardView(card: up, width: 34)
                            Text("Trumps")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        .position(x: size.width * 0.84, y: size.height * 0.14)
                    }

                    ForEach(table.trick, id: \.card.id) { play in
                        let p = trickSpots[play.seat]
                        CardView(card: play.card, width: min(50, size.width * 0.12))
                            .overlay {
                                if table.trickWinner == play.seat {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(Color.yellow, lineWidth: 3)
                                }
                            }
                            .position(x: size.width * p.x, y: size.height * p.y)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Text(table.message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: size.width * 0.5)
                        .position(x: size.width * 0.5, y: size.height * 0.74)

                    ForEach(Array(table.players.enumerated()), id: \.offset) { i, player in
                        TrickSeat(player: player, label: label(i), isTurn: table.turn == i, detail: detail(i))
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: table.trick.count)
            }
            .frame(minHeight: 360)

            if let banner = table.banner {
                CasinoBanner(text: banner)
            }

            yourHand
                .padding(.horizontal, 8)

            actionBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), Color(red: 0.08, green: 0.0, blue: 0.1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.default, value: table.banner)
    }

    private func label(_ i: Int) -> String {
        let p = table.players[i]
        if p.isPrincess { return table.partnerships ? "Princess · partner" : "Princess" }
        return p.isHuman ? "Lavender" : p.name
    }

    private func detail(_ i: Int) -> String {
        let p = table.players[i]
        if table.game == .dominoHearts {
            let h = p.taken.filter { $0.suit == .hearts }.count
            return "\(p.score) pts" + (h > 0 ? " · +\(h)♥" : "")
        }
        if table.game == .callItRight {
            return "\(p.score) pts" + (p.bid.map { " · \(p.tricks)/\($0)" } ?? "")
        }
        return p.tricks > 0 || p.bid != nil ? "\(p.tricks) trick\(p.tricks == 1 ? "" : "s")" : ""
    }

    private var scoreboard: some View {
        HStack(spacing: 10) {
            if table.partnerships {
                ForEach(0..<2, id: \.self) { t in
                    VStack(spacing: 0) {
                        Text(table.teamNames[t]).font(.system(size: 11, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                        Text("\(table.teamScore[t])" + (table.game == .spades ? " · \(table.teamBags[t]) bags" : ""))
                            .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(t == 0 ? Color.pink : .orange)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(table.goalText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
                .frame(maxWidth: table.partnerships ? 110 : .infinity)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Your cards in a fan: tap to play. Cards you can't play are dimmed.
    private var yourHand: some View {
        GeometryReader { geo in
            let hand = table.human.hand
            let w = 50.0
            let step = hand.count > 1 ? min(w + 2, (geo.size.width - w) / Double(hand.count - 1)) : 0
            let legal = table.legalForHuman
            HStack(spacing: step - w) {
                ForEach(hand) { card in
                    Button { table.tap(card) } label: {
                        CardView(card: card, dim: table.humanToPlay && !legal.contains(card.id), width: w)
                    }
                    .buttonStyle(.plain)
                    .offset(y: table.humanToPlay && legal.contains(card.id) ? -12 : 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 86)
    }

    private func waiting(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
        }
        .frame(minHeight: 46)
    }

    @ViewBuilder private var actionBar: some View {
        switch table.ask {
        case .bid(let options):
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { o in
                        Button(o.label) { table.answer(o.value) }
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .buttonStyle(.borderedProminent)
                            .tint(o.label == "Pass" ? .gray : .pink)
                    }
                }
            }
            .frame(minHeight: 46)
        case .suit:
            HStack(spacing: 6) {
                ForEach(Suit.allCases, id: \.self) { s in
                    Button { table.answer(s.rawValue) } label: {
                        Text(s.symbol)
                            .font(.system(size: 26))
                            .foregroundStyle(s.isRed ? .red : .black)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .play:
            waiting("Lavender's turn — tap a raised card to play it.")
        case .none:
            if table.finished {
                Text("The \(table.game.name.lowercased()) game is over.")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                waiting(table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " ")
            }
        }
    }
}

private struct TrickSeat: View {
    let player: TrickTable.Player
    let label: String
    let isTurn: Bool
    let detail: String

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if player.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: player.skin, look: player.look) }
            }
            .frame(width: 54, height: 54)
            .background(Circle().fill(Color.white.opacity(0.15)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(isTurn ? Color.yellow : Color.white.opacity(0.4), lineWidth: isTurn ? 3 : 1))
            .opacity(player.out ? 0.4 : 1)
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if !player.note.isEmpty {
                Text(player.note)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(.white.opacity(0.9)))
                    .lineLimit(1)
            }
            if !player.isHuman && !player.hand.isEmpty {
                HStack(spacing: -11) {
                    ForEach(0..<min(player.hand.count, 13), id: \.self) { _ in
                        CardView(card: Card(rank: 2, suit: .clubs), faceUp: false, width: 14)
                    }
                }
            }
        }
        .frame(width: 100)
    }
}
