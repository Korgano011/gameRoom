import SwiftUI

enum Screen { case title, intro, hunt, huntResults, banker, pick, summary, eliminated, finalIntro, finale }

/// What the show is waiting on the viewer for.
enum Await: Equatable {
    case none, proceed, pickCase, openCase, dealOrNot, eliminate, gameOver
}

// MARK: - The board

enum Board {
    /// The left side never changes.
    static let left: [Double] = [0.01, 0.25, 0.50, 0.75, 1, 5, 10, 25, 50, 75]
    /// The right side always starts with these four…
    static let rightBase: [Double] = [100, 250, 500, 1_000]
    /// …and each later round adds a new highest amount, which carries over to every round after it.
    static let newHighs: [Double] = [50_000, 75_000, 100_000, 150_000]
    static let caseCount = 20
    /// The final case starts here; every good deal is added to it.
    static let finalCaseStart = 150_000.0
}

/// One amount on the board and the case it's hidden in.
struct BoardEntry: Identifiable {
    let id: Int              // 0–9 left side, 10–19 right side
    let value: Double
    var label: String? = nil // "Excursion", "Final case", …
    var who: Int? = nil      // the player whose excursion it came from
}

// MARK: - Facing the banker

@Observable final class BankerRound {
    let player: Int
    let isFinal: Bool
    let entries: [BoardEntry]       // left side first, then the right side low to high
    let caseEntry: [Int]            // case number (0-based) -> board entry
    var mine: Int?
    var opened: [Int] = []          // cases opened, in order
    var offers: [Double] = []
    var offer: Double?              // the offer on the table right now
    var round = 0
    var toOpen = 0
    var dealt: Double?
    var outcome: Double?            // what the player walks away with
    var good: Bool?
    var host = ""
    var tapped: Int?
    var takeIt: Bool?
    var lastOpened: Int?

    /// Cases opened before each offer: 5, 4, 3, 2, 2, then 1 at a time — leaving yours and one other for the last offer.
    static let schedule = [5, 4, 3, 2, 2, 1, 1]
    /// How much of the average left on the board the banker offers, round by round.
    static let generosity = [0.20, 0.30, 0.42, 0.54, 0.66, 0.78, 0.90]

    init(player: Int, isFinal: Bool, entries: [BoardEntry]) {
        self.player = player
        self.isFinal = isFinal
        self.entries = entries
        caseEntry = Array(entries.indices).shuffled()
    }

    func value(ofCase c: Int) -> Double { entries[caseEntry[c]].value }
    /// The board slot holding the final case (final round only).
    var finalEntry: Int? { entries.firstIndex { $0.label == "Final case" } }
    func isFinalCase(_ c: Int) -> Bool { finalEntry != nil && caseEntry[c] == finalEntry }
    var finalCaseInPlay: Bool { finalEntry.map { !isOpened(entry: $0) } ?? false }
    func isOpened(entry e: Int) -> Bool { opened.contains { caseEntry[$0] == e } }
    var closed: [Int] { (0..<Board.caseCount).filter { !opened.contains($0) && $0 != mine } }
    /// Every amount still in play, your case included.
    var remaining: [Double] { (0..<Board.caseCount).filter { !opened.contains($0) }.map(value(ofCase:)) }
    var average: Double { remaining.reduce(0, +) / Double(max(1, remaining.count)) }
}

// MARK: - The show

@Observable final class Show {
    var players = Roster.make()
    var humanID: Int?
    var screen: Screen = .title
    var finalCase = Board.finalCaseStart
    var excursion = 0
    var hunt: Hunt?
    var ranking: [Int] = []
    var seat: Int?
    var round: BankerRound?
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
            // The lowest amount brought back faces the banker.
            seat = ranking.last
            screen = .huntResults
            _ = await wait(.proceed)
            guard let seat else { return }

            let r = BankerRound(player: seat, isFinal: false, entries: board(for: ex, final: false))
            await playBanker(r)
            guard !Task.isCancelled, let won = r.outcome else { return }

