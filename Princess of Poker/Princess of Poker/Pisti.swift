import SwiftUI

/// Pişti at the salon's card table: you, the Princess and two newcomers, each playing for herself.
/// Four cards each, four to the middle; match the top card's rank (or play a jack) to capture the pile.
/// Nobody bets — like hearts, pişti is just for fun, so it makes the salon no money.
@Observable final class PistiTable {
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
        /// Cards captured this round.
        var captured: [Card] = []
        /// Pişti bonus points this round (10 each, 20 for a jack on a lone jack).
        var pistiPoints = 0
        var score = 0
    }

    /// The first player to this many points wins.
    static let gameTarget = 100

    /// Seated clockwise: 0 you (bottom), 1 left, 2 the Princess (top), 3 right. Play goes counterclockwise.
    var players: [Player]
    /// The middle pile, bottom first. The dealer's first three are face down.
    var pile: [Card] = []
    /// How many cards at the bottom of the pile are still face down.
    var faceDown = 0
    var turn: Int?
    var dealer = 1
    var roundNumber = 0
    var cardsLeft = 0
    var lastCapturer: Int?
    var message = "Shuffle up and deal!"
    var banner: String?
    /// Flashes over the pile after a pişti.
    var pistiFlash: String?
    var finished = false
    var winner: Int?

    private var deck: [Card] = []
    /// Ranks seen face up this round, so the newcomers can play safe.
    private var seen: [Int: Int] = [:]
    private var abandoned = false
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
    var top: Card? { pile.count > faceDown ? pile.last : nil }
    /// Counterclockwise: from you to the player on your right.
    static func next(_ i: Int) -> Int { (i + 3) % 4 }

    // MARK: Flow

    func run() async {
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled && !abandoned {
            await playRound()
            if players.contains(where: { $0.score >= Self.gameTarget }) { break }
        }
        turn = nil
        let best = players.indices.max { players[$0].score < players[$1].score }!
        winner = best
        message = "Game over! \(players[best].name) wins with \(players[best].score) points."
        sound.chime()
        finished = true
        try? await Task.sleep(for: .seconds(3.0))
        onFinished?()
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s / pace))
    }

    private func playRound() async {
        roundNumber += 1
        dealer = Self.next(dealer)
        deck = Deck.shuffled()
        seen = [:]
        pile = []
        faceDown = 0
        lastCapturer = nil
        for i in players.indices {
            players[i].hand = []
            players[i].captured = []
            players[i].pistiPoints = 0
        }
        message = "Round \(roundNumber). \(players[dealer].name) deals."
        await deal()
        // Three face down in the middle, then one face up — never a jack.
        for _ in 0..<3 {
            pile.append(deck.removeFirst())
            faceDown += 1
            sound.card()
            await wait(0.15)
        }
        while deck[0].rank == 11 {
            let j = deck.removeFirst()
            deck.insert(j, at: Int.random(in: 4...deck.count))
            message = "A jack turned up — it goes back in the deck."
        }
        let up = deck.removeFirst()
        pile.append(up)
        seen[up.rank, default: 0] += 1
        cardsLeft = deck.count
        sound.card()
        await wait(0.8)

        var i = Self.next(dealer)
        while !abandoned || players.contains(where: { !$0.hand.isEmpty }) {
            if players.allSatisfy({ $0.hand.isEmpty }) {
                if deck.isEmpty { break }
                message = "\(players[dealer].name) deals four more each."
                await deal()
                i = Self.next(dealer)
            }
            turn = i
            let card: Card
            if players[i].isHuman && !abandoned {
                message = top.map { "Lavender's turn. Match the \($0.rankText) or play a jack to take the pile." } ?? "Lavender's turn — the pile is empty."
                card = await withCheckedContinuation { playCont = $0 }
            } else {
                await wait(0.8)
                card = players[i].isHuman ? players[i].hand[0] : choose(i)
            }
            await play(i, card)
            i = Self.next(i)
        }
        turn = nil

        // The last capturer sweeps whatever is left.
        if !pile.isEmpty, let l = lastCapturer {
            players[l].captured += pile
            pile = []
            faceDown = 0
            message = "\(players[l].name) made the last capture and takes the rest of the pile."
            sound.card()
            await wait(1.4)
        }

        // Tally the round.
        let counts = players.map(\.captured.count)
        let most = counts.max() ?? 0
        let majority = counts.filter { $0 == most }.count == 1 ? counts.firstIndex(of: most) : nil
        var lines: [String] = []
        for k in players.indices {
            let pts = players[k].captured.reduce(0) { $0 + Self.points($1) } + players[k].pistiPoints + (majority == k ? 3 : 0)
            players[k].score += pts
            lines.append("\(players[k].isPrincess ? "Princess" : players[k].name) +\(pts)")
        }
        banner = "Round \(roundNumber): " + lines.joined(separator: " · ")
            + (majority.map { " · Most cards: \(players[$0].isPrincess ? "Princess" : players[$0].name) (\(most))" } ?? " · Most cards tied — no bonus")
        sound.chime()
        await wait(3.6)
        banner = nil
    }

    /// Four cards each, counterclockwise from the dealer's right.
    private func deal() async {
        for _ in 0..<4 {
            for k in 0..<4 {
                var i = dealer
                for _ in 0...k { i = Self.next(i) }
                players[i].hand.append(deck.removeFirst())
                sound.card()
                await wait(0.06)
            }
        }
        cardsLeft = deck.count
        for i in players.indices { players[i].hand.sort { $0.rank * 4 + $0.suit.rawValue < $1.rank * 4 + $1.suit.rawValue } }
    }

    private func play(_ i: Int, _ card: Card) async {
        players[i].hand.removeAll { $0.id == card.id }
        seen[card.rank, default: 0] += 1
        let before = top
        let lone = pile.count == 1
        pile.append(card)
        sound.card()
        let who = players[i].name, s = "s"
        guard let before, card.rank == before.rank || card.rank == 11 else {
            message = "\(who) play\(s) the \(card.text)."
            await wait(0.5)
            return
        }
        // A capture.
        await wait(0.6)
        var bonus = 0
        if lone && card.rank == before.rank {
            bonus = card.rank == 11 ? 20 : 10
            players[i].pistiPoints += bonus
        }
        let n = pile.count
        players[i].captured += pile
        pile = []
        faceDown = 0
        lastCapturer = i
        if bonus > 0 {
            pistiFlash = bonus == 20 ? "JACK PİŞTİ! +20" : "PİŞTİ! +10"
            message = "\(who) score\(s) a \(bonus == 20 ? "jack pişti" : "pişti") with the \(card.text)! +\(bonus)"
            sound.chime()
            await wait(1.6)
            pistiFlash = nil
        } else {
            message = "\(who) take\(s) the pile (\(n) cards) with the \(card.text)."
            sound.coin()
            await wait(1.0)
        }
    }

    func tap(_ card: Card) {
        guard let c = playCont, human.hand.contains(where: { $0.id == card.id }) else { return }
        playCont = nil
        c.resume(returning: card)
    }

    /// Leaving mid-game: plays your first card and lets the game wind down.
    func abandon() {
        abandoned = true
        if let c = playCont {
            playCont = nil
            c.resume(returning: human.hand[0])
        }
    }

    // MARK: Rules

    /// Each jack and ace 1, the 2♣ 2, the 10♦ 3.
    static func points(_ c: Card) -> Int {
        if c.rank == 11 || c.rank == 14 { return 1 }
        if c.rank == 2 && c.suit == .clubs { return 2 }
        if c.rank == 10 && c.suit == .diamonds { return 3 }
        return 0
    }

    func capturedPoints(_ i: Int) -> Int {
        players[i].captured.reduce(0) { $0 + Self.points($1) } + players[i].pistiPoints
    }

    // MARK: Newcomer AI

    private func choose(_ i: Int) -> Card {
        let hand = players[i].hand
        let pileValue = pile.count + pile.reduce(0) { $0 + Self.points($1) } * 2
        // Match the top card if possible (a pişti if it's alone).
        if let t = top, let match = hand.filter({ $0.rank == t.rank && $0.rank != 11 }).first { return match }
        if let t = top, t.rank == 11, pile.count == 1, let j = hand.first(where: { $0.rank == 11 }) { return j }
        let others = hand.filter { $0.rank != 11 }
        // A jack takes a pile worth having.
        if let j = hand.first(where: { $0.rank == 11 }), !pile.isEmpty, pileValue >= 6 || others.isEmpty { return j }
        guard !others.isEmpty else { return hand[0] }
        // Otherwise lay the card least likely to be matched: ranks already seen (or paired in hand), low value.
        let risk = { (c: Card) -> Double in
            let out = 4 - (self.seen[c.rank] ?? 0) - hand.filter { $0.rank == c.rank }.count
            return Double(max(0, out)) * (self.pile.isEmpty ? 2 : 1) + Double(Self.points(c)) * 1.5 + Double.random(in: 0..<0.5)
        }
        return others.min { risk($0) < risk($1) }!
    }
}

