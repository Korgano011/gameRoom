import SwiftUI

/// Pedro at the salon's card table: you and the Princess (partners, sitting across) against two newcomers.
/// Nine cards each, bid 7–14 for the right to name trump, then capture the point cards.
/// Nobody bets — like hearts, pedro is just for fun, so it makes the salon no money.
@Observable final class PedroTable {
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
        /// What she said in the bidding this hand ("Pass", "Bid 8").
        var note = ""
    }

    /// The first team to this many points wins.
    static let gameTarget = 62
    static let minBid = 7
    static let maxBid = 14

    /// Seated clockwise: 0 you (bottom), 1 left, 2 the Princess (top), 3 right. Teams: 0 & 2, 1 & 3.
    var players: [Player]
    /// Game scores: team 0 is you & the Princess, team 1 the newcomers.
    var scores = [0, 0]
    /// Points captured this hand by each team.
    var handPoints = [0, 0]
    var trick: [(seat: Int, card: Card)] = []
    var turn: Int?
    var dealer = 1
    var handNumber = 0
    var message = "Shuffle up and deal!"
    var banner: String?
    var finished = false
    var winningTeam: Int?
    var trump: Suit?
    var bidder: Int?
    var highBid = 0
    var trickWinner: Int?
    /// True while you're choosing a bid or a trump suit.
    var bidding = false
    var choosingTrump = false

    private var deck: [Card] = []
    private var abandoned = false
    private var playCont: CheckedContinuation<Card, Never>?
    private var bidCont: CheckedContinuation<Int, Never>?
    private var trumpCont: CheckedContinuation<Suit, Never>?
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
    /// Bids you may make right now (pass is always allowed).
    var bidOptions: [Int] { highBid >= Self.maxBid ? [] : Array(max(Self.minBid, highBid + 1)...Self.maxBid) }
    static func team(_ seat: Int) -> Int { seat % 2 }
    func teamName(_ t: Int) -> String {
        t == 0 ? "Lavender & the Princess" : "\(players[1].name) & \(players[3].name)"
    }

    // MARK: Flow

    func run() async {
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled && !abandoned {
            await playHand()
            if scores.contains(where: { $0 >= Self.gameTarget }) { break }
        }
        turn = nil
        // Both over the line on the same hand: the bidders go out first.
        let bt = bidder.map(Self.team) ?? 0
        let w = scores[bt] >= Self.gameTarget ? bt : (scores[0] >= scores[1] ? 0 : 1)
        winningTeam = w
        message = "Game over! \(teamName(w)) win \(scores[w]) to \(scores[1 - w])."
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
        dealer = (dealer + 1) % 4
        trump = nil
        bidder = nil
        highBid = 0
        handPoints = [0, 0]
        trick = []
        trickWinner = nil
        deck = Deck.shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].note = ""
        }
        message = "Hand \(handNumber). \(players[dealer].name) deals nine cards each, three at a time."
        // Three rounds of three cards, starting on the dealer's left.
        for _ in 0..<3 {
            for k in 1...4 {
                let i = (dealer + k) % 4
                players[i].hand += deck.prefix(3)
                deck.removeFirst(3)
                sound.card()
                await wait(0.12)
            }
        }
        for i in players.indices { sortHand(i) }

        // Bidding: once around, starting on the dealer's left.
        for k in 1...4 {
            let i = (dealer + k) % 4
            turn = i
            let b: Int
            if players[i].isHuman && !abandoned {
                message = highBid == 0 ? "Lavender's bid — 7 to 14 points, or pass." : "Lavender's bid — beat \(highBid), or pass."
                bidding = true
                b = await withCheckedContinuation { bidCont = $0 }
                bidding = false
            } else {
                await wait(0.9)
                b = players[i].isHuman ? 0 : aiBid(i)
            }
            players[i].note = b == 0 ? "Pass" : "Bid \(b)"
            if b > highBid {
                highBid = b
                bidder = i
            }
            sound.card()
            message = "\(players[i].name) \(b == 0 ? "passes" : "bids \(b)")."
            await wait(0.6)
        }
        if bidder == nil {
            bidder = dealer
            highBid = Self.minBid
            players[dealer].note = "Stuck 7"
            message = "Everybody passed — \(players[dealer].name) is stuck with the minimum bid of 7."
            await wait(1.6)
        }
        let b = bidder!

        // The high bidder names trump.
        turn = b
        if players[b].isHuman && !abandoned {
            message = "Lavender won the bid at \(highBid). She names trump."
            choosingTrump = true
            trump = await withCheckedContinuation { trumpCont = $0 }
            choosingTrump = false
        } else {
            await wait(1.0)
            trump = bestSuit(players[b].hand)
        }
        let t = trump!
        for i in players.indices { sortHand(i) }
        sound.chime()
        message = "\(players[b].name) bids \(highBid) — \(Self.suitName(t)) are trump. Pedros: 5\(t.symbol) and 5\(Self.pedroPartner(t).symbol)."
        await wait(2.0)

        // Nine tricks; the high bidder leads the first.
        var leader = b
        for _ in 0..<9 {
            trick = []
            trickWinner = nil
            for k in 0..<4 {
                let i = (leader + k) % 4
                turn = i
                let card: Card
                if players[i].isHuman && !abandoned {
                    message = trick.isEmpty ? "Lavender's lead." : "Lavender's turn — follow \(effectiveSuit(trick[0].card).symbol) if she can."
                    card = await withCheckedContinuation { playCont = $0 }
                } else {
                    await wait(0.7)
                    card = players[i].isHuman ? legal(i)[0] : choose(i)
                }
                play(i, card)
            }
            turn = nil
            let w = winner(trick)
            // The 2 of trump (Low) scores for the side that played it; everything else goes to the trick's winner.
            var pts = 0
            for p in trick {
                if isLow(p.card) {
                    handPoints[Self.team(p.seat)] += 1
                } else {
                    pts += points(p.card)
                }
            }
            handPoints[Self.team(w)] += pts
            trickWinner = w
            message = "\(players[w].name) takes the trick" + (pts > 0 ? " — \(pts) point\(pts == 1 ? "" : "s")." : ".")
            await wait(1.3)
            leader = w
        }
        trick = []
        trickWinner = nil

        // Scoring: the bidders need their bid or lose it; the other side always keeps what it caught.
        let bt = Self.team(b), ot = 1 - bt
        let made = handPoints[bt] >= highBid
        scores[bt] += made ? handPoints[bt] : -highBid
        scores[ot] += handPoints[ot]
        banner = "\(teamName(bt)) " + (made
            ? "made the bid of \(highBid) with \(handPoints[bt]) — +\(handPoints[bt])."
            : "went set: \(handPoints[bt]) of \(highBid) — −\(highBid).")
            + " \(teamName(ot)) +\(handPoints[ot])."
        if made { sound.chime() }
        await wait(3.2)
        banner = nil
    }

    private func play(_ i: Int, _ card: Card) {
        players[i].hand.removeAll { $0.id == card.id }
        trick.append((i, card))
        sound.card()
    }

    func tap(_ card: Card) {
        guard let c = playCont, legalForHuman.contains(card.id) else { return }
        playCont = nil
        c.resume(returning: card)
    }

    /// 0 passes.
    func submitBid(_ b: Int) {
        guard let c = bidCont else { return }
        bidCont = nil
        c.resume(returning: b)
    }

    func nameTrump(_ s: Suit) {
        guard let c = trumpCont else { return }
        trumpCont = nil
        c.resume(returning: s)
    }

    /// Leaving mid-game: passes, names the best suit or plays your first legal card, and lets the game wind down.
    func abandon() {
        abandoned = true
        if let c = bidCont {
            bidCont = nil
            c.resume(returning: 0)
        }
        if let c = trumpCont {
            trumpCont = nil
            c.resume(returning: bestSuit(human.hand))
        }
        if let c = playCont {
            playCont = nil
            c.resume(returning: legal(0)[0])
        }
    }

    // MARK: Rules

    static func suitName(_ s: Suit) -> String { ["Clubs", "Diamonds", "Hearts", "Spades"][s.rawValue] }
    /// The other suit of trump's color: its 5 is the Low Pedro.
    static func pedroPartner(_ t: Suit) -> Suit {
        switch t {
        case .clubs: .spades
        case .spades: .clubs
        case .hearts: .diamonds
        case .diamonds: .hearts
        }
    }

    private func isLowPedro(_ c: Card, _ t: Suit) -> Bool { c.rank == 5 && c.suit == Self.pedroPartner(t) }
    private func isLow(_ c: Card) -> Bool { trump == c.suit && c.rank == 2 }

    /// The Low Pedro plays as a trump.
    func effectiveSuit(_ c: Card) -> Suit {
        guard let t = trump else { return c.suit }
        return isLowPedro(c, t) ? t : c.suit
    }

    /// A, J, 10 and 2 of trump are 1 each; both pedros are 5. 14 points in all.
    func points(_ c: Card) -> Int { trump.map { Self.points(c, trump: $0) } ?? 0 }

    static func points(_ c: Card, trump t: Suit) -> Int {
        if c.suit == t {
            switch c.rank {
            case 14, 11, 10, 2: return 1
            case 5: return 5
            default: return 0
            }
        }
        return c.rank == 5 && c.suit == pedroPartner(t) ? 5 : 0
    }

    /// Strength within its (effective) suit. In trump: A K Q J 10 9 8 7 6 5 · Low Pedro · 4 3 2.
    private func power(_ c: Card) -> Int {
        guard let t = trump else { return c.rank * 2 }
        if c.suit == t { return c.rank == 5 ? 11 : c.rank * 2 }
        if isLowPedro(c, t) { return 10 }
        return c.rank * 2
    }

    private func winner(_ cards: [(seat: Int, card: Card)]) -> Int {
        let trumps = cards.filter { effectiveSuit($0.card) == trump }
        let led = effectiveSuit(cards[0].card)
        let pool = trumps.isEmpty ? cards.filter { effectiveSuit($0.card) == led } : trumps
        return pool.max { power($0.card) < power($1.card) }!.seat
    }

    func legal(_ i: Int) -> [Card] {
        let hand = players[i].hand
        guard let first = trick.first else { return hand }
        let follow = hand.filter { effectiveSuit($0) == effectiveSuit(first.card) }
        return follow.isEmpty ? hand : follow
    }

    /// Grouped by suit with trump (and the Low Pedro) on the right, low to high.
    private func sortHand(_ i: Int) {
        let key = { (c: Card) -> Int in
            let s = self.effectiveSuit(c)
            return (s == self.trump ? 10 : s.rawValue) * 100 + self.power(c)
        }
        players[i].hand.sort { key($0) < key($1) }
    }

    // MARK: Newcomer AI

    /// Roughly how many points this hand (plus a partner's help) might catch with `t` as trump.
    private func estimate(_ hand: [Card], _ t: Suit) -> Double {
        let trumps = hand.filter { $0.suit == t || isLowPedro($0, t) }
        let high = trumps.filter { $0.suit == t && $0.rank > 5 }.count
        var e = 3.0 + Double(trumps.count) * 0.6
        for c in trumps {
            if c.suit == t {
                switch c.rank {
                case 14: e += 1
                case 13: e += 0.6
                case 11: e += 0.5
                case 10: e += 0.4
                case 2: e += 1
                case 5: e += 5 * min(0.9, 0.35 + 0.15 * Double(high))
                default: break
                }
            } else {
                e += 5 * min(0.85, 0.3 + 0.15 * Double(high))
            }
        }
        return e
    }

    private func bestSuit(_ hand: [Card]) -> Suit {
        Suit.allCases.max { estimate(hand, $0) < estimate(hand, $1) }!
    }

    private func aiBid(_ i: Int) -> Int {
        let hand = players[i].hand
        let e = estimate(hand, bestSuit(hand))
        let next = max(Self.minBid, highBid + 1)
        guard next <= Self.maxBid else { return 0 }
        // Don't climb over your own partner unless the hand is much stronger.
        let partnerHolds = bidder.map { Self.team($0) == Self.team(i) } ?? false
        let want = Int(e.rounded(.down)) - (partnerHolds ? 2 : 0)
        return want >= next ? min(Self.maxBid, Double.random(in: 0..<1) < 0.7 ? next : want) : 0
    }

    private func choose(_ i: Int) -> Card {
        let options = legal(i)
        if options.count == 1 { return options[0] }
        let t = trump!
        let team = Self.team(i)
        // The 2 of trump scores for whoever plays it, so it's safe to throw.
        let worth = { (c: Card) in self.isLow(c) ? 0 : self.points(c) }
        let lowest = { (cards: [Card]) in cards.min { self.power($0) < self.power($1) } }
        let isTrump = { (c: Card) in self.effectiveSuit(c) == t }

        if trick.isEmpty {
            let trumps = options.filter(isTrump)
            // The bidding side pulls trump with the ace or king.
            if let b = bidder, Self.team(b) == team,
               let top = trumps.max(by: { power($0) < power($1) }), top.suit == t, top.rank >= 13 {
                return top
            }
            if let ace = options.first(where: { $0.rank == 14 && !isTrump($0) }) { return ace }
            let safe = options.filter { worth($0) == 0 && !isTrump($0) }
            return lowest(safe.isEmpty ? options.filter { worth($0) == 0 } : safe) ?? lowest(options)!
        }

        let current = winner(trick)
        let currentCard = trick.first { $0.seat == current }!.card
        let isLast = trick.count == 3
        let trickPoints = trick.reduce(0) { $0 + worth($1.card) }
        let junk = options.filter { worth($0) == 0 }
        let cheapest = lowest(junk) ?? options.min { worth($0) < worth($1) }!

        if Self.team(current) == team {
            // Partner has it: feed points when the trick is safe.
            let safe = isLast || (currentCard.suit == t && currentCard.rank >= 13)
            if safe, let gift = options.filter({ worth($0) > 0 }).max(by: { worth($0) < worth($1) }) { return gift }
            return cheapest
        }
        let beats = options.filter { c in winner(trick + [(seat: i, card: c)]) == i }
        if !beats.isEmpty && (trickPoints > 0 || isLast || options.contains(where: { worth($0) > 0 })) {
            // Last to play: grab it with a point card if possible; otherwise win as cheaply as possible.
            if isLast, let best = beats.max(by: { worth($0) < worth($1) }), worth(best) > 0 { return best }
            return lowest(beats.filter { worth($0) == 0 }) ?? lowest(beats)!
        }
        return cheapest
    }
}

