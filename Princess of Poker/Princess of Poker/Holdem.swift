import SwiftUI

/// The girls' poker game in the salon's poker room: no-limit Texas or Omaha Hold'em, or Caribbean Stud
/// against the Princess's hand. The Princess deals; you play as yourself against tonight's newcomers. A newcomer who goes broke or doubles her $50 buy-in
/// to $100 is beamed back down and turned back.
@Observable final class HoldemTable {
    struct Seat: Identifiable {
        let id: Int
        var name: String
        /// Who she was before the salon's adjustment.
        var wasName: String
        var skin: Color
        var look: GirlLook
        var isHuman: Bool
        var stack: Int
        /// The Princess of Poker plays too, with the house's money; she never beams down.
        var isPrincess = false
        /// A boy who came by on his own; when he leaves he goes home to his mom, still a girl.
        var isKid = false
        var hole: [Card] = []
        var folded = false
        var allIn = false
        var bet = 0
        var put = 0
        var seated = true
        var note = ""
        var showCards = false
        /// 0…1: how often she bets and bluffs.
        var aggression = 0.5
    }

    enum Action { case fold, check, call, raise(to: Int) }

    /// Tonight's game. They take turns night by night; night 2 (the co-workers) is always blackjack.
    /// Blackjack, pai gow poker and craps are played at their own banked tables (`BlackjackTable`, `PaiGowTable`, `CrapsTable`) for real money,
    /// and so are three card poker, let it ride and red dog (`BankedTable`).
    /// Hearts, nines, pedro and pişti are played at their own tables (`HeartsTable`, `NinesTable`, `PedroTable`, `PistiTable`) just for fun — they make no money;
    /// so are pepper, spades and domino hearts (`TrickTable`).
    enum Game: CaseIterable {
        case texas, omaha, draw, caribbean, blackjack, paigow, craps, threeCard, letItRide, redDog
        case hearts, nines, pedro, pisti, big2, ninetyNine, ohHell, californiaJack, pepper, spades, dominoHearts, callItRight
        /// The day-by-day rotation: the money-makers, then a game of hearts.
        static let rotation: [Game] = [.texas, .omaha, .caribbean, .blackjack, .paigow, .craps, .hearts]
        static func forNight(_ night: Int) -> Game {
            night == 1 ? .ninetyNine : rotation[(max(2, night) - 2) % rotation.count]
        }
        var name: String {
            switch self {
            case .texas: "Texas Hold'em"
            case .omaha: "Omaha Hold'em"
            case .draw: "Five Card Draw"
            case .caribbean: "Caribbean Stud"
            case .blackjack: "Blackjack"
            case .paigow: "Pai Gow Poker"
            case .craps: "Craps"
            case .threeCard: "Three Card Poker"
            case .letItRide: "Let It Ride"
            case .redDog: "Red Dog"
            case .hearts: "Hearts"
            case .nines: "Nines"
            case .pedro: "Pedro"
            case .pisti: "Pişti"
            case .big2: "Big Two"
            case .ninetyNine: "99"
            case .ohHell: "Oh Hell"
            case .californiaJack: "California Jack"
            case .pepper: "Pepper"
            case .spades: "Spades"
            case .dominoHearts: "Domino Hearts"
            case .callItRight: "Call It Right"
            }
        }
        var icon: String {
            switch self {
            case .texas: "suit.spade.fill"
            case .omaha: "suit.club.fill"
            case .draw: "arrow.triangle.2.circlepath"
            case .caribbean: "sun.max.fill"
            case .blackjack: "21.circle.fill"
            case .paigow: "square.split.2x1.fill"
            case .craps: "dice.fill"
            case .threeCard: "3.circle.fill"
            case .letItRide: "arrow.uturn.backward.circle.fill"
            case .redDog: "dog.fill"
            case .hearts: "suit.heart.fill"
            case .nines: "9.circle.fill"
            case .pedro: "person.2.fill"
            case .pisti: "rectangle.stack.fill"
            case .big2: "2.circle.fill"
            case .ninetyNine: "sum"
            case .ohHell: "flame.fill"
            case .californiaJack: "j.circle.fill"
            case .pepper: "leaf.fill"
            case .spades: "suit.spade"
            case .dominoHearts: "heart.circle.fill"
            case .callItRight: "megaphone.fill"
            }
        }
        /// The afternoon game: the next game in the rotation after the morning's (never the same one).
        func afternoon(day: Int) -> Game {
            let cycle = Game.rotation
            if let i = cycle.firstIndex(of: self) { return cycle[(i + 1) % cycle.count] }
            let g = Game.forNight(day)
            return g == self ? .texas : g
        }
        /// How the host pitches it to passersby.
        var pitch: String { isForFun || self == .blackjack || self == .paigow || self == .craps || self == .redDog ? "a girls game of \(name.lowercased())" : "a girls poker game" }
        /// Hearts, nines, pedro and pişti: no money on the table.
        var isForFun: Bool { self == .hearts || self == .nines || self == .pedro || self == .pisti || self == .big2 || self == .ninetyNine || self == .ohHell || self == .californiaJack
            || self == .pepper || self == .spades || self == .dominoHearts || self == .callItRight }
        /// Passersby to invite: hearts, pedro and pişti need two to make four, nines one to make three; poker seats up to three.
        var newcomerSeats: Int {
            switch self {
            case .hearts, .pedro, .pisti, .big2, .ninetyNine, .ohHell, .californiaJack, .pepper, .spades, .dominoHearts, .callItRight: 2
            case .nines: 1
            default: 3
            }
        }
    }

