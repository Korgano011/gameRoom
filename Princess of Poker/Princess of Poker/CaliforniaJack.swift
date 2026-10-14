import SwiftUI

/// California Jack for four, everyone for herself: you across from the Princess, a newcomer on each side.
/// Six cards each; the other 28 sit face up as the stock, and the suit of its top card is trump for the hand.
/// Follow the suit led or trump if you can; otherwise play anything. The trick's winner takes the top stock card,
/// then the others draw clockwise — once the stock runs out the last six tricks are played without drawing.
/// Points: High (ace of trump), Low (2 of trump), Jack (jack of trump) to whoever captures them, and Game to the most
/// card points (10s 10, aces 4, kings 3, queens 2, jacks 1; a tie scores nobody). First to 10 wins; if several get
/// there on the same hand, points count in the order High, Low, Jack, Game.
/// Nobody bets — like hearts, california jack is just for fun, so it makes the salon no money.
@Observable final class CaliforniaJackTable {
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
        /// Every card she has taken in tricks this hand.
        var won: [Card] = []
        var score = 0
    }

    static let target = 10
    static let handSize = 6

    /// Seated clockwise: 0 you (bottom), 1 left, 2 the Princess (top), 3 right.
    var players: [Player]
    var trick: [(seat: Int, card: Card)] = []
    var turn: Int?
    var hand = 0
    var dealer = 2
    /// The face-up stock; `stock.first` is the card the next trick's winner takes.
    var stock: [Card] = []
    var trump: Suit = .spades
    var message = "Shuffle up and deal!"
    var banner: String?
    var finished = false
    var trickWinner: Int?
    var winnerSeat: Int?

    var trumpText: String { "Trump \(trump.symbol)" }

    private var playCont: CheckedContinuation<Card, Never>?
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
    /// Highest score so far — the leader (or, at the end, the winner).
    var leaders: [Int] {
        if let w = winnerSeat { return [w] }
        let top = players.map(\.score).max() ?? 0
        return players.indices.filter { players[$0].score == top }
    }

    // MARK: Flow

    func run() async {
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled && winnerSeat == nil {
            await playHand()
        }
        turn = nil
        if let w = winnerSeat {
            message = "Game over! \(players[w].name) wins with \(players[w].score) points."
        }
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
        var deck = Deck.shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].won = []
        }
        stock = []
        message = "Hand \(hand) · \(players[dealer].name) deals six each."
        for _ in 0..<Self.handSize {
            for k in 1...4 {
                players[(dealer + k) % 4].hand.append(deck.removeFirst())
                sound.card()
                await wait(0.05)
            }
        }
        stock = deck
        trump = stock[0].suit
        sound.card()
        sortHands()
        message = "The stock is face up. The \(stock[0].text) is on top — \(trump.symbol) are trumps."
        await wait(1.6)

        var leader = (dealer + 1) % 4
        while !players[leader].hand.isEmpty && !Task.isCancelled {
            trick = []
            trickWinner = nil
            for k in 0..<4 {
                let i = (leader + k) % 4
                turn = i
                let card: Card
                if players[i].isHuman {
                    if Task.isCancelled { return }
                    message = trick.isEmpty
                        ? (stock.isEmpty ? "Lavender's lead. The stock is gone." : "Lavender's lead. The winner takes the \(stock[0].text).")
                        : "Lavender's turn — follow \(trick[0].card.suit.symbol) or trump \(trump.symbol) if she can."
                    card = await withCheckedContinuation { playCont = $0 }
                } else {
                    await wait(0.7)
                    card = choose(i)
                }
                play(i, card)
            }
            turn = nil
            let w = winner()
            players[w].won += trick.map(\.card)
            trickWinner = w
            message = "\(players[w].name) takes the trick."
            await wait(1.2)

            // The winner draws the face-up top card, then the others clockwise.
            if !stock.isEmpty {
                let top = stock[0]
                for k in 0..<4 {
                    let i = (w + k) % 4
                    players[i].hand.append(stock.removeFirst())
                }
                sound.card()
                sortHands()
                message = "\(players[w].name) draws the \(top.text). " + (stock.isEmpty ? "The stock is gone — six tricks left, no more drawing." : "Next up: the \(stock[0].text).")
                await wait(1.1)
            }
            leader = w
        }
        trick = []
        trickWinner = nil
        score()
        await wait(3.6)
        banner = nil
    }

    /// High, Low, Jack, then Game — counted in that order so the first to reach 10 wins outright.
    private func score() {
        var awards: [(label: String, seat: Int)] = []
        for (label, rank) in [("High", 14), ("Low", 2), ("Jack", 11)] {
            if let s = players.indices.first(where: { i in players[i].won.contains { $0.rank == rank && $0.suit == trump } }) {
                awards.append((label, s))
            }
        }
        let counts = players.map { Self.gamePoints($0.won) }
        let best = counts.max() ?? 0
        let tops = counts.indices.filter { counts[$0] == best }
        let gameNote: String
        if tops.count == 1 {
            awards.append(("Game", tops[0]))
            gameNote = "Game: \(players[tops[0]].name) with \(best)"
        } else {
            gameNote = "Game tied at \(best) — nobody scores it"
        }
        for a in awards {
            players[a.seat].score += 1
            if players[a.seat].score >= Self.target && winnerSeat == nil {
                winnerSeat = a.seat
                break
            }
        }
        banner = "Hand \(hand): " + awards.filter { $0.label != "Game" }.map { "\($0.label) \(players[$0.seat].name)" }.joined(separator: " · ")
            + " · " + gameNote
        if awards.contains(where: { $0.seat == 0 }) { sound.chime() }
    }

    static func gamePoints(_ cards: [Card]) -> Int {
        cards.reduce(0) { sum, c in
            sum + (c.rank == 10 ? 10 : c.rank == 14 ? 4 : c.rank == 13 ? 3 : c.rank == 12 ? 2 : c.rank == 11 ? 1 : 0)
        }
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

    /// Leaving mid-game: plays whatever's legal so the game can wind down.
    func abandon() {
        if let c = playCont {
            playCont = nil
            c.resume(returning: legal(0)[0])
        }
    }

    // MARK: Rules

    /// Follow the suit led or play a trump; only if she can do neither may she play anything.
    func legal(_ i: Int) -> [Card] {
        let hand = players[i].hand
        guard let led = trick.first?.card.suit else { return hand }
        let ok = hand.filter { $0.suit == led || $0.suit == trump }
        return ok.isEmpty ? hand : ok
    }

    /// The highest trump takes the trick; otherwise the highest card of the suit led.
    private func winner(_ plays: [(seat: Int, card: Card)]? = nil) -> Int {
        let plays = plays ?? trick
        let suit = plays.contains { $0.card.suit == trump } ? trump : plays[0].card.suit
        return plays.filter { $0.card.suit == suit }.max { $0.card.rank < $1.card.rank }!.seat
    }

    // MARK: Newcomer AI

    /// What a card is worth to whoever captures it: its game points, plus a lot for the scoring trumps.
    private func worth(_ c: Card) -> Double {
        let special = c.suit == trump && (c.rank == 14 || c.rank == 11 || c.rank == 2)
        return Double(Self.gamePoints([c])) + (special ? 12 : c.suit == trump ? 1.5 : 0)
    }

    /// Trumps count as higher than anything else.
    private func strength(_ c: Card) -> Int { c.rank + (c.suit == trump ? 20 : 0) }

    private func choose(_ i: Int) -> Card {
        let options = legal(i)
        if options.count == 1 { return options[0] }
        // What the trick's winner gets on top of the cards: first pick of the face-up stock.
        let prize = stock.first.map { worth($0) * 0.6 + ($0.suit == trump ? 1 : 0) } ?? 0
        let cheapest = options.min { (worth($0), strength($0)) < (worth($1), strength($1)) }!

        if trick.isEmpty {
            // The ace of trump can't lose — cash it whenever there's anything worth taking.
            if let ace = options.first(where: { $0.suit == trump && $0.rank == 14 }), prize >= 2 || stock.isEmpty { return ace }
            if prize >= 3, let ace = options.first(where: { $0.rank == 14 }) { return ace }
            let plain = options.filter { $0.suit != trump && worth($0) < 3 }
            return plain.min { strength($0) < strength($1) } ?? cheapest
        }
        let stake = trick.reduce(0) { $0 + worth($1.card) } + prize
        let wins = options.filter { winner(trick + [(i, $0)]) == i }
        if !wins.isEmpty && (stake >= 2.5 || trick.count == 3) {
            // Last to play: a scoring trump that wins brings itself home.
            if trick.count == 3, let own = wins.first(where: { worth($0) >= 12 }) { return own }
            let safe = wins.filter { worth($0) < 12 || $0.rank == 14 }
            return (safe.isEmpty ? wins : safe).min { strength($0) < strength($1) }!
        }
        // Let it go: throw the card worth the least.
        let losers = options.filter { winner(trick + [(i, $0)]) != i }
        return losers.min { (worth($0), strength($0)) < (worth($1), strength($1)) } ?? cheapest
    }
}

