import SwiftUI

/// Blackjack at the salon's card table: the house deals and banks, everyone else plays against her hand.
/// The Princess is normally the house; you can choose to be the house instead, and then the Princess plays a seat.
/// Real money: $50 buy-ins, and a newcomer who goes broke or doubles up to $100 is beamed back down and turned back.
@Observable final class BlackjackTable {
    struct Hand {
        var cards: [Card] = []
        var bet = 0
        var doubled = false
        /// A hand made by splitting a pair (21 on two cards isn't a blackjack).
        var fromSplit = false
        var done = false
        /// Already paid or collected (blackjack or bust).
        var settled = false
    }

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
        var stack = HoldemTable.buyIn
        var hands: [Hand] = []
        var seated = true
        var note = ""
        /// 0…1: how big she bets and how often she takes a chance.
        var aggression = 0.5
    }

    enum Move { case hit, stand, double, split }

    static let betChoices = [5, 10, 25]
    static let lastCallHand = 40

    /// 0 is you; the newcomers follow; the Princess is last.
    var players: [Player]
    /// You chose to be the house: you deal, and the Princess plays a seat.
    private(set) var youAreHouse = false
    /// Waiting for you to choose: player or house.
    var choosingRole: Bool { roleCont != nil }
    var dealerCards: [Card] = []
    var holeShown = false
    /// What the dealer just said ("Bust", "I have blackjack.").
    var dealerLine: String?
    var turn: Int?
    var activeHand = 0
    var handNumber = 0
    var message = "Will Lavender play, or be the house?"
    var banner: String?
    var departures: [HoldemTable.Departure] = []
    var winners: Set<Int> = []
    var finished = false
    /// Your bet for the next hand (kept from hand to hand).
    var humanBet = 5

    private var deck: [Card] = []
    private var roleCont: CheckedContinuation<Bool, Never>?
    private var betCont: CheckedContinuation<Void, Never>?
    private var moveCont: CheckedContinuation<Move, Never>?
    let sound: Sound
    let pace: Double
    var onDeparture: ((HoldemTable.Departure) -> Void)?
    var onFinished: (() -> Void)?

    init(players: [Player], sound: Sound, pace: Double) {
        self.players = players
        self.sound = sound
        self.pace = pace
    }

    var human: Player { players[0] }
    var princessIndex: Int { players.firstIndex(where: \.isPrincess) ?? players.count - 1 }
    /// Whoever deals and banks: the Princess, or you.
    var house: Int { youAreHouse ? 0 : princessIndex }
    /// The seat at the bottom of the table: you, or the Princess when you're the house.
    var bottom: Int { youAreHouse ? princessIndex : 0 }
    var humanToBet: Bool { betCont != nil }
    var humanToMove: Bool { moveCont != nil }
    var watching: Bool { !youAreHouse && human.stack <= 0 && human.hands.isEmpty && !choosingRole }
    var dealerName: String { youAreHouse ? "Lavender" : "The Princess" }
    var dealerVoice: Voice { youAreHouse ? .girl : .princess }

    private var newcomers: [Int] { players.indices.filter { !players[$0].isHuman && !players[$0].isPrincess && players[$0].seated } }
    /// Everyone who plays against the house, in the order they act.
    private var bettors: [Int] { players.indices.filter { $0 != house && players[$0].seated } }

    // MARK: Values

    static func total(_ cards: [Card]) -> (value: Int, soft: Bool) {
        var v = 0, aces = 0
        for c in cards {
            if c.rank == 14 { aces += 1; v += 11 } else { v += min(c.rank, 10) }
        }
        while v > 21 && aces > 0 { v -= 10; aces -= 1 }
        return (v, aces > 0)
    }

    static func isBlackjack(_ cards: [Card]) -> Bool { cards.count == 2 && total(cards).value == 21 }

    static func text(_ hand: Hand) -> String {
        if !hand.fromSplit && isBlackjack(hand.cards) { return "Blackjack" }
        let t = total(hand.cards)
        if t.value > 21 { return "Bust \(t.value)" }
        return t.soft && t.value < 21 ? "Soft \(t.value)" : "\(t.value)"
    }

    var dealerText: String? {
        guard !dealerCards.isEmpty else { return nil }
        if !holeShown { return "Showing \(Self.total([dealerCards[0]]).value)" }
        return Self.isBlackjack(dealerCards) ? "Blackjack" : "\(Self.total(dealerCards).value)"
    }

    // MARK: Your choices

    func chooseRole(house: Bool) {
        guard let c = roleCont else { return }
        roleCont = nil
        c.resume(returning: house)
    }

    func placeBet() {
        guard let c = betCont else { return }
        betCont = nil
        c.resume()
    }

    func move(_ m: Move) {
        guard let c = moveCont else { return }
        moveCont = nil
        c.resume(returning: m)
    }

    var humanCanDouble: Bool {
        guard humanToMove, let h = human.hands[safe: activeHand] else { return false }
        return h.cards.count == 2 && human.stack >= h.bet
    }

    var humanCanSplit: Bool {
        guard humanToMove, human.hands.count == 1, let h = human.hands.first else { return false }
        return Self.canSplit(h, stack: human.stack)
    }

    private static func canSplit(_ h: Hand, stack: Int) -> Bool {
        h.cards.count == 2 && min(h.cards[0].rank, 10) == min(h.cards[1].rank, 10) && stack >= h.bet
    }

    /// Leaving the table: stand on everything.
    func abandon() {
        if let c = roleCont { roleCont = nil; c.resume(returning: false) }
        if let c = betCont { betCont = nil; c.resume() }
        move(.stand)
    }

    // MARK: Flow

    func run() async {
        youAreHouse = await withCheckedContinuation { roleCont = $0 }
        if Task.isCancelled { return }
        if youAreHouse {
            message = "Lavender is the house! She deals, and the Princess takes a seat."
            sound.speak("You deal, honey. I'll take a seat and play!", as: .princess)
        } else {
            message = "The Princess deals. Blackjack pays 3 to 2."
            sound.speak("Place your bets, girls!", as: .princess)
        }
        await wait(2)
        while !Task.isCancelled {
            if newcomers.isEmpty { break }
            if handNumber >= Self.lastCallHand {
                message = "Last call! The table is closed."
                for i in newcomers { depart(i, reason: "cashes out at last call") }
                break
            }
            await playHand()
            await checkDepartures()
        }
        turn = nil
        finished = true
        try? await Task.sleep(for: .seconds(1.5))
        onFinished?()
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s * (watching || youAreHouse ? 0.7 : 1) / pace))
    }

    private func draw() -> Card {
        if deck.isEmpty { deck = Deck.shuffled() }
        sound.card()
        return deck.removeFirst()
    }

    private func dealerSay(_ text: String) {
        dealerLine = text
        message = "\(dealerName) says: “\(text)”"
        sound.speak(text, as: dealerVoice)
    }

    private func playHand() async {
        handNumber += 1
        // Two fresh decks, shuffled every hand.
        deck = Deck.shuffled() + Deck.shuffled()
        dealerCards = []
        holeShown = false
        dealerLine = nil
        winners = []
        for i in players.indices {
            players[i].hands = []
            players[i].note = ""
        }

        // Bets
        var inHand: [Int] = []
        for i in bettors where players[i].stack > 0 {
            let bet: Int
            if players[i].isHuman {
                if Task.isCancelled { return }
                turn = i
                humanBet = min(humanBet, players[i].stack)
                message = "Hand \(handNumber). Lavender places her bet."
                await withCheckedContinuation { betCont = $0 }
                bet = max(1, min(humanBet, players[i].stack))
            } else {
                turn = i
                await wait(0.35)
                let wants = players[i].aggression > 0.6 && Double.random(in: 0..<1) < 0.5 ? 10 : 5
                bet = min(wants, players[i].stack)
            }
            players[i].stack -= bet
            players[i].hands = [Hand(bet: bet)]
            players[i].note = "Bet $\(bet)"
            sound.coin()
            inHand.append(i)
        }
        turn = nil
        guard !inHand.isEmpty else { return }

        // Deal: a card each, a card to the house, again.
        message = "Hand \(handNumber). \(dealerName) deals."
        for _ in 0..<2 {
            for i in inHand {
                players[i].hands[0].cards.append(draw())
                await wait(0.15)
            }
            dealerCards.append(draw())
            await wait(0.15)
        }

        // The house peeks under a ten or an ace.
        let up = min(dealerCards[0].rank, 10)
        if (up == 10 || dealerCards[0].rank == 14) && Self.isBlackjack(dealerCards) {
            await wait(0.6)
            holeShown = true
            dealerSay("I have blackjack.")
            await wait(1.6)
            for i in inHand {
                let h = players[i].hands[0]
                if Self.isBlackjack(h.cards) {
                    players[i].stack += h.bet
                    players[i].note = "Blackjack — push"
                } else {
                    players[house].stack += h.bet
                    players[i].note = "Loses $\(h.bet)"
                }
            }
            winners = [house]
            sound.coin()
            await wait(2.4)
            return
        }

        // Blackjacks pay 3 to 2 right away.
        for i in inHand where Self.isBlackjack(players[i].hands[0].cards) {
            let bet = players[i].hands[0].bet
            let won = bet * 3 / 2
            players[i].stack += bet + won
            players[house].stack -= won
            players[i].hands[0].done = true
            players[i].hands[0].settled = true
            players[i].note = "Blackjack! +$\(won)"
            winners.insert(i)
            sound.chime()
        }

        // Each player plays her hands.
        for i in inHand {
            var h = 0
            while h < players[i].hands.count {
                await playOne(i, h)
                h += 1
            }
        }
        turn = nil

        // The house turns over the hole card and draws to 17 (stands on soft 17).
        await wait(0.5)
        holeShown = true
        sound.card()
        let live = inHand.contains { i in players[i].hands.contains { !$0.settled } }
        if live {
            while Self.total(dealerCards).value < 17 {
                await wait(0.7)
                dealerCards.append(draw())
            }
        }
        let d = Self.total(dealerCards).value
        message = d > 21 ? "\(dealerName) busts with \(d)!" : "\(dealerName) stands on \(d)."
        await wait(0.8)

        // Settle up.
        var houseWon = false
        for i in inHand {
            var lines: [String] = []
            for k in players[i].hands.indices {
                var hand = players[i].hands[k]
                if hand.settled {
                    if Self.isBlackjack(hand.cards) && !hand.fromSplit { lines.append("Blackjack") } else { lines.append("Bust"); houseWon = true }
                    continue
                }
                let p = Self.total(hand.cards).value
                if d > 21 || p > d {
                    players[i].stack += hand.bet * 2
                    players[house].stack -= hand.bet
                    lines.append("Wins $\(hand.bet)")
                    winners.insert(i)
                } else if p == d {
                    players[i].stack += hand.bet
                    lines.append("Push")
                } else {
                    players[house].stack += hand.bet
                    lines.append("Loses $\(hand.bet)")
                    houseWon = true
                }
                hand.settled = true
                players[i].hands[k] = hand
            }
            players[i].note = lines.joined(separator: " · ")
        }
        if houseWon { winners.insert(house) }
        sound.coin()
        await wait(2.8)
    }

    private func playOne(_ i: Int, _ h: Int) async {
        guard !players[i].hands[h].done else { return }
        turn = i
        activeHand = h
        // A split hand gets its second card now.
        if players[i].hands[h].cards.count == 1 {
            await wait(0.3)
            players[i].hands[h].cards.append(draw())
            // Split aces get one card each.
            if players[i].hands[h].cards[0].rank == 14 {
                players[i].hands[h].done = true
                await wait(0.5)
                return
            }
        }
        while !players[i].hands[h].done && Self.total(players[i].hands[h].cards).value < 21 {
            let move: Move
            if players[i].isHuman {
                if Task.isCancelled { return }
                message = "Lavender's \(players[i].hands.count > 1 ? "hand \(h + 1)" : "hand"): \(Self.text(players[i].hands[h])). Hit or stand?"
                move = await withCheckedContinuation { moveCont = $0 }
            } else {
                await wait(0.8)
                move = decide(i, h)
            }
            switch move {
            case .hit:
                players[i].hands[h].cards.append(draw())
                players[i].note = "Hit"
            case .stand:
                players[i].hands[h].done = true
                players[i].note = "Stand on \(Self.total(players[i].hands[h].cards).value)"
            case .double:
                let bet = players[i].hands[h].bet
                guard players[i].hands[h].cards.count == 2, players[i].stack >= bet else { continue }
                players[i].stack -= bet
                players[i].hands[h].bet += bet
                players[i].hands[h].doubled = true
                sound.coin()
                players[i].hands[h].cards.append(draw())
                players[i].hands[h].done = true
                players[i].note = "Double — $\(bet * 2)"
            case .split:
                guard players[i].hands.count == 1, Self.canSplit(players[i].hands[h], stack: players[i].stack) else { continue }
                let bet = players[i].hands[h].bet
                players[i].stack -= bet
                let second = players[i].hands[h].cards.removeLast()
                players[i].hands[h].fromSplit = true
                players[i].hands.append(Hand(cards: [second], bet: bet, fromSplit: true))
                players[i].note = "Split"
                sound.coin()
                await wait(0.3)
                players[i].hands[h].cards.append(draw())
                if players[i].hands[h].cards[0].rank == 14 {
                    players[i].hands[h].done = true
                }
            }
            await wait(0.35)
        }
        let t = Self.total(players[i].hands[h].cards).value
        if t > 21 {
            // A bust loses right away, and the dealer calls it.
            let bet = players[i].hands[h].bet
            players[house].stack += bet
            players[i].hands[h].settled = true
            players[i].note = "Bust"
            dealerSay("Bust")
            await wait(1.2)
        }
        players[i].hands[h].done = true
    }

    /// Basic strategy, with the newcomers now and then hitting a stiff hand on a hunch.
    private func decide(_ i: Int, _ h: Int) -> Move {
        let hand = players[i].hands[h]
        let up = dealerCards[0].rank == 14 ? 11 : min(dealerCards[0].rank, 10)
        let canDouble = hand.cards.count == 2 && players[i].stack >= hand.bet
        if players[i].hands.count == 1 && Self.canSplit(hand, stack: players[i].stack) {
            let r = min(hand.cards[0].rank, 10)
            let ace = hand.cards[0].rank == 14
            if ace || r == 8 { return .split }
            if r == 9 && up <= 9 && up != 7 { return .split }
            if [2, 3, 7].contains(r) && up <= 7 { return .split }
            if r == 6 && up <= 6 { return .split }
        }
        let t = Self.total(hand.cards)
        if t.soft {
            if canDouble && (17...18).contains(t.value) && (3...6).contains(up) { return .double }
            if t.value >= 19 { return .stand }
            if t.value == 18 { return up >= 9 ? .hit : .stand }
            return .hit
        }
        if canDouble && (t.value == 11 || (t.value == 10 && up <= 9) || (t.value == 9 && (3...6).contains(up))) { return .double }
        if t.value >= 17 { return .stand }
        if t.value >= 12 {
            let stand = t.value == 12 ? (4...6).contains(up) : up <= 6
            if stand && !players[i].isPrincess && Double.random(in: 0..<1) < 0.12 * players[i].aggression { return .hit }
            return stand ? .stand : .hit
        }
        return .hit
    }

    private func checkDepartures() async {
        for i in newcomers {
            if players[i].stack <= 0 {
                depart(i, reason: "is out of money")
            } else if players[i].stack >= HoldemTable.goal {
                depart(i, reason: "doubled her money")
            }
        }
        if !youAreHouse && human.stack <= 0 && !human.hands.isEmpty {
            players[0].hands = []
            banner = "Lavender is out of chips — she sits back and watches the rest of the game."
            await wait(2.5)
        }
    }

    private func depart(_ i: Int, reason: String) {
        guard players[i].seated else { return }
        players[i].seated = false
        let d = HoldemTable.Departure(name: players[i].name, wasName: players[i].wasName, takeaway: max(0, players[i].stack),
                                      reason: reason, isKid: players[i].isKid)
        departures.append(d)
        banner = d.isKid
            ? "\(d.name) \(reason)! She heads home to her mom — still a girl" + (d.takeaway > 0 ? ", with $\(d.takeaway)." : ".")
            : "\(d.name) \(reason)! She's beamed back down and turned back into \(d.wasName)" + (d.takeaway > 0 ? " — taking $\(d.takeaway)." : ".")
        sound.beam(true)
        Task { [sound] in
            try? await Task.sleep(for: .seconds(1.5))
            sound.beam(false)
        }
        onDeparture?(d)
    }

    /// What you won (as a player, or as the house's bank).
    var yourWinnings: Int { human.stack - HoldemTable.buyIn }
    var princessWinnings: Int { players[princessIndex].stack - HoldemTable.buyIn }
    /// Whatever you and the Princess win between you is the salon's revenue.
    var revenue: Int { yourWinnings + princessWinnings }
}