    struct Departure: Identifiable {
        let id = UUID()
        let name: String
        let wasName: String
        let takeaway: Int
        let reason: String
        var isKid = false
    }

    static let buyIn = 50
    static let goal = 100
    static let smallBlind = 1
    static let bigBlind = 2
    static let lastCallHand = 60

    var seats: [Seat]
    let game: Game
    /// Omaha Hold'em (four hole cards, use exactly two) instead of Texas Hold'em.
    var omaha: Bool { game == .omaha }
    var caribbean: Bool { game == .caribbean }
    /// Five Card Draw: five cards each, one round of betting, a draw, then a second round.
    var draw: Bool { game == .draw }
    /// Five Card Draw: your cards picked to throw away.
    var discards: Set<Int> = []
    private var drawCont: CheckedContinuation<Void, Never>?
    var humanToDraw: Bool { drawCont != nil }
    var gameName: String { game.name }
    /// The community cards — or, in Caribbean Stud, the Princess's five-card hand.
    var board: [Card] = []
    /// Caribbean Stud: the Princess has turned over all five of her cards.
    var dealerShown = false
    var dealer = 0
    var turn: Int?
    var currentBet = 0
    var lastRaise = bigBlind
    var message = "Shuffle up and deal!"
    var banner: String?
    var handNumber = 0
    var departures: [Departure] = []
    var winners: Set<Int> = []
    var finished = false

    var pot: Int { seats.reduce(0) { $0 + $1.put } }
    var human: Seat { seats[0] }
    /// Caribbean Stud only: you chose to be the house — you hold the dealer's hand and bank the table, and the Princess plays instead.
    /// Hold'em, Omaha and Five Card Draw have no house option.
    private(set) var youAreHouse = false
    /// Waiting for you to choose: player or house.
    var choosingRole: Bool { roleCont != nil }
    private var roleCont: CheckedContinuation<Bool, Never>?
    var princessIndex: Int { seats.firstIndex(where: \.isPrincess) ?? seats.count - 1 }
    /// Caribbean Stud's bank: the Princess, or you.
    var houseIndex: Int { youAreHouse ? 0 : princessIndex }
    var dealerName: String { youAreHouse ? "Lavender" : "The Princess" }

    func chooseRole(house: Bool) {
        guard let c = roleCont else { return }
        roleCont = nil
        c.resume(returning: house)
    }
    var humanToAct: Bool { turn == 0 && humanCont != nil }
    var watching: Bool { human.stack == 0 && human.hole.isEmpty }

