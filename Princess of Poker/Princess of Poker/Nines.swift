import SwiftUI

/// A three-handed game of Nines at the salon's card table: you, the Princess and one newcomer.
/// Everyone starts on 9 points and counts down toward 0 by taking exactly four tricks a round.
/// Nobody bets — like hearts, nines is just for fun, so it makes the salon no money.
@Observable final class NinesTable {
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
        /// Counts down from 9; the first to reach 0 wins.
        var score = NinesTable.startScore
        /// Tricks taken this round.
        var tricks = 0
    }

    static let startScore = 9
    /// Take exactly this many tricks to hold your score.
    static let quota = 4
    /// If nobody has counted down to 0 by now, the lowest score wins.
    static let maxRounds = 10
    /// Trumps rotate every round: clubs, diamonds, hearts, spades, then no trump — and around again.
    static let trumpCycle: [Suit?] = [.clubs, .diamonds, .hearts, .spades, nil]

    /// Seated clockwise: 0 you (bottom), 1 the newcomer (left), 2 the Princess (right).
    var players: [Player]
    var trick: [(seat: Int, card: Card)] = []
    var turn: Int?
    var round = 0
    var dealer = 2
    var message = "Shuffle up and deal!"
    var banner: String?
    var finished = false
    /// The thirteen-card spare hand in the middle of the table.
    var spare: [Card] = []
    /// Face down until somebody swaps; then their old hand lies face up.
    var spareFaceUp = false
    /// True during the exchanging phase, before the first lead.
    var exchanging = false
    /// The cards you picked up from the spare this round, highlighted until the first trick.
    var received: Set<Int> = []
    var trickWinner: Int?

    var trump: Suit? { Self.trumpCycle[(max(1, round) - 1) % Self.trumpCycle.count] }
    var trumpText: String { trump.map { "Trump \($0.symbol)" } ?? "No Trump" }

    private var deck: [Card] = []
    private var playCont: CheckedContinuation<Card, Never>?
    private var swapCont: CheckedContinuation<Bool, Never>?
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
    var humanToSwap: Bool { swapCont != nil }
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
            await playRound()
            if players.contains(where: { $0.score <= 0 }) || round >= Self.maxRounds { break }
        }
        turn = nil
        let w = leaders
        message = "Game over! " + w.map { players[$0].name }.joined(separator: " & ")
            + " win\(w.count == 1 ? "s" : "") with \(players[w[0]].score) point\(players[w[0]].score == 1 ? "" : "s") left."
        sound.chime()
        finished = true
        try? await Task.sleep(for: .seconds(3.0))
        onFinished?()
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s / pace))
    }

    private func playRound() async {
        round += 1
        dealer = (dealer + 1) % 3
        received = []
        trick = []
        trickWinner = nil
        spareFaceUp = false
        deck = Deck.shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].tricks = 0
        }
        spare = []
        message = "Round \(round) · \(trump.map { "\($0.symbol) are trumps" } ?? "no trumps"). \(players[dealer].name) deals."
        for _ in 0..<13 {
            for i in players.indices { players[i].hand.append(deck.removeFirst()) }
            spare.append(deck.removeFirst())
            sound.card()
            await wait(0.07)
        }
        sortHands()

        // The exchange: starting left of the dealer, keep your hand or swap it for the spare.
        exchanging = true
        for k in 1...3 {
            let i = (dealer + k) % 3
            turn = i
            let swap: Bool
            if players[i].isHuman {
                message = spareFaceUp
                    ? "Lavender's choice — keep her hand, or swap it for the face-up spare?"
                    : "Lavender's choice — keep her hand, or gamble on the face-down spare?"
                swap = await withCheckedContinuation { swapCont = $0 }
            } else {
                await wait(1.0)
                swap = wantsSwap(i)
            }
            if swap {
                let old = players[i].hand
                players[i].hand = spare
                spare = old
                spareFaceUp = true
                sortHands()
                if players[i].isHuman { received = Set(players[i].hand.map(\.id)) }
                sound.card()
                message = "\(players[i].name) swaps for the spare hand."
            } else {
                message = "\(players[i].name) keeps her hand."
            }
            await wait(1.3)
        }
        exchanging = false
        turn = nil

        var leader = (dealer + 1) % 3
        for t in 0..<13 {
            trick = []
            trickWinner = nil
            for k in 0..<3 {
                let i = (leader + k) % 3
                turn = i
                let card: Card
                if players[i].isHuman {
                    message = trick.isEmpty
                        ? "Lavender's lead. She has \(players[0].tricks) of \(Self.quota) tricks."
                        : "Lavender's turn — follow \(trick[0].card.suit.symbol) if she can."
                    card = await withCheckedContinuation { playCont = $0 }
                } else {
                    await wait(0.7)
                    card = choose(i)
                }
                play(i, card)
            }
            turn = nil
            if t == 0 { received = [] }
            let w = winner()
            players[w].tricks += 1
            trickWinner = w
            message = "\(players[w].name) takes the trick (\(players[w].tricks))."
            await wait(1.3)
            leader = w
        }
        trick = []
        trickWinner = nil

        // Exactly four holds steady; each trick over takes a point off, each one short adds one.
        for i in players.indices { players[i].score += Self.quota - players[i].tricks }
        banner = "Round \(round): " + players.map { p in
            let d = Self.quota - p.tricks
            return "\(p.name) \(p.tricks) tricks " + (d == 0 ? "±0" : (d < 0 ? "−\(-d)" : "+\(d)"))
        }.joined(separator: " · ")
        if players.contains(where: { $0.tricks == Self.quota }) { sound.chime() }
        await wait(3.0)
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

    func choose(swap: Bool) {
        guard let c = swapCont else { return }
        swapCont = nil
        c.resume(returning: swap)
    }

    /// Leaving mid-game: keeps your hand and plays your first legal card so the game can wind down.
    func abandon() {
        choose(swap: false)
        if let c = playCont {
            playCont = nil
            c.resume(returning: legal(0)[0])
        }
    }

    // MARK: Rules

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

    /// A rough guess at how many tricks a hand will take with tonight's trump.
    private func estimate(_ hand: [Card]) -> Double {
        let bySuit = Dictionary(grouping: hand, by: \.suit)
        let trumps = trump.map { bySuit[$0]?.count ?? 0 } ?? 0
        var est = 0.0
        for (suit, cards) in bySuit {
            let n = cards.count
            for c in cards {
                switch c.rank {
                case 14: est += 1
                case 13: est += n >= 2 ? 0.75 : 0.3
                case 12: est += n >= 3 ? 0.45 : 0.15
                case 11: est += n >= 4 ? 0.25 : 0
                default: break
                }
            }
            if suit == trump { est += Double(max(0, n - 3)) * 0.7 }
            else if trump != nil && n <= 1 && trumps >= 2 { est += 0.4 }
        }
        return est
    }

    private func wantsSwap(_ i: Int) -> Bool {
        let off = abs(estimate(players[i].hand) - Double(Self.quota))
        if spareFaceUp { return abs(estimate(spare) - Double(Self.quota)) + 0.5 < off }
        // A blind swap is a gamble — only worth it for a really lopsided hand.
        return off >= 2 || (off >= 1.5 && Bool.random())
    }

    /// Low cards first; trumps count as higher than anything else.
    private func strength(_ c: Card) -> Int { c.rank + (c.suit == trump ? 20 : 0) }

    private func choose(_ i: Int) -> Card {
        let options = legal(i)
        if options.count == 1 { return options[0] }
        let wantMore = players[i].tricks < Self.quota
        let lowest = options.min { strength($0) < strength($1) }!
        let highest = options.max { strength($0) < strength($1) }!

        if trick.isEmpty {
            guard wantMore else { return lowest }
            // Cash an ace in a side suit first, then the top of the longest suit.
            if let ace = options.first(where: { $0.rank == 14 && $0.suit != trump }) { return ace }
            return highest
        }
        let wins = options.filter { winner(trick + [(i, $0)]) == i }
        let loses = options.filter { winner(trick + [(i, $0)]) != i }
        if wantMore {
            guard !wins.isEmpty else { return lowest }
            // Last to play: win as cheaply as possible. Otherwise, win high so the next player can't top it.
            return trick.count == 2 ? wins.min { strength($0) < strength($1) }! : wins.max { strength($0) < strength($1) }!
        }
        // Already has four: duck with the highest card that still loses.
        if let duck = loses.max(by: { strength($0) < strength($1) }) { return duck }
        return lowest
    }
}

