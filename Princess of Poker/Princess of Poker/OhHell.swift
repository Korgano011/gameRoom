import SwiftUI

/// Oh Hell (Blackout), the ascending 13-hand version for four: you across from the Princess, a newcomer on each side.
/// Hand 1 deals one card each, hand 2 two, up to hand 13 where the whole deck is dealt and there's no trump;
/// before that the top card of what's left is turned up for trump. Everyone bids how many tricks she'll take,
/// starting left of the dealer — and the dealer may not bid the number that makes the bids add up to the cards
/// dealt (the hook), so somebody always misses. Hit your bid exactly for 10 points plus 1 a trick; miss and score 0.
/// Nobody bets — like hearts, oh hell is just for fun, so it makes the salon no money.
@Observable final class OhHellTable {
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
        var bid: Int?
        /// Tricks taken this hand.
        var tricks = 0
        var score = 0
        /// What she scored on the last hand, for the score line.
        var last: Int?
    }

    static let hands = 13

    /// Seated clockwise: 0 you (bottom), 1 left, 2 the Princess (top), 3 right.
    var players: [Player]
    var trick: [(seat: Int, card: Card)] = []
    var turn: Int?
    var hand = 0
    var dealer = 2
    /// The card turned up for trump; nil on the last, no-trump hand.
    var trumpCard: Card?
    var message = "Shuffle up and deal!"
    var banner: String?
    var finished = false
    var trickWinner: Int?

    var trump: Suit? { trumpCard?.suit }
    var trumpText: String { trump.map { "Trump \($0.symbol)" } ?? "No Trump" }
    var bidTotal: Int { players.compactMap(\.bid).reduce(0, +) }

    private var deck: [Card] = []
    private var playCont: CheckedContinuation<Card, Never>?
    private var bidCont: CheckedContinuation<Int, Never>?
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
    var humanToBid: Bool { bidCont != nil }
    var legalForHuman: Set<Int> { humanToPlay ? Set(legal(0).map(\.id)) : [] }
    /// The bid the dealer isn't allowed to make (the hook), if you're the dealer and it's your bid.
    var hookForHuman: Int? { humanToBid ? hook(for: 0) : nil }
    /// Highest score so far — the leader (or, at the end, the winner).
    var leaders: [Int] {
        let top = players.map(\.score).max() ?? 0
        return players.indices.filter { players[$0].score == top }
    }

    // MARK: Flow

    func run() async {
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled && hand < Self.hands {
            await playHand()
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
        hand += 1
        dealer = (dealer + 1) % 4
        trick = []
        trickWinner = nil
        deck = Deck.shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].tricks = 0
            players[i].bid = nil
        }
        trumpCard = nil
        message = "Hand \(hand) of \(Self.hands) · \(hand) card\(hand == 1 ? "" : "s") each. \(players[dealer].name) deals."
        for _ in 0..<hand {
            for k in 1...4 {
                players[(dealer + k) % 4].hand.append(deck.removeFirst())
                sound.card()
                await wait(0.05)
            }
        }
        // Turn up the next card for trump — unless the whole deck is out (hand 13).
        if !deck.isEmpty {
            trumpCard = deck.removeFirst()
            sound.card()
        }
        sortHands()
        message = trump.map { "The \(trumpCard!.text) is turned up — \($0.symbol) are trumps." } ?? "Every card is dealt — no trump this hand!"
        await wait(1.4)

        // Bidding, starting left of the dealer. The dealer is on the hook.
        for k in 1...4 {
            let i = (dealer + k) % 4
            turn = i
            let bid: Int
            if players[i].isHuman {
                if Task.isCancelled { return }
                message = hook(for: i).map { "Lavender's bid. She's the dealer — she can't bid \($0) (the bids can't add up to \(hand))." }
                    ?? "Lavender's bid. How many tricks will she take?"
                bid = await withCheckedContinuation { bidCont = $0 }
            } else {
                await wait(0.9)
                bid = computerBid(i)
            }
            players[i].bid = bid
            message = "\(players[i].name) bids \(bid)."
            sound.beep()
            await wait(0.8)
        }
        turn = nil
        let total = bidTotal
        message = "Bids total \(total) for \(hand) trick\(hand == 1 ? "" : "s") — \(total > hand ? "over" : "under") by \(abs(total - hand)). Somebody's going to miss!"
        await wait(1.6)

        var leader = (dealer + 1) % 4
        for _ in 0..<hand {
            trick = []
            trickWinner = nil
            for k in 0..<4 {
                let i = (leader + k) % 4
                turn = i
                let card: Card
                if players[i].isHuman {
                    if Task.isCancelled { return }
                    message = trick.isEmpty
                        ? "Lavender's lead. She bid \(human.bid ?? 0) and has \(human.tricks)."
                        : "Lavender's turn — follow \(trick[0].card.suit.symbol) if she can."
                    card = await withCheckedContinuation { playCont = $0 }
                } else {
                    await wait(0.7)
                    card = choose(i)
                }
                play(i, card)
            }
            turn = nil
            let w = winner()
            players[w].tricks += 1
            trickWinner = w
            message = "\(players[w].name) takes the trick (\(players[w].tricks) of \(players[w].bid ?? 0) bid)."
            await wait(1.3)
            leader = w
        }
        trick = []
        trickWinner = nil

        // Hit your bid exactly for 10 plus 1 a trick; miss by any amount and it's a blackout — 0.
        for i in players.indices {
            let hit = players[i].tricks == players[i].bid
            let pts = hit ? 10 + players[i].tricks : 0
            players[i].score += pts
            players[i].last = pts
        }
        banner = "Hand \(hand): " + players.map { p in
            p.tricks == p.bid ? "\(p.name) hits \(p.bid ?? 0) +\(p.last ?? 0)" : "\(p.name) blacks out (\(p.tricks)/\(p.bid ?? 0))"
        }.joined(separator: " · ")
        if human.tricks == human.bid { sound.chime() }
        await wait(3.2)
        banner = nil
    }

    private func sortHands() {
        for i in players.indices { players[i].hand.sort(by: HeartsTable.handOrder) }
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

    func placeBid(_ n: Int) {
        guard let c = bidCont, n >= 0, n <= hand, n != hook(for: 0) else { return }
        bidCont = nil
        c.resume(returning: n)
    }

    /// Leaving mid-game: bids and plays whatever's legal so the game can wind down.
    func abandon() {
        if let c = bidCont {
            bidCont = nil
            c.resume(returning: hook(for: 0) == 0 ? 1 : 0)
        }
        if let c = playCont {
            playCont = nil
            c.resume(returning: legal(0)[0])
        }
    }

    // MARK: Rules

    /// The dealer bids last and can't make the bids add up to the cards dealt.
    func hook(for i: Int) -> Int? {
        guard i == dealer else { return nil }
        let rest = players.indices.filter { $0 != i }.compactMap { players[$0].bid }.reduce(0, +)
        let banned = hand - rest
        return banned >= 0 ? banned : nil
    }

    func legal(_ i: Int) -> [Card] {
        let hand = players[i].hand
        guard let led = trick.first?.card.suit else { return hand }
        let follow = hand.filter { $0.suit == led }
        return follow.isEmpty ? hand : follow
    }

    /// The highest trump takes the trick; otherwise the highest card of the suit led.
    private func winner(_ plays: [(seat: Int, card: Card)]? = nil) -> Int {
        let plays = plays ?? trick
        let led = plays[0].card.suit
        let suit = trump.flatMap { t in plays.contains { $0.card.suit == t } ? t : nil } ?? led
        return plays.filter { $0.card.suit == suit }.max { $0.card.rank < $1.card.rank }!.seat
    }

    // MARK: Newcomer AI

    /// A rough guess at how many tricks a hand will take with this hand's trump.
    private func estimate(_ cards: [Card]) -> Double {
        let bySuit = Dictionary(grouping: cards, by: \.suit)
        let trumps = trump.map { bySuit[$0]?.count ?? 0 } ?? 0
        let short = cards.count <= 4
        var est = 0.0
        for (suit, group) in bySuit {
            let n = group.count
            for c in group {
                if suit == trump {
                    est += c.rank >= 13 ? 0.95 : c.rank >= 11 ? 0.7 : short ? 0.45 : 0.3
                    continue
                }
                switch c.rank {
                case 14: est += short ? 0.85 : 0.9
                case 13: est += n >= 2 ? 0.65 : 0.3
                case 12: est += n >= 3 ? 0.35 : 0.1
                default: break
                }
            }
            if trump != nil && suit != trump && n <= 1 && trumps >= 2 && !short { est += 0.3 }
        }
        return est
    }

    private func computerBid(_ i: Int) -> Int {
        let est = estimate(players[i].hand)
        var bid = min(hand, max(0, Int(est.rounded())))
        if let banned = hook(for: i), bid == banned {
            // On the hook: go whichever way the hand leans.
            let up = bid + 1 <= hand ? bid + 1 : nil
            let down = bid - 1 >= 0 ? bid - 1 : nil
            if let u = up, let d = down { bid = est >= Double(bid) ? u : d } else { bid = up ?? down! }
        }
        return bid
    }

    /// Low cards first; trumps count as higher than anything else.
    private func strength(_ c: Card) -> Int { c.rank + (c.suit == trump ? 20 : 0) }

    private func choose(_ i: Int) -> Card {
        let options = legal(i)
        if options.count == 1 { return options[0] }
        let wantMore = players[i].tricks < (players[i].bid ?? 0)
        let lowest = options.min { strength($0) < strength($1) }!
        let highest = options.max { strength($0) < strength($1) }!

        if trick.isEmpty {
            guard wantMore else { return lowest }
            if let ace = options.first(where: { $0.rank == 14 && $0.suit != trump }) { return ace }
            return highest
        }
        let wins = options.filter { winner(trick + [(i, $0)]) == i }
        let loses = options.filter { winner(trick + [(i, $0)]) != i }
        if wantMore {
            guard !wins.isEmpty else { return lowest }
            return trick.count == 3 ? wins.min { strength($0) < strength($1) }! : wins.max { strength($0) < strength($1) }!
        }
        // Made her bid: duck with the highest card that still loses.
        if let duck = loses.max(by: { strength($0) < strength($1) }) { return duck }
        return lowest
    }
}