    /// What you're holding right now, in words ("Pair of 8s", "Flush"…).
    var humanHandText: String? {
        let hole = human.hole
        guard hole.count >= 2 else { return nil }
        if caribbean || draw { return hole.count == 5 ? HandEval.name(of: HandEval.score5(hole)) : nil }
        if board.count >= 3 { return HandEval.name(of: score(hole, board)) }
        if omaha {
            let sorted = hole.sorted { $0.rank > $1.rank }
            let pair = Dictionary(grouping: sorted, by: \.rank).filter { $0.value.count >= 2 }.keys.max()
            return sorted.map(\.rankText).joined(separator: "-")
                + (pair.map { r in " · pair of \(sorted.first { $0.rank == r }!.rankText)s" } ?? "")
        }
        if hole[0].rank == hole[1].rank { return "Pair of \(hole[0].rankText)s" }
        let hi = hole.max { $0.rank < $1.rank }!, lo = hole.min { $0.rank < $1.rank }!
        return "\(hi.rankText)-\(lo.rankText)" + (hi.suit == lo.suit ? " suited" : "")
    }
    var newcomerCount: Int

    private var deck: [Card] = []

    private func score(_ hole: [Card], _ board: [Card]) -> Int {
        if draw { return HandEval.score5(hole) }
        return omaha ? HandEval.bestOmaha(hole, board) : HandEval.best(hole + board)
    }
    private var humanCont: CheckedContinuation<Action, Never>?
    let sound: Sound
    let pace: Double
    let looseness: Double
    var onDeparture: ((Departure) -> Void)?
    var onFinished: (() -> Void)?

    init(seats: [Seat], sound: Sound, pace: Double, looseness: Double, game: Game = .texas) {
        self.seats = seats
        self.game = game
        self.sound = sound
        self.pace = pace
        self.looseness = looseness
        newcomerCount = seats.filter { !$0.isHuman && !$0.isPrincess }.count
        dealer = Int.random(in: 0..<seats.count)
    }

    // MARK: Flow

