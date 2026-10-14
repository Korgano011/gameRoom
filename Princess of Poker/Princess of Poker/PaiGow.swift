import SwiftUI

/// Pai Gow Poker at the salon's card table, banked by the Princess. A 53-card deck with the joker
/// (an ace, or the missing card for a straight or flush). Everyone gets seven cards and sets them into a five-card
/// high hand and a two-card low hand; the high hand must beat the low. Win both against the Princess to win
/// even money less 5% commission; win one for a push; ties ("copies") go to the house.
/// You can choose to be the house instead: you bank and set the house's hand, and the Princess plays a seat.
@Observable final class PaiGowTable {
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
        var cards: [Card] = []
        var high: [Card] = []
        var low: [Card] = []
        var bet = 0
        var seated = true
        var note = ""
        var aggression = 0.5
        var isSet: Bool { high.count == 5 }
    }

    static let lastCallHand = 30

    /// 0 is you; the newcomers follow; the Princess (the house) is last.
    var players: [Player]
    var handNumber = 0
    var turn: Int?
    var message = "Shuffle up and deal!"
    var banner: String?
    var departures: [HoldemTable.Departure] = []
    var winners: Set<Int> = []
    var finished = false
    /// The Princess has set and turned over her hand.
    var houseShown = false
    /// Your bet for the next hand (kept from hand to hand).
    var humanBet = 5
    /// The two cards you've picked for your low hand.
    var lowPick: [Int] = []

    private var deck: [Card] = []
    private var betCont: CheckedContinuation<Void, Never>?
    private var setCont: CheckedContinuation<Void, Never>?
    let sound: Sound
    let pace: Double
    var onFinished: (() -> Void)?

    init(players: [Player], sound: Sound, pace: Double) {
        self.players = players
        self.sound = sound
        self.pace = pace
    }

    var human: Player { players[0] }
    /// You chose to be the house: you bank and set the house's hand; the Princess plays a seat.
    private(set) var youAreHouse = false
    var choosingRole: Bool { roleCont != nil }
    private var roleCont: CheckedContinuation<Bool, Never>?
    var princessIndex: Int { players.firstIndex(where: \.isPrincess) ?? players.count - 1 }
    var house: Int { youAreHouse ? 0 : princessIndex }
    /// The seat at the bottom of the table: you, or the Princess when you're the house.
    var bottom: Int { youAreHouse ? princessIndex : 0 }
    var dealerName: String { youAreHouse ? "Lavender" : "The Princess" }
    var humanToBet: Bool { betCont != nil }
    var humanToSet: Bool { setCont != nil }
    var watching: Bool { !youAreHouse && human.stack <= 0 && human.cards.isEmpty && !choosingRole }
    private var newcomers: [Int] { players.indices.filter { !players[$0].isHuman && !players[$0].isPrincess && players[$0].seated } }

    // MARK: Hands

    /// The five-card high hand's score; the joker is an ace or fills a straight or flush.
    static func highScore(_ c: [Card]) -> Int {
        guard let j = c.firstIndex(where: \.isJoker) else { return HandEval.score5(c) }
        var rest = c
        rest.remove(at: j)
        if rest.filter({ $0.rank == 14 }).count == 4 { return 9 * 759375 }   // five aces
        var best = Suit.allCases.map { s in HandEval.score5(rest + [Card(rank: 14, suit: s)]) }.max()!
        for s in Suit.allCases {
            for r in 2...14 {
                let sc = HandEval.score5(rest + [Card(rank: r, suit: s)])
                if [4, 5, 8].contains(sc / 759375) { best = max(best, sc) }
            }
        }
        return best
    }

    /// The two-card low hand's score: any pair beats any two singles. The joker is an ace.
    static func lowScore(_ c: [Card]) -> Int {
        let r = c.map { $0.isJoker ? 14 : $0.rank }.sorted(by: >)
        return r[0] == r[1] ? 1000 + r[0] : r[0] * 15 + r[1]
    }

    static func highName(_ score: Int) -> String {
        score >= 9 * 759375 ? "Five Aces" : HandEval.name(of: score)
    }

    static func lowName(_ c: [Card]) -> String {
        let s = lowScore(c)
        let text = { (r: Int) in r == 14 ? "A" : r == 13 ? "K" : r == 12 ? "Q" : r == 11 ? "J" : "\(r)" }
        return s >= 1000 ? "Pair of \(text(s - 1000))s" : "\(text(s / 15))-\(text(s % 15))"
    }

    /// The five-card hand has to outrank the two-card hand.
    static func valid(high: Int, low: Int) -> Bool {
        let cat = high / 759375
        let top = (high / 50625) % 15, second = (high / 3375) % 15
        if low >= 1000 {
            return cat >= 2 || (cat == 1 && top >= low - 1000)
        }
        if cat >= 1 { return true }
        return top * 15 + second >= low
    }

    /// The house way: keep the best five-card hand you can, then the best two-card hand that goes with it.
    static func houseWay(_ cards: [Card]) -> (high: [Card], low: [Card]) {
        var best: (cat: Int, low: Int, high: Int, a: Int, b: Int)?
        for a in 0..<cards.count {
            for b in (a + 1)..<cards.count {
                let low = [cards[a], cards[b]]
                let high = cards.indices.filter { $0 != a && $0 != b }.map { cards[$0] }
                let hs = highScore(high), ls = lowScore(low)
                guard valid(high: hs, low: ls) else { continue }
                let cand = (cat: hs / 759375, low: ls, high: hs, a: a, b: b)
                if let cur = best {
                    if (cand.cat, cand.low, cand.high) > (cur.cat, cur.low, cur.high) { best = cand }
                } else {
                    best = cand
                }
            }
        }
        let a = best?.a ?? 0, b = best?.b ?? 1
        return (cards.indices.filter { $0 != a && $0 != b }.map { cards[$0] }, [cards[a], cards[b]])
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

    func toggleLow(_ card: Card) {
        guard humanToSet else { return }
        if let k = lowPick.firstIndex(of: card.id) {
            lowPick.remove(at: k)
        } else if lowPick.count < 2 {
            lowPick.append(card.id)
        } else {
            lowPick[1] = card.id
        }
    }

    func useHouseWay() {
        guard humanToSet else { return }
        lowPick = Self.houseWay(human.cards).low.map(\.id)
    }

    /// Your pick as high/low hands, if it's a legal setting.
    var humanSetting: (high: [Card], low: [Card], ok: Bool)? {
        guard lowPick.count == 2 else { return nil }
        let low = human.cards.filter { lowPick.contains($0.id) }
        let high = human.cards.filter { !lowPick.contains($0.id) }
        return (high, low, Self.valid(high: Self.highScore(high), low: Self.lowScore(low)))
    }

    func confirmSet() {
        guard let s = humanSetting, s.ok, let c = setCont else { return }
        players[0].high = s.high
        players[0].low = s.low
        setCont = nil
        c.resume()
    }

    func abandon() {
        if let c = roleCont { roleCont = nil; c.resume(returning: false) }
        if let c = betCont { betCont = nil; c.resume() }
        if let c = setCont {
            setCont = nil
            let way = Self.houseWay(human.cards)
            players[0].high = way.high
            players[0].low = way.low
            c.resume()
        }
    }

    // MARK: Flow

    func run() async {
        youAreHouse = await withCheckedContinuation { roleCont = $0 }
        if Task.isCancelled { return }
        if youAreHouse {
            message = "Lavender is the house! She banks the table and sets the house's hand; the Princess plays a seat."
            sound.speak("You're the house, honey. I'll play!", as: .princess)
        } else {
            sound.speak("Pai gow poker, girls! Seven cards each. Set your high hand and your low hand.", as: .princess)
        }
        await wait(1.5)
        while !Task.isCancelled {
            if newcomers.isEmpty { break }
            if handNumber >= Self.lastCallHand {
                message = "Last call! The Princess closes the table."
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
        try? await Task.sleep(for: .seconds(s * (watching ? 0.6 : 1) / pace))
    }

    private func playHand() async {
        handNumber += 1
        deck = Deck.shuffled(joker: true)
        houseShown = false
        winners = []
        lowPick = []
        for i in players.indices {
            players[i].cards = []
            players[i].high = []
            players[i].low = []
            players[i].bet = 0
            players[i].note = ""
        }

        // Bets
        var inHand: [Int] = []
        for i in players.indices where i != house && players[i].seated && players[i].stack > 0 {
            let bet: Int
            turn = i
            if players[i].isHuman {
                if Task.isCancelled { return }
                humanBet = min(humanBet, players[i].stack)
                message = "Hand \(handNumber). Lavender places her bet."
                await withCheckedContinuation { betCont = $0 }
                bet = max(1, min(humanBet, players[i].stack))
            } else {
                await wait(0.35)
                bet = min(players[i].aggression > 0.6 && Double.random(in: 0..<1) < 0.5 ? 10 : 5, players[i].stack)
            }
            players[i].stack -= bet
            players[i].bet = bet
            players[i].note = "Bet $\(bet)"
            sound.coin()
            inHand.append(i)
        }
        turn = nil
        guard !inHand.isEmpty else { return }

        message = "Hand \(handNumber). Seven cards each."
        for _ in 0..<7 {
            for i in inHand + [house] {
                players[i].cards.append(deck.removeFirst())
                sound.card()
                await wait(0.05)
            }
        }
        for i in inHand + [house] {
            players[i].cards.sort { ($0.isJoker ? 15 : $0.rank) > ($1.isJoker ? 15 : $1.rank) }
        }

        // Everyone sets her hand.
        for i in inHand {
            turn = i
            if players[i].isHuman {
                if Task.isCancelled { return }
                message = "Tap two cards for Lavender's low hand. Her five-card hand must beat it."
                await withCheckedContinuation { setCont = $0 }
            } else {
                await wait(0.7)
                let way = Self.houseWay(players[i].cards)
                players[i].high = way.high
                players[i].low = way.low
            }
            players[i].note = "Set"
        }
        turn = nil

        // The house sets hers — the Princess the house way, or you by hand — and turns it over.
        if youAreHouse {
            if Task.isCancelled { return }
            turn = 0
            lowPick = []
            message = "Lavender is the house — tap two cards for the house's low hand."
            await withCheckedContinuation { setCont = $0 }
            turn = nil
        } else {
            await wait(0.6)
            let way = Self.houseWay(players[house].cards)
            players[house].high = way.high
            players[house].low = way.low
        }
        houseShown = true
        sound.card()
        let hHigh = Self.highScore(players[house].high), hLow = Self.lowScore(players[house].low)
        message = "\(dealerName) sets \(Self.highName(hHigh)) and \(Self.lowName(players[house].low))."
        await wait(1.4)

        var houseWon = false
        for i in inHand {
            let bet = players[i].bet
            let winHigh = Self.highScore(players[i].high) > hHigh
            let winLow = Self.lowScore(players[i].low) > hLow
            if winHigh && winLow {
                // Even money, less the house's 5% commission.
                let won = bet * 95 / 100
                players[i].stack += bet + won
                players[house].stack -= won
                players[i].note = "Wins $\(won)"
                winners.insert(i)
            } else if winHigh || winLow {
                players[i].stack += bet
                players[i].note = "Push"
            } else {
                players[house].stack += bet
                players[i].note = "Loses $\(bet)"
                houseWon = true
            }
        }
        if houseWon { winners.insert(house) }
        sound.coin()
        await wait(3.2)
    }

    private func checkDepartures() async {
        for i in newcomers {
            if players[i].stack <= 0 {
                depart(i, reason: "is out of money")
            } else if players[i].stack >= HoldemTable.goal {
                depart(i, reason: "doubled her money")
            }
        }
        if !youAreHouse && human.stack <= 0 && !human.cards.isEmpty {
            players[0].cards = []
            players[0].high = []
            players[0].low = []
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
    }

    var yourWinnings: Int { human.stack - HoldemTable.buyIn }
    var princessWinnings: Int { players[princessIndex].stack - HoldemTable.buyIn }
    var revenue: Int { yourWinnings + princessWinnings }
}

// MARK: - View

struct PaiGowView: View {
    @Bindable var table: PaiGowTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color
    let goldChips: Bool

    private let spots: [CGPoint] = [CGPoint(x: 0.14, y: 0.42), CGPoint(x: 0.86, y: 0.42), CGPoint(x: 0.16, y: 0.75), CGPoint(x: 0.84, y: 0.75)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Pai Gow Poker · Hand \(table.handNumber)")
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

                    let h = table.players[table.house]
                    CasinoSeat(name: table.youAreHouse ? "Lavender · House" : "Princess · House", skin: h.skin, look: h.look, isPrincess: h.isPrincess, stack: h.stack, note: "",
                               isTurn: false, winner: table.winners.contains(table.house), seated: true, goldChips: goldChips) { EmptyView() }
                        .position(x: size.width * 0.5, y: size.height * 0.11)
                    Group {
                        if table.houseShown {
                            setHand(h, width: min(40, size.width * 0.085))
                        } else {
                            HStack(spacing: -16) {
                                ForEach(Array(h.cards.enumerated()), id: \.offset) { _, c in
                                    CardView(card: c, faceUp: table.youAreHouse, width: min(40, size.width * 0.085))
                                }
                            }
                        }
                    }
                    .position(x: size.width * 0.5, y: size.height * 0.3)

                    VStack(spacing: 2) {
                        Text("WIN BOTH HANDS · 5% COMMISSION · COPIES GO TO THE HOUSE")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow.opacity(0.8))
                        Text(table.message)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: size.width * 0.55)
                    .position(x: size.width * 0.5, y: size.height * 0.46)

                    let others = table.players.indices.filter { $0 != table.house && $0 != table.bottom }
                    ForEach(Array(others.enumerated()), id: \.element) { k, i in
                        let p = table.players[i]
                        CasinoSeat(name: p.name, skin: p.skin, look: p.look, isPrincess: false, stack: p.stack, note: p.note,
                                   isTurn: table.turn == i, winner: table.winners.contains(i), seated: p.seated, goldChips: goldChips) {
                            if p.isSet && table.houseShown {
                                VStack(spacing: 2) {
                                    HStack(spacing: -8) { ForEach(Array(p.high.enumerated()), id: \.offset) { _, c in CardView(card: c, width: 18) } }
                                    HStack(spacing: -8) { ForEach(Array(p.low.enumerated()), id: \.offset) { _, c in CardView(card: c, width: 18) } }
                                }
                            } else if !p.cards.isEmpty {
                                HStack(spacing: -12) { ForEach(Array(p.cards.enumerated()), id: \.offset) { _, c in CardView(card: c, faceUp: false, width: 18) } }
                            }
                        }
                        .position(x: size.width * spots[k % spots.count].x, y: size.height * spots[k % spots.count].y)
                    }

                    // The bottom seat: you, or the Princess when you're the house.
                    let b = table.players[table.bottom]
                    if b.isSet && (!table.youAreHouse || table.houseShown) {
                        setHand(b, width: min(44, size.width * 0.09))
                            .position(x: size.width * 0.5, y: size.height * 0.65)
                    } else if table.youAreHouse && !b.cards.isEmpty {
                        HStack(spacing: -16) { ForEach(Array(b.cards.enumerated()), id: \.offset) { _, c in CardView(card: c, faceUp: false, width: 34) } }
                            .position(x: size.width * 0.5, y: size.height * 0.68)
                    }
                    CasinoSeat(name: table.youAreHouse ? "Princess" : "Lavender", skin: b.skin, look: b.look, isPrincess: b.isPrincess, stack: b.stack,
                               note: b.note, isTurn: table.turn == table.bottom, winner: table.winners.contains(table.bottom), seated: true, goldChips: goldChips) { EmptyView() }
                        .position(x: size.width * 0.5, y: size.height * 0.88)
                }
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

    /// A set hand: the five-card high hand and the two-card low hand side by side, each named.
    private func setHand(_ p: PaiGowTable.Player, width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 3) {
                HStack(spacing: -width * 0.35) { ForEach(Array(p.high.enumerated()), id: \.offset) { _, c in CardView(card: c, width: width) } }
                tag(PaiGowTable.highName(PaiGowTable.highScore(p.high)))
            }
            VStack(spacing: 3) {
                HStack(spacing: -width * 0.35) { ForEach(Array(p.low.enumerated()), id: \.offset) { _, c in CardView(card: c, width: width) } }
                tag(PaiGowTable.lowName(p.low))
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .lineLimit(1)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.yellow, in: Capsule())
    }

    @ViewBuilder private var actionBar: some View {
        if table.choosingRole {
            RoleChoice(detail: "Should Lavender play a seat against the Princess, or be the house and bank the table? Then the Princess plays instead.") { table.chooseRole(house: $0) }
        } else if table.finished {
            Text("The table is closed for the day.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.humanToBet {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(BlackjackTable.betChoices, id: \.self) { b in
                        let ok = b <= table.human.stack || b == BlackjackTable.betChoices[0]
                        let picked = table.humanBet == min(b, table.human.stack)
                        Button { table.humanBet = min(b, table.human.stack) } label: {
                            Text("$\(b)")
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(picked ? .black : .white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(picked ? Color.yellow : Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!ok)
                        .opacity(ok ? 1 : 0.35)
                    }
                }
                CasinoButton(title: "Deal — bet $\(table.humanBet)", color: .pink) { table.placeBet() }
            }
        } else if table.humanToSet {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(table.human.cards) { card in
                        let low = table.lowPick.contains(card.id)
                        Button { table.toggleLow(card) } label: {
                            CardView(card: card, width: 46)
                                .overlay(alignment: .top) {
                                    if low {
                                        Text("LOW")
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .background(Capsule().fill(Color.pink))
                                            .offset(y: -8)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .offset(y: low ? -10 : 0)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: table.lowPick)
                if let s = table.humanSetting {
                    Text(s.ok ? "High: \(PaiGowTable.highName(PaiGowTable.highScore(s.high))) · Low: \(PaiGowTable.lowName(s.low))"
                              : "Foul! Lavender's five-card hand must beat her two-card hand.")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(s.ok ? .yellow : .red)
                }
                HStack(spacing: 8) {
                    CasinoButton(title: "House way", color: .purple) { table.useHouseWay() }
                    CasinoButton(title: "Set hand", color: .pink) { table.confirmSet() }
                        .disabled(!(table.humanSetting?.ok ?? false))
                        .opacity(table.humanSetting?.ok ?? false ? 1 : 0.45)
                }
            }
        } else if table.youAreHouse {
            HStack {
                Text(table.turn.map { "\(table.players[$0].name) is setting her hand…" } ?? "Lavender is the house — she banks the table and pays the winners.")
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
                Text(table.turn.map { "\(table.players[$0].name) is setting her hand…" } ?? " ")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 44)
        }
    }
}