// MARK: - View

struct BlackjackView: View {
    @Bindable var table: BlackjackTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color
    let goldChips: Bool

    /// Where the newcomers sit around the table (fractions of the table area).
    private let spots: [CGPoint] = [CGPoint(x: 0.14, y: 0.42), CGPoint(x: 0.86, y: 0.42), CGPoint(x: 0.16, y: 0.75), CGPoint(x: 0.84, y: 0.75)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Blackjack · Hand \(table.handNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text(table.youAreHouse ? "Lavender is the house" : "Princess is the house")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.yellow)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    CasinoFelt(felt: felt, size: size)

                    // The house: seat at the top, her cards just below.
                    let h = table.players[table.house]
                    CasinoSeat(name: table.youAreHouse ? "Lavender · House" : "Princess · House", skin: h.skin, look: h.look, isPrincess: h.isPrincess,
                               stack: h.stack, note: "", isTurn: false, winner: table.winners.contains(table.house), seated: true, goldChips: goldChips) { EmptyView() }
                        .position(x: size.width * 0.5, y: size.height * 0.11)
                    VStack(spacing: 4) {
                        HStack(spacing: -14) {
                            ForEach(Array(table.dealerCards.enumerated()), id: \.offset) { k, card in
                                CardView(card: card, faceUp: k == 0 || table.holeShown, width: min(50, size.width * 0.11))
                            }
                        }
                        if let t = table.dealerText {
                            tag(t, .white)
                        }
                    }
                    .position(x: size.width * 0.5, y: size.height * 0.3)
                    if let line = table.dealerLine {
                        Text(line)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.white, in: Capsule())
                            .position(x: size.width * 0.73, y: size.height * 0.22)
                            .transition(.scale.combined(with: .opacity))
                            .id(line + "\(table.handNumber)")
                    }