    func run() async {
        if caribbean {
            youAreHouse = await withCheckedContinuation { roleCont = $0 }
            if Task.isCancelled { return }
        }
        if youAreHouse {
            message = "Lavender is the house! She holds the dealer's hand and banks the table; the Princess plays a seat."
            sound.speak("You're the house, honey. I'll play!", as: .princess)
        } else {
            message = "Shuffle up and deal!"
        }
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled {
            let newcomers = seats.indices.filter { !seats[$0].isHuman && !seats[$0].isPrincess && seats[$0].seated }
            if newcomers.isEmpty { break }
            let withChips = seats.indices.filter { seats[$0].seated && seats[$0].stack > 0 }
            if !caribbean && withChips.count < 2 {
                for i in newcomers { depart(i, reason: "is the last one at the table") }
                break
            }
            if handNumber >= Self.lastCallHand {
                message = "Last call! The Princess closes the table."
                for i in newcomers { depart(i, reason: "cashes out at last call") }
                break
            }
            if caribbean { await playCaribbeanHand() } else if draw { await playDrawHand() } else { await playHand() }
            await checkDepartures()
        }
        turn = nil
        finished = true
        try? await Task.sleep(for: .seconds(1.5))
        onFinished?()
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s * (watching || youAreHouse ? 0.5 : 1) / pace))
    }

    private func next(after i: Int, where ok: (Seat) -> Bool) -> Int {
        var j = i
        for _ in 0..<seats.count {
            j = (j + 1) % seats.count
            if ok(seats[j]) { return j }
        }
        return i
    }

    private var inHand: [Int] { seats.indices.filter { !seats[$0].folded } }
    private var canAct: [Int] { seats.indices.filter { !seats[$0].folded && !seats[$0].allIn } }

    private func playHand() async {
        handNumber += 1
        board = []
        winners = []
        deck = Deck.shuffled()
        for i in seats.indices {
            seats[i].hole = []
            seats[i].folded = !(seats[i].seated && seats[i].stack > 0)
            seats[i].allIn = false
            seats[i].bet = 0
            seats[i].put = 0
            seats[i].note = ""
            seats[i].showCards = false
        }
        let live: (Seat) -> Bool = { !$0.folded }
        dealer = next(after: dealer, where: live)
        let headsUp = inHand.count == 2
        let sb = headsUp ? dealer : next(after: dealer, where: live)
        let bb = next(after: sb, where: live)
        message = "Hand \(handNumber). \(seats[dealer].name) has the button."
        post(sb, Self.smallBlind, "Small blind")
        post(bb, Self.bigBlind, "Big blind")
        currentBet = Self.bigBlind
        lastRaise = Self.bigBlind
        for _ in 0..<(omaha ? 4 : 2) {
            for i in inHand {
                seats[i].hole.append(deck.removeFirst())
                sound.card()
                await wait(0.12)
            }
        }
        await bettingRound(first: next(after: bb, where: live))

        for (street, count) in [("Flop", 3), ("Turn", 1), ("River", 1)] {
            if inHand.count <= 1 { break }
            for i in seats.indices { seats[i].bet = 0 }
            currentBet = 0
            lastRaise = Self.bigBlind
            await wait(0.7)
            board += deck.prefix(count)
            deck.removeFirst(count)
            sound.card()
            message = "The \(street.lowercased()): " + board.suffix(count).map(\.text).joined(separator: " ")
            if canAct.count >= 2 {
                for i in seats.indices where !seats[i].folded && !seats[i].allIn { seats[i].note = "" }
                await bettingRound(first: next(after: dealer, where: live))
            } else {
                for i in inHand { seats[i].showCards = true }
                await wait(1.2)
            }
        }
        await showdown()
    }

    private func post(_ i: Int, _ amount: Int, _ label: String) {
        let a = min(amount, seats[i].stack)
        seats[i].stack -= a
        seats[i].bet += a
        seats[i].put += a
        seats[i].note = label
        if seats[i].stack == 0 { seats[i].allIn = true }
    }

    private func bettingRound(first: Int) async {
        var needs = Set(canAct)
        var i = first
        while !needs.isEmpty && inHand.count > 1 {
            if !needs.contains(i) {
                i = (i + 1) % seats.count
                continue
            }
            // The only player left who can act doesn't have to if nobody else can respond and she's matched.
            if canAct.count == 1 && seats[i].bet >= currentBet { break }
            turn = i
            let action: Action
            if seats[i].isHuman {
                message = seats[i].bet < currentBet ? "Lavender's turn — $\(currentBet - seats[i].bet) to call." : "Lavender's turn."
                action = await withCheckedContinuation { humanCont = $0 }
            } else {
                await wait(0.9)
                action = decide(i)
            }
            if apply(action, i) {
                needs = Set(canAct.filter { $0 != i })
            } else {
                needs.remove(i)
            }
            i = (i + 1) % seats.count
        }
        turn = nil
    }

    /// Whoever folds says so out loud, in her own voice.
    private func sayFold(_ i: Int) {
        sound.speak("Fold", as: seats[i].isPrincess ? .princess : seats[i].isKid ? .kidGirl : .girl)
    }

    /// Applies an action; returns true when it was a raise that reopens the betting.
    @discardableResult
    private func apply(_ action: Action, _ i: Int) -> Bool {
        let toCall = currentBet - seats[i].bet
        switch action {
        case .fold:
            seats[i].folded = true
            seats[i].note = "Fold"
            sayFold(i)
            return false
        case .check where toCall <= 0:
            seats[i].note = "Check"
            sound.card()
            return false
        case .check, .call:
            let a = min(toCall, seats[i].stack)
            move(i, a)
            seats[i].note = seats[i].allIn ? "All in $\(seats[i].bet)" : (a == 0 ? "Check" : "Call $\(a)")
            return false
        case .raise(let to):
            let cap = seats[i].bet + seats[i].stack
            let target = min(cap, max(to, currentBet + lastRaise))
            if target <= currentBet {
                return apply(.call, i)
            }
            move(i, target - seats[i].bet)
            if target - currentBet >= lastRaise { lastRaise = target - currentBet }
            let wasOpen = currentBet == 0
            currentBet = target
            seats[i].note = seats[i].allIn ? "All in $\(target)" : (wasOpen ? "Bet $\(target)" : "Raise to $\(target)")
            sound.coin()
            return true
        }
    }

    private func move(_ i: Int, _ a: Int) {
        seats[i].stack -= a
        seats[i].bet += a
        seats[i].put += a
        if seats[i].stack == 0 { seats[i].allIn = true }
    }

    func act(_ action: Action) {
        guard let c = humanCont else { return }
        humanCont = nil
        c.resume(returning: action)
    }

    /// Ends a hand early (leaving the table): the human folds.
    func abandon() {
        if let c = roleCont {
            roleCont = nil
            c.resume(returning: false)
        }
        if let c = drawCont {
            drawCont = nil
            c.resume()
        }
        act(.fold)
    }

    func toggleDiscard(_ card: Card) {
        guard humanToDraw else { return }
        if discards.contains(card.id) {
            discards.remove(card.id)
        } else if discards.count < 3 {
            discards.insert(card.id)
        } else if discards.count == 3, human.hole.first(where: { !discards.contains($0.id) && $0.id != card.id })?.rank == 14 {
            // A fourth card only when the one you keep is an ace.
            discards.insert(card.id)
        }
    }

    func confirmDraw() {
        guard let c = drawCont else { return }
        drawCont = nil
        c.resume()
    }

    // MARK: Five Card Draw

    private func playDrawHand() async {
        handNumber += 1
        board = []
        winners = []
        discards = []
        deck = Deck.shuffled()
        for i in seats.indices {
            seats[i].hole = []
            seats[i].folded = !(seats[i].seated && seats[i].stack > 0)
            seats[i].allIn = false
            seats[i].bet = 0
            seats[i].put = 0
            seats[i].note = ""
            seats[i].showCards = false
        }
        let live: (Seat) -> Bool = { !$0.folded }
        dealer = next(after: dealer, where: live)
        let headsUp = inHand.count == 2
        let sb = headsUp ? dealer : next(after: dealer, where: live)
        let bb = next(after: sb, where: live)
        message = "Hand \(handNumber). \(seats[dealer].name) has the button. Five cards each."
        post(sb, Self.smallBlind, "Small blind")
        post(bb, Self.bigBlind, "Big blind")
        currentBet = Self.bigBlind
        lastRaise = Self.bigBlind
        for _ in 0..<5 {
            for i in inHand {
                seats[i].hole.append(deck.removeFirst())
                sound.card()
                await wait(0.08)
            }
        }
        await bettingRound(first: next(after: bb, where: live))

        if inHand.count > 1 {
            // The draw, starting left of the button.
            for i in seats.indices { seats[i].bet = 0 }
            currentBet = 0
            lastRaise = Self.bigBlind
            await wait(0.6)
            var i = dealer
            for _ in seats.indices {
                i = (i + 1) % seats.count
                guard !seats[i].folded else { continue }
                turn = i
                let toss: Set<Int>
                if seats[i].isHuman {
                    discards = []
                    message = "The draw! Tap up to three cards for Lavender to throw away (four if she keeps an ace)."
                    await withCheckedContinuation { drawCont = $0 }
                    toss = discards
                    discards = []
                } else {
                    message = "\(seats[i].name) is drawing…"
                    await wait(0.8)
                    toss = Set(Self.drawChoice(seats[i].hole).map(\.id))
                }
                for k in seats[i].hole.indices where toss.contains(seats[i].hole[k].id) {
                    seats[i].hole[k] = deck.removeFirst()
                }
                seats[i].note = toss.isEmpty ? "Stands pat" : "Draws \(toss.count)"
                message = "\(seats[i].name) \(toss.isEmpty ? "stands pat" : "draws \(toss.count)")."
                sound.card()
                await wait(0.6)
            }
            turn = nil
            if canAct.count >= 2 {
                for k in seats.indices where !seats[k].folded && !seats[k].allIn { seats[k].note = "" }
                await bettingRound(first: next(after: dealer, where: live))
            } else {
                await wait(0.8)
            }
        }
        await showdown()
    }

    /// Newcomers keep anything made, four to a flush or straight, or their two highest cards.
    static func drawChoice(_ hole: [Card]) -> [Card] {
        let category = HandEval.score5(hole) / 759375
        if category >= 4 { return [] }
        let counts = Dictionary(grouping: hole, by: \.rank).mapValues(\.count)
        if category >= 1 { return hole.filter { counts[$0.rank] == 1 } }
        if let four = Dictionary(grouping: hole, by: \.suit).values.first(where: { $0.count == 4 }) {
            return hole.filter { c in !four.contains(c) }
        }
        let ranks = hole.map(\.rank).sorted()
        for skip in ranks.indices {
            var rest = ranks
            rest.remove(at: skip)
            if rest.last! - rest.first! == 3 { return [hole.first { $0.rank == ranks[skip] }!] }
        }
        return Array(hole.sorted { $0.rank > $1.rank }.suffix(3))
    }

    private func showdown() async {
        turn = nil
        let contenders = inHand
        if contenders.count == 1 {
            let w = contenders[0]
            let amount = pot
            seats[w].stack += amount
            winners = [w]
            message = "\(seats[w].name) wins $\(amount)."
            sound.coin()
        } else {
            for i in contenders { seats[i].showCards = true }
            var score: [Int: Int] = [:]
            for i in contenders { score[i] = self.score(seats[i].hole, board) }
            let levels = Array(Set(contenders.map { seats[$0].put })).sorted()
            var prev = 0
            var paid = 0
            var lines: [String] = []
            var lastWinners: [Int] = []
            for level in levels {
                let part = seats.reduce(0) { $0 + min($1.put, level) - min($1.put, prev) }
                let eligible = contenders.filter { seats[$0].put >= level }
                let best = eligible.map { score[$0]! }.max()!
                let w = eligible.filter { score[$0] == best }
                distribute(part, to: w)
                paid += part
                lastWinners = w
                if part > 0 {
                    lines.append(w.map { seats[$0].name }.joined(separator: " & ") + " win\(w.count == 1 ? "s" : "") $\(part) with \(HandEval.name(of: best))")
                }
                prev = level
            }
            let leftover = pot - paid
            if leftover > 0 { distribute(leftover, to: lastWinners) }
            winners = Set(lastWinners)
            message = lines.joined(separator: " · ")
            sound.coin()
        }
        for i in seats.indices { seats[i].bet = 0 }
        await wait(contenders.count == 1 ? 1.8 : 3.6)
        for i in seats.indices { seats[i].put = 0 }
    }

    private func distribute(_ amount: Int, to w: [Int]) {
        guard !w.isEmpty else { return }
        let share = amount / w.count
        for i in w { seats[i].stack += share }
        seats[w[0]].stack += amount - share * w.count
    }

    private func checkDepartures() async {
        for i in seats.indices where !seats[i].isHuman && !seats[i].isPrincess && seats[i].seated {
            if seats[i].stack == 0 {
                depart(i, reason: "is out of money")
            } else if seats[i].stack >= Self.goal {
                depart(i, reason: "doubled her money")
            }
        }
        if human.stack == 0 && !human.hole.isEmpty {
            seats[0].hole = []
            banner = "Lavender is out of chips — she sits back and watches the rest of the game."
            await wait(2.5)
        }
    }

    private func depart(_ i: Int, reason: String) {
        guard seats[i].seated else { return }
        seats[i].seated = false
        seats[i].folded = true
        let d = Departure(name: seats[i].name, wasName: seats[i].wasName, takeaway: seats[i].stack, reason: reason, isKid: seats[i].isKid)
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

    /// What you won tonight (negative if you lost chips).
    var yourWinnings: Int { human.stack - Self.buyIn }
    /// What the Princess won tonight (negative if she lost chips).
    var princessWinnings: Int { (seats.first(where: \.isPrincess)?.stack ?? Self.buyIn) - Self.buyIn }
    /// Whatever you and the Princess win in the poker room is the salon's revenue.
    var revenue: Int { yourWinnings + princessWinnings }

    // MARK: Caribbean Stud

    static let ante = 5

    /// Your raise if you play this hand: twice the ante, or whatever you have left.
    var humanRaise: Int { min(human.bet * 2, human.stack) }

    private func anteSize(_ stack: Int) -> Int {
        stack >= Self.ante * 3 ? Self.ante : max(1, min(stack, stack / 3))
    }

    /// What a winning raise pays when the Princess qualifies: even money up to 100 to 1 for a royal flush.
    static func bonus(_ score: Int) -> Int {
        let category = score / 759375
        if category == 8 { return (score / 50625) % 15 == 14 ? 100 : 50 }
        return [1, 1, 2, 3, 4, 5, 7, 20][category]
    }

    /// The Princess plays her hand only with Ace-King or better.
    static func qualifies(_ score: Int) -> Bool {
        score / 759375 >= 1 || ((score / 50625) % 15 == 14 && (score / 3375) % 15 == 13)
    }

    /// Everyone antes and gets five cards against the Princess's five (one face up); each player folds
    /// her ante or raises double to play. The Princess's money is the house bank.
    private func playCaribbeanHand() async {
        let house = houseIndex
        handNumber += 1
        board = []
        dealerShown = false
        winners = []
        deck = Deck.shuffled()
        dealer = house
        for i in seats.indices {
            seats[i].hole = []
            seats[i].folded = i == house || !(seats[i].seated && seats[i].stack > 0)
            seats[i].allIn = false
            seats[i].bet = 0
            seats[i].put = 0
            seats[i].note = ""
            seats[i].showCards = false
        }
        let players = inHand
        message = "Hand \(handNumber). Ante up — $\(Self.ante) each."
        for i in players {
            let a = anteSize(seats[i].stack)
            move(i, a)
            seats[i].note = "Ante $\(a)"
        }
        sound.coin()
        await wait(0.6)
        for _ in 0..<5 {
            for i in players {
                seats[i].hole.append(deck.removeFirst())
                sound.card()
                await wait(0.08)
            }
            board.append(deck.removeFirst())
            sound.card()
            await wait(0.08)
        }
        message = "\(dealerName) shows the \(board[0].text). Lavender folds her ante, or raises double to play."

        for i in players {
            let raise = min(seats[i].bet * 2, seats[i].stack)
            turn = i
            let action: Action
            if seats[i].isHuman {
                message = "The Princess shows the \(board[0].text). Lavender's turn — raise $\(raise) to play, or fold."
                action = await withCheckedContinuation { humanCont = $0 }
            } else {
                await wait(0.8)
                action = caribbeanDecide(i)
            }
            if case .fold = action {
                seats[i].folded = true
                seats[i].note = "Fold"
                sayFold(i)
                seats[house].stack += seats[i].put
                seats[i].bet = 0
                seats[i].put = 0
            } else {
                move(i, raise)
                seats[i].note = raise > 0 ? "Raise $\(raise)" : "Play"
                sound.coin()
            }
        }
        turn = nil

        await wait(0.8)
        dealerShown = true
        sound.card()
        let theirs = HandEval.score5(board)
        let qualified = Self.qualifies(theirs)
        let still = inHand
        for i in still { seats[i].showCards = true }
        if still.isEmpty {
            message = "Everyone folded. \(dealerName) has \(HandEval.name(of: theirs))."
        } else {
            message = qualified
                ? "\(dealerName) has \(HandEval.name(of: theirs)) — she qualifies!"
                : "\(dealerName) doesn't qualify (needs Ace-King) — antes pay even money."
        }
        await wait(1.2)
        for i in still {
            let ante = seats[i].bet, staked = seats[i].put
            let raise = staked - ante
            let mine = HandEval.score5(seats[i].hole)
            if !qualified {
                seats[i].stack += staked + ante
                seats[house].stack -= ante
                seats[i].note = "Ante pays $\(ante)"
                winners.insert(i)
            } else if mine > theirs {
                let won = ante + raise * Self.bonus(mine)
                seats[i].stack += staked + won
                seats[house].stack -= won
                seats[i].note = "\(HandEval.name(of: mine)) wins $\(won)"
                winners.insert(i)
            } else if mine == theirs {
                seats[i].stack += staked
                seats[i].note = "Push"
            } else {
                seats[house].stack += staked
                seats[i].note = "Loses $\(staked)"
            }
            seats[i].bet = 0
            seats[i].put = 0
        }
        if winners.isEmpty && !still.isEmpty { winners = [house] }
        sound.coin()
        await wait(still.isEmpty ? 1.6 : 3.2)
    }

    /// Newcomers play pairs, sometimes Ace-King, and now and then a hunch.
    private func caribbeanDecide(_ i: Int) -> Action {
        let s = seats[i]
        let mine = HandEval.score5(s.hole)
        let r = Double.random(in: 0..<1)
        if mine / 759375 >= 1 { return .call }
        if (mine / 50625) % 15 == 14 && (mine / 3375) % 15 == 13 {
            let matchesUpCard = s.hole.contains { $0.rank == board[0].rank }
            return matchesUpCard || r < 0.5 + 0.3 * s.aggression ? .call : .fold
        }
        return r < 0.06 + 0.14 * s.aggression + 0.1 * looseness ? .call : .fold
    }

    // MARK: Newcomer AI

    private func decide(_ i: Int) -> Action {
        let s = seats[i]
        let toCall = currentBet - s.bet
        let opponents = max(1, inHand.count - 1)
        let eq = equity(s.hole, board, opponents: opponents)
        let potNow = pot
        let odds = toCall > 0 ? Double(toCall) / Double(potNow + toCall) : 0
        let r = Double.random(in: 0..<1)
        let aggro = s.aggression

        if eq > 0.82 - 0.1 * aggro && r < 0.35 + 0.3 * aggro {
            if r < 0.12 { return .raise(to: s.bet + s.stack) }
            let size = Double(max(potNow, 4)) * Double.random(in: 0.5...1.0)
            return .raise(to: currentBet + max(lastRaise, Int(size)))
        }
        if eq > 0.6 - 0.1 * aggro && r < 0.25 + 0.35 * aggro {
            let size = Double(max(potNow, 4)) * Double.random(in: 0.4...0.75)
            return .raise(to: currentBet + max(lastRaise, Int(size)))
        }
        if toCall == 0 {
            if r < 0.08 + 0.12 * aggro {
                return .raise(to: max(Self.bigBlind, Int(Double(potNow) * 0.5)))
            }
            return .check
        }
        if eq + 0.04 + looseness * 0.08 >= odds { return .call }
        if toCall <= Self.bigBlind * 2 && r < 0.35 + looseness * 0.3 { return .call }
        return .fold
    }

    /// Monte Carlo chance of winning against `opponents` random hands.
    private func equity(_ hole: [Card], _ board: [Card], opponents: Int, trials: Int = 220) -> Double {
        let trials = omaha ? trials / 2 : trials
        let n = hole.count
        let known = Set(hole.map(\.id) + board.map(\.id))
        let rest = Deck.shuffled().filter { !known.contains($0.id) }
        var won = 0.0
        for _ in 0..<trials {
            var pool = rest.shuffled()
            var b = board
            while b.count < 5 { b.append(pool.removeLast()) }
            let mine = score(hole, b)
            var beaten = false
            var ties = 1
            for _ in 0..<opponents {
                let theirs = score((0..<n).map { _ in pool.removeLast() }, b)
                if theirs > mine { beaten = true; break }
                if theirs == mine { ties += 1 }
            }
            if !beaten { won += 1 / Double(ties) }
        }
        return won / Double(trials)
    }
}
