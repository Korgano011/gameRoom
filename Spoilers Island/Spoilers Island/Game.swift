import SwiftUI

enum Screen { case title, intro, hunt, huntResults, spoilers, pick, summary, eliminated, finalIntro, finale }

/// What the show is waiting on the viewer for.
enum Await: Equatable {
    case none, proceed, pickClue, giveOrPass, guess, eliminate, gameOver
}

// MARK: - The Spoilers round

enum Tile: Equatable { case hidden, reading, given, passed, unused }

/// One round against the Spoilers: the player in the hot seat tries to give 4 clues
/// without all three Spoilers naming the secret subject.
@Observable final class SpoilerRound {
    let hotSeat: Int
    let spoilers: [Int]
    let subject: Subject
    let choices: [String]          // what a Spoiler can answer: the subject and its five look-alikes
    let passLimit: Int
    let stake: Int                 // what goes into the jackpot (in the final, the jackpot plus the Belmar card: the whole prize)
    let isFinal: Bool
    let order: [Int]               // board number -> clue
    var tiles: [Tile] = Array(repeating: .hidden, count: 8)
    var current: Int?
    var given = 0
    var passes = 0
    var retired: Set<Int> = []     // Spoilers who named the subject
    var guesses: [Int: String] = [:]
    var shown: Set<Int> = []       // Spoilers whose guess for the current clue is on screen
    var earned: [Int: Int] = [:]
    var host = ""
    var tapped: Int?
    var giveIt: Bool?
    var humanGuess: String?
    var won: Bool?

    static let goal = 4
    static let reward = 250

    init(hotSeat: Int, spoilers: [Int], subject: Subject, passLimit: Int, stake: Int, isFinal: Bool) {
        self.hotSeat = hotSeat
        self.spoilers = spoilers
        self.subject = subject
        self.passLimit = passLimit
        self.stake = stake
        self.isFinal = isFinal
        choices = ([subject.name] + subject.decoys).shuffled()
        order = Array(0..<8).shuffled()
        for id in [hotSeat] + spoilers { earned[id] = 0 }
    }

    func clue(_ slot: Int) -> Clue { subject.clues[order[slot]] }
    var active: [Int] { spoilers.filter { !retired.contains($0) } }
    var passesLeft: Int { passLimit - passes }
    var hidden: [Int] { tiles.indices.filter { tiles[$0] == .hidden } }
    var givenClues: [Clue] { tiles.indices.filter { tiles[$0] == .given }.map(clue) }
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
    var hotSeat: Int?
    var spoilerTeam: [Int] = []
    var stake = 0
    var round: SpoilerRound?
    var pickable: [Int] = []
    var picker: Int?
    var picked: Int?
    var summary: [String] = []
    var awaiting: Await = .none
    var fast = false
    var timeScale = 1.0
    private var deck = SubjectBank.deck()
    private var cont: CheckedContinuation<Bool, Never>?
    private var task: Task<Void, Never>?
    private var toldOut = false