                    VStack(spacing: 2) {
                        Text("BLACKJACK PAYS 3 TO 2 · HOUSE STANDS ON SOFT 17")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow.opacity(0.8))
                        Text(table.message)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: size.width * 0.55)
                    .position(x: size.width * 0.5, y: size.height * 0.45)

                    // Newcomers around the sides.
                    let others = table.players.indices.filter { $0 != table.house && $0 != table.bottom }
                    ForEach(Array(others.enumerated()), id: \.element) { k, i in
                        let p = table.players[i]
                        CasinoSeat(name: p.name, skin: p.skin, look: p.look, isPrincess: p.isPrincess, stack: p.stack, note: p.note,
                                   isTurn: table.turn == i, winner: table.winners.contains(i), seated: p.seated, goldChips: goldChips) {
                            HStack(spacing: 4) {
                                ForEach(Array(p.hands.enumerated()), id: \.offset) { _, hand in
                                    HStack(spacing: -10) {
                                        ForEach(Array(hand.cards.enumerated()), id: \.offset) { _, c in CardView(card: c, width: 22) }
                                    }
                                }
                            }
                        }
                        .position(x: size.width * spots[k % spots.count].x, y: size.height * spots[k % spots.count].y)
                    }

                    // The bottom seat (you, or the Princess when you deal) with her hands big enough to read.
                    let b = table.players[table.bottom]
                    HStack(spacing: 14) {
                        ForEach(Array(b.hands.enumerated()), id: \.offset) { k, hand in
                            VStack(spacing: 3) {
                                HStack(spacing: -22) {
                                    ForEach(Array(hand.cards.enumerated()), id: \.offset) { _, c in
                                        CardView(card: c, width: b.hands.count > 1 ? 44 : 54)
                                    }
                                }
                                .overlay {
                                    if table.turn == table.bottom && table.activeHand == k && !hand.done {
                                        RoundedRectangle(cornerRadius: 6).strokeBorder(Color.yellow, lineWidth: 2).padding(-3)
                                    }
                                }
                                if !hand.cards.isEmpty {
                                    tag(BlackjackTable.text(hand) + " · $\(hand.bet)", .yellow)
                                }
                            }
                        }
                    }
                    .position(x: size.width * 0.5, y: size.height * 0.64)
                    CasinoSeat(name: table.youAreHouse ? "Princess" : "Lavender", skin: b.skin, look: b.look, isPrincess: b.isPrincess, stack: b.stack,
                               note: b.note, isTurn: table.turn == table.bottom, winner: table.winners.contains(table.bottom), seated: true, goldChips: goldChips) { EmptyView() }
                        .position(x: size.width * 0.5, y: size.height * 0.88)
                }
                .animation(.easeOut(duration: 0.2), value: table.dealerLine)
            }
            .frame(minHeight: 460)

            if let banner = table.banner {
                CasinoBanner(text: banner)
            }

            actionBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), Color(red: 0.08, green: 0.0, blue: 0.1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.default, value: table.banner)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color, in: Capsule())
    }

    @ViewBuilder private var actionBar: some View {
        if table.choosingRole {
            RoleChoice(detail: "Should Lavender play a seat against the Princess, or be the house and deal? Then the Princess plays instead.") { table.chooseRole(house: $0) }
        } else if table.finished {
            Text("The table is closed for the day.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.humanToBet {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(BlackjackTable.betChoices, id: \.self) { b in
                        let ok = b <= table.human.stack || b == BlackjackTable.betChoices[0]
                        Button { table.humanBet = min(b, table.human.stack) } label: {
                            Text("$\(b)")
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(table.humanBet == min(b, table.human.stack) ? .black : .white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(table.humanBet == min(b, table.human.stack) ? Color.yellow : Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!ok)
                        .opacity(ok ? 1 : 0.35)
                    }
                }
                CasinoButton(title: "Deal — bet $\(table.humanBet)", color: .pink) { table.placeBet() }
            }
        } else if table.humanToMove {
            HStack(spacing: 8) {
                CasinoButton(title: "Hit", color: .blue) { table.move(.hit) }
                CasinoButton(title: "Stand", color: .gray) { table.move(.stand) }
                if table.humanCanDouble {
                    CasinoButton(title: "Double", color: .orange) { table.move(.double) }
                }
                if table.humanCanSplit {
                    CasinoButton(title: "Split", color: .purple) { table.move(.split) }
                }
            }
        } else if table.youAreHouse {
            HStack {
                Text("Lavender is the house — she deals, draws to 17, and pays the winners.")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
            .frame(minHeight: 44)
        } else if table.watching {
            HStack {
                Text("Lavender is out of chips — watching the rest of the game.")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
        } else {
            HStack {
                Text(table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " ")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 44)
        }
    }
}

// MARK: - Shared pieces for the banked games (blackjack and pai gow)

struct CasinoFelt: View {
    let felt: Color
    let size: CGSize

    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [felt.opacity(0.95), felt.opacity(0.7)], center: .center, startRadius: 10, endRadius: size.width * 0.6))
            .overlay(Ellipse().strokeBorder(Color(red: 0.45, green: 0.25, blue: 0.1), lineWidth: 14))
            .overlay(Ellipse().strokeBorder(Color.yellow.opacity(0.5), lineWidth: 2).padding(7))
            .padding(.horizontal, size.width * 0.12)
            .padding(.vertical, size.height * 0.12)
    }
}

