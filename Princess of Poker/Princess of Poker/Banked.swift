import SwiftUI

/// Red Dog, Three Card Poker, Let It Ride, Mississippi Stud and Crazy 4 Poker at the salon's card table, banked by the Princess for real money.
/// They share seats, the house, departures at $0 or $100, last call and revenue; `game` picks which hand is dealt.
/// You can choose to be the house instead: you bank the table, and the Princess plays a seat.
@Observable final class BankedTable {
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
        /// Everything this player has riding on the current hand.
        var bets: [Int] = []
        /// The optional side bet: Three Card Poker's Pair Plus, or Crazy 4 Poker's Queens Up.
        var pairPlus = 0
        var folded = false
        var seated = true
        var note = ""
        /// 0…1: how boldly she bets.
        var aggression = 0.5
        var staked: Int { bets.reduce(0, +) + pairPlus }
    }

    static let lastCallHand = 30

    let game: HoldemTable.Game
    /// 0 is you; the newcomers follow; the Princess is last.
    var players: [Player]
    var handNumber = 0
    var turn: Int?
    var message = "Shuffle up and deal!"
    var banner: String?
    var departures: [HoldemTable.Departure] = []
    var winners: Set<Int> = []
    var finished = false
    /// Your bet for the next hand (kept from hand to hand).
    var humanBet = 5
    /// The question in front of you right now ("Raise?", "Let it ride?").
    var choice: (yes: String, no: String)?
    /// A pick of several buttons right now (Mississippi Stud: Fold / 1× / 2× / 3×).
    var options: [String]?

    // Red Dog: the two cards everyone plays, then the third.
    var shared: [Card] = []
    var spread: Int?
    // Three Card Poker / Crazy 4 Poker: the house's cards, and your Pair Plus / Queens Up switch.
    var dealerCards: [Card] = []
    var dealerShown = false
    var humanPairPlus = false
    // Let It Ride: the two community cards; Mississippi Stud: three.
    var community: [Card] = []
    var communityShown = 0

    private var betCont: CheckedContinuation<Void, Never>?
    private var choiceCont: CheckedContinuation<Bool, Never>?
    private var pickCont: CheckedContinuation<Int, Never>?
    private var roleCont: CheckedContinuation<Bool, Never>?
    let sound: Sound
    let pace: Double
    var onFinished: (() -> Void)?

    init(game: HoldemTable.Game, players: [Player], sound: Sound, pace: Double) {
        self.game = game
        self.players = players
        self.sound = sound
        self.pace = pace
    }

    var human: Player { players[0] }
    /// You chose to be the house: you bank the table; the Princess plays a seat.
    private(set) var youAreHouse = false
    var choosingRole: Bool { roleCont != nil }
    var princessIndex: Int { players.firstIndex(where: \.isPrincess) ?? players.count - 1 }
    var house: Int { youAreHouse ? 0 : princessIndex }
    /// The seat at the bottom of the table: you, or the Princess when you're the house.
    var bottom: Int { youAreHouse ? princessIndex : 0 }
    var dealerName: String { youAreHouse ? "Lavender" : "The Princess" }
    var humanToBet: Bool { betCont != nil }
    var humanToChoose: Bool { choiceCont != nil }
    var humanToPick: Bool { pickCont != nil }
    var watching: Bool { !youAreHouse && human.stack <= 0 && human.bets.isEmpty && !choosingRole }
    private var newcomers: [Int] { players.indices.filter { !players[$0].isHuman && !players[$0].isPrincess && players[$0].seated } }
    /// Everyone betting this hand (not the house), in seat order.
    private var bettors: [Int] { players.indices.filter { $0 != house && players[$0].seated && players[$0].stack > 0 } }

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

    func choose(_ yes: Bool) {
        guard let c = choiceCont else { return }
        choiceCont = nil
        choice = nil
        c.resume(returning: yes)
    }

    func pick(_ k: Int) {
        guard let c = pickCont else { return }
        pickCont = nil
        options = nil
        c.resume(returning: k)
    }

    func abandon() {
        if let c = roleCont { roleCont = nil; c.resume(returning: false) }
        if let c = betCont { betCont = nil; c.resume() }
        if let c = choiceCont { choiceCont = nil; choice = nil; c.resume(returning: false) }
        if let c = pickCont { pickCont = nil; options = nil; c.resume(returning: 0) }
    }

    // MARK: Flow

    func run() async {
        youAreHouse = await withCheckedContinuation { roleCont = $0 }
        if Task.isCancelled { return }
        if youAreHouse {
            message = "Lavender is the house! She banks the table; the Princess plays a seat."
            sound.speak("You're the house, honey. I'll play!", as: .princess)
        } else {
            sound.speak("\(game.name), girls! Place your bets.", as: .princess)
        }
        await wait(1.5)
        while !Task.isCancelled {
            if newcomers.isEmpty { break }
            if handNumber >= Self.lastCallHand {
                message = "Last call! The Princess closes the table."
                for i in newcomers { depart(i, reason: "cashes out at last call") }
                break
            }
            handNumber += 1
            winners = []
            for i in players.indices {
                players[i].cards = []
                players[i].bets = []
                players[i].pairPlus = 0
                players[i].folded = false
                players[i].note = ""
            }
            switch game {
            case .threeCard: await playThreeCard()
            case .letItRide: await playLetItRide()
            case .mississippiStud: await playMississippiStud()
            case .crazy4: await playCrazy4()
            default: await playRedDog()
            }
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

    /// Waits for you to pick your chip and press Deal; returns the bet.
    private func humanBets(_ prompt: String, max cap: Int) async -> Int {
        humanBet = min(humanBet, cap)
        message = prompt
        await withCheckedContinuation { betCont = $0 }
        return max(1, min(humanBet, cap))
    }

    /// Asks you a yes/no question at the table.
    private func humanChooses(_ prompt: String, yes: String, no: String) async -> Bool {
        message = prompt
        choice = (yes, no)
        return await withCheckedContinuation { choiceCont = $0 }
    }

    /// Asks you to pick one of several buttons; returns its index.
    private func humanPicks(_ prompt: String, _ labels: [String]) async -> Int {
        message = prompt
        options = labels
        return await withCheckedContinuation { pickCont = $0 }
    }

    /// A newcomer's opening bet: $5, sometimes $10 for the bold ones.
    private func newcomerBet(_ i: Int, max cap: Int) -> Int {
        min(players[i].aggression > 0.6 && Bool.random() ? 10 : 5, cap)
    }

    private func sayFold(_ i: Int) {
        sound.speak("Fold", as: players[i].isPrincess ? .princess : players[i].isKid ? .kidGirl : .girl)
    }

    /// Returns player `i`'s stake plus `amount` won from the house (a negative amount goes to the house).
    private func settle(_ i: Int, won amount: Int) {
        players[i].stack += players[i].staked + amount
        players[house].stack -= amount
        if amount > 0 { winners.insert(i) }
    }

    private func checkDepartures() async {
        for i in newcomers {
            if players[i].stack <= 0 {
                depart(i, reason: "is out of money")
            } else if players[i].stack >= HoldemTable.goal {
                depart(i, reason: "doubled her money")
            }
        }
        if !youAreHouse && human.stack <= 0 && !human.bets.isEmpty {
            players[0].cards = []
            players[0].bets = []
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
}

// MARK: - Red Dog

enum RedDog {
    /// Pays on a win by spread: 1 card → 5 to 1, 2 → 4 to 1, 3 → 2 to 1, 4 or more → even money.
    static func payout(spread: Int) -> Int { spread <= 3 ? [0, 5, 4, 2][max(0, spread)] : 1 }
}

/// Red Dog (acey-deucey): everyone bets, two cards go face up for the whole table, and the third card
/// has to land between them. The tighter the spread, the bigger the payout; you may double your bet first.
extension BankedTable {
    fileprivate func playRedDog() async {
        shared = []
        spread = nil
        var deck = Deck.shuffled()
        for i in bettors {
            turn = i
            let bet: Int
            if players[i].isHuman {
                if Task.isCancelled { return }
                bet = await humanBets("Hand \(handNumber). Lavender places her bet.", max: players[i].stack)
            } else {
                await wait(0.35)
                bet = newcomerBet(i, max: players[i].stack)
            }
            players[i].stack -= bet
            players[i].bets = [bet]
            players[i].note = "Bet $\(bet)"
            sound.coin()
        }
        turn = nil
        let inHand = players.indices.filter { !players[$0].bets.isEmpty }
        guard !inHand.isEmpty else { return }

        for _ in 0..<2 {
            shared.append(deck.removeFirst())
            sound.card()
            await wait(0.5)
        }
        let lo = min(shared[0].rank, shared[1].rank), hi = max(shared[0].rank, shared[1].rank)
        if hi - lo == 1 {
            message = "Consecutive cards — it's a push. Everyone keeps her bet."
            for i in inHand { settle(i, won: 0); players[i].note = "Push" }
            await wait(2.4)
            return
        }
        if hi == lo {
            message = "A pair! A third card — three of a kind pays 11 to 1."
            await wait(1.2)
            shared.append(deck.removeFirst())
            sound.card()
            let trips = shared[2].rank == lo
            for i in inHand {
                let win = trips ? players[i].bets[0] * 11 : 0
                settle(i, won: win)
                players[i].note = trips ? "Wins $\(win)" : "Push"
            }
            message = trips ? "Three of a kind! 11 to 1!" : "No third match — a push."
            if trips { sound.chime() }
            await wait(2.6)
            return
        }
        let s = hi - lo - 1
        spread = s
        let pays = RedDog.payout(spread: s)
        sound.speak("The spread is \(s). It pays \(pays) to 1.", as: youAreHouse ? .girl : .princess)
        message = "Spread of \(s) — pays \(pays) to 1. Raise (double the bet) or stay?"
        await wait(1.0)
        for i in inHand {
            turn = i
            let raise: Bool
            let canRaise = players[i].stack >= players[i].bets[0]
            if players[i].isHuman && canRaise {
                if Task.isCancelled { return }
                raise = await humanChooses("Spread of \(s) — pays \(pays) to 1. Lavender's turn: raise $\(players[i].bets[0]) or stay?",
                                           yes: "Raise $\(players[i].bets[0])", no: "Stay")
            } else {
                await wait(0.5)
                raise = canRaise && !players[i].isHuman && s >= 7 - Int(players[i].aggression * 2)
            }
            if raise {
                players[i].stack -= players[i].bets[0]
                players[i].bets.append(players[i].bets[0])
                players[i].note = "Raise to $\(players[i].staked)"
                sound.coin()
            } else {
                players[i].note = "Stays $\(players[i].staked)"
            }
        }
        turn = nil
        await wait(0.6)
        shared.append(deck.removeFirst())
        sound.card()
        let third = shared[2].rank
        let between = third > lo && third < hi
        for i in inHand {
            let stake = players[i].staked
            let win = between ? stake * pays : -stake
            settle(i, won: win)
            players[i].note = between ? "Wins $\(win)" : "Loses $\(stake)"
        }
        if !between { winners.insert(house) }
        message = between ? "The \(shared[2].text) lands in between — winners!" : "The \(shared[2].text) is outside — the house wins."
        sound.coin()
        await wait(2.8)
    }
}

// MARK: - Three Card Poker

enum ThreeCard {
    static let names = ["High Card", "Pair", "Flush", "Straight", "Three of a Kind", "Straight Flush"]

    /// A comparable score for three cards (bigger wins).
    static func score(_ c: [Card]) -> Int {
        let r = c.map(\.rank).sorted(by: >)
        let flush = Set(c.map(\.suit)).count == 1
        var straightHigh = 0
        if r[0] - r[1] == 1 && r[1] - r[2] == 1 { straightHigh = r[0] }
        if r == [14, 3, 2] { straightHigh = 3 }
        let cat: Int
        var tie = r
        if straightHigh > 0 && flush { cat = 5; tie = [straightHigh, 0, 0] }
        else if r[0] == r[2] { cat = 4 }
        else if straightHigh > 0 { cat = 3; tie = [straightHigh, 0, 0] }
        else if flush { cat = 2 }
        else if r[0] == r[1] || r[1] == r[2] {
            cat = 1
            let pair = r[1], kick = r[0] == r[1] ? r[2] : r[0]
            tie = [pair, kick, 0]
        } else { cat = 0 }
        return ((cat * 15 + tie[0]) * 15 + tie[1]) * 15 + tie[2]
    }

    static func category(_ score: Int) -> Int { score / 3375 }
    static func name(_ c: [Card]) -> String { names[category(score(c))] }
    /// The house needs Queen-high or better.
    static func qualifies(_ score: Int) -> Bool { category(score) >= 1 || (score / 225) % 15 >= 12 }
    static func anteBonus(_ cat: Int) -> Int { [0, 0, 0, 1, 4, 5][cat] }
    static func pairPlusPays(_ cat: Int) -> Int { [0, 1, 4, 6, 30, 40][cat] }
}

/// Three Card Poker against the house's three cards: ante, then fold or play (match the ante).
/// The house needs Queen-high to qualify. The optional Pair Plus bet pays on your hand alone.
extension BankedTable {
    fileprivate func playThreeCard() async {
        dealerCards = []
        dealerShown = false
        var deck = Deck.shuffled()
        for i in bettors {
            turn = i
            var ante: Int
            var pp = 0
            if players[i].isHuman {
                if Task.isCancelled { return }
                ante = await humanBets("Hand \(handNumber). Lavender antes — playing costs the same again.", max: max(1, players[i].stack / 2))
                if humanPairPlus && players[i].stack - ante >= 5 { pp = 5 }
            } else {
                await wait(0.35)
                ante = newcomerBet(i, max: max(1, players[i].stack / 2))
                if players[i].stack - ante >= 5 && Double.random(in: 0..<1) < 0.3 + 0.3 * players[i].aggression { pp = 5 }
            }
            ante = min(ante, players[i].stack)
            players[i].stack -= ante + pp
            players[i].bets = [ante]
            players[i].pairPlus = pp
            players[i].note = "Ante $\(ante)" + (pp > 0 ? " + PP $\(pp)" : "")
            sound.coin()
        }
        turn = nil
        let inHand = players.indices.filter { !players[$0].bets.isEmpty }
        guard !inHand.isEmpty else { return }
        for _ in 0..<3 {
            for i in inHand { players[i].cards.append(deck.removeFirst()) }
            dealerCards.append(deck.removeFirst())
            sound.card()
            await wait(0.12)
        }
        for i in inHand { players[i].cards.sort { $0.rank > $1.rank } }

        for i in inHand {
            turn = i
            let ante = players[i].bets[0]
            let canPlay = players[i].stack >= ante
            let play: Bool
            if players[i].isHuman {
                if Task.isCancelled { return }
                play = canPlay ? await humanChooses("Lavender has \(ThreeCard.name(players[i].cards)). Play for $\(ante) more, or fold?",
                                                     yes: "Play $\(ante)", no: "Fold") : false
            } else {
                await wait(0.6)
                // Play Queen-6-4 or better, with a little extra nerve for the bold ones.
                let mine = ThreeCard.score(players[i].cards)
                play = canPlay && (mine >= ThreeCard.score([Card(rank: 12, suit: .clubs), Card(rank: 6, suit: .hearts), Card(rank: 4, suit: .spades)])
                                   || Double.random(in: 0..<1) < 0.1 * players[i].aggression)
            }
            if play {
                players[i].stack -= ante
                players[i].bets.append(ante)
                players[i].note = "Plays $\(ante)"
                sound.coin()
            } else {
                players[i].folded = true
                players[i].note = "Fold"
                sayFold(i)
            }
        }
        turn = nil
        await wait(0.7)
        dealerShown = true
        sound.card()
        let theirs = ThreeCard.score(dealerCards)
        let qualified = ThreeCard.qualifies(theirs)
        message = "\(dealerName) has \(ThreeCard.names[ThreeCard.category(theirs)])" + (qualified ? " — the house qualifies." : " — the house doesn't qualify (needs Queen-high).")
        await wait(1.2)
        var houseWon = false
        for i in inHand {
            let ante = players[i].bets[0]
            let mine = ThreeCard.score(players[i].cards)
            let cat = ThreeCard.category(mine)
            var win = 0
            if players[i].folded {
                win -= ante
            } else {
                let play = players[i].bets[1]
                if !qualified { win += ante }
                else if mine > theirs { win += ante + play }
                else if mine < theirs { win -= ante + play; houseWon = true }
                win += ante * ThreeCard.anteBonus(cat)
            }
            let pp = players[i].pairPlus
            if pp > 0 {
                let pays = ThreeCard.pairPlusPays(cat)
                win += pays > 0 ? pp * pays : -pp
            }
            settle(i, won: win)
            players[i].note = win > 0 ? "Wins $\(win)" : (win < 0 ? "Loses $\(-win)" : "Push")
        }
        if houseWon { winners.insert(house) }
        sound.coin()
        await wait(3.0)
    }
}

// MARK: - Let It Ride

enum LetItRide {
    /// What the five-card hand pays per bet left riding (0 = loses).
    static func pays(_ c: [Card]) -> (Int, String) {
        let s = HandEval.score5(c)
        let top = (s / 50625) % 15
        switch s / 759375 {
        case 8: return top == 14 ? (1000, "Royal Flush") : (200, "Straight Flush")
        case 7: return (50, "Four of a Kind")
        case 6: return (11, "Full House")
        case 5: return (8, "Flush")
        case 4: return (5, "Straight")
        case 3: return (3, "Three of a Kind")
        case 2: return (2, "Two Pair")
        case 1: return top >= 10 ? (1, "Pair of \(Card(rank: top, suit: .clubs).rankText)s") : (0, "Low Pair")
        default: return (0, "High Card")
        }
    }
}

/// Let It Ride: three equal bets, three cards each and two community cards. Pull back a bet after seeing your
/// cards, and another after the first community card — or let them ride. Pays on a pair of 10s or better.
extension BankedTable {
    private func keepsRiding(_ cards: [Card], aggression: Double) -> Bool {
        let counts = Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
        if counts.contains(where: { $0.value >= 2 && ($0.key >= 10 || $0.value >= 3 || cards.count >= 4) }) { return true }
        let ranks = cards.map(\.rank)
        if cards.count >= 3 && Set(cards.map(\.suit)).count == 1 && ranks.max()! - ranks.min()! <= 4 { return true }
        if cards.count == 4 && Dictionary(grouping: cards, by: \.suit).values.contains(where: { $0.count == 4 }) { return true }
        return Double.random(in: 0..<1) < 0.06 * aggression
    }

    fileprivate func playLetItRide() async {
        community = []
        communityShown = 0
        var deck = Deck.shuffled()
        for i in bettors {
            turn = i
            if players[i].stack < 3 {
                if !players[i].isHuman && !players[i].isPrincess { depart(i, reason: "can't cover three bets") }
                continue
            }
            var unit: Int
            if players[i].isHuman {
                if Task.isCancelled { return }
                unit = await humanBets("Hand \(handNumber). Lavender places three equal bets.", max: players[i].stack / 3)
            } else {
                await wait(0.35)
                unit = players[i].aggression > 0.65 && Bool.random() ? 10 : 5
            }
            unit = max(1, min(unit, players[i].stack / 3))
            players[i].stack -= unit * 3
            players[i].bets = [unit, unit, unit]
            players[i].note = "3 × $\(unit)"
            sound.coin()
        }
        turn = nil
        let inHand = players.indices.filter { !players[$0].bets.isEmpty }
        guard !inHand.isEmpty else { return }
        for _ in 0..<3 {
            for i in inHand { players[i].cards.append(deck.removeFirst()) }
            sound.card()
            await wait(0.12)
        }
        community = [deck.removeFirst(), deck.removeFirst()]

        for round in 0..<2 {
            for i in inHand {
                turn = i
                // The third bet always rides, so it remembers the bet size.
                let unit = players[i].bets[2]
                let seen = players[i].cards + community.prefix(communityShown)
                let ride: Bool
                if players[i].isHuman {
                    if Task.isCancelled { return }
                    ride = await humanChooses("Bet \(round + 1): Lavender pulls back $\(unit), or lets it ride?", yes: "Let it ride", no: "Pull back $\(unit)")
                } else {
                    await wait(0.6)
                    ride = keepsRiding(seen, aggression: players[i].aggression)
                }
                if !ride {
                    players[i].bets[round] = 0
                    players[i].stack += unit
                    players[i].note = "Pulls back bet \(round + 1)"
                } else {
                    players[i].note = "Lets it ride"
                }
            }
            turn = nil
            await wait(0.5)
            communityShown += 1
            sound.card()
            message = "Community card: \(community[round].text)"
            await wait(0.9)
        }
        var houseWon = false
        for i in inHand {
            let riding = players[i].staked
            let (pays, name) = LetItRide.pays(players[i].cards + community)
            let win = pays > 0 ? riding * pays : -riding
            if win < 0 { houseWon = true }
            settle(i, won: win)
            players[i].note = pays > 0 ? "\(name) wins $\(win)" : "Loses $\(riding)"
        }
        if houseWon { winners.insert(house) }
        message = "Pays on a pair of 10s or better."
        sound.coin()
        await wait(3.0)
    }
}

// MARK: - Mississippi Stud

enum MississippiStud {
    /// What the five-card hand pays per dollar bet (0 = push on 6s–10s, -1 = loses).
    static func pays(_ c: [Card]) -> (Int, String) {
        let s = HandEval.score5(c)
        let top = (s / 50625) % 15
        switch s / 759375 {
        case 8: return top == 14 ? (500, "Royal Flush") : (100, "Straight Flush")
        case 7: return (40, "Four of a Kind")
        case 6: return (10, "Full House")
        case 5: return (6, "Flush")
        case 4: return (4, "Straight")
        case 3: return (3, "Three of a Kind")
        case 2: return (2, "Two Pair")
        case 1:
            let pair = "Pair of \(Card(rank: top, suit: .clubs).rankText)s"
            return top >= 11 ? (1, pair) : top >= 6 ? (0, pair) : (-1, "Low Pair")
        default: return (-1, "High Card")
        }
    }

    /// How many antes a newcomer bets on this street (0 = fold), from the cards she can see.
    static func streetBet(_ cards: [Card], aggression: Double) -> Int {
        let counts = Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
        if counts.values.contains(where: { $0 >= 3 }) { return 3 }
        if let pair = counts.first(where: { $0.value == 2 })?.key {
            return pair >= 6 || counts.values.filter({ $0 == 2 }).count == 2 ? 3 : 1
        }
        let suited = Dictionary(grouping: cards, by: \.suit).values.map(\.count).max() ?? 0
        if suited == cards.count && cards.count >= 3 { return 3 }
        let highs = cards.filter { $0.rank >= 11 }.count
        let mids = cards.filter { $0.rank >= 6 }.count
        if highs >= 2 || (cards.count >= 4 && suited == 4) { return Double.random(in: 0..<1) < aggression ? 3 : 1 }
        if highs >= 1 || mids >= cards.count - (cards.count >= 4 ? 1 : 0) { return 1 }
        return Double.random(in: 0..<1) < 0.08 * aggression ? 1 : 0
    }
}

/// Mississippi Stud: an ante, two cards each and three community cards. Before each community card turns,
/// fold or bet one to three times the ante. Everything left on the table pays on a pair of Jacks or better;
/// a pair of 6s through 10s pushes.
extension BankedTable {
    fileprivate func playMississippiStud() async {
        community = []
        communityShown = 0
        var deck = Deck.shuffled()
        for i in bettors {
            turn = i
            // The ante plus up to 3× on each of three streets.
            let cap = max(1, players[i].stack / 10)
            var ante: Int
            if players[i].isHuman {
                if Task.isCancelled { return }
                ante = await humanBets("Hand \(handNumber). Lavender antes — each street can cost up to three antes more.", max: cap)
            } else {
                await wait(0.35)
                ante = newcomerBet(i, max: cap)
            }
            ante = max(1, min(ante, players[i].stack))
            players[i].stack -= ante
            players[i].bets = [ante]
            players[i].note = "Ante $\(ante)"
            sound.coin()
        }
        turn = nil
        let inHand = players.indices.filter { !players[$0].bets.isEmpty }
        guard !inHand.isEmpty else { return }
        for _ in 0..<2 {
            for i in inHand { players[i].cards.append(deck.removeFirst()) }
            sound.card()
            await wait(0.12)
        }
        community = [deck.removeFirst(), deck.removeFirst(), deck.removeFirst()]

        let streets = ["3rd street", "4th street", "5th street"]
        for street in 0..<3 {
            for i in inHand where !players[i].folded {
                turn = i
                let ante = players[i].bets[0]
                let affordable = min(3, players[i].stack / ante)
                let seen = players[i].cards + community.prefix(communityShown)
                var times: Int
                if players[i].isHuman {
                    if Task.isCancelled { return }
                    let labels = ["Fold"] + (0..<affordable).map { "\($0 + 1)× $\(ante * ($0 + 1))" }
                    times = await humanPicks("\(streets[street].capitalized): Lavender folds, or bets 1 to 3 antes?", labels)
                } else {
                    await wait(0.6)
                    times = MississippiStud.streetBet(seen, aggression: players[i].aggression)
                }
                times = min(times, affordable)
                if times == 0 {
                    players[i].folded = true
                    players[i].note = "Fold"
                    sayFold(i)
                } else {
                    players[i].stack -= ante * times
                    players[i].bets.append(ante * times)
                    players[i].note = "Bets \(times)× · $\(players[i].staked)"
                    sound.coin()
                }
            }
            turn = nil
            await wait(0.5)
            communityShown += 1
            sound.card()
            message = "Community card: \(community[street].text)"
            await wait(0.9)
        }
        var houseWon = false
        for i in inHand {
            let staked = players[i].staked
            if players[i].folded {
                settle(i, won: -staked)
                houseWon = true
                continue
            }
            let (pays, name) = MississippiStud.pays(players[i].cards + community)
            let win = pays >= 0 ? staked * pays : -staked
            if win < 0 { houseWon = true }
            if pays > 2 { sound.chime() }
            settle(i, won: win)
            players[i].note = win > 0 ? "\(name) wins $\(win)" : win == 0 ? "\(name) · Push" : "Loses $\(staked)"
        }
        if houseWon { winners.insert(house) }
        message = "Pays on Jacks or better · 6s–10s push."
        sound.coin()
        await wait(3.0)
    }
}

// MARK: - Crazy 4 Poker

enum Crazy4 {
    static let names = ["High Card", "Pair", "Two Pair", "Straight", "Flush", "Three of a Kind", "Straight Flush", "Four of a Kind"]

    /// A comparable score for four cards (bigger wins). Four of a kind beats a straight flush; A-2-3-4 is the low straight.
    static func score4(_ c: [Card]) -> Int {
        var counts = [Int](repeating: 0, count: 15)
        for card in c { counts[card.rank] += 1 }
        let flush = c.allSatisfy { $0.suit == c[0].suit }
        let order = (2...14).filter { counts[$0] > 0 }.sorted {
            counts[$0] != counts[$1] ? counts[$0] > counts[$1] : $0 > $1
        }
        var straightHigh = 0
        if order.count == 4 {
            if order.max()! - order.min()! == 3 { straightHigh = order.max()! }
            if Set(order) == [14, 2, 3, 4] { straightHigh = 4 }
        }
        let cat: Int
        var tiebreak = order
        if counts[order[0]] == 4 { cat = 7 }
        else if straightHigh > 0 && flush { cat = 6; tiebreak = [straightHigh] }
        else if counts[order[0]] == 3 { cat = 5 }
        else if flush { cat = 4 }
        else if straightHigh > 0 { cat = 3; tiebreak = [straightHigh] }
        else if counts[order[0]] == 2 && order.count == 2 { cat = 2 }
        else if counts[order[0]] == 2 { cat = 1 }
        else { cat = 0 }
        var s = cat
        for i in 0..<4 { s = s * 15 + (i < tiebreak.count ? tiebreak[i] : 0) }
        return s
    }

    /// The best four cards out of five.
    static func best(_ five: [Card]) -> Int {
        five.indices.map { k in score4(five.enumerated().filter { $0.offset != k }.map(\.element)) }.max() ?? 0
    }

    static func category(_ score: Int) -> Int { score / 50625 }
    static func top(_ score: Int) -> Int { (score / 3375) % 15 }
    static func name(_ score: Int) -> String {
        let cat = category(score)
        return cat == 1 ? "Pair of \(Card(rank: top(score), suit: .clubs).rankText)s" : names[cat]
    }
    /// The house needs King-high or better.
    static func qualifies(_ score: Int) -> Bool { category(score) >= 1 || top(score) >= 13 }
    /// A pair of Aces or better may play up to three times the ante.
    static func playsTriple(_ score: Int) -> Bool { category(score) >= 2 || (category(score) == 1 && top(score) == 14) }

    /// What the Super Bonus wins on a straight or better (nil = the hand is too small).
    static func superBonus(_ score: Int, bet: Int) -> Int? {
        switch category(score) {
        case 7: top(score) == 14 ? bet * 200 : bet * 30
        case 6: bet * 15
        case 5: bet * 2
        case 4: bet * 3 / 2
        case 3: bet
        default: nil
        }
    }

    /// The Queens Up side bet, paid on your hand alone (0 = loses).
    static func queensUp(_ score: Int) -> Int {
        switch category(score) {
        case 7: 50
        case 6: 40
        case 5: 7
        case 4: 4
        case 3: 3
        case 2: 2
        case 1: top(score) >= 12 ? 1 : 0
        default: 0
        }
    }
}

/// Crazy 4 Poker against the house: equal Ante and Super Bonus bets, five cards each, best four count.
/// Fold, or play once the ante — three times with a pair of Aces or better. The house needs King-high to keep the ante in action;
/// the Super Bonus pays on a straight or better even if the house wins. The optional Queens Up bet pays on your hand alone.
extension BankedTable {
    fileprivate func playCrazy4() async {
        dealerCards = []
        dealerShown = false
        var deck = Deck.shuffled()
        for i in bettors {
            turn = i
            if players[i].stack < 2 {
                if !players[i].isHuman && !players[i].isPrincess { depart(i, reason: "can't cover the ante and super bonus") }
                continue
            }
            // Ante + Super Bonus + up to 3× to play.
            let cap = max(1, players[i].stack / 5)
            var ante: Int
            var qu = 0
            if players[i].isHuman {
                if Task.isCancelled { return }
                ante = await humanBets("Hand \(handNumber). Lavender antes — the Super Bonus matches it.", max: cap)
                if humanPairPlus && players[i].stack - ante * 2 >= 5 { qu = 5 }
            } else {
                await wait(0.35)
                ante = newcomerBet(i, max: cap)
                if players[i].stack - ante * 2 >= 5 && Double.random(in: 0..<1) < 0.25 + 0.3 * players[i].aggression { qu = 5 }
            }
            ante = max(1, min(ante, players[i].stack / 2))
            players[i].stack -= ante * 2 + qu
            players[i].bets = [ante, ante]
            players[i].pairPlus = qu
            players[i].note = "Ante $\(ante) + SB $\(ante)" + (qu > 0 ? " + QU $\(qu)" : "")
            sound.coin()
        }
        turn = nil
        let inHand = players.indices.filter { !players[$0].bets.isEmpty }
        guard !inHand.isEmpty else { return }
        for _ in 0..<5 {
            for i in inHand { players[i].cards.append(deck.removeFirst()) }
            dealerCards.append(deck.removeFirst())
            sound.card()
            await wait(0.12)
        }
        for i in inHand { players[i].cards.sort { $0.rank > $1.rank } }

        for i in inHand {
            turn = i
            let ante = players[i].bets[0]
            let mine = Crazy4.best(players[i].cards)
            let maxTimes = players[i].stack >= ante * 3 && Crazy4.playsTriple(mine) ? 3 : players[i].stack >= ante ? 1 : 0
            var times: Int
            if players[i].isHuman {
                if Task.isCancelled { return }
                if maxTimes == 0 {
                    times = 0
                } else {
                    let labels = ["Fold", "Play 1× $\(ante)"] + (maxTimes == 3 ? ["Play 3× $\(ante * 3)"] : [])
                    times = await humanPicks("Lavender has \(Crazy4.name(mine)). Fold, or play?" + (maxTimes == 3 ? " Aces or better can play 3×!" : ""), labels)
                    if times == 2 { times = 3 }
                }
            } else {
                await wait(0.6)
                // Raise big with Aces or better; play King-high or better; once in a while a bold one plays anyway.
                times = Crazy4.playsTriple(mine) ? (Double.random(in: 0..<1) < 0.5 + 0.5 * players[i].aggression ? 3 : 1)
                    : Crazy4.qualifies(mine) || Double.random(in: 0..<1) < 0.1 * players[i].aggression ? 1 : 0
                times = min(times, maxTimes)
            }
            if times == 0 {
                players[i].folded = true
                players[i].note = "Fold"
                sayFold(i)
            } else {
                players[i].stack -= ante * times
                players[i].bets.append(ante * times)
                players[i].note = "Plays \(times)× · $\(ante * times)"
                sound.coin()
            }
        }
        turn = nil
        await wait(0.7)
        dealerShown = true
        sound.card()
        let theirs = Crazy4.best(dealerCards)
        let qualified = Crazy4.qualifies(theirs)
        message = "\(dealerName) has \(Crazy4.name(theirs))" + (qualified ? " — the house qualifies." : " — the house doesn't qualify (needs King-high). Antes push.")
        await wait(1.2)
        var houseWon = false
        for i in inHand {
            let ante = players[i].bets[0], sb = players[i].bets[1]
            let mine = Crazy4.best(players[i].cards)
            var win = 0
            if players[i].folded {
                win -= ante + sb
            } else {
                let play = players[i].bets[2]
                if mine > theirs {
                    win += play + (qualified ? ante : 0)
                } else if mine < theirs {
                    win -= play + (qualified ? ante : 0)
                    houseWon = true
                }
                if let bonus = Crazy4.superBonus(mine, bet: sb) {
                    win += bonus
                    sound.chime()
                } else if mine < theirs {
                    win -= sb
                }
            }
            let qu = players[i].pairPlus
            if qu > 0 {
                let pays = Crazy4.queensUp(mine)
                win += pays > 0 ? qu * pays : -qu
            }
            settle(i, won: win)
            players[i].note = (players[i].folded ? "" : "\(Crazy4.name(mine)) · ") + (win > 0 ? "Wins $\(win)" : win < 0 ? "Loses $\(-win)" : "Push")
        }
        if houseWon { winners.insert(house) }
        sound.coin()
        await wait(3.0)
    }
}

// MARK: - View

struct BankedView: View {
    @Bindable var table: BankedTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color
    let goldChips: Bool

    private var game: HoldemTable.Game { table.game }
    private let spots: [CGPoint] = [CGPoint(x: 0.14, y: 0.42), CGPoint(x: 0.86, y: 0.42), CGPoint(x: 0.16, y: 0.72), CGPoint(x: 0.84, y: 0.72)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · \(game.name) · Hand \(table.handNumber)")
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
                    CasinoSeat(name: table.youAreHouse ? "Lavender · House" : "Princess · House", skin: h.skin, look: h.look, isPrincess: h.isPrincess,
                               stack: h.stack, note: "", isTurn: false, winner: table.winners.contains(table.house), seated: true, goldChips: goldChips) { EmptyView() }
                        .position(x: size.width * 0.5, y: size.height * 0.11)
                    middle(size)
                        .position(x: size.width * 0.5, y: size.height * 0.4)
                    let others = table.players.indices.filter { $0 != table.house && $0 != table.bottom }
                    ForEach(Array(others.enumerated()), id: \.element) { k, i in
                        let p = table.players[i]
                        CasinoSeat(name: p.isHuman ? "Lavender" : p.name, skin: p.skin, look: p.look, isPrincess: p.isPrincess, stack: p.stack, note: p.note,
                                   isTurn: table.turn == i, winner: table.winners.contains(i), seated: p.seated, goldChips: goldChips) {
                            if !p.cards.isEmpty {
                                HStack(spacing: -8) {
                                    ForEach(p.cards) { c in CardView(card: c, faceUp: reveal, width: 20) }
                                }
                            }
                        }
                        .position(x: size.width * spots[k % spots.count].x, y: size.height * spots[k % spots.count].y)
                    }
                    let b = table.players[table.bottom]
                    if !b.cards.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(b.cards) { c in CardView(card: c, faceUp: !table.youAreHouse || reveal, dim: b.folded, width: 54) }
                        }
                        .position(x: size.width * 0.5, y: size.height * 0.66)
                    }
                    CasinoSeat(name: table.youAreHouse ? "Princess · player" : "Lavender", skin: b.skin, look: b.look, isPrincess: b.isPrincess,
                               stack: b.stack, note: b.note, isTurn: table.turn == table.bottom,
                               winner: table.winners.contains(table.bottom), seated: true, goldChips: goldChips) { EmptyView() }
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
        .background(LinearGradient(colors: [Color(red: 0.2, green: 0.03, blue: 0.22), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.default, value: table.banner)
    }

    /// The newcomers' cards stay face down until the hand is settled.
    private var reveal: Bool {
        switch game {
        case .threeCard, .crazy4: table.dealerShown
        case .letItRide: table.communityShown == 2
        case .mississippiStud: table.communityShown == 3
        default: true
        }
    }

    @ViewBuilder private func middle(_ size: CGSize) -> some View {
        let w = min(52, size.width * 0.11)
        let t = table
        VStack(spacing: 6) {
            switch game {
            case .threeCard:
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { k in CardView(card: t.dealerCards[safe: k], faceUp: t.dealerShown || t.youAreHouse, width: w) }
                }
                caption("HOUSE QUALIFIES WITH QUEEN HIGH · PAIR PLUS 1/4/6/30/40")
            case .letItRide:
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { k in CardView(card: t.community[safe: k], faceUp: k < t.communityShown, width: w) }
                }
                caption("10s+ 1 · 2P 2 · 3K 3 · STR 5 · FL 8 · FH 11 · 4K 50 · SF 200 · RF 1000")
            case .mississippiStud:
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { k in CardView(card: t.community[safe: k], faceUp: k < t.communityShown, width: w) }
                }
                caption("6–10 PUSH · JJ+ 1 · 2P 2 · 3K 3 · STR 4 · FL 6 · FH 10 · 4K 40 · SF 100 · RF 500")
            case .crazy4:
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { k in CardView(card: t.dealerCards[safe: k], faceUp: t.dealerShown || t.youAreHouse, width: w * 0.85) }
                }
                caption("BEST 4 CARDS · HOUSE QUALIFIES WITH KING HIGH · AA+ MAY PLAY 3×")
                caption("SUPER BONUS STR 1 · FL 3:2 · 3K 2 · SF 15 · 4K 30 · AAAA 200 · QUEENS UP QQ+ 1 · 2P 2 · STR 3 · FL 4 · 3K 7 · SF 40 · 4K 50")
            default:
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { k in CardView(card: t.shared[safe: k], width: w) }
                }
                caption(t.spread.map { "SPREAD \($0) · PAYS \(RedDog.payout(spread: $0)) TO 1" } ?? "1 → 5:1 · 2 → 4:1 · 3 → 2:1 · 4+ → 1:1 · TRIPS 11:1")
            }
            Text(table.message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: size.width * 0.56)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(.yellow)
            .multilineTextAlignment(.center)
    }

    private func waiting(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder private var actionBar: some View {
        if table.finished {
            Text("The table is closed for the day.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.choosingRole {
            RoleChoice(detail: "Should Lavender play a seat against the Princess, or be the house and bank the \(game.name) table? Then the Princess plays instead.") {
                table.chooseRole(house: $0)
            }
        } else if table.humanToBet {
            VStack(spacing: 8) {
                if game == .threeCard || game == .crazy4 {
                    Toggle(game == .crazy4 ? "Queens Up side bet ($5)" : "Pair Plus side bet ($5)", isOn: $table.humanPairPlus)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .tint(.pink)
                }
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
                CasinoButton(title: game == .letItRide ? "Deal — 3 × $\(table.humanBet)" : game == .crazy4 ? "Deal — ante + bonus $\(table.humanBet * 2)" : game == .threeCard || game == .mississippiStud ? "Deal — ante $\(table.humanBet)" : "Deal — bet $\(table.humanBet)",
                             color: .pink) { table.placeBet() }
            }
        } else if let labels = table.options, table.humanToPick {
            HStack(spacing: 6) {
                ForEach(Array(labels.enumerated()), id: \.offset) { k, label in
                    CasinoButton(title: label, color: k == 0 ? .gray : .pink) { table.pick(k) }
                }
            }
        } else if let c = table.choice, table.humanToChoose {
            HStack(spacing: 8) {
                CasinoButton(title: c.no, color: .gray) { table.choose(false) }
                CasinoButton(title: c.yes, color: .pink) { table.choose(true) }
            }
        } else if table.youAreHouse {
            waiting(table.turn.map { "Lavender is the house · \(table.players[$0].name) is deciding…" } ?? "Lavender is the house — she deals and pays the table.")
        } else if table.watching {
            waiting("Lavender is out of chips — watching the rest of the game.")
        } else {
            waiting(table.turn.map { "\(table.players[$0].isHuman ? "Lavender" : table.players[$0].name) is deciding…" } ?? " ")
        }
    }
}
