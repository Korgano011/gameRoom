import SwiftUI

enum Screen { case title, intro, hunt, huntResults, payCards, bonus, pick, summary, eliminated, final, finale }

/// What the show is waiting on the viewer for.
enum Await: Equatable {
    case none, proceed, call, keepOrPass, take, guess, deckPick, finalMove, eliminate, gameOver
}

// MARK: - Pay Cards

enum PCKind: Int, CaseIterable {
    case draw, strategy, wild

    var title: String { ["Five Card Draw", "Strategy Round", "Wild Card Round"][rawValue] }
    var blurb: String {
        [
            "Call three cards. A pair must be kept; otherwise keep them or turn them back and pass. Then call your fourth and fifth cards one at a time.",
            "The four corners are face up. On each turn, call more cards and take the ones you want from everything showing.",
            "Five Card Draw again — but two jokers are hiding on the board. A joker is wild, so five of a kind is possible.",
        ][rawValue]
    }
}

enum SlotState { case down, up, taken }

struct Slot: Identifiable {
    let id: Int
    var card: PlayingCard
    var state = SlotState.down
}

@Observable final class PayCards {
    let ids: [Int]
    var kind = PCKind.draw
    var slots: [Slot] = []
    var fresh: Set<Int> = []                 // turned up during the current turn
    var hands: [Int: [PlayingCard]] = [:]
    var money: [Int: Int] = [:]
    var results: [Int: String] = [:]         // last hand's result line per player
    var best: Set<Int> = []
    var turn: Int?
    var host = ""
    var memory: [Int: [Int: PlayingCard]] = [:]   // computer players' recall: slot -> card
    var tapped: Int?
    var drawOff: [Int: PlayingCard] = [:]
    var winner: Int?

    init(ids: [Int]) {
        self.ids = ids
        for id in ids { money[id] = 0; hands[id] = [] }
    }

    func other(_ id: Int) -> Int { ids[0] == id ? ids[1] : ids[0] }

    func deal(_ k: PCKind) {
        kind = k
        let deck = PlayingCard.payDeck(jokers: k == .wild ? 2 : 0).shuffled().prefix(16)
        slots = deck.enumerated().map { Slot(id: $0, card: $1) }
        for id in ids { hands[id] = []; memory[id] = [:] }
        fresh = []
        results = [:]
        best = []
        turn = nil
    }

    var down: [Int] { slots.filter { $0.state == .down }.map(\.id) }
    var showing: [Int] { slots.filter { $0.state == .up }.map(\.id) }
}

// MARK: - Bonus round

@Observable final class Bonus {
    let player: Int
    let prizes: [Int]
    var phase = 0
    var secondChance = false
    var cards: [PlayingCard] = []
    var faceUp = false
    var memorizeEnd: Date?
    var memorizeSeconds = 0.0
    var target: PlayingCard?
    var guess: Int?
    var results: [Bool?] = [nil, nil, nil]
    var thirdForfeited = false
    var winnings = 0
    var survived = false
    var host = ""

    init(player: Int, top: Int) {
        self.player = player
        prizes = [50, 500, top]
    }
}

// MARK: - Final jackpot round

/// What the finalist does next: turn a card over, throw one out of a full hand, or stop and take the money.
enum FinalMove: Equatable { case flip(Int), discard(Int), stop }

@Observable final class FinalRound {
    let player: Int
    let jackpot: Int
    /// 16 face-down cards: one four of a kind, two threes of a kind, two pairs, one odd card and the Queen of Spades.
    var cards: [PlayingCard] = []
    var hand: [Int] = []                      // board positions in the hand, in the order turned over
    var discarded: Set<Int> = []
    var queenAt: Int?                         // where the Queen of Spades turned up, if she did
    var kiss = false                          // the Queen has come up to the screen to blow you a kiss
    var needsReplacement = false              // a card was thrown out; the next flip replaces it
    var move: FinalMove?
    var won: Bool?                            // true = four of a kind, false = Queen of Spades, nil = still playing or stopped
    var winnings = 0
    var revealed = false                      // the whole board turned face up at the end
    var host = ""

    static let queen = PlayingCard(rank: 12, suit: 0)

