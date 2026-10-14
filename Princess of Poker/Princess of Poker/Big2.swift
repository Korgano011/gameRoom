import SwiftUI

/// Big Two at the salon's card table: you, the Princess and two newcomers, each playing for herself.
/// Thirteen cards each; beat the last play with a higher combination of the same size, or pass.
/// The first to shed every card wins the deal; the others take penalty points for the cards they hold.
/// Nobody bets — like hearts, Big Two is just for fun, so it makes the salon no money.
@Observable final class Big2Table {
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
        /// Passed since the last play in this trick.
        var passed = false
        /// Penalty points — lowest wins.
        var score = 0
    }

    /// A legal play: a single, pair, triple or five-card hand.
    struct Combo {
        enum Kind: Int { case single, pair, triple, straight, flush, fullHouse, quads, straightFlush }
        let cards: [Card]
        let kind: Kind
        /// Higher beats lower among plays of the same size.
        let key: Int

        var name: String {
            switch kind {
            case .single: "single"
            case .pair: "pair"
            case .triple: "triple"
            case .straight: "straight"
            case .flush: "flush"
            case .fullHouse: "full house"
            case .quads: "four of a kind"
            case .straightFlush: "straight flush"
            }
        }

        func beats(_ other: Combo) -> Bool { cards.count == other.cards.count && key > other.key }
    }

    /// The game ends once anyone reaches this many penalty points.
    static let gameTarget = 50

    /// Seated clockwise: 0 you (bottom), 1 left, 2 the Princess (top), 3 right.
    var players: [Player]
    /// The play to beat in this trick, and who made it.
    var current: Combo?
    var currentBy: Int?
    var turn: Int?
    var dealNumber = 0
    var message = "Shuffle up and deal!"
    var banner: String?
    /// "One card!" — flashes when someone is down to her last card.
    var flash: String?
    var finished = false
    var winner: Int?
    /// The cards you've picked to play.
    var selected: Set<Int> = []
    /// The 3♦ must be in the very first play of a deal.
    private(set) var mustPlayThreeOfDiamonds = false

    private var abandoned = false
    private var playCont: CheckedContinuation<[Card], Never>?
    /// Who broke the single-card rule last, and whose last card she let through.
    private var careless: (by: Int, victim: Int)?
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
    /// Clockwise: from you to the player on your left.
    static func next(_ i: Int) -> Int { (i + 1) % 4 }

    // MARK: Card order

    /// 3 lowest … A, then 2 highest.
    static func rankValue(_ c: Card) -> Int { c.rank == 2 ? 12 : c.rank - 3 }
    /// ♦ < ♣ < ♥ < ♠
    static func suitValue(_ s: Suit) -> Int {
        switch s {
        case .diamonds: 0
        case .clubs: 1
        case .hearts: 2
        case .spades: 3
        }
    }
    static func value(_ c: Card) -> Int { rankValue(c) * 4 + suitValue(c.suit) }
    static let threeOfDiamonds = Card(rank: 3, suit: .diamonds)

    // MARK: Flow

    func run() async {
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled && !abandoned {
            await playDeal()
            if players.contains(where: { $0.score >= Self.gameTarget }) { break }
        }
        turn = nil
        let best = players.indices.min { players[$0].score < players[$1].score }!
        winner = best
        message = "Game over! \(players[best].name) wins with just \(players[best].score) penalty points."
        sound.chime()
        finished = true
        try? await Task.sleep(for: .seconds(3.0))
        onFinished?()
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s / pace))
    }

    private func playDeal() async {
        dealNumber += 1
        current = nil
        currentBy = nil
        careless = nil
        selected = []
        var deck = Deck.shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].passed = false
        }
        message = "Deal \(dealNumber). Thirteen cards each."
        for _ in 0..<13 {
            for i in players.indices {
                players[i].hand.append(deck.removeFirst())
            }
            sound.card()
            await wait(0.05)
        }
        // Sorted by suit, lowest to highest (♦ ♣ ♥ ♠), then by rank within each suit.
        for i in players.indices { players[i].hand.sort { Self.suitValue($0.suit) * 13 + Self.rankValue($0) < Self.suitValue($1.suit) * 13 + Self.rankValue($1) } }
        var i = players.firstIndex { $0.hand.contains(Self.threeOfDiamonds) }!
        mustPlayThreeOfDiamonds = true
        message = "\(players[i].name) has the 3♦ and leads."
        await wait(1.2)

        var out: Int?
        while out == nil {
            turn = i
            let leading = current == nil
            let cards: [Card]
            if players[i].isHuman && !abandoned {
                message = leading
                    ? (mustPlayThreeOfDiamonds ? "Lavender's lead. Her play must include the 3♦." : "Lavender controls the table — lead anything.")
                    : "Beat the \(current!.name) with \(current!.cards.count) higher card\(current!.cards.count == 1 ? "" : "s"), or pass."
                cards = await withCheckedContinuation { playCont = $0 }
            } else {
                await wait(0.9)
                cards = choose(i)
            }
            noteCareless(i, cards)
            if cards.isEmpty {
                players[i].passed = true
                message = "\(players[i].name) passes."
                sound.beep()
                await wait(0.5)
                // Everyone else passed: the last to play takes control.
                if let by = currentBy, players.indices.filter({ $0 != by }).allSatisfy({ players[$0].passed }) {
                    await wait(0.4)
                    current = nil
                    for k in players.indices { players[k].passed = false }
                    message = "Everyone passed — \(players[by].name) controls the table."
                    await wait(1.0)
                    i = by
                    continue
                }
            } else {
                let combo = Self.combo(cards)!
                players[i].hand.removeAll { c in cards.contains(c) }
                current = combo
                currentBy = i
                mustPlayThreeOfDiamonds = false
                for k in players.indices { players[k].passed = false }
                sound.card()
                message = "\(players[i].name) plays " + (combo.cards.count == 1 ? "the \(cards[0].text)" : "a \(combo.name)") + "."
                if players[i].hand.isEmpty {
                    out = i
                    break
                }
                if players[i].hand.count == 1 {
                    flash = "\(players[i].isPrincess ? "Princess" : players[i].name): one card!"
                    sound.chime()
                    await wait(1.2)
                    flash = nil
                } else {
                    await wait(0.4)
                }
            }
            i = Self.next(i)
        }
        turn = nil
        selected = []

        // Penalties for the cards still held.
        let w = out!
        var pen = players.map { Self.penalty($0.hand.count) }
        pen[w] = 0
        var lines: [String] = []
        if let c = careless, c.victim == w, c.by != w {
            // The careless player let the last card through: she pays for the whole table.
            let total = pen.reduce(0, +)
            pen = pen.indices.map { $0 == c.by ? total : 0 }
            lines.append("\(players[c.by].name) didn't block with her highest single and pays for everyone")
        }
        for k in players.indices where k != w {
            players[k].score += pen[k]
        }
        banner = "\(players[w].name) is out! " + lines.map { $0 + ". " }.joined()
            + players.indices.filter { $0 != w }.map { "\(players[$0].isPrincess ? "Princess" : players[$0].name) +\(pen[$0])" }.joined(separator: " · ")
        sound.chime()
        await wait(4.0)
        banner = nil
    }

    /// 1–7 cards: 1 each; 8–9: 2 each; 10–12: 3 each; all 13: 4 each.
    static func penalty(_ n: Int) -> Int {
        switch n {
        case 0: 0
        case 1...7: n
        case 8...9: n * 2
        case 10...12: n * 3
        default: n * 4
        }
    }

    /// The single-card rule: with the next player down to one card, you must block with your highest single.
    private func noteCareless(_ i: Int, _ cards: [Card]) {
        // Her turn came and she didn't go out: whoever let her through is off the hook.
        if let c = careless, c.victim == i, cards.count != players[i].hand.count { careless = nil }
        let victim = Self.next(i)
        guard players[victim].hand.count == 1, current == nil || current!.cards.count == 1 else {
            if !cards.isEmpty { careless = nil }
            return
        }
        let highest = players[i].hand.max { Self.value($0) < Self.value($1) }!
        let blocked: Bool
        if cards.isEmpty {
            // Passing is fine only if even your highest single can't beat the table.
            blocked = current.map { Self.value(highest) <= $0.key } ?? false
        } else if cards.count == 1 {
            blocked = cards[0] == highest
        } else {
            blocked = true
        }
        if blocked { if !cards.isEmpty { careless = nil } } else { careless = (i, victim) }
    }

    // MARK: Your play

    func toggle(_ card: Card) {
        guard humanToPlay else { return }
        if selected.contains(card.id) { selected.remove(card.id) } else { selected.insert(card.id) }
    }

    var selectedCards: [Card] { human.hand.filter { selected.contains($0.id) } }

    /// Why the picked cards can't be played right now (nil when they can).
    var selectionProblem: String? {
        let cards = selectedCards
        if cards.isEmpty { return "Pick cards for Lavender to play." }
        guard let c = Self.combo(cards) else { return "That's not a single, pair, triple or five-card hand." }
        if mustPlayThreeOfDiamonds && !cards.contains(Self.threeOfDiamonds) { return "The first play must include the 3♦." }
        if let cur = current {
            if cur.cards.count != cards.count { return "Lavender must play \(cur.cards.count) card\(cur.cards.count == 1 ? "" : "s")." }
            if !c.beats(cur) { return "That doesn't beat the \(cur.name)." }
        }
        return nil
    }

    var canPass: Bool { humanToPlay && current != nil }
    /// The next player is down to one card and the table is singles: you're expected to block.
    var mustBlock: Bool { players[Self.next(0)].hand.count == 1 && (current == nil || current!.cards.count == 1) }

    func playSelected() {
        guard let c = playCont, selectionProblem == nil else { return }
        let cards = selectedCards
        playCont = nil
        selected = []
        c.resume(returning: cards)
    }

    func pass() {
        guard let c = playCont, current != nil else { return }
        playCont = nil
        selected = []
        c.resume(returning: [])
    }

    /// Leaving mid-game: your seat plays itself and the game winds down.
    func abandon() {
        abandoned = true
        if let c = playCont {
            playCont = nil
            c.resume(returning: choose(0))
        }
    }

    // MARK: Combinations

    static func combo(_ raw: [Card]) -> Combo? {
        let cards = raw.sorted { value($0) < value($1) }
        let ranks = cards.map(rankValue)
        let top = cards.last.map(value) ?? 0
        switch cards.count {
        case 1:
            return Combo(cards: cards, kind: .single, key: top)
        case 2:
            return ranks[0] == ranks[1] ? Combo(cards: cards, kind: .pair, key: top) : nil
        case 3:
            return Set(ranks).count == 1 ? Combo(cards: cards, kind: .triple, key: ranks[0]) : nil
        case 5:
            let flush = Set(cards.map(\.suit)).count == 1
            let straight = straightKey(cards)
            let counts = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
            if let s = straight, flush { return Combo(cards: cards, kind: .straightFlush, key: 40_000 + s) }
            if let quad = counts.first(where: { $0.value == 4 })?.key { return Combo(cards: cards, kind: .quads, key: 30_000 + quad) }
            if counts.count == 2, let trip = counts.first(where: { $0.value == 3 })?.key {
                return Combo(cards: cards, kind: .fullHouse, key: 20_000 + trip)
            }
            if flush { return Combo(cards: cards, kind: .flush, key: 10_000 + suitValue(cards[0].suit) * 100 + rankValue(cards.last!)) }
            if let s = straight { return Combo(cards: cards, kind: .straight, key: s) }
            return nil
        default:
            return nil
        }
    }

    /// Straights run 3-4-5-6-7 (lowest) up to 10-J-Q-K-A, then A-2-3-4-5, then 2-3-4-5-6 (highest);
    /// ties go to the suit of the top card.
    private static func straightKey(_ cards: [Card]) -> Int? {
        let natural = Set(cards.map(\.rank))
        guard natural.count == 5 else { return nil }
        let lo = natural.min()!, hi = natural.max()!
        if hi - lo == 4 && lo >= 3 {
            let topCard = cards.first { $0.rank == hi }!
            return (lo - 3) * 4 + suitValue(topCard.suit)
        }
        let two = cards.first { $0.rank == 2 }
        if natural == [14, 2, 3, 4, 5], let two { return 8 * 4 + suitValue(two.suit) }
        if natural == [2, 3, 4, 5, 6], let two { return 9 * 4 + suitValue(two.suit) }
        return nil
    }

    /// Every legal play in a hand.
    static func allCombos(_ hand: [Card]) -> [Combo] {
        var out = hand.compactMap { combo([$0]) }
        let byRank = Dictionary(grouping: hand, by: rankValue)
        for group in byRank.values {
            for a in 0..<group.count { for b in (a + 1)..<max(a + 1, group.count) { out.append(combo([group[a], group[b]])!) } }
            if group.count >= 3 {
                for a in 0..<group.count { for b in (a + 1)..<group.count { for c in (b + 1)..<max(b + 1, group.count) {
                    out.append(combo([group[a], group[b], group[c]])!)
                } } }
            }
        }
        let n = hand.count
        if n >= 5 {
            for a in 0..<n { for b in (a + 1)..<n { for c in (b + 1)..<n { for d in (c + 1)..<n { for e in (d + 1)..<n {
                if let k = combo([hand[a], hand[b], hand[c], hand[d], hand[e]]) { out.append(k) }
            } } } } }
        }
        return out
    }

    // MARK: Newcomer AI

    private func choose(_ i: Int) -> [Card] {
        let hand = players[i].hand
        let combos = Self.allCombos(hand)
        let block = players[Self.next(i)].hand.count == 1
        // Low cards cost more to hold onto; spending 2s and big hands early is wasteful.
        let cost = { (c: Combo) -> Double in
            Double(c.cards.map(Self.rankValue).max()!) + (c.cards.contains { $0.rank == 2 } ? 6 : 0) - Double(c.cards.count) * 1.5
        }
        if let cur = current {
            let beating = combos.filter { $0.beats(cur) }
            guard !beating.isEmpty else { return [] }
            if block && cur.cards.count == 1 {
                let high = beating.filter { $0.cards.count == 1 }.max { $0.key < $1.key }!
                return high.cards
            }
            // Keep pairs and five-card hands together when beating a single.
            let breaks = { (c: Combo) -> Double in
                c.cards.count < 5 ? Double(c.cards.filter { card in hand.filter { Self.rankValue($0) == Self.rankValue(card) }.count > c.cards.count }.count) * 3 : 0
            }
            let pick = beating.min { cost($0) + breaks($0) < cost($1) + breaks($1) }!
            // Pass now and then rather than burn a 2 when nobody's close to going out.
            let danger = players.indices.contains { $0 != i && players[$0].hand.count <= 3 }
            if pick.cards.contains(where: { $0.rank == 2 }) && !danger && hand.count > 4 && Double.random(in: 0..<1) < 0.6 { return [] }
            return pick.cards
        }
        // Leading: get rid of the lowest card in the biggest combination it fits.
        let lowest = mustPlayThreeOfDiamonds ? Self.threeOfDiamonds : hand.min { Self.value($0) < Self.value($1) }!
        let withLowest = combos.filter { $0.cards.contains(lowest) }
        if block {
            if let multi = combos.filter({ $0.cards.count > 1 }).min(by: { cost($0) < cost($1) }) { return multi.cards }
            if !mustPlayThreeOfDiamonds { return [hand.max { Self.value($0) < Self.value($1) }!] }
        }
        let best = withLowest.max { a, b in
            a.cards.count != b.cards.count ? a.cards.count < b.cards.count : a.key > b.key
        }
        return best?.cards ?? [lowest]
    }
}

