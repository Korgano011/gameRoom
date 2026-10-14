import SwiftUI

/// 99 at the salon's card table: you, the Princess and two newcomers. Three cards each; every card played
/// changes the running count, and whoever can't keep it at 99 or under busts and loses a token.
/// Two tokens apiece; lose both and you're out. Nobody bets — 99 is just for fun, so it makes the salon no money.
@Observable final class NinetyNineTable {
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
        var tokens = NinetyNineTable.startTokens
        var isOut: Bool { tokens <= 0 }
    }

    /// One way to play a card: aces count 1 or 11, tens add or take away 10.
    struct Move: Hashable {
        let card: Card
        let total: Int
        let label: String
    }

    static let startTokens = 2
    static let limit = 99

    /// Seated clockwise: 0 you (bottom), 1 left, 2 the Princess (top), 3 right.
    var players: [Player]
    var total = 0
    /// +1 clockwise, -1 after a 4 reverses play.
    var direction = 1
    var discard: [Card] = []
    var stockCount = 0
    var turn: Int?
    var dealer = 3
    var roundNumber = 0
    var message = "Shuffle up and deal!"
    var banner: String?
    /// Flashes over the count when someone busts.
    var bustFlash: String?
    var finished = false
    var winner: Int?
    /// Your card that can be played two ways, waiting for you to pick one.
    var choosing: Card?

    private var stock: [Card] = []
    private var abandoned = false
    private var playCont: CheckedContinuation<Move, Never>?
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
    var top: Card? { discard.last }
    private var alive: [Int] { players.indices.filter { !players[$0].isOut } }

    /// The next player still in the game, in the current direction.
    private func next(_ i: Int) -> Int {
        var j = i
        repeat { j = (j + direction + 4) % 4 } while players[j].isOut && j != i
        return j
    }

    // MARK: Flow

    func run() async {
        try? await Task.sleep(for: .seconds(1.2))
        while alive.count > 1 && !Task.isCancelled {
            await playRound()
        }
        turn = nil
        let w = alive.first ?? 0
        winner = w
        message = "Game over! \(players[w].name) wins the 99 game."
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
        direction = 1
        dealer = next(dealer)
        stock = Deck.shuffled()
        discard = []
        total = 0
        for i in players.indices { players[i].hand = [] }
        message = "Round \(roundNumber). \(players[dealer].name) deals three cards each. The count starts at 0."
        for _ in 0..<3 {
            var i = dealer
            for _ in alive {
                i = next(i)
                players[i].hand.append(stock.removeFirst())
                sound.card()
                await wait(0.07)
            }
        }
        stockCount = stock.count
        sortHands()
        await wait(1.0)

        // The player to the dealer's left goes first.
        var i = next(dealer)
        while true {
            turn = i
            let moves = legalMoves(i)
            if moves.isEmpty {
                await bust(i)
                break
            }
            let move: Move
            if players[i].isHuman && !abandoned {
                message = "Lavender's turn. The count is \(total) — keep it at 99 or under."
                move = await withCheckedContinuation { playCont = $0 }
            } else {
                await wait(0.9)
                move = choose(i, moves)
            }
            await play(i, move)
            i = next(i)
        }
        turn = nil
    }

    private func play(_ i: Int, _ move: Move) async {
        players[i].hand.removeAll { $0.id == move.card.id }
        discard.append(move.card)
        total = move.total
        sound.card()
        let who = players[i].name, s = "s"
        var note = ""
        switch move.card.rank {
        case 4:
            direction = -direction
            note = " Play reverses!"
        case 9: note = " A pass."
        case 13: note = " Straight to 99!"
        default: break
        }
        message = "\(who) play\(s) the \(move.card.text)\(move.label.isEmpty ? "" : " (\(move.label))") — \(total)!" + note
        // A 4 calls "Reverse", a 9 calls "Pass", anything else calls out the new count.
        let call = move.card.rank == 4 ? "Reverse" : move.card.rank == 9 ? "Pass" : "\(total)"
        sound.speak(call, as: voice(i))
        await wait(0.6)
        // Draw back up to three.
        if stock.isEmpty {
            // Everything under the top card is reshuffled into a new stock.
            stock = discard.dropLast().shuffled()
            discard = Array(discard.suffix(1))
        }
        if !stock.isEmpty {
            players[i].hand.append(stock.removeFirst())
            sortHands()
        }
        stockCount = stock.count
        await wait(0.5)
    }

    private func bust(_ i: Int) async {
        let who = players[i].name
        players[i].tokens -= 1
        bustFlash = "BUST!"
        message = "\(who) can't keep the count at 99 or under — she busts and loses a token!"
        sound.beep()
        await wait(1.8)
        bustFlash = nil
        if players[i].isOut {
            banner = "\(who) is out of tokens — she's out of the game!"
        } else {
            banner = "\(players[i].isPrincess ? "Princess" : who) has \(players[i].tokens) token\(players[i].tokens == 1 ? "" : "s") left."
        }
        sound.chime()
        await wait(2.8)
        banner = nil
    }

    private func sortHands() {
        for i in players.indices { players[i].hand.sort { $0.rank * 4 + $0.suit.rawValue < $1.rank * 4 + $1.suit.rawValue } }
    }

    private func voice(_ i: Int) -> Voice {
        players[i].isPrincess ? .princess : (players[i].isKid ? .kidGirl : .girl)
    }

    // MARK: You

    func tap(_ card: Card) {
        guard humanToPlay, human.hand.contains(where: { $0.id == card.id }) else { return }
        let ways = moves(for: card)
        if ways.count == 1 {
            choosing = nil
            submit(ways[0])
        } else if ways.count > 1 {
            choosing = choosing == card ? nil : card
        }
    }

    func pick(_ move: Move) {
        choosing = nil
        submit(move)
    }

    private func submit(_ move: Move) {
        guard let c = playCont else { return }
        playCont = nil
        c.resume(returning: move)
    }

    /// Leaving mid-game: the newcomers play your cards for you and the game winds down.
    func abandon() {
        abandoned = true
        if let c = playCont {
            playCont = nil
            c.resume(returning: choose(0, legalMoves(0)))
        }
    }

    // MARK: Rules

    /// Every legal way to play `card` on the current count (at 99 or under).
    func moves(for card: Card) -> [Move] {
        let options: [(Int, String)]
        switch card.rank {
        case 14: options = [(total + 1, "1"), (total + 11, "11")]
        case 4: options = [(total, "reverse")]
        case 9: options = [(total, "pass")]
        case 10: options = total >= 10 ? [(total + 10, "+10"), (total - 10, "−10")] : [(total + 10, "+10")]
        case 11, 12: options = [(total + 10, "")]
        case 13: options = [(Self.limit, "99")]
        default: options = [(total + card.rank, "")]
        }
        return options.filter { $0.0 <= Self.limit }.map { Move(card: card, total: $0.0, label: $0.1) }
    }

    private func legalMoves(_ i: Int) -> [Move] {
        players[i].hand.flatMap { moves(for: $0) }
    }

    /// What a card does, for the hand tags.
    static func effect(_ card: Card) -> String {
        switch card.rank {
        case 14: "1/11"
        case 4: "⇄ 0"
        case 9: "0"
        case 10: "±10"
        case 11, 12: "+10"
        case 13: "=99"
        default: "+\(card.rank)"
        }
    }

    // MARK: Newcomer AI

    /// Push the count up with plain cards and save the safe ones (kings, nines, fours, tens to subtract) for when they're needed.
    private func choose(_ i: Int, _ moves: [Move]) -> Move {
        let noise = players[i].isKid ? 6.0 : (players[i].isPrincess ? 0.5 : 2.0)
        func score(_ m: Move) -> Double {
            let safe: Double
            switch m.card.rank {
            case 13: safe = 60
            case 9, 4: safe = 40
            case 10 where m.total < total: safe = 35
            default: safe = 0
            }
            return Double(m.total) - safe + Double.random(in: 0..<noise)
        }
        return moves.max { score($0) < score($1) }!
    }
}

