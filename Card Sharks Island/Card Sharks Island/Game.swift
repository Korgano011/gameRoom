import SwiftUI

enum Screen { case title, intro, hunt, huntResults, cards, pick, summary, eliminated, finalIntro, bonus, finale }

/// What the show is waiting on the viewer for.
enum Await: Equatable {
    case none, proceed, wager, eliminate, bonusPick, gameOver
}

// MARK: - The Money Cards

enum CallResult { case right, wrong, push }

/// One spot on the Money Cards board.
struct Slot {
    var card: PCard?
    var up = false
    var higher: Bool?        // the call made on this card
    var wager = 0
    var result: CallResult?
    var moved = false        // carried up from the row below
    var unused = false       // skipped after a bust on the first row
}

enum CardsOutcome { case bust, lostBig, wonBig }

@Observable final class MoneyCards {
    let player: Int
    let isFinal: Bool
    /// Row 0: base card + 3 to call. Row 1: carried card + 3 to call. Row 2 (the Big Bet): carried card + 1.
    var rows: [[Slot]]
    var level = 0
    var pos = 1
    var bank = MoneyCards.stake
    var bustedOnce = false
    var outcome: CardsOutcome?
    var host = ""
    var flash: CallResult?
    // The human's choices
    var wager = MoneyCards.minBet
    var higher: Bool?
    private var spare: [PCard]
    /// Rows whose base card has already been swapped (once per row).
    var changedRows: Set<Int> = []
    /// Base cards swapped out — seen, so they don't count among the unseen.
    var discards: [PCard] = []

    static let stake = 200
    static let minBet = 50
    static let step = 50
    static let rowLengths = [4, 4, 2]
    /// Wagering everything on every card and calling them all right.
    static let maxPayout = ((stake * 8 + stake) * 8) * 2      // $28,800

    init(player: Int, isFinal: Bool) {
        self.player = player
        self.isFinal = isFinal
        var deck = PCard.deck().shuffled()
        rows = MoneyCards.rowLengths.enumerated().map { r, n in
            (0..<n).map { i in
                // the first spot of rows 2 and 3 is filled by the card carried up
                if r > 0 && i == 0 { return Slot() }
                return Slot(card: deck.removeLast())
            }
        }
        spare = deck
        rows[0][0].up = true
    }

    var isBigBet: Bool { level == 2 }
    var base: PCard { rows[level][pos - 1].card! }
    var current: PCard { rows[level][pos].card! }
    var minWager: Int {
        guard isBigBet else { return min(MoneyCards.minBet, bank) }
        // the Big Bet must be at least half of the bank
        let half = (bank + 1) / 2
        return min(bank, ((half + MoneyCards.step - 1) / MoneyCards.step) * MoneyCards.step)
    }
    var seen: [PCard] { rows.flatMap { $0 }.filter(\.up).compactMap(\.card) + discards }
    /// The base card can be changed once per row, before the first call on that row.
    var canChange: Bool { outcome == nil && pos == 1 && !changedRows.contains(level) }
    var unseen: [PCard] { PCard.deck().filter { !seen.contains($0) } }

    /// How many unseen cards beat, lose to and tie the base card.
    var odds: (higher: Int, lower: Int, same: Int) {
        let b = base.rank
        let u = unseen
        return (u.filter { $0.rank > b }.count, u.filter { $0.rank < b }.count, u.filter { $0.rank == b }.count)
    }

    func clampWager() {
        wager = min(max(wager, minWager), bank)
    }

    /// Same rank as the Big Bet's base card: burn it and deal another.
    func redealBigBet() {
        rows[2][1].card = spare.removeLast()
    }

    /// Swap the row's base card for a fresh one off the deck.
    func changeBase() {
        guard canChange, let old = rows[level][0].card else { return }
        discards.append(old)
        rows[level][0] = Slot(card: spare.removeLast(), up: true)
        changedRows.insert(level)
    }

    func carryUp(_ card: PCard, to row: Int) {
        rows[row][0] = Slot(card: card, up: true, moved: true)
    }
}