struct CaliforniaJackView: View {
    @Bindable var table: CaliforniaJackTable
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
                Text("\(day) · California Jack · Hand \(table.hand)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text(table.trumpText)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(table.trump.isRed ? .red : .black)
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

                    // The face-up stock: everyone can see the card the next trick's winner takes.
                    if let top = table.stock.first, !table.finished {
                        VStack(spacing: 2) {
                            ZStack {
                                ForEach(1..<min(3, table.stock.count), id: \.self) { k in
                                    RoundedRectangle(cornerRadius: 3.4).fill(.white).frame(width: 34, height: 34 * 1.42)
                                        .overlay(RoundedRectangle(cornerRadius: 3.4).strokeBorder(.gray.opacity(0.5)))
                                        .offset(x: Double(k) * -2, y: Double(k) * -2)
                                }
                                CardView(card: top, width: 34)
                            }
                            Text("STOCK \(table.stock.count)")
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
                        CaliforniaJackSeat(player: player, trump: table.trump, isTurn: table.turn == i, isDealer: table.dealer == i,
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
            let w = 54.0
            let step = hand.count > 1 ? min(w + 4, (geo.size.width - w) / Double(hand.count - 1)) : 0
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
        .frame(height: 90)
    }

    @ViewBuilder private var actionBar: some View {
        if table.finished {
            Text("The california jack game is over for the day.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else {
            HStack {
                Text(table.humanToPlay ? "Lavender's turn — tap a raised card. \(table.human.won.count / 4) trick\(table.human.won.count == 4 ? "" : "s") so far."
                     : (table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " "))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 46)
        }
    }
}

private struct CaliforniaJackSeat: View {
    let player: CaliforniaJackTable.Player
    let trump: Suit
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
            Text("Tricks \(player.won.count / 4)")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            // The scoring trumps she's captured so far this hand.
            let caught = [(14, "A"), (2, "2"), (11, "J")].filter { r in player.won.contains { $0.rank == r.0 && $0.suit == trump } }
            if !caught.isEmpty {
                Text(caught.map { $0.1 + trump.symbol }.joined(separator: " "))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(trump.isRed ? .red : .black)
                    .padding(.horizontal, 6)
                    .background(Color.white, in: Capsule())
            }
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