struct NinetyNineView: View {
    @Bindable var table: NinetyNineTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color

    /// Where each seat sits around the table (fractions of the table area), clockwise from you.
    private let spots: [CGPoint] = [CGPoint(x: 0.5, y: 0.87), CGPoint(x: 0.13, y: 0.47), CGPoint(x: 0.5, y: 0.13), CGPoint(x: 0.87, y: 0.47)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · 99 · Round \(table.roundNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text("Just for fun · \(NinetyNineTable.startTokens) tokens each")
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

                    // The stock, left of the discard pile.
                    VStack(spacing: 2) {
                        CardView(card: Card(rank: 2, suit: .clubs), faceUp: false, width: w * 0.8)
                        Text("\(table.stockCount) left")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .position(x: size.width * 0.33, y: size.height * 0.45)

                    // The discard pile.
                    ZStack {
                        if table.discard.isEmpty {
                            CardView(card: nil, width: w)
                        }
                        ForEach(Array(table.discard.suffix(4).enumerated()), id: \.element.id) { k, card in
                            CardView(card: card, width: w)
                                .rotationEffect(.degrees(Double((card.id * 37) % 21) - 10))
                                .offset(x: Double(k) * 2, y: Double(k) * -1.5)
                        }
                    }
                    .position(x: size.width * 0.5, y: size.height * 0.45)
                    .animation(.easeOut(duration: 0.2), value: table.discard.count)

                    // The running count and which way play is going.
                    VStack(spacing: 0) {
                        Text("\(table.total)")
                            .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(table.total >= 90 ? .red : .yellow)
                            .contentTransition(.numericText())
                        Image(systemName: table.direction == 1 ? "arrow.clockwise" : "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .position(x: size.width * 0.67, y: size.height * 0.45)
                    .animation(.default, value: table.total)

                    if let flash = table.bustFlash {
                        Text(flash)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.red)
                            .shadow(color: .white, radius: 6)
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
                        NinetyNineSeat(player: player, isTurn: table.turn == i, isDealer: table.dealer == i, winning: table.winner == i)
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.spring(duration: 0.3), value: table.bustFlash)
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

            if let card = table.choosing {
                HStack(spacing: 10) {
                    Text("Lavender plays the \(card.text) as")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    ForEach(table.moves(for: card), id: \.self) { m in
                        Button("\(m.label) → \(m.total)") { table.pick(m) }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                    }
                }
            }

            yourHand
                .padding(.horizontal, 8)

            HStack {
                Text(table.finished ? "The 99 game is over."
                     : table.human.isOut ? "Lavender is out — watching the others finish."
                     : table.humanToPlay ? "Lavender's turn — tap a card to play it. Outlined cards keep the count at 99 or under."
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
        .animation(.default, value: table.choosing)
    }

    /// Your three cards: tap one to play it. Cards that keep the count at 99 or under are outlined.
    private var yourHand: some View {
        HStack(spacing: 8) {
            ForEach(table.human.hand) { card in
                let ok = !table.moves(for: card).isEmpty
                Button { table.tap(card) } label: {
                    CardView(card: card, dim: !table.humanToPlay || !ok, width: 64)
                        .overlay {
                            if table.humanToPlay && ok {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(table.choosing == card ? Color.pink : Color.yellow, lineWidth: 3)
                            }
                        }
                        .overlay(alignment: .top) {
                            Text(NinetyNineTable.effect(card))
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.pink))
                                .offset(y: -10)
                        }
                }
                .buttonStyle(.plain)
                .offset(y: table.humanToPlay ? -10 : 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .bottom)
    }
}

private struct NinetyNineSeat: View {
    let player: NinetyNineTable.Player
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
            .opacity(player.isOut ? 0.4 : 1)
            Text(player.isPrincess ? "Princess" : player.isHuman ? "Lavender" : player.name)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // Tokens left: a chip for each.
            HStack(spacing: 3) {
                if player.isOut {
                    Text("OUT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.red)
                } else {
                    ForEach(0..<NinetyNineTable.startTokens, id: \.self) { k in
                        Circle()
                            .fill(k < player.tokens ? Color.yellow : Color.white.opacity(0.15))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])))
                            .frame(width: 13, height: 13)
                    }
                }
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