struct NinesView: View {
    @Bindable var table: NinesTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color

    /// Where each seat sits around the table (fractions of the table area), clockwise from you.
    private let spots: [CGPoint] = [CGPoint(x: 0.5, y: 0.87), CGPoint(x: 0.14, y: 0.3), CGPoint(x: 0.86, y: 0.3)]
    /// Where each seat's card lands in the trick, toward that seat.
    private let trickSpots: [CGPoint] = [CGPoint(x: 0.5, y: 0.58), CGPoint(x: 0.38, y: 0.42), CGPoint(x: 0.62, y: 0.42)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Nines · Round \(table.round)")
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

                    if table.exchanging && !table.spare.isEmpty {
                        spareView(width: size.width)
                            .position(x: size.width * 0.5, y: size.height * 0.36)
                            .transition(.opacity)
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
                        NinesSeat(player: player, isTurn: table.turn == i, isDealer: table.dealer == i,
                                  leading: table.finished && table.leaders.contains(i))
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: table.trick.count)
                .animation(.easeOut(duration: 0.3), value: table.exchanging)
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

    /// The spare hand: a face-down stack, or the swapped-out hand spread face up.
    private func spareView(width: CGFloat) -> some View {
        VStack(spacing: 3) {
            Text(table.spareFaceUp ? "Spare hand (face up)" : "Spare hand")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
            let w = table.spareFaceUp ? min(30, width * 0.07) : 22.0
            HStack(spacing: table.spareFaceUp ? -w * 0.45 : -19) {
                ForEach(table.spare) { card in
                    CardView(card: card, faceUp: table.spareFaceUp, width: w)
                }
            }
        }
    }

    /// Your thirteen cards in a fan: tap to play. Cards you can't play are dimmed.
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
                            .overlay {
                                if table.received.contains(card.id) {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(Color.pink, lineWidth: 2)
                                }
                            }
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
            Text("The nines game is over for the night.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.humanToSwap {
            HStack(spacing: 10) {
                barButton("Keep my hand", color: .gray) { table.choose(swap: false) }
                barButton(table.spareFaceUp ? "Swap for the spare" : "Swap blind", color: .pink) { table.choose(swap: true) }
            }
        } else {
            HStack {
                Text(table.humanToPlay ? "Lavender's turn — tap a raised card to play it. She aims for exactly \(NinesTable.quota) tricks."
                     : (table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " "))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 46)
        }
    }

    private func barButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct NinesSeat: View {
    let player: NinesTable.Player
    let isTurn: Bool
    let isDealer: Bool
    let leading: Bool

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if player.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: player.skin, look: player.look) }
            }
            .frame(width: 58, height: 58)
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
            Text("Score \(player.score) · \(player.tricks)/\(NinesTable.quota) tricks")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(player.tricks == NinesTable.quota ? .green : (player.tricks > NinesTable.quota ? .orange : .yellow))
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