struct Big2View: View {
    @Bindable var table: Big2Table
    /// "Day 3 · Morning"
    let day: String
    let felt: Color

    /// Where each seat sits around the table (fractions of the table area), clockwise from you.
    private let spots: [CGPoint] = [CGPoint(x: 0.5, y: 0.87), CGPoint(x: 0.13, y: 0.47), CGPoint(x: 0.5, y: 0.13), CGPoint(x: 0.87, y: 0.47)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Big Two · Deal \(table.dealNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text("Just for fun · to \(Big2Table.gameTarget)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.pink)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                let w = min(50, size.width * 0.11)
                ZStack {
                    Ellipse()
                        .fill(RadialGradient(colors: [felt.opacity(0.95), felt.opacity(0.7)], center: .center, startRadius: 10, endRadius: size.width * 0.6))
                        .overlay(Ellipse().strokeBorder(Color(red: 0.45, green: 0.25, blue: 0.1), lineWidth: 14))
                        .overlay(Ellipse().strokeBorder(Color.pink.opacity(0.5), lineWidth: 2).padding(7))
                        .padding(.horizontal, size.width * 0.12)
                        .padding(.vertical, size.height * 0.12)

                    // The play to beat.
                    VStack(spacing: 4) {
                        if let cur = table.current {
                            HStack(spacing: -w * 0.35) {
                                ForEach(cur.cards) { card in CardView(card: card, width: w) }
                            }
                            Text("\(table.currentBy.map { table.players[$0].isPrincess ? "Princess" : table.players[$0].isHuman ? "Lavender" : table.players[$0].name } ?? "") · \(cur.name)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .background(Capsule().fill(Color.yellow))
                        } else {
                            CardView(card: nil, width: w)
                        }
                    }
                    .position(x: size.width * 0.5, y: size.height * 0.45)
                    .animation(.easeOut(duration: 0.2), value: table.current?.key)

                    if let flash = table.flash {
                        Text(flash)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                            .shadow(color: .pink, radius: 6)
                            .position(x: size.width * 0.5, y: size.height * 0.27)
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
                        Big2Seat(player: player, isTurn: table.turn == i, winning: table.winner == i)
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.spring(duration: 0.3), value: table.flash)
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

            HStack(spacing: 10) {
                Text(table.finished ? "The Big Two game is over."
                     : table.humanToPlay ? (table.mustBlock ? "Left has one card — Lavender must block with her highest single!" : (table.selectionProblem ?? "Lavender is ready to play!"))
                     : (table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " "))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(table.humanToPlay && table.mustBlock ? .yellow : .white.opacity(0.75))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
                if table.humanToPlay {
                    Button("Pass") { table.pass() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .disabled(!table.canPass)
                    Button("Play") { table.playSelected() }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .disabled(table.selectionProblem != nil)
                }
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

    /// Your thirteen cards in suit groups, lowest suit to highest (♦ ♣ ♥ ♠), with a gap and a suit tag
    /// between groups: tap to pick, tap again to put back.
    private var yourHand: some View {
        GeometryReader { geo in
            let hand = table.human.hand.sorted {
                Big2Table.suitValue($0.suit) * 13 + Big2Table.rankValue($0) < Big2Table.suitValue($1.suit) * 13 + Big2Table.rankValue($1)
            }
            let n = max(1, hand.count)
            let groups = max(1, Set(hand.map(\.suit)).count)
            let gap = 16.0
            let w = min(56.0, geo.size.width / 5)
            let step = n > 1 ? min(w + 4, (geo.size.width - w - gap * Double(groups - 1)) / Double(n - 1)) : 0
            // Each card's x: its index times the step, plus a gap for every suit change before it.
            let xs: [Double] = hand.indices.map { k in
                Double(k) * step + gap * Double(hand.prefix(k + 1).indices.dropFirst().filter { hand[$0].suit != hand[$0 - 1].suit }.count)
            }
            ZStack(alignment: .bottomLeading) {
                ForEach(Array(hand.enumerated()), id: \.element.id) { k, card in
                    let picked = table.selected.contains(card.id)
                    Button { table.toggle(card) } label: {
                        CardView(card: card, dim: !table.humanToPlay, width: w)
                            .overlay {
                                if picked { RoundedRectangle(cornerRadius: 5).strokeBorder(Color.yellow, lineWidth: 3) }
                            }
                    }
                    .buttonStyle(.plain)
                    .offset(x: xs[k], y: picked ? -18 : 0)
                    .overlay(alignment: .topLeading) {
                        // The suit tag above the first card of each group.
                        if k == 0 || hand[k - 1].suit != card.suit {
                            Text(card.suit.symbol)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(card.suit.isRed ? Color(red: 1, green: 0.45, blue: 0.5) : .white)
                                .offset(x: xs[k] + 4, y: -20)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            .animation(.easeOut(duration: 0.15), value: table.selected)
            .animation(.easeOut(duration: 0.2), value: hand.count)
        }
        .frame(height: 120)
    }
}

private struct Big2Seat: View {
    let player: Big2Table.Player
    let isTurn: Bool
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
                if player.passed {
                    Text("PASS")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.white))
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
            Text("\(player.hand.count) card\(player.hand.count == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(player.hand.count == 1 ? .yellow : .white.opacity(0.7))
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