struct PistiView: View {
    @Bindable var table: PistiTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color

    /// Where each seat sits around the table (fractions of the table area), clockwise from you.
    private let spots: [CGPoint] = [CGPoint(x: 0.5, y: 0.87), CGPoint(x: 0.13, y: 0.47), CGPoint(x: 0.5, y: 0.13), CGPoint(x: 0.87, y: 0.47)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Pişti · Round \(table.roundNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text("Just for fun · to \(PistiTable.gameTarget)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.pink)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                let w = min(58, size.width * 0.13)
                ZStack {
                    Ellipse()
                        .fill(RadialGradient(colors: [felt.opacity(0.95), felt.opacity(0.7)], center: .center, startRadius: 10, endRadius: size.width * 0.6))
                        .overlay(Ellipse().strokeBorder(Color(red: 0.45, green: 0.25, blue: 0.1), lineWidth: 14))
                        .overlay(Ellipse().strokeBorder(Color.pink.opacity(0.5), lineWidth: 2).padding(7))
                        .padding(.horizontal, size.width * 0.12)
                        .padding(.vertical, size.height * 0.12)

                    // The deck, beside the pile.
                    if table.cardsLeft > 0 {
                        VStack(spacing: 2) {
                            CardView(card: Card(rank: 2, suit: .clubs), faceUp: false, width: w * 0.8)
                            Text("\(table.cardsLeft) left")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .position(x: size.width * 0.33, y: size.height * 0.45)
                    }

                    // The middle pile: face-down cards peek out under the top card.
                    ZStack {
                        if table.pile.isEmpty {
                            CardView(card: nil, width: w)
                        }
                        ForEach(Array(table.pile.suffix(6).enumerated()), id: \.element.id) { k, card in
                            let index = table.pile.count - min(6, table.pile.count) + k
                            CardView(card: card, faceUp: index >= table.faceDown, width: w)
                                .rotationEffect(.degrees(Double((card.id * 37) % 21) - 10))
                                .offset(x: Double(k) * 2, y: Double(k) * -1.5)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if table.pile.count > 1 {
                            Text("\(table.pile.count)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .background(Capsule().fill(Color.yellow))
                                .offset(y: 12)
                        }
                    }
                    .position(x: size.width * 0.5, y: size.height * 0.45)
                    .animation(.easeOut(duration: 0.2), value: table.pile.count)

                    if let flash = table.pistiFlash {
                        Text(flash)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                            .shadow(color: .pink, radius: 6)
                            .position(x: size.width * 0.5, y: size.height * 0.28)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Text(table.message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: size.width * 0.5)
                        .position(x: size.width * 0.5, y: size.height * 0.68)

                    ForEach(Array(table.players.enumerated()), id: \.offset) { i, player in
                        PistiSeat(player: player, points: table.capturedPoints(i), isTurn: table.turn == i,
                                  isDealer: table.dealer == i, winning: table.winner == i)
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.spring(duration: 0.3), value: table.pistiFlash)
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

            HStack {
                Text(table.finished ? "The pişti game is over for the night."
                     : table.humanToPlay ? "Lavender's turn — tap a card to play it. Jacks take the whole pile!"
                     : (table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " "))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 46)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), Color(red: 0.08, green: 0.0, blue: 0.1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.default, value: table.banner)
    }

    /// Your four cards: tap one to play it. Cards that would capture are outlined.
    private var yourHand: some View {
        HStack(spacing: 8) {
            ForEach(table.human.hand) { card in
                let captures = table.top.map { card.rank == $0.rank || card.rank == 11 } ?? false
                Button { table.tap(card) } label: {
                    CardView(card: card, dim: !table.humanToPlay, width: 64)
                        .overlay {
                            if table.humanToPlay && captures {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(Color.yellow, lineWidth: 3)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if PistiTable.points(card) > 0 {
                                Text("\(PistiTable.points(card))")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(Circle().fill(Color.pink))
                                    .offset(x: 6, y: -6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .offset(y: table.humanToPlay ? -10 : 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .bottom)
    }
}

private struct PistiSeat: View {
    let player: PistiTable.Player
    let points: Int
    let isTurn: Bool
    let isDealer: Bool
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
            Text("\(player.score) pts")
                .font(.system(size: 12, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.yellow)
            Text("\(player.captured.count) cards · +\(points)")
                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
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