struct OhHellView: View {
    @Bindable var table: OhHellTable
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
                Text("\(day) · Oh Hell · Hand \(table.hand) of \(OhHellTable.hands)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text(table.trumpText)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(table.trump?.isRed == true ? .red : .black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white, in: Capsule())
            }
            .foregroundStyle(.white)
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

                    // The turned-up trump card beside the rest of the deck.
                    if let t = table.trumpCard, !table.finished {
                        VStack(spacing: 2) {
                            HStack(spacing: -24) {
                                CardView(card: t, faceUp: false, width: 30)
                                CardView(card: t, width: 30)
                            }
                            Text("TRUMP")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        .position(x: size.width * 0.24, y: size.height * 0.24)
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
                        OhHellSeat(player: player, isTurn: table.turn == i, isDealer: table.dealer == i,
                                   leading: table.finished && table.leaders.contains(i))
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: table.trick.count)
            }
            .frame(minHeight: 380)

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

    @ViewBuilder private var actionBar: some View {
        if table.finished {
            Text("The oh hell game is over for the day.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.humanToBid {
            VStack(spacing: 6) {
                Text("How many tricks will Lavender take?")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(0...table.hand, id: \.self) { n in
                        let banned = n == table.hookForHuman
                        Button { table.placeBid(n) } label: {
                            Text("\(n)")
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background((banned ? Color.gray : Color.pink).gradient, in: RoundedRectangle(cornerRadius: 10))
                                .overlay {
                                    if banned {
                                        Image(systemName: "xmark").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.8))
                                            .offset(x: 12, y: -10)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(banned)
                        .opacity(banned ? 0.45 : 1)
                    }
                }
            }
        } else {
            HStack {
                Text(table.humanToPlay ? "Lavender's turn — tap a raised card. She bid \(table.human.bid ?? 0) and has \(table.human.tricks)."
                     : (table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " "))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 46)
        }
    }
}

private struct OhHellSeat: View {
    let player: OhHellTable.Player
    let isTurn: Bool
    let isDealer: Bool
    let leading: Bool

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if player.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: player.skin, look: player.look) }
            }
            .frame(width: 54, height: 54)
            .background(Circle().fill(Color.white.opacity(0.15)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(isTurn ? Color.yellow : (leading ? Color.green : Color.white.opacity(0.4)), lineWidth: isTurn || leading ? 3 : 1))
            .overlay(alignment: .topTrailing) {
                if isDealer {
                    Text("D")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white))
                }
            }
            Text(player.isPrincess ? "Princess" : player.isHuman ? "Lavender" : player.name)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(player.score) pts")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.yellow)
            Text(player.bid.map { "Bid \($0) · Won \(player.tricks)" } ?? "Bid –")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(player.bid.map { player.tricks == $0 ? Color.green : (player.tricks > $0 ? .orange : .white) } ?? .white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !player.isHuman && !player.hand.isEmpty {
                HStack(spacing: -11) {
                    ForEach(0..<player.hand.count, id: \.self) { _ in
                        CardView(card: Card(rank: 2, suit: .clubs), faceUp: false, width: 14)
                    }
                }
            }
        }
        .frame(width: 110)
    }
}