    /// The amount at stake is the biggest money card brought back, never less than this.
    static let minStake = 1_000
    static let finalPasses = 2
    /// Excursions that send someone home; the last one, Belmar, only picks the final hot seat.
    static let eliminationExcursions = 4

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
        for ex in 0..<Show.eliminationExcursions {
            guard !Task.isCancelled, alive.count > 4 else { break }
            guard await runExcursion(ex) else { return }
            stake = max(players[ranking[0]].chest ?? 0, Show.minStake)
            // The four smallest treasures face elimination: the very smallest takes the hot seat.
            let bottom = Array(ranking.suffix(4))
            hotSeat = bottom.last
            spoilerTeam = Array(bottom.dropLast())
            screen = .huntResults
            _ = await wait(.proceed)

            guard let seat = hotSeat else { return }
            let r = SpoilerRound(hotSeat: seat, spoilers: spoilerTeam, subject: nextSubject(),
                                 passLimit: 4, stake: stake, isFinal: false)
            let beat = await playSpoilers(r)
            guard !Task.isCancelled else { return }

            var lines: [String] = []
            for id in [seat] + spoilerTeam where (r.earned[id] ?? 0) > 0 {
                lines.append("\(name(id)) earned \(money(r.earned[id]!)) in the Spoilers round.")
            }
            if beat {
                jackpot += stake
                lines.append("\(name(seat)) got 4 clues past the Spoilers! \(money(stake)) goes into the final jackpot.")
                let out = await chooseElimination(by: seat, from: r.active)
                guard !Task.isCancelled else { return }
                eliminate(out, "Sent home by \(name(seat))")
                lines.append("\(name(seat)) sent \(name(out)) home. \(name(out)) leaves with \(money(players[out].bank)).")
            } else {
                eliminate(seat, "Spoiled in the hot seat")
                lines.append("All three Spoilers named \(r.subject.name). \(name(seat)) keeps the \(money(players[seat].bank)) won so far but is off the island, and nothing goes into the jackpot.")
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
        guard !Task.isCancelled else { return }
        // Belmar: the final four's excursion decides who takes the final hot seat.
        guard await runExcursion(HuntKind.belmar.rawValue) else { return }
        await playFinal()
        guard !Task.isCancelled else { return }
        screen = .finale
        _ = await wait(.gameOver)
    }

    /// Intro, the treasure hunt itself, then everyone ranked by the money card they brought back.
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

    private func nextSubject() -> Subject {
        if deck.isEmpty { deck = SubjectBank.deck() }
        return deck.removeLast()
    }

    // MARK: Spoilers round

    private func playSpoilers(_ r: SpoilerRound) async -> Bool {
        round = r
        fast = false
        screen = .spoilers
        let seat = r.hotSeat
        let mine = isHuman(seat)
        let team = r.spoilers.map(name).formatted(.list(type: .and))
        r.host = r.isFinal
            ? "\(name(seat)), this is it — for \(money(r.stake)): the \(money(jackpot)) jackpot plus the \(money(stake)) Belmar card at stake! Get 4 clues past \(team) without all three naming the subject. In the final you only get \(r.passLimit) passes."
            : "\(name(seat)), you're in the hot seat. \(team), you're the Spoilers. \(name(seat)) needs to get 4 clues past you."
        await pause(4.5)
        r.host = "The secret subject is a \(r.subject.kind.noun). Every miss pays \(name(seat)) \(money(SpoilerRound.reward)); every Spoiler who names it wins \(money(SpoilerRound.reward)) and steps out of the booth."
        await pause(4.5)

        while r.given < SpoilerRound.goal, !r.active.isEmpty, !Task.isCancelled {
            // Pick a number.
            r.host = "\(name(seat)), pick a clue. \(r.given) of \(SpoilerRound.goal) given, \(r.passesLeft) \(r.passesLeft == 1 ? "pass" : "passes") left."
            let slot: Int
            if mine {
                r.tapped = nil
                _ = await wait(.pickClue)
                slot = r.tapped ?? r.hidden.randomElement()!
            } else {
                await pause(1.4)
                slot = r.hidden.randomElement()!
            }
            guard !Task.isCancelled else { return false }
            r.current = slot
            r.tiles[slot] = .reading
            sfx(.flip)

            // Give it or pass it.
            let mustGive = r.passesLeft == 0
            r.host = mustGive
                ? "Clue \(slot + 1). No passes left, \(name(seat)) — this one goes to the Spoilers."
                : "Clue \(slot + 1). \(name(seat)) reads it privately... give it to the Spoilers, or pass?"
            var give = true
            if mine {
                r.giveIt = nil
                _ = await wait(.giveOrPass)
                give = mustGive || (r.giveIt ?? true)
            } else {
                await pause(mustGive ? 2 : 2.6)
                give = mustGive || cpuGives(r, r.clue(slot), seat)
            }
            guard !Task.isCancelled else { return false }
            r.current = nil
            if !give {
                r.tiles[slot] = .passed
                r.passes += 1
                sfx(.select)
                r.host = "\(name(seat)) passes on clue \(slot + 1). \(r.passesLeft) \(r.passesLeft == 1 ? "pass" : "passes") left."
                await pause(1.8)
                continue
            }

            r.tiles[slot] = .given
            r.given += 1
            r.guesses = [:]
            r.shown = []
            let clue = r.clue(slot)
            r.host = "Clue \(r.given): \"\(clue.text)\" Spoilers, what's the subject?"
            await pause(3)

            // The Spoilers still in their booths each guess.
            let guessers = r.active
            for id in guessers where !isHuman(id) {
                r.guesses[id] = cpuGuess(r, id, latest: clue)
            }
            if let me = humanID, guessers.contains(me) {
                r.humanGuess = nil
                r.host = "Clue \(r.given): \"\(clue.text)\" \(name(me)), lock in your answer."
                _ = await wait(.guess)
                r.guesses[me] = r.humanGuess ?? r.choices.randomElement()!
            } else {
                await pause(1.5)
            }
            guard !Task.isCancelled else { return false }

            // Reveal the answers one booth at a time.
            for id in guessers {
                let g = r.guesses[id]!
                let right = g == r.subject.name
                r.shown.insert(id)
                if right {
                    r.retired.insert(id)
                    r.earned[id, default: 0] += SpoilerRound.reward
                    players[id].bank += SpoilerRound.reward
                    r.host = "\(name(id)) says \(g)... that's RIGHT! \(name(id)) wins \(money(SpoilerRound.reward)) and is out of the round."
                } else {
                    r.earned[seat, default: 0] += SpoilerRound.reward
                    players[seat].bank += SpoilerRound.reward
                    r.host = "\(name(id)) says \(g)... no! \(money(SpoilerRound.reward)) to \(name(seat))."
                }
                sfx(right ? .bell : .razz)
                await pause(1.9)
            }
            guard !Task.isCancelled else { return false }
            if r.active.isEmpty { break }
            r.host = "\(r.active.count) \(r.active.count == 1 ? "Spoiler" : "Spoilers") still stumped. \(r.given) of \(SpoilerRound.goal) clues given."
            await pause(2)
        }
        guard !Task.isCancelled else { return false }

        let beat = !r.active.isEmpty
        r.won = beat
        for s in r.tiles.indices where r.tiles[s] == .hidden { r.tiles[s] = .unused }   // the board turns over
        if beat {
            sfx(.jackpot)
            r.host = r.isFinal
                ? "\(name(seat)) gets all 4 clues past the Spoilers and WINS \(money(r.stake))! The subject was \(r.subject.name)."
                : "\(name(seat)) gets 4 clues past the Spoilers! The subject was \(r.subject.name). \(money(r.stake)) goes into the final jackpot."
        } else {
            sfx(.laugh)            // the Spoilers' victory chimes
            r.host = (r.isFinal ? "All three Spoilers named \(r.subject.name)! The jackpot and the \(money(stake)) Belmar card are lost. " : "All three Spoilers named \(r.subject.name)! ") + "\(name(seat)) has been spoiled — \(name(seat)) keeps the \(money(players[seat].bank)) won so far, but is off the island."
        }
        _ = await wait(.proceed)
        return beat
    }

    /// How a computer player in the hot seat judges a clue. Most see how much it gives away;
    /// now and then they misjudge it by a notch.
    private func cpuGives(_ r: SpoilerRound, _ clue: Clue, _ id: Int) -> Bool {
        var seen = clue.level
        if chance(0.25) { seen += Bool.random() ? 1 : -1 }
        if seen <= 2 { return true }
        if seen >= 4 { return false }
        // A middling clue: pass while passes are plentiful, risk it when they run short.
        let spare = Double(r.passesLeft) / Double(r.passLimit)
        return chance(0.25 + 0.4 * players[id].nerve * (1 - spare))
    }

    /// A computer Spoiler's guess: the more the given clues give away, the likelier they name it.
    private func cpuGuess(_ r: SpoilerRound, _ id: Int, latest: Clue) -> String {
        let total = Double(r.givenClues.reduce(0) { $0 + $1.level })
        var p = 1 - exp(-pow(total * players[id].smarts / 7.0, 2.2))
        if latest.level == 5 { p = max(p, 0.8 * players[id].smarts) }
        if chance(min(p, 0.97)) { return r.subject.name }
        return r.subject.decoys.randomElement()!
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
        // The computer sends home whoever looks most dangerous: the biggest treasure so far.
        let choice = chance(0.7) ? options.max { players[$0].treasure < players[$1].treasure }! : options.randomElement()!
        picked = choice
        await pause(2.5)
        return choice
    }

    // MARK: Final round

    private func playFinal() async {
        guard ranking.count >= 2 else { return }
        // The highest money card at Belmar earns the hot seat; the other three are the Spoilers.
        let seat = ranking[0]
        hotSeat = seat
        spoilerTeam = Array(ranking.dropFirst())
        // The highest Belmar card is at stake: beat the Spoilers and it goes into the jackpot you win.
        stake = max(players[seat].chest ?? 0, Show.minStake)
        fast = false
        screen = .finalIntro
        _ = await wait(.proceed)

        let r = SpoilerRound(hotSeat: seat, spoilers: spoilerTeam, subject: nextSubject(),
                             passLimit: Show.finalPasses, stake: jackpot + stake, isFinal: true)
        let beat = await playSpoilers(r)
        guard !Task.isCancelled else { return }
        if beat {
            jackpot += stake
            players[seat].bank += jackpot
            players[seat].fate = "Won the Spoilers Island jackpot"
        } else {
            players[seat].fate = "Spoiled in the final hot seat"
        }
        for id in spoilerTeam {
            players[id].fate = r.retired.contains(id) ? "Named the final subject as a Spoiler" : "Stumped in the final as a Spoiler"
        }
    }
}