struct PedroView: View {
    @Bindable var table: PedroTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color

    /// Where each seat sits around the table (fractions of the table area), clockwise from you.
    private let spots: [CGPoint] = [CGPoint(x: 0.5, y: 0.87), CGPoint(x: 0.13, y: 0.47), CGPoint(x: 0.5, y: 0.13), CGPoint(x: 0.87, y: 0.47)]
    /// Where each seat's card lands in the trick, toward that seat.
    private let trickSpots: [CGPoint] = [CGPoint(x: 0.5, y: 0.6), CGPoint(x: 0.36, y: 0.47), CGPoint(x: 0.5, y: 0.33), CGPoint(x: 0.64, y: 0.47)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Pedro · Hand \(table.handNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text("Just for fun · to \(PedroTable.gameTarget)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.pink)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            HStack(spacing: 8) {
                teamScore(0)
                teamScore(1)
            }
            .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Ellipse()
                        .fill(RadialGradient(colors: [felt.opacity(0.95), felt.opacity(0.7)], center: .center, startRadius: 10, endRadius: size.width * 0.6))
                        .overlay(Ellipse().strokeBorder(Color(red: 0.45, green: 0.25, blue: 0.1), lineWidth: 14))
                        .overlay(Ellipse().strokeBorder(Color.pink.opacity(0.5), lineWidth: 2).padding(7))
                        .padding(.horizontal, size.width * 0.12)
                        .padding(.vertical, size.height * 0.12)

                    if let t = table.trump {
                        Text("Trump \(t.symbol)" + (table.bidder.map { " · \(table.players[$0].isPrincess ? "Princess" : table.players[$0].isHuman ? "Lavender" : table.players[$0].name) bid \(table.highBid)" } ?? ""))
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(t.isRed ? Color.red : Color.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.85), in: Capsule())
                            .position(x: size.width * 0.5, y: size.height * 0.24)
                    }

                    ForEach(table.trick, id: \.card.id) { play in
                        let p = trickSpots[play.seat]
                        CardView(card: play.card, width: min(52, size.width * 0.12))
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
                        .position(x: size.width * 0.5, y: size.height * 0.73)

                    ForEach(Array(table.players.enumerated()), id: \.offset) { i, player in
                        PedroSeat(player: player, isTurn: table.turn == i, isDealer: table.dealer == i,
                                  isBidder: table.trump != nil && table.bidder == i,
                                  winning: table.winningTeam == PedroTable.team(i))
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: table.trick.count)
            }
            .frame(minHeight: 360)

            if let banner = table.banner {
                Text(banner)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.pink.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .transition(.opacity)
                    .id(banner)
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

    private func teamScore(_ t: Int) -> some View {
        VStack(spacing: 1) {
            Text(table.teamName(t))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(table.scores[t])" + (table.handPoints[t] > 0 ? "  (+\(table.handPoints[t]) this hand)" : ""))
                .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.yellow)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background((t == 0 ? Color.pink : Color.blue).opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Your nine cards: tap a raised card to play it. Cards you can't play are dimmed.
    private var yourHand: some View {
        GeometryReader { geo in
            let hand = table.human.hand
            let w = 54.0
            let step = hand.count > 1 ? min(w + 4, (geo.size.width - w) / Double(hand.count - 1)) : 0
            let legal = table.legalForHuman
            HStack(spacing: step - w) {
                ForEach(hand) { card in
                    Button { table.tap(card) } label: {
                        CardView(card: card, dim: table.humanToPlay && !legal.contains(card.id), width: w)
                            .overlay {
                                if table.points(card) > 0 {
                                    Text("\(table.points(card))")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(3)
                                        .background(Circle().fill(Color.pink))
                                        .offset(x: w * 0.36, y: -w * 0.6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .offset(y: table.humanToPlay && legal.contains(card.id) ? -12 : 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 92)
    }

    @ViewBuilder private var actionBar: some View {
        if table.finished {
            Text("The pedro game is over for the night.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.bidding {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                bidButton("Pass", value: 0, color: .gray)
                ForEach(table.bidOptions, id: \.self) { b in
                    bidButton("\(b)", value: b, color: .pink)
                }
            }
        } else if table.choosingTrump {
            HStack(spacing: 8) {
                ForEach(Suit.allCases, id: \.self) { s in
                    Button {
                        table.nameTrump(s)
                    } label: {
                        Text(s.symbol)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(s.isRed ? Color.red : Color.black)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            HStack {
                Text(table.humanToPlay ? "Lavender's turn — tap a raised card to play it."
                     : (table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " "))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 46)
        }
    }

    private func bidButton(_ label: String, value: Int, color: Color) -> some View {
        Button {
            table.submitBid(value)
        } label: {
            Text(label)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct PedroSeat: View {
    let player: PedroTable.Player
    let isTurn: Bool
    let isDealer: Bool
    let isBidder: Bool
    let winning: Bool

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if player.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: player.skin, look: player.look) }
            }
            .frame(width: 58, height: 58)
            .background(Circle().fill(Color.white.opacity(0.15)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(isTurn ? Color.yellow : (winning ? Color.green : Color.white.opacity(0.4)), lineWidth: isTurn || winning ? 3 : 1))
            .overlay(alignment: .bottomTrailing) {
                if isDealer {
                    Text("D")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.white))
                }
            }
            Text(player.isPrincess ? "Princess" : player.isHuman ? "Lavender" : player.name)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !player.note.isEmpty {
                Text(isBidder ? "★ " + player.note : player.note)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isBidder ? .yellow : .white.opacity(0.7))
            }
            if !player.isHuman && !player.hand.isEmpty {
                HStack(spacing: -11) {
                    ForEach(0..<player.hand.count, id: \.self) { _ in
                        CardView(card: Card(rank: 2, suit: .clubs), faceUp: false, width: 14)
                    }
                }
            }
        }
        .frame(width: 96)
    }
}