struct CasinoSeat<Cards: View>: View {
    let name: String
    let skin: Color
    let look: GirlLook
    let isPrincess: Bool
    let stack: Int
    let note: String
    let isTurn: Bool
    let winner: Bool
    let seated: Bool
    let goldChips: Bool
    @ViewBuilder let cards: () -> Cards

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: skin, look: look) }
            }
            .frame(width: 56, height: 56)
            .background(Circle().fill(Color.white.opacity(0.15)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(isTurn ? Color.yellow : (winner ? Color.green : Color.white.opacity(0.4)), lineWidth: isTurn || winner ? 3 : 1))
            .opacity(seated ? 1 : 0.25)
            Text(name)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if seated {
                HStack(spacing: 3) {
                    Circle().fill(goldChips ? Color.yellow : Color.red).frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])))
                    Text(stack < 0 ? "-$\(-stack)" : "$\(stack)")
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.yellow)
                }
                cards()
                if !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.9)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                Text("beamed down")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 112)
    }
}

/// Before a money game: play a seat, or be the house (and the Princess plays instead).
struct RoleChoice: View {
    let detail: String
    let choose: (Bool) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(detail)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                CasinoButton(title: "Be a Player", color: .pink) { choose(false) }
                CasinoButton(title: "Be the House", color: .purple) { choose(true) }
            }
        }
    }
}

struct CasinoBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.pink.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .transition(.opacity)
            .id(text)
    }
}

struct CasinoButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