// MARK: - The bonus round

/// Ten face-down cards: Ace through 9 and the Queen of Spades. Each card picked becomes the next digit —
/// ones, tens, hundreds… up to six cards. Stop any time; turn over the Queen and the cash is gone.
@Observable final class BonusRound {
    static let queen = PCard(rank: 12, suit: 3)
    static let maxPicks = 6
    /// The most it can pay: 9 in the hundred-thousands place down to 4 in the ones.
    static let topPrize = 987_654

    let player: Int
    let cards: [PCard]
    var turned: [Int] = []          // card positions, in the order picked
    var hitQueen = false
    var stopped = false
    var kiss = false                // the Queen has come up to the screen to blow a kiss
    var host = ""
    var tapped: Int?
    var stopTapped = false

    init(player: Int) {
        self.player = player
        // A through 9 in mixed suits (never the Queen's spades for her neighbours to hide behind) and the Queen.
        let digits = (1...9).map { d in PCard(rank: d == 1 ? 14 : d, suit: [0, 1, 2][Int.random(in: 0..<3)]) }
        cards = (digits + [BonusRound.queen]).shuffled()
    }

    static func digit(_ c: PCard) -> Int { c.rank == 14 ? 1 : c.rank }
    var digits: [Int] { turned.map { cards[$0] }.filter { $0 != BonusRound.queen }.map(BonusRound.digit) }
    /// The cash built so far: the first card is the ones place, the second the tens, and so on.
    var cash: Int {
        guard !hitQueen else { return 0 }
        return digits.enumerated().reduce(0) { $0 + $1.element * Int(pow(10, Double($1.offset))) }
    }
    var over: Bool { hitQueen || stopped || turned.count >= BonusRound.maxPicks }
    var faceDown: [Int] { cards.indices.filter { !turned.contains($0) } }
    static let places = ["ones", "tens", "hundreds", "thousands", "ten-thousands", "hundred-thousands"]
}

// MARK: - The show

@Observable final class Show {
    var players = Roster.make()
    var humanID: Int?
    var screen: Screen = .title
    var excursion = 0
    var hunt: Hunt?
    var ranking: [Int] = []
    var tied: Set<Int> = []
    var seat: Int?
    var cards: MoneyCards?
    var bonus: BonusRound?
    var pickable: [Int] = []
    var picker: Int?
    var picked: Int?
    var summary: [String] = []
    var awaiting: Await = .none
    var fast = false
    var timeScale = 1.0
    private var cont: CheckedContinuation<Bool, Never>?
    private var task: Task<Void, Never>?
    private var toldOut = false

    var humanIn: Bool { humanID.map { !players[$0].out } ?? false }
    /// Once your player is knocked out, the rest of the show plays at normal speed.
    var watchingAfterOut: Bool { humanID != nil && !humanIn }
    private var speedUp: Bool { fast && !watchingAfterOut }
    var alive: [Int] { players.filter { !$0.out }.map(\.id) }
    var kind: HuntKind { HuntKind(rawValue: excursion)! }

    func name(_ id: Int) -> String { players[id].name }
    func isHuman(_ id: Int?) -> Bool { id != nil && id == humanID }

    func start(as id: Int?) {
        humanID = id
        if let id { players[id].human = true }
        task = Task { await runShow() }
    }

    #if DEBUG
    /// Launch argument -debugCards YES: jump straight into the Money Cards as Maya.
    func debugCards() {
        humanID = 0
        players[0].human = true
        players[0].chest = 2
        task = Task { await playCards(MoneyCards(player: 0, isFinal: false)) }
    }

    /// Launch argument -debugBonus YES: watch Rosa play the bonus round.
    func debugBonus() {
        task = Task { await playBonus(BonusRound(player: 2)) }
    }
    #endif

    func quit() {
        task?.cancel()
        respond(false)
    }

    // MARK: Waiting and pacing

    func wait(_ a: Await) async -> Bool {
        guard !Task.isCancelled else { return false }
        awaiting = a
        return await withCheckedContinuation { cont = $0 }
    }