            var lines: [String] = []
            if r.good == true {
                finalCase += won
                lines.append("\(name(seat)) made a GOOD deal: \(money(won)) beats the \(money(r.value(ofCase: r.mine!))) in case \(r.mine! + 1). \(name(seat)) stays on the island, and \(money(won)) goes into the final case.")
                let out = await chooseElimination(by: seat, from: alive.filter { $0 != seat })
                guard !Task.isCancelled else { return }
                eliminate(out, "Sent home by \(name(seat))")
                lines.append("\(name(seat)) sent \(name(out)) home. \(name(out)) leaves with \(money(players[out].bank)).")
            } else {
                players[seat].bank += won
                eliminate(seat, "Made a bad deal with the banker")
                let inCase = r.value(ofCase: r.mine!)
                lines.append(r.dealt != nil
                    ? "\(name(seat)) made a BAD deal: took \(money(won)), but case \(r.mine! + 1) held \(money(inCase)). \(name(seat)) keeps the \(money(won)) but is off the island."
                    : "\(name(seat)) said no deal all the way and case \(r.mine! + 1) held only \(money(inCase)) — less than the banker's last offer. \(name(seat)) keeps the \(money(won)) but is off the island.")
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
        // The last player standing faces the banker for the final case — no more excursions.
        seat = last
        fast = false
        screen = .finalIntro
        _ = await wait(.proceed)
        let r = BankerRound(player: last, isFinal: true, entries: board(for: excursion + 1, final: true))
        await playBanker(r)
        guard !Task.isCancelled, let won = r.outcome else { return }
        players[last].bank += won
        players[last].fate = r.dealt != nil ? "Took the banker's final deal" : "Opened their own case in the final"
        screen = .finale
        _ = await wait(.gameOver)
    }

    /// The 20 amounts for this round: the fixed left side; on the right the four base amounts, every
    /// new highest amount added so far, and the amounts the players brought back. In the final, the final case
    /// takes a slot and the last player's amount from Belmar carries over.
    func board(for ex: Int, final: Bool) -> [BoardEntry] {
        var right: [BoardEntry] = Board.rightBase.map { BoardEntry(id: 0, value: $0) }
        right += Board.newHighs.prefix(min(ex, Board.newHighs.count)).map { BoardEntry(id: 0, value: $0, label: "New high") }
        if final {
            right.append(BoardEntry(id: 0, value: finalCase, label: "Final case"))
        }
        right += alive.map { BoardEntry(id: 0, value: Double(players[$0].boardAmount), label: "Excursion", who: $0) }
        right.sort { $0.value < $1.value }
        let left = Board.left.map { BoardEntry(id: 0, value: $0) }
        return (left + right).enumerated().map { i, e in
            BoardEntry(id: i, value: e.value, label: e.label, who: e.who)
        }
    }