    init(player: Int, jackpot: Int) {
        self.player = player
        self.jackpot = jackpot
        var ranks = Array((2...14).filter { $0 != 12 }.shuffled().prefix(7))
        var board: [PlayingCard] = []
        for size in [4, 3, 3, 2, 2, 1] {
            let r = ranks.removeFirst()
            board += (0..<4).shuffled().prefix(size).map { PlayingCard(rank: r, suit: $0) }
        }
        board.append(Self.queen)
        cards = board.shuffled()
    }

    var handCards: [PlayingCard] { hand.map { cards[$0] } }
    var value: HandValue { Hands.evaluate(handCards) }
    var down: [Int] { cards.indices.filter { !hand.contains($0) && !discarded.contains($0) && $0 != queenAt } }
    var full: Bool { hand.count == 5 && !needsReplacement }

    /// Pair $500, two pair $1,000, three of a kind $1,500, full house $2,500, four of a kind the jackpot.
    func payout(_ v: HandValue) -> Int {
        v.category >= 5 ? jackpot : [0, 500, 1_000, 1_500, 2_500][v.category]
    }
    var payout: Int { payout(value) }
}

// MARK: - The show

@Observable final class Show {
    var players = Roster.make()
    var humanID: Int?
    var screen: Screen = .title
    var jackpot = 50_000
    var excursion = 0
    var hunt: Hunt?
    var ranking: [Int] = []
    var facing: [Int] = []
    var topPlayer: Int?
    var bonusTop = 0
    var payCards: PayCards?
    var bonus: Bonus?
    var final: FinalRound?
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

    /// The bonus round's top prize is the biggest money card brought back, never less than this.
    static let minTop = 1_000

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

    /// Memorizing time is never fast-forwarded while you're the one memorizing.
    private func hold(_ s: Double, forHuman: Bool) async {
        guard !Task.isCancelled, timeScale > 0 else { return }
        try? await Task.sleep(for: .seconds(s * timeScale * (speedUp && !forHuman ? 0.15 : 1)))
    }

    private func sfx(_ effect: Sound.Effect) {
        if case .flip = effect, speedUp { return }
        if timeScale > 0 { Sound.shared.play(effect) }
    }

    private func ding(_ right: Bool) { sfx(right ? .bell : .razz) }

    private func eliminate(_ id: Int, _ fate: String) {
        players[id].out = true
        players[id].fate = fate
    }

    // MARK: Show flow