    func respond(_ yes: Bool = true) {
        guard let c = cont else { return }
        cont = nil
        awaiting = .none
        c.resume(returning: yes)
    }

    private func pause(_ s: Double) async {
        guard !Task.isCancelled, timeScale > 0 else { return }
        try? await Task.sleep(for: .seconds(s * timeScale * (speedUp ? 0.15 : 1)))
    }

    private func sfx(_ effect: Sound.Effect) {
        if case .flip = effect, speedUp { return }
        if timeScale > 0 { Sound.shared.play(effect) }
    }

    private func eliminate(_ id: Int, _ fate: String) {
        players[id].out = true
        players[id].fate = fate
    }

    // MARK: Show flow

    private func runShow() async {
        for ex in 0..<HuntKind.allCases.count {
            guard !Task.isCancelled, alive.count > 1 else { break }
            guard await runExcursion(ex) else { return }
            // The lowest number brought back faces elimination.
            seat = ranking.last
            screen = .huntResults
            _ = await wait(.proceed)
            guard let seat else { return }

            let m = MoneyCards(player: seat, isFinal: false)
            await playCards(m)
            guard !Task.isCancelled, let result = m.outcome else { return }

            var lines: [String] = []
            switch result {
            case .wonBig:
                players[seat].bank += m.bank
                lines.append("\(name(seat)) won the Big Bet and banked \(money(m.bank)). \(name(seat)) stays on the island!")
                let out = await chooseElimination(by: seat, from: alive.filter { $0 != seat })
                guard !Task.isCancelled else { return }
                eliminate(out, "Sent home by \(name(seat))")
                lines.append("\(name(seat)) sent \(name(out)) home. \(name(out)) leaves with \(money(players[out].bank)).")
            case .lostBig:
                players[seat].bank += m.bank
                eliminate(seat, "Lost the Big Bet")
                lines.append("\(name(seat)) lost the Big Bet. \(name(seat)) keeps \(money(m.bank)) but is off the island.")
            case .bust:
                eliminate(seat, "Busted on the Money Cards")
                lines.append("\(name(seat)) busted on the Money Cards and is off the island\(players[seat].bank > 0 ? ", leaving with \(money(players[seat].bank)) from earlier" : " with nothing").")
            }
            summary = lines
            screen = .summary
            _ = await wait(.proceed)

            if !humanIn && humanID != nil && !toldOut {
                toldOut = true
                screen = .eliminated
                guard await wait(.gameOver) else { return }
            }
        }
        guard !Task.isCancelled, let last = alive.first else { return }
        // The player left plays the bonus round.
        seat = last
        fast = false
        screen = .finalIntro
        _ = await wait(.proceed)
        let b = BonusRound(player: last)
        await playBonus(b)
        guard !Task.isCancelled else { return }
        players[last].bank += b.cash
        players[last].fate = b.hitQueen ? "Champion — found the Queen of Spades in the bonus round"
            : "Champion — won \(money(b.cash)) in the bonus round"
        screen = .finale
        _ = await wait(.gameOver)
    }

    /// Intro, the treasure hunt itself, then everyone ranked by the number they brought back.
    private func runExcursion(_ ex: Int) async -> Bool {
        excursion = ex
        screen = .intro
        _ = await wait(.proceed)

        let h = Hunt(kind: kind, players: alive.map { players[$0] }, humanID: humanIn ? humanID : nil,
                     canFastForward: !watchingAfterOut)
        hunt = h
        if timeScale == 0 {
            h.simulate()
        } else {
            screen = .hunt
            await h.run()
        }
        guard !Task.isCancelled else { return false }
        for id in alive {
            players[id].chest = h.amount(for: id)
            players[id].chestTier = h.tier(for: id)
        }
        let tiebreak = Dictionary(uniqueKeysWithValues: alive.map { ($0, Double.random(in: 0..<1)) })
        ranking = alive.sorted {
            (players[$0].chest!, tiebreak[$0]!) > (players[$1].chest!, tiebreak[$1]!)
        }
        let low = players[ranking.last!].chest!
        tied = Set(alive.filter { players[$0].chest == low })
        if tied.count < 2 { tied = [] }
        return true
    }