    /// Intro, the treasure hunt itself, then everyone ranked by the amount they brought back.
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
            players[id].treasure += h.amount(for: id)
        }
        let tiebreak = Dictionary(uniqueKeysWithValues: alive.map { ($0, Double.random(in: 0..<1)) })
        ranking = alive.sorted {
            (players[$0].chest!, tiebreak[$0]!) > (players[$1].chest!, tiebreak[$1]!)
        }
        return true
    }

    // MARK: The banker

    private func playBanker(_ r: BankerRound) async {
        round = r
        fast = false
        screen = .banker
        let p = r.player
        let me = isHuman(p)
        let you = me ? "you" : name(p)
        r.host = r.isFinal
            ? "\(name(p)), this is it. The final case — \(money(finalCase)) — is somewhere on this board. Whatever you walk away with is yours to keep."
            : "\(name(p)), you brought back the lowest amount, so you face the banker. Beat the banker — take a deal worth more than your case — and you stay on the island."
        await pause(4.5)

        // Choose your case.
        r.host = "Twenty cases. \(me ? "Pick" : "\(name(p)) picks") a case to keep."
        let mine: Int
        if me {
            r.tapped = nil
            _ = await wait(.pickCase)
            mine = r.tapped ?? Int.random(in: 0..<Board.caseCount)
        } else {
            await pause(1.6)
            mine = Int.random(in: 0..<Board.caseCount)
        }
        guard !Task.isCancelled else { return }
        r.mine = mine
        sfx(.select)
        r.host = "\(me ? "You keep" : "\(name(p)) keeps") case \(mine + 1)."
        await pause(1.8)

        for (ri, count) in BankerRound.schedule.enumerated() {
            r.round = ri
            r.toOpen = count
            r.host = "Open \(count) \(count == 1 ? "case" : "cases")."
            await pause(1.2)
            while r.toOpen > 0 {
                guard !Task.isCancelled else { return }
                let c: Int
                if me {
                    r.tapped = nil
                    r.host = "Open \(r.toOpen) more \(r.toOpen == 1 ? "case" : "cases")."
                    _ = await wait(.openCase)
                    c = r.tapped.flatMap { r.closed.contains($0) ? $0 : nil } ?? r.closed.randomElement()!
                } else {
                    await pause(1.0)
                    c = r.closed.randomElement()!
                }
                await open(c, in: r)
                r.toOpen -= 1
            }
            guard !Task.isCancelled else { return }

            // The banker calls.
            sfx(.phone)
            r.host = "The banker is calling…"
            await pause(2.2)
            let offer = bankerOffer(r)
            r.offer = offer
            r.offers.append(offer)
            let stillThere = r.isFinal && r.finalCaseInPlay ? " The \(money(finalCase)) final case is still in play!" : ""
            r.host = "The banker offers \(money(offer)).\(stillThere) \(me ? "Deal, or no deal?" : "\(name(p)), deal, or no deal?")"
            let take: Bool
            if me {
                r.takeIt = nil
                _ = await wait(.dealOrNot)
                take = r.takeIt ?? false
            } else {
                await pause(2.4)
                take = cpuTakes(r, offer)
            }
            guard !Task.isCancelled else { return }
            if take {
                r.dealt = offer
                sfx(.bell)
                r.host = "\(me ? "You take" : "\(name(p)) takes") the deal: \(money(offer))!"
                await pause(2)
                break
            }
            sfx(.select)
            r.host = "No deal!"
            r.offer = nil
            await pause(1.4)
        }
        guard !Task.isCancelled else { return }

        // No deal all the way: the last other case opens, then your own.
        if r.dealt == nil, let other = r.closed.first {
            r.host = "No deal all the way. First, the last other case…"
            await pause(1.6)
            await open(other, in: r)
        }
        r.host = "Now, what's in case \(mine + 1)?"
        await pause(2)
        r.lastOpened = mine
        let inCase = r.value(ofCase: mine)
        r.opened.append(mine)
        sfx(.flip)

        let lastOffer = r.offers.last ?? 0
        let won = r.dealt ?? inCase
        r.outcome = won
        if r.isFinal {
            r.good = true
            sfx(.jackpot)
            r.host = r.dealt != nil
                ? (r.isFinalCase(mine) ? "Case \(mine + 1) was the FINAL CASE — \(money(inCase))! " : "Case \(mine + 1) held \(money(inCase)). ")
                    + "\(name(p)) walks away with the deal: \(money(won))!"
                : r.isFinalCase(mine) ? "Case \(mine + 1) is the FINAL CASE! \(name(p)) wins \(money(won))!"
                : "Case \(mine + 1) holds \(money(inCase))! \(name(p)) wins \(money(won))!"
        } else {
            r.good = r.dealt != nil ? won > inCase : inCase >= lastOffer
            sfx(r.good! ? .jackpot : .laugh)
            if r.dealt != nil {
                r.host = r.good!
                    ? "Case \(mine + 1) held only \(money(inCase)). \(you.capitalized) beat the banker! A GOOD deal — \(money(won)) goes into the final case."
                    : "Case \(mine + 1) held \(money(inCase))! The banker wins — a BAD deal. \(name(p)) keeps \(money(won)) but leaves the island."
            } else {
                r.host = r.good!
                    ? "Case \(mine + 1) holds \(money(inCase)) — more than the banker's last offer of \(money(lastOffer))! A GOOD deal: it goes into the final case."
                    : "Case \(mine + 1) holds \(money(inCase)) — less than the banker's last offer of \(money(lastOffer)). A BAD deal. \(name(p)) keeps \(money(won)) but leaves the island."
            }
        }
        _ = await wait(.proceed)
    }

    private func open(_ c: Int, in r: BankerRound) async {
        r.opened.append(c)
        r.lastOpened = c
        let v = r.value(ofCase: c)
        // Losing a big amount hurts the next offer; knocking out a little one helps.
        let big = v >= 1_000 || v >= r.average
        sfx(.flip)
        r.host = r.isFinalCase(c) ? "Case \(c + 1): \(money(v))… that was the FINAL CASE! It's gone."
                                   : "Case \(c + 1): \(money(v))\(big ? "…" : "!")"
        await pause(0.5)
        sfx(big ? .razz : .bell)
        await pause(1.3)
    }

    private func bankerOffer(_ r: BankerRound) -> Double {
        let raw = r.average * BankerRound.generosity[r.round] * Double.random(in: 0.92...1.08)
        let step: Double = raw >= 10_000 ? 500 : raw >= 1_000 ? 50 : raw >= 100 ? 5 : 1
        return max(1, (raw / step).rounded() * step)
    }

    /// A computer player weighs the offer against the amounts still in play. In the elimination rounds
    /// what matters is beating their own case; in the final, it's simply the money.
    private func cpuTakes(_ r: BankerRound, _ offer: Double) -> Bool {
        let nerve = players[r.player].nerve
        if r.isFinal {
            return offer >= r.average * (0.5 + 0.45 * nerve) * Double.random(in: 0.9...1.1)
        }
        let below = Double(r.remaining.filter { $0 < offer }.count) / Double(r.remaining.count)
        let wants = 0.62 + 0.28 * nerve + (r.round == 0 ? 0.08 : 0) + Double.random(in: -0.08...0.08)
        return below >= wants || r.round == BankerRound.schedule.count - 1 && below >= 0.5 && chance(1 - nerve)
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
        // The computer sends home whoever looks most dangerous: the biggest amount brought back this time.
        let choice = chance(0.7) ? options.max { (players[$0].chest ?? 0) < (players[$1].chest ?? 0) }! : options.randomElement()!
        picked = choice
        await pause(2.5)
        return choice
    }
}