    private func runShow() async {
        for ex in 0..<HuntKind.allCases.count {
            guard !Task.isCancelled, alive.count > 1 else { break }
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
            guard !Task.isCancelled else { return }
            for id in alive { players[id].chest = h.amount(for: id) }
            let tiebreak = Dictionary(uniqueKeysWithValues: alive.map { ($0, Double.random(in: 0..<1)) })
            ranking = alive.sorted {
                (players[$0].chest!, tiebreak[$0]!) > (players[$1].chest!, tiebreak[$1]!)
            }
            topPlayer = ranking.first
            bonusTop = max(players[ranking[0]].chest ?? 0, Show.minTop)
            facing = Array(ranking.suffix(2))       // higher of the two first
            screen = .huntResults
            _ = await wait(.proceed)

            var lines: [String] = []
            let (winner, loser) = await playPayCards(facing)
            guard !Task.isCancelled else { return }
            eliminate(loser, "Lost at Pay Cards")
            lines.append("\(name(loser)) lost at Pay Cards and leaves with \(money(players[loser].bank)).")

            let survived = await playBonus(winner)
            guard !Task.isCancelled else { return }
            if survived {
                jackpot += bonusTop
                lines.append("\(name(winner)) beat all three bonus levels! \(money(bonusTop)) goes into the final jackpot.")
                let out = await chooseElimination(by: winner)
                guard !Task.isCancelled else { return }
                eliminate(out, "Sent home by \(name(winner))")
                lines.append("\(name(winner)) sent \(name(out)) home. \(name(out)) leaves with \(money(players[out].bank)).")
            } else {
                eliminate(winner, "Fell short in the bonus round")
                lines.append("\(name(winner)) won at Pay Cards but fell short in the bonus round, leaving with \(money(players[winner].bank)).")
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
        guard !Task.isCancelled, let finalist = alive.first else { return }
        await playFinal(finalist)
        guard !Task.isCancelled else { return }
        screen = .finale
        _ = await wait(.gameOver)
    }

    // MARK: Pay Cards

    private func playPayCards(_ pair: [Int]) async -> (winner: Int, loser: Int) {
        let pc = PayCards(ids: pair)
        payCards = pc
        fast = false
        screen = .payCards
        let humanPlays = pair.contains { isHuman($0) }
        pc.host = "\(name(pair[0])) and \(name(pair[1])), you brought back the two smallest treasures. Three hands of Pay Cards — the lower money total leaves the island."
        await pause(4)

        for k in PCKind.allCases {
            guard !Task.isCancelled else { break }
            pc.deal(k)
            let first: Int
            switch k {
            case .draw: first = pair[0]
            case .strategy: first = pair[1]
            case .wild: first = pc.money[pair[0]]! <= pc.money[pair[1]]! ? pair[0] : pair[1]   // trailing player starts
            }
            pc.host = "Hand \(k.rawValue + 1): \(k.title). \(k.blurb) \(name(first)) goes first."
            await pause(4)
            if k == .strategy { await strategyHand(pc, first: first) } else { await drawHand(pc, first: first) }
            guard !Task.isCancelled else { break }
            await payHand(pc)
            if humanPlays { _ = await wait(.proceed) } else { await pause(4) }
        }

        let a = pair[0], b = pair[1]
        var winner = pc.money[a]! > pc.money[b]! ? a : b
        if pc.money[a] == pc.money[b] {
            pc.host = "It's a tie at \(money(pc.money[a]!))! Sudden death: one card each, high card wins $50."
            await pause(3)
            var deck = PlayingCard.fullDeck().shuffled()
            while true {
                let ca = deck.removeLast(), cb = deck.removeLast()
                pc.drawOff = [a: ca, b: cb]
                sfx(.flip)
                await pause(2)
                if ca.rank != cb.rank {
                    winner = ca.rank > cb.rank ? a : b
                    break
                }
                pc.host = "Both drew a \(PlayingCard.rankName(ca.rank)) — draw again!"
                await pause(2)
            }
            pc.money[winner]! += 50
        }
        let loser = pc.other(winner)
        pc.winner = winner
        for id in pair { players[id].bank += pc.money[id]! }
        ding(isHuman(winner) || !humanPlays)
        pc.host = "\(name(winner)) wins Pay Cards, \(money(pc.money[winner]!)) to \(money(pc.money[loser]!)), and plays the bonus round. \(name(loser)) keeps \(money(pc.money[loser]!)) but leaves the island."
        _ = await wait(.proceed)
        return (winner, loser)
    }

    /// The player calls one face-down card; it turns face up.
    private func call(_ pc: PayCards, _ p: Int, with pending: [PlayingCard] = []) async -> Int {
        let s: Int
        if isHuman(p) {
            pc.tapped = nil
            _ = await wait(.call)
            s = pc.tapped ?? pc.down.randomElement()!
        } else {
            await pause(1.1)
            s = cpuCall(pc, p, pending: pending)
        }
        pc.slots[s].state = .up
        pc.fresh.insert(s)
        sfx(.flip)
        await pause(0.8)
        return s
    }

    private func cpuCall(_ pc: PayCards, _ p: Int, pending: [PlayingCard]) -> Int {
        let down = pc.down
        let mem = pc.memory[p] ?? [:]
        let now = pc.hands[p]! + pending
        let current = Hands.evaluate(now)
        if pc.kind != .strategy {
            // Head for a remembered card that improves the hand.
            let good = down.filter { s in mem[s].map { Hands.evaluate(now + [$0]) > current || $0.isJoker } ?? false }
            if let g = good.randomElement() { return g }
        }
        let unknown = down.filter { mem[$0] == nil }
        return (unknown.isEmpty ? down : unknown).randomElement()!
    }

    private func take(_ pc: PayCards, _ s: Int, _ p: Int) {
        pc.slots[s].state = .taken
        pc.hands[p]!.append(pc.slots[s].card)
        pc.fresh.remove(s)
        for id in pc.ids { pc.memory[id]?[s] = nil }
        sfx(.select)
    }

    private func turnBack(_ pc: PayCards, _ slots: [Int], by p: Int) {
        for s in slots {
            pc.slots[s].state = .down
            pc.fresh.remove(s)
            for id in pc.ids where !isHuman(id) {
                if chance(min(0.98, players[id].memory + (id == p ? 0.05 : 0))) { pc.memory[id]![s] = pc.slots[s].card }
            }
        }
        sfx(.flip)
    }

    private func drawHand(_ pc: PayCards, first: Int) async {
        var p = first
        var refusals: [Int: Int] = [:]
        while pc.hands.values.contains(where: { $0.count < 5 }), !Task.isCancelled {
            let o = pc.other(p)
            pc.turn = p
            if pc.hands[o]!.count == 5 {
                pc.host = "\(name(o)) has a full hand. \(name(p)), you must keep every card you turn over now."
                await pause(2.5)
                while pc.hands[p]!.count < 5, !Task.isCancelled {
                    pc.host = "\(name(p)), call your \(ordinal(pc.hands[p]!.count + 1)) card — you have to keep it."
                    let s = await call(pc, p)
                    take(pc, s, p)
                    await pause(0.6)
                }
                break
            }
            if pc.hands[p]!.isEmpty {
                var three: [Int] = []
                for n in 1...3 {
                    pc.host = "\(name(p)), call \(n == 1 ? "three cards" : n == 2 ? "two more" : "one more")."
                    three.append(await call(pc, p, with: three.map { pc.slots[$0].card }))
                }
                guard !Task.isCancelled else { return }
                let cards = three.map { pc.slots[$0].card }
                let v = Hands.evaluate(cards)
                if v.category >= 1 {
                    pc.host = "\(v.detail)! \(name(p)) has to keep all three."
                    await pause(2.2)
                    for s in three { take(pc, s, p) }
                } else {
                    pc.host = "No pair. \(name(p)), keep these three, or turn them back and pass?"
                    let keep: Bool
                    if isHuman(p) {
                        keep = await wait(.keepOrPass)
                    } else {
                        await pause(1.6)
                        keep = chance(0.6 + 0.3 * players[p].nerve)
                    }
                    if keep {
                        pc.host = "\(name(p)) keeps them."
                        for s in three { take(pc, s, p) }
                        await pause(1)
                    } else {
                        turnBack(pc, three, by: p)
                        pc.host = "\(name(p)) turns them back. Control passes to \(name(o))."
                        await pause(2)
                        p = o
                        continue
                    }
                }
            }
            while pc.hands[p]!.count < 5, !Task.isCancelled {
                let n = pc.hands[p]!.count + 1
                pc.host = "\(name(p)), call your \(ordinal(n)) card."
                let s = await call(pc, p)
                let c = pc.slots[s].card
                pc.host = "The \(c.name). Keep it, \(name(p))? If you turn it back, control passes to \(name(o))."
                let keep: Bool
                if isHuman(p) {
                    keep = await wait(.keepOrPass)
                } else {
                    await pause(1.4)
                    let hand = pc.hands[p]!
                    let improves = Hands.evaluate(hand + [c]).category > Hands.evaluate(hand).category
                    keep = improves || refusals[p, default: 0] >= 3 || chance(0.3 + 0.4 * (1 - players[p].nerve))
                }
                if keep {
                    take(pc, s, p)
                    pc.host = "\(name(p)) keeps the \(c.name)."
                    await pause(1)
                } else {
                    refusals[p, default: 0] += 1
                    turnBack(pc, [s], by: p)
                    pc.host = "\(name(p)) turns it back. Over to \(name(o))."
                    await pause(1.8)
                    break
                }
            }
            p = o
        }
        pc.turn = nil
    }

    private func strategyHand(_ pc: PayCards, first: Int) async {
        for c in [0, 3, 12, 15] { pc.slots[c].state = .up }
        sfx(.flip)
        pc.host = "The four corner cards are face up."
        await pause(2)
        let order = [first, pc.other(first)]
        for round in 0..<3 {
            for p in order {
                guard !Task.isCancelled else { return }
                pc.turn = p
                let n = round < 2 ? 2 : 1
                for k in 0..<n where !pc.down.isEmpty {
                    pc.host = "\(name(p)), call \(n == 1 ? "one more card" : k == 0 ? "two cards" : "one more card")."
                    _ = await call(pc, p)
                }
                for k in 0..<n {
                    guard !Task.isCancelled else { return }
                    pc.host = "\(name(p)), take \(n == 1 ? "your last card" : k == 0 ? "two cards" : "one more") from the \(pc.showing.count) showing."
                    let s: Int
                    if isHuman(p) {
                        pc.tapped = nil
                        _ = await wait(.take)
                        s = pc.tapped ?? pc.showing.randomElement()!
                    } else {
                        await pause(1.4)
                        s = cpuTake(pc, p, left: n - k)
                    }
                    let c = pc.slots[s].card
                    take(pc, s, p)
                    pc.host = "\(name(p)) takes the \(c.name)."
                    await pause(1)
                }
                pc.fresh = []
            }
        }
        pc.turn = nil
    }

    private func cpuTake(_ pc: PayCards, _ p: Int, left: Int) -> Int {
        let showing = pc.showing
        let hand = pc.hands[p]!
        if chance(0.12 * (1 - players[p].memory)) { return showing.randomElement()! }
        var bestSlot = showing[0], bestScore = -1.0
        for s in showing {
            // Look one card ahead when there's a second pick to come.
            var score = Hands.potential(hand + [pc.slots[s].card])
            if left > 1 {
                let follow = showing.filter { $0 != s }.map { Hands.potential(hand + [pc.slots[s].card, pc.slots[$0].card]) }
                score = max(score, follow.max() ?? score)
            }
            if score > bestScore { bestScore = score; bestSlot = s }
        }
        return bestSlot
    }

    private func payHand(_ pc: PayCards) async {
        let vals = Dictionary(uniqueKeysWithValues: pc.ids.map { ($0, Hands.evaluate(pc.hands[$0]!)) })
        let a = pc.ids[0], b = pc.ids[1]
        pc.best = vals[a]! > vals[b]! ? [a] : vals[b]! > vals[a]! ? [b] : [a, b]
        for id in pc.ids {
            let v = vals[id]!
            let bonus = pc.best.contains(id) ? 50 : 0
            pc.money[id]! += v.payout + bonus
            pc.results[id] = "\(v.detail) — \(money(v.payout))" + (bonus > 0 ? " + $50 best hand" : "")
        }
        pc.fresh = []
        let top = pc.best.count == 2 ? "Dead even — both of you get the $50 best-hand bonus."
            : "\(name(pc.best.first!)) has the best hand and earns the $50 bonus."
        pc.host = "\(name(a)): \(vals[a]!.detail). \(name(b)): \(vals[b]!.detail). \(top)"
        sfx(.bell)
        await pause(1)
    }

    // MARK: Bonus round

    private func playBonus(_ id: Int) async -> Bool {
        let b = Bonus(player: id, top: bonusTop)
        bonus = b
        fast = false
        screen = .bonus
        b.host = "\(name(id)), welcome to the bonus round! Memorize 4 cards for $50, then 8 cards for $500, then 12 cards for \(money(bonusTop)) — the biggest treasure brought back. Clear all three and you stay on the island."
        await pause(5)

        var third = true
        for phase in 0..<2 {
            guard !Task.isCancelled else { return false }
            if await memoryTest(b, phase, second: false) {
                b.winnings = b.prizes[phase]
                b.results[phase] = true
                b.host = "Right! You've won \(money(b.winnings))."
                await pause(2)
                continue
            }
            third = false
            b.thirdForfeited = true
            b.host = "Wrong! That costs you the third level — but here's a second chance at \(money(b.prizes[phase]))."
            await pause(3)
            let again = await memoryTest(b, phase, second: true)
            b.results[phase] = again
            if again { b.winnings = b.prizes[phase] }
            b.host = again ? "Got it on the second try! \(money(b.winnings)) so far." : "Missed again. \(money(b.winnings)) so far."
            await pause(2.5)
        }
        guard !Task.isCancelled else { return false }
        if third {
            if await memoryTest(b, 2, second: false) {
                b.results[2] = true
                b.survived = true
                sfx(.jackpot)
                b.host = "YES! \(name(id)) clears all three levels! \(money(bonusTop)) goes into the final jackpot, and \(name(id)) stays on the island."
            } else {
                b.results[2] = false
                b.host = "So close! No second chance on the last level. \(name(id)) keeps \(money(b.winnings)) and leaves the island."
            }
        } else {
            b.host = "\(name(id)) finishes with \(money(b.winnings)), but without the third level it's time to leave the island."
        }
        if !b.survived { players[id].bank += b.winnings }
        _ = await wait(.proceed)
        return b.survived
    }

    private func memoryTest(_ b: Bonus, _ phase: Int, second: Bool) async -> Bool {
        let n = [4, 8, 12][phase]
        let mine = isHuman(b.player)
        b.phase = phase
        b.secondChance = second
        b.cards = Array(PlayingCard.fullDeck().shuffled().prefix(n))
        b.target = nil
        b.guess = nil
        b.faceUp = true
        sfx(.flip)
        b.host = (second ? "Reshuffled. " : "Level \(phase + 1): ") + "memorize these \(n) cards. You have \(n) seconds."
        let secs = Double(n) * max(timeScale, 0) * (speedUp && !mine ? 0.15 : 1)
        b.memorizeSeconds = secs
        b.memorizeEnd = Date().addingTimeInterval(secs)
        await hold(Double(n), forHuman: mine)
        b.memorizeEnd = nil
        b.faceUp = false
        sfx(.flip)
        await pause(0.8)
        let target = b.cards.randomElement()!
        b.target = target
        b.host = "From the deck... the \(target.name)! Where is it?"
        let right = b.cards.firstIndex(of: target)!
        if mine {
            _ = await wait(.guess)
        } else {
            await pause(2.2)
            let odds = players[b.player].memory * [0.97, 0.84, 0.68][phase]
            b.guess = chance(odds) ? right : b.cards.indices.filter { $0 != right }.randomElement()!
            sfx(.select)
            await pause(1.2)
        }
        b.faceUp = true
        let ok = b.guess == right
        ding(ok)
        await pause(2)
        return ok
    }

    // MARK: Picking who goes home

    private func chooseElimination(by id: Int) async -> Int {
        let others = alive.filter { $0 != id }
        guard others.count > 1 else { return others[0] }
        pickable = others
        picker = id
        picked = nil
        screen = .pick
        if isHuman(id) {
            _ = await wait(.eliminate)
            return picked ?? others.randomElement()!
        }
        await pause(2.5)
        // The computer sends home whoever looks most dangerous: the biggest treasure this time.
        let choice = chance(0.7) ? others.max { (players[$0].chest ?? 0) < (players[$1].chest ?? 0) }! : others.randomElement()!
        picked = choice
        await pause(2.5)
        return choice
    }

    // MARK: Final jackpot round

    private func playFinal(_ id: Int) async {
        let f = FinalRound(player: id, jackpot: jackpot)
        final = f
        fast = false
        screen = .final
        let mine = isHuman(id)
        f.host = "\(name(id)), you're the last player on Pay Cards Island! Hidden on this board is one four of a kind. Turn cards over one at a time to build a hand. Pair \(money(500)), two pair \(money(1_000)), three of a kind \(money(1_500)), full house \(money(2_500)) — and four of a kind wins the \(money(jackpot)) jackpot!"
        await pause(mine ? 7 : 4.5)
        f.host = "Once you have five cards, you can throw one out and turn over another. Stop whenever you like and take your money. But the Queen of Spades is hiding in there too. Turn her over and you go home with nothing."
        await pause(mine ? 7 : 4.5)

        while !Task.isCancelled {
            if f.down.isEmpty {
                f.host = "That's every card on the board! \(name(id)) takes the \(f.value.name.lowercased())."
                break
            }
            // What next?
            let move: FinalMove
            if mine {
                f.host = f.hand.isEmpty ? "Turn over your first card."
                    : f.needsReplacement ? "Turn over a card to replace the one you threw out."
                    : f.full ? "\(f.value.detail) — worth \(money(f.payout)). Throw one card out and try for more, or stop and take the money."
                    : "\(f.hand.count) \(f.hand.count == 1 ? "card" : "cards"): \(f.payout > 0 ? "\(f.value.detail), worth \(money(f.payout))" : "no pay yet"). Turn over another, or stop?"
                f.move = nil
                _ = await wait(.finalMove)
                guard let m = f.move else { return }
                move = m
            } else {
                await pause(1.4)
                move = computerFinalMove(f, nerve: players[id].nerve)
            }

            switch move {
            case .stop:
                f.host = f.payout > 0 ? "\(name(id)) stops with \(f.value.detail.lowercased())!" : "\(name(id)) stops with nothing."
            case .discard(let i):
                f.hand.removeAll { $0 == i }
                f.discarded.insert(i)
                f.needsReplacement = true
                sfx(.select)
                f.host = "\(name(id)) throws out the \(f.cards[i].name)."
                if !mine { await pause(1.4) }
                continue
            case .flip(let i):
                let card = f.cards[i]
                sfx(.flip)
                if card == FinalRound.queen {
                    f.queenAt = i
                    // She comes up to the screen, winks, blows the finalist a kiss — then has a big laugh.
                    // Never fast-forwarded, so she always gets her whole moment.
                    f.host = "It's the QUEEN OF SPADES..."
                    f.kiss = true
                    await hold(QueenKissView.blowAt, forHuman: true)
                    sfx(.kiss)
                    await hold(QueenKissView.laughAt - QueenKissView.blowAt, forHuman: true)
                    sfx(.laugh)
                    await hold(QueenKissView.length - QueenKissView.laughAt, forHuman: true)
                    f.kiss = false
                    f.revealed = true
                    ding(false)
                    f.won = false
                    f.winnings = 0
                    players[id].bank = 0
                    players[id].fate = "Found the Queen of Spades in the final — left with nothing"
                    f.host = "Oh no — the QUEEN OF SPADES! \(name(id)) leaves Pay Cards Island with nothing."
                    await pause(4)
                    return
                }
                f.hand.append(i)
                f.needsReplacement = false
                let v = f.value
                if v.category >= 5 {
                    f.won = true
                    f.revealed = true
                    f.winnings = jackpot
                    sfx(.jackpot)
                    players[id].bank += jackpot
                    players[id].fate = "Won the Pay Cards Island jackpot"
                    f.host = "FOUR \(PlayingCard.plural(v.groups[0]).uppercased())! \(name(id)) wins the \(money(jackpot)) jackpot!"
                    await pause(4)
                    return
                }
                if f.payout > 0 { ding(true) }
                if !mine {
                    f.host = "The \(card.name). \(f.payout > 0 ? "\(v.detail) — \(money(f.payout))." : "No pay yet.")"
                    await pause(1.6)
                }
                continue
            }
            break
        }
        guard !Task.isCancelled else { return }
        f.winnings = f.payout
        f.revealed = true
        players[id].bank += f.winnings
        players[id].fate = f.winnings > 0 ? "Stopped in the final with \(f.value.detail.lowercased())" : "Stopped in the final with nothing"
        if f.winnings > 0 { sfx(.bell) }
        await pause(4)
    }

    /// The computer gambles hard — it keeps flipping until it has five cards, then keeps chasing the jackpot,
    /// braver players longer, so the Queen of Spades gets plenty of chances. A full hand throws out an odd card.
    private func computerFinalMove(_ f: FinalRound, nerve: Double) -> FinalMove {
        if f.hand.isEmpty || f.needsReplacement || f.payout == 0 || !f.full { return .flip(f.down.randomElement()!) }
        let keepGoing = [1, 0.97, 0.92, 0.85, 0.7][min(f.value.category, 4)] * (0.85 + 0.15 * nerve)
        guard chance(keepGoing) else { return .stop }
        if f.full {
            var counts: [Int: Int] = [:]
            for c in f.handCards { counts[c.rank, default: 0] += 1 }
            let top = counts.max { ($0.value, $0.key) < ($1.value, $1.key) }!.key
            // Keep the biggest group; throw out a card from the smallest.
            let throwaway = f.hand.filter { f.cards[$0].rank != top }.min { counts[f.cards[$0].rank]! < counts[f.cards[$1].rank]! }!
            return .discard(throwaway)
        }
        return .flip(f.down.randomElement()!)
    }
}