    // MARK: The Money Cards

    private func playCards(_ m: MoneyCards) async {
        cards = m
        fast = false
        screen = .cards
        let p = m.player
        let me = isHuman(p)
        m.host = m.isFinal
            ? "\(name(p)), you've outlasted everyone! Now play the Money Cards. Here's \(money(MoneyCards.stake)) — bet on each card, higher or lower."
            : "\(name(p)), you brought back the lowest number. Play the Money Cards: win the Big Bet and you stay. Here's \(money(MoneyCards.stake)) to start."
        sfx(.bell)
        await pause(4)
        m.host = "The first card is \(m.rows[0][0].card!.spoken)."
        sfx(.flip)
        await pause(2)

        while m.outcome == nil {
            guard !Task.isCancelled else { return }
            // Take the wager and the call.
            let wager: Int, higher: Bool
            m.clampWager()
            if m.isBigBet {
                m.host = "The BIG BET! You must wager at least half — \(money(m.minWager)) — on the last card. \(me ? "Higher or lower than" : "\(name(p)), higher or lower than") \(m.base.spoken)?"
                if !me { await pause(2.5) }
            } else {
                m.host = "\(me ? "Your" : "\(name(p))'s") bank: \(money(m.bank)). Higher or lower than \(m.base.spoken)?"
            }
            if me {
                m.higher = nil
                m.wager = max(m.minWager, min(m.wager, m.bank))
                _ = await wait(.wager)
                guard !Task.isCancelled else { return }
                wager = min(max(m.wager, m.minWager), m.bank)
                higher = m.higher ?? true
            } else {
                await pause(1.6)
                if m.canChange && cpuWantsChange(m) {
                    let old = m.base
                    m.changeBase()
                    sfx(.flip)
                    m.host = "\(name(p)) doesn't like \(old.spoken) — changes it for \(m.base.spoken)."
                    await pause(2.2)
                    m.clampWager()
                }
                (wager, higher) = cpuBet(m)
            }
            m.rows[m.level][m.pos].wager = wager
            m.rows[m.level][m.pos].higher = higher
            sfx(.select)
            m.host = "\(me ? "You bet" : "\(name(p)) bets") \(money(wager)) on \(higher ? "HIGHER" : "LOWER")."
            await pause(1.6)

            // Turn the card.
            var card = m.current
            if m.isBigBet && card.rank == m.base.rank {
                m.rows[m.level][m.pos].up = true
                sfx(.flip)
                m.host = "\(card.spoken.capitalized) — the same as the base card! On the Big Bet a tie doesn't count. The dealer burns it and deals another."
                await pause(2.8)
                m.rows[m.level][m.pos].up = false
                while m.current.rank == m.base.rank { m.redealBigBet() }
                card = m.current
                await pause(0.6)
            }
            m.rows[m.level][m.pos].up = true
            sfx(.flip)
            let result: CallResult = card.rank == m.base.rank ? .push
                : (card.rank > m.base.rank) == higher ? .right : .wrong
            m.rows[m.level][m.pos].result = result
            m.flash = result
            switch result {
            case .right:
                m.bank += wager
                sfx(.bell)
                m.host = "\(card.spoken.capitalized)! Right — \(money(wager)) added. Bank: \(money(m.bank))."
            case .wrong:
                m.bank -= wager
                sfx(.razz)
                m.host = "\(card.spoken.capitalized)… wrong. \(money(wager)) lost. Bank: \(money(m.bank))."
            case .push:
                sfx(.select)
                m.host = "\(card.spoken.capitalized) — a pair! No gain, no loss."
            }
            await pause(2.4)
            m.flash = nil

            // Where next?
            if m.isBigBet {
                m.outcome = result == .right ? .wonBig : .lostBig
                break
            }
            let lastInRow = m.pos == MoneyCards.rowLengths[m.level] - 1
            if m.bank <= 0 {
                if m.level == 0 && !m.bustedOnce {
                    // Bust on the first row: the last card called moves up, with another $200 for the last four cards.
                    m.bustedOnce = true
                    for i in (m.pos + 1)..<MoneyCards.rowLengths[0] { m.rows[0][i].unused = true }
                    sfx(.laugh)
                    m.host = "Busted on the first row! \(card.spoken.capitalized) moves up, and here's another \(money(MoneyCards.stake)) for the last four cards."
                    await pause(3)
                    m.carryUp(card, to: 1)
                    m.level = 1; m.pos = 1
                    m.bank = MoneyCards.stake
                    await pause(1.2)
                    continue
                }
                m.outcome = .bust
                sfx(.laugh)
                m.host = m.isFinal
                    ? "Busted! The Money Cards are over."
                    : "Busted! \(name(p)) is off the island."
                break
            }
            if lastInRow {
                m.carryUp(card, to: m.level + 1)
                if m.level == 0 {
                    m.bank += MoneyCards.stake
                    sfx(.bell)
                    m.host = "\(card.spoken.capitalized) moves up to the second row — plus another \(money(MoneyCards.stake))! Bank: \(money(m.bank))."
                } else {
                    sfx(.rumble)
                    m.host = "\(card.spoken.capitalized) moves up to the top row. Time for the BIG BET!"
                }
                m.level += 1; m.pos = 1
                await pause(2.8)
            } else {
                m.pos += 1
            }
        }
        guard !Task.isCancelled, let result = m.outcome else { return }
        switch result {
        case .wonBig:
            sfx(.jackpot)
            m.host = m.isFinal
                ? "You won the Big Bet! \(name(p)) takes home \(money(m.bank)) from the Money Cards!"
                : "\(me ? "You" : name(p)) won the Big Bet with \(money(m.bank))! \(me ? "You stay" : "\(name(p)) stays") on the island — and \(me ? "you choose" : "chooses") who goes home."
        case .lostBig:
            sfx(.laugh)
            m.host = m.isFinal
                ? "The Big Bet is lost. \(name(p)) still takes home \(money(m.bank))."
                : "The Big Bet is lost. \(name(p)) keeps \(money(m.bank)) but is off the island."
        case .bust:
            break
        }
        _ = await wait(.proceed)
    }

    // MARK: The bonus round

    private func playBonus(_ b: BonusRound) async {
        bonus = b
        screen = .bonus
        let p = b.player
        let me = isHuman(p)
        b.host = "Ten cards: Ace through 9 — and the Queen of Spades. The first card \(me ? "you pick" : "\(name(p)) picks") is the ones place, then the tens, the hundreds… up to six cards. Stop any time. But find the Queen of Spades and the cash is gone!"
        sfx(.bell)
        await pause(5)
        while !b.over {
            guard !Task.isCancelled else { return }
            let place = BonusRound.places[b.turned.count]
            let pick: Int?
            if me {
                b.host = b.turned.isEmpty
                    ? "Pick your first card — it goes in the ones place."
                    : "You have \(money(b.cash)). Pick a card for the \(place) place, or stop and take the cash."
                b.tapped = nil
                b.stopTapped = false
                _ = await wait(.bonusPick)
                guard !Task.isCancelled else { return }
                pick = b.stopTapped ? nil : (b.tapped.flatMap { b.faceDown.contains($0) ? $0 : nil } ?? b.faceDown.randomElement()!)
            } else {
                b.host = b.turned.isEmpty ? "\(name(p)) picks the first card…"
                    : "\(name(p)) has \(money(b.cash)). Another card for the \(place) place?"
                await pause(2.2)
                pick = cpuKeepsGoing(b) ? b.faceDown.randomElement()! : nil
            }
            guard let pick else {
                b.stopped = true
                sfx(.jackpot)
                b.host = "\(me ? "You stop" : "\(name(p)) stops") with \(money(b.cash))!"
                break
            }
            b.turned.append(pick)
            sfx(.flip)
            let c = b.cards[pick]
            if c == BonusRound.queen {
                b.hitQueen = true
                b.host = "The QUEEN OF SPADES!"
                await pause(0.8)
                // She comes up to the screen, winks, blows a kiss — then has a big laugh.
                b.kiss = true
                await hold(QueenKissView.blowAt)
                sfx(.kiss)
                await hold(QueenKissView.laughAt - QueenKissView.blowAt)
                sfx(.queenLaugh)
                await hold(QueenKissView.length - QueenKissView.laughAt)
                b.kiss = false
                b.host = "The Queen of Spades takes it all. \(me ? "Your" : "\(name(p))'s") bonus cash is gone."
                break
            }
            sfx(.select)
            b.host = "\(c.spoken.capitalized) in the \(place) place — \(money(b.cash))!"
            await pause(2)
            if b.turned.count >= BonusRound.maxPicks {
                sfx(.jackpot)
                b.host = "Six cards! \(name(p)) wins \(money(b.cash))!"
            }
        }
        _ = await wait(.proceed)
    }

    /// The Queen's moment is never fast-forwarded.
    private func hold(_ s: Double) async {
        guard !Task.isCancelled, timeScale > 0 else { return }
        try? await Task.sleep(for: .seconds(s))
    }

    /// The first card is always free of doubt; after that, the bolder the player the further they push.
    private func cpuKeepsGoing(_ b: BonusRound) -> Bool {
        let n = b.turned.count
        if n == 0 { return true }
        let keep = [1, 0.92, 0.8, 0.65, 0.5, 0.35][n] * (0.75 + 0.25 * players[b.player].nerve)
        return chance(keep)
    }

    /// The viewer swaps the base card (once per row) while deciding on a wager.
    func changeBase() {
        guard awaiting == .wager, let m = cards, m.canChange else { return }
        let old = m.base
        m.changeBase()
        sfx(.flip)
        m.clampWager()
        m.host = "Out goes \(old.spoken) — the new base card is \(m.base.spoken). Higher or lower than \(m.base.spoken)?"
    }

    /// Computer players change a middling base card (6 through 10); the bold ones less often.
    private func cpuWantsChange(_ m: MoneyCards) -> Bool {
        (6...10).contains(m.base.rank) && chance(0.9 - 0.3 * players[m.player].nerve)
    }

    /// The computer calls the likelier way, and bets more the surer it is — bolder players more so.
    private func cpuBet(_ m: MoneyCards) -> (Int, Bool) {
        let o = m.odds
        let total = Double(o.higher + o.lower + o.same)
        let higher = o.higher != o.lower ? o.higher > o.lower : chance(0.5)
        let p = Double(max(o.higher, o.lower)) / total
        let nerve = players[m.player].nerve
        let fraction: Double
        switch p {
        case 0.85...: fraction = 1
        case 0.72...: fraction = 0.45 + 0.5 * nerve
        case 0.6...:  fraction = 0.15 + 0.35 * nerve
        default:      fraction = nerve > 0.8 && chance(0.3) ? 0.3 : 0
        }
        let raw = Double(m.bank) * fraction
        let bet = Int((raw / Double(MoneyCards.step)).rounded()) * MoneyCards.step
        return (min(max(bet, m.minWager), m.bank), higher)
    }

    // MARK: Picking who goes home

    private func chooseElimination(by id: Int, from options: [Int]) async -> Int {
        pickable = options
        picker = id
        picked = nil
        screen = .pick
        if isHuman(id) {
            _ = await wait(.eliminate)
            return picked ?? options.randomElement()!
        }
        await pause(2.5)
        // The computer sends home whoever looks most dangerous: the highest number brought back this time.
        let choice = chance(0.7) ? options.max { (players[$0].chest ?? 0) < (players[$1].chest ?? 0) }! : options.randomElement()!
        picked = choice
        await pause(2.5)
        return choice
    }
}
