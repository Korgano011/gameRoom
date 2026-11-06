import SwiftUI

enum HuntKind: Int, CaseIterable {
    case maze, boats, pyramid, bufadora, belmar

    var title: String { ["The Hedge Maze", "Boat Hunt", "The Pyramid", "La Bufadora", "Belmar Beach"][rawValue] }
    var symbol: String { ["square.grid.3x3.fill", "sailboat.fill", "triangle.fill", "water.waves", "beach.umbrella.fill"][rawValue] }
    var blurb: String {
        [
            "All eight players enter a twisting hedge maze hiding treasure chests. Grab one before the clock runs out.",
            "The seven left head out in boats. Treasure chests float on rafts that drift with the current.",
            "A giant stepped pyramid, riddled with tunnels. Chests are hidden on the great staircase up its face and in the passages inside — and so are trap doors that drop you all the way back to the bottom.",
            "The last five explore the cliffs around La Bufadora, the roaring sea geyser near Ensenada, and three smaller blowholes in the rocks. Carry your chest back to base camp — if a blowhole erupts while you're close, it knocks the chest right out of your hands.",
            "The final four hit the Jersey Shore at Belmar. The chests are out in the water between the jetties — grab one and carry it back to the sand. Get hit by a wave and it washes you back to the beach without your chest, so you have to try again. The highest money card takes the final hot seat.",
        ][rawValue]
    }
    var cols: Int { [21, 23, 21, 19, 21][rawValue] }
    var rows: Int { [15, 15, 15, 15, 15][rawValue] }
    var sight: Double { [3.3, 4.5, 3.0, 3.8, 5.0][rawValue] }
    var seconds: Double { [80, 60, 50, 40, 35][rawValue] }
    /// Money cards grow with each excursion: the maze pays face value, later hunts pay a multiple.
    var payScale: Int { [1, 2, 3, 4, 5][rawValue] }
    var trapCount: Int { self == .pyramid ? 8 : 0 }
    var tiers: [ChestTier] {
        switch self {
        case .maze:      Array(repeating: .gold, count: 3) + Array(repeating: .silver, count: 4) + Array(repeating: .bronze, count: 5)
        case .boats:     Array(repeating: .gold, count: 2) + Array(repeating: .silver, count: 3) + Array(repeating: .bronze, count: 5)
        case .pyramid: [.gold, .gold, .silver, .silver, .bronze, .bronze, .bronze, .bronze]
        case .bufadora:  [.gold, .gold, .silver, .silver, .bronze, .bronze]
        case .belmar:    [.gold, .silver, .silver, .bronze, .bronze, .bronze]
        }
    }
    /// At La Bufadora and Belmar a chest only counts once it's carried back to base camp or the beach.
    var mustReturn: Bool { self == .bufadora || self == .belmar }
    /// Open water: everyone can see everyone, and there's only a light haze beyond your sight.
    var openWater: Bool { self == .boats || self == .belmar }
}

nonisolated struct Pt: Hashable {
    var x: Int
    var y: Int

    static let dirs = [Pt(x: 0, y: -1), Pt(x: 1, y: 0), Pt(x: 0, y: 1), Pt(x: -1, y: 0)]
    static func + (a: Pt, b: Pt) -> Pt { Pt(x: a.x + b.x, y: a.y + b.y) }
    func dist(_ o: Pt) -> Double { hypot(Double(x - o.x), Double(y - o.y)) }
}

struct Chest: Identifiable {
    let id: Int
    var pos: Pt
    let tier: ChestTier
    let amount: Int
    var owner: Int? = nil
    var drift = Pt.dirs.randomElement()!
}

struct Runner: Identifiable {
    let id: Int
    var pos: Pt
    let name: String
    let color: Color
    let speed: Double
    let nerve: Double
    let human: Bool
    var chest: Int? = nil      // the chest they're holding
    var banked = false         // done: the chest counts
    var known: Set<Int> = []
    var visited: Set<Pt> = []
}

enum Geyser { case calm, rumbling, blasting }

/// One of La Bufadora's blowholes. Each one rumbles and erupts on its own clock.
struct Vent: Identifiable {
    let id: Int
    let pos: Pt
    let name: String
    var state = Geyser.calm
    var clock = 0
    var nextBlast: Int
}

/// A Belmar breaker rolling in toward the beach across columns `from...to`.
struct Wave: Identifiable {
    let id: Int
    var y: Int
    let from: Int
    let to: Int
}

struct HuntPopup: Equatable {
    let title: String
    let amount: Int?
    let note: String
    let color: Color
}

@Observable final class Hunt {
    let kind: HuntKind
    let cols: Int
    let rows: Int
    let start: Pt
    let humanID: Int?
    private(set) var blocked: [Bool]
    private(set) var vents: [Vent] = []
    private(set) var traps: Set<Pt> = []          // pyramid trap doors (hidden until sprung)
    private(set) var sprung: Set<Pt> = []         // trap doors everyone has seen open
    private(set) var slide: (id: Int, from: Pt, at: Double)?
    private(set) var waves: [Wave] = []
    private(set) var wipeouts: [(id: Int, from: Pt, at: Double)] = []
    private var nextWave = 8
    private var waveCount = 0
    var chests: [Chest] = []
    var runners: [Runner] = []
    var seen: Set<Pt> = []
    var timeLeft: Double
    var finished = false
    var fastForward = false
    let canFastForward: Bool
    var news = ""
    var popup: HuntPopup?
    private var ticks = 0
    private var lastMove = Date.distantPast
    private var silent = false

    static let blastRadius = 3.2
    private static let rumbleTicks = 8      // 2 seconds of warning
    private static let blastTicks = 6       // 1.5 seconds of spray

    init(kind: HuntKind, players: [Contestant], humanID: Int?, canFastForward: Bool = true) {
        self.kind = kind
        self.canFastForward = canFastForward
        cols = kind.cols
        rows = kind.rows
        self.humanID = humanID
        timeLeft = kind.seconds
        switch kind {
        case .maze:
            start = Pt(x: (kind.cols / 2) | 1, y: (kind.rows / 2) | 1)
            blocked = Hunt.carveMaze(cols: cols, rows: rows, from: start, loops: 0.10, rooms: 0)
        case .pyramid:
            start = Pt(x: (kind.cols / 2) | 1, y: kind.rows - 2)
            blocked = Hunt.carveMaze(cols: cols, rows: rows, from: start, loops: 0.12, rooms: 2)
            for y in 1...rows - 2 {                 // the great staircase up the pyramid face: three steps wide
                for x in start.x - 1...start.x + 1 { blocked[y * cols + x] = false }
            }
        case .bufadora:
            start = Pt(x: (kind.cols / 2) | 1, y: kind.rows - 2)
            blocked = Hunt.carveMaze(cols: cols, rows: rows, from: start, loops: 0.22, rooms: 3)
            // La Bufadora itself by the sea, plus three smaller blowholes among the rocks.
            var holes = [Pt(x: start.x, y: 1)]
            let start = start
            for _ in 0..<200 where holes.count < 4 {      // spread out, with base camp out of every ring
                var picked = [Pt(x: start.x, y: 1)]
                for _ in 0..<3 {
                    let spots = (0..<cols * rows).map { Pt(x: $0 % cols, y: $0 / cols) }.filter { p in
                        p.x % 2 == 1 && p.y % 2 == 1 && p.x >= 3 && p.x <= cols - 4 && p.y >= 3 && p.y <= rows - 4
                            && p.dist(start) > Hunt.blastRadius + 2 && picked.allSatisfy { p.dist($0) >= 5.5 }
                    }
                    if let p = spots.randomElement() { picked.append(p) }
                }
                if picked.count > holes.count { holes = picked }
            }
            let names = ["La Bufadora", "The Snorer", "Devil's Kettle", "The Spout"]
            for (n, hole) in holes.enumerated() {
                let r = n == 0 ? 2.3 : 1.5
                for y in max(1, hole.y - 2)...min(rows - 2, hole.y + 2) {   // a rocky ledge around each blowhole
                    for x in max(1, hole.x - 2)...min(cols - 2, hole.x + 2) where Pt(x: x, y: y).dist(hole) <= r {
                        blocked[y * cols + x] = false
                    }
                }
                vents.append(Vent(id: n, pos: hole, name: names[n],
                                  nextBlast: n == 0 ? Int.random(in: 24...36) : Int.random(in: 10...44)))
            }
        case .belmar:
            start = Pt(x: kind.cols / 2, y: kind.rows - 1)
            blocked = Array(repeating: false, count: cols * rows)
            // Two rock jetties run out from the beach into the surf.
            for jx in [4, kind.cols - 5] {
                for y in (kind.rows - 10)...(kind.rows - Hunt.beachRows - 1) { blocked[y * cols + jx] = true }
            }
        case .boats:
            start = Pt(x: kind.cols / 2, y: kind.rows - 1)
            blocked = Array(repeating: false, count: cols * rows)
            for i in blocked.indices {
                let p = Pt(x: i % cols, y: i / cols)
                if p.dist(start) > 2.5 && chance(0.11) { blocked[i] = true }
            }
        }
        let dist = distances(from: start)
        for i in blocked.indices where dist[i] < 0 { blocked[i] = true }   // seal unreachable pockets
        placeChests(dist: dist)
        placeTraps(dist: dist)
        runners = players.map {
            Runner(id: $0.id, pos: start, name: $0.name, color: $0.color,
                   speed: $0.speed, nerve: $0.nerve, human: $0.id == humanID)
        }
        revealAroundHuman()
    }

    // MARK: Map

    func open(_ p: Pt) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < cols && p.y < rows && !blocked[p.y * cols + p.x]
    }

    func isStairs(_ p: Pt) -> Bool {
        kind == .pyramid && abs(p.x - start.x) <= 1 && p.y >= 1 && p.y <= rows - 2
    }

    func isSea(_ p: Pt) -> Bool { kind == .bufadora && p.y == 0 }

    static let beachRows = 3
    func isBeach(_ p: Pt) -> Bool { kind == .belmar && p.y >= rows - Hunt.beachRows }

    /// Where a carried chest counts: base camp at La Bufadora, anywhere on the sand at Belmar.
    func isHome(_ p: Pt) -> Bool { kind == .belmar ? isBeach(p) : p == start }

    /// A wave is bearing down on this spot.
    func threatened(_ p: Pt) -> Bool {
        !isBeach(p) && waves.contains { $0.y <= p.y && p.y - $0.y <= 3 && ($0.from...$0.to).contains(p.x) }
    }

    func inBlast(_ p: Pt) -> Bool { vents.contains { p.dist($0.pos) <= Hunt.blastRadius } }

    private static func carveMaze(cols: Int, rows: Int, from s: Pt, loops: Double, rooms: Int) -> [Bool] {
        var b = Array(repeating: true, count: cols * rows)
        func i(_ p: Pt) -> Int { p.y * cols + p.x }
        b[i(s)] = false                     // s sits on odd coordinates (a maze cell)
        var stack = [s]
        while let cur = stack.last {
            let next = Pt.dirs.map { Pt(x: cur.x + $0.x * 2, y: cur.y + $0.y * 2) }
                .filter { $0.x >= 1 && $0.y >= 1 && $0.x <= cols - 2 && $0.y <= rows - 2 && b[i($0)] }
            if let n = next.randomElement() {
                b[i(Pt(x: (cur.x + n.x) / 2, y: (cur.y + n.y) / 2))] = false
                b[i(n)] = false
                stack.append(n)
            } else {
                stack.removeLast()
            }
        }
        for y in 1..<rows - 1 {
            for x in 1..<cols - 1 where b[y * cols + x] {
                let between = (x % 2 == 0 && y % 2 == 1) || (x % 2 == 1 && y % 2 == 0)
                if between && chance(loops) { b[y * cols + x] = false }
            }
        }
        for _ in 0..<rooms {
            let cx = Int.random(in: 1...(cols - 4) / 2) * 2 + 1
            let cy = Int.random(in: 1...(rows - 4) / 2) * 2 + 1
            for y in cy - 1...cy + 1 { for x in cx - 1...cx + 1 { b[y * cols + x] = false } }
        }
        b[i(s)] = false
        return b
    }

    private func distances(from s: Pt) -> [Int] {
        var d = Array(repeating: -1, count: cols * rows)
        guard open(s) else { return d }
        d[s.y * cols + s.x] = 0
        var queue = [s]
        var head = 0
        while head < queue.count {
            let p = queue[head]; head += 1
            for dir in Pt.dirs {
                let n = p + dir
                if open(n) && d[n.y * cols + n.x] < 0 {
                    d[n.y * cols + n.x] = d[p.y * cols + p.x] + 1
                    queue.append(n)
                }
            }
        }
        return d
    }

    private func placeChests(dist: [Int]) {
        let minDist = kind == .maze ? 6 : 5
        var pool = blocked.indices.filter { !blocked[$0] && dist[$0] >= minDist }
            .map { Pt(x: $0 % cols, y: $0 / cols) }
            .filter { kind != .belmar || $0.y <= rows - Hunt.beachRows - 3 }
        for (n, tier) in kind.tiers.shuffled().enumerated() where !pool.isEmpty {
            let sample = pool.shuffled().prefix(15)
            let pick = sample.max { score($0) < score($1) }!
            func score(_ p: Pt) -> Double {
                let spread = chests.map { $0.pos.dist(p) }.min() ?? 10
                var lure = 0.0
                if tier == .gold {
                    // Gold hides deep — and at La Bufadora, right by the geyser.
                    if let b = vents.map(\.pos).min(by: { p.dist($0) < p.dist($1) }) {
                        lure = max(0, 7 - p.dist(b)) * 1.5
                    } else {
                        lure = Double(dist[p.y * cols + p.x]) / 3
                    }
                }
                return min(spread, 8) + lure
            }
            chests.append(Chest(id: n, pos: pick, tier: tier, amount: tier.roll() * kind.payScale))
            pool.removeAll { $0 == pick }
        }
    }

    /// Trap doors hide on the steps and in the passages — never on a chest or right by the bottom.
    private func placeTraps(dist: [Int]) {
        guard kind.trapCount > 0 else { return }
        let chestSpots = Set(chests.map(\.pos))
        let pool = blocked.indices.filter { !blocked[$0] && dist[$0] >= 4 }
            .map { Pt(x: $0 % cols, y: $0 / cols) }
            .filter { !chestSpots.contains($0) }
        let stairs = pool.filter(isStairs).shuffled()
        let passages = pool.filter { !isStairs($0) }.shuffled()
        for p in stairs.prefix(3) + passages where traps.count < kind.trapCount {
            if traps.allSatisfy({ $0.dist(p) >= 2.5 }) { traps.insert(p) }
        }
    }

    /// First step of the shortest path from `from` to any tile matching `goal`.
    private func nextStep(from: Pt, avoid: Set<Pt> = [], goal: (Pt) -> Bool) -> Pt? {
        var parent = Array(repeating: -1, count: cols * rows)
        let si = from.y * cols + from.x
        parent[si] = si
        var queue = [from]
        var head = 0
        while head < queue.count {
            let p = queue[head]; head += 1
            if p != from && goal(p) {
                var cur = p
                while parent[cur.y * cols + cur.x] != si {
                    let pi = parent[cur.y * cols + cur.x]
                    cur = Pt(x: pi % cols, y: pi / cols)
                }
                return cur
            }
            for dir in Pt.dirs.shuffled() {
                let n = p + dir
                if open(n) && parent[n.y * cols + n.x] < 0 && !avoid.contains(n) {
                    parent[n.y * cols + n.x] = p.y * cols + p.x
                    queue.append(n)
                }
            }
        }
        return nil
    }

    // MARK: Play

    var human: Runner? { runners.first { $0.human } }
    var bankedCount: Int { runners.filter(\.banked).count }

    func tier(for id: Int) -> ChestTier? {
        guard let r = runners.first(where: { $0.id == id }), r.banked, let c = r.chest else { return nil }
        return chests[c].tier
    }

    func amount(for id: Int) -> Int {
        guard let r = runners.first(where: { $0.id == id }), r.banked, let c = r.chest else { return 0 }
        return chests[c].amount
    }

    func move(_ d: Pt) {
        guard !finished, let hi = runners.firstIndex(where: { $0.human }), !runners[hi].banked else { return }
        let now = Date()
        guard now.timeIntervalSince(lastMove) > 0.08 else { return }
        let n = runners[hi].pos + d
        guard open(n) else { return }
        lastMove = now
        runners[hi].pos = n
        springTrap(hi)
        checkWaves()
        revealAroundHuman()
        claim()
        bankReturns()
    }

    func run() async {
        while !finished && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(fastForward ? 0.03 : 0.25))
            tick()
        }
        finished = true
        try? await Task.sleep(for: .seconds(1.5))
    }

    func simulate() {
        silent = true
        while !finished { tick() }
    }

    private func sfx(_ e: Sound.Effect) {
        if !silent && !fastForward { Sound.shared.play(e) }
    }

    private func tick() {
        guard !finished else { return }
        ticks += 1
        if kind == .boats && ticks % 3 == 0 {
            driftRafts()
            claim()
        }
        if kind == .bufadora { geyserTick() }
        if kind == .belmar { waveTick() }
        for i in runners.indices where !runners[i].human && !runners[i].banked {
            if chance(runners[i].speed) { cpuStep(i) }
        }
        claim()
        bankReturns()
        timeLeft = max(0, timeLeft - 0.25)
        if timeLeft == 0 || runners.allSatisfy(\.banked) { finished = true }
    }

    private func cpuStep(_ i: Int) {
        var r = runners[i]
        var next: Pt?
        // At Belmar, see a wave coming and try to slip around the end of it.
        if kind == .belmar, threatened(r.pos), !chance(r.nerve * 0.35),
           let dodge = Pt.dirs.map({ r.pos + $0 }).filter({ open($0) && !threatened($0) }).randomElement() {
            runners[i].pos = dodge
            return
        }
        if r.chest != nil {
            // Carrying a chest home. Cautious players back away from a rumbling geyser.
            let danger = vents.filter { $0.state != .calm && r.pos.dist($0.pos) <= Hunt.blastRadius + 1.5 }.map(\.pos)
            if !danger.isEmpty, !chance(r.nerve * 0.6) {
                func safety(_ p: Pt) -> Double { danger.map { p.dist($0) }.min()! }
                next = ([r.pos] + Pt.dirs.map { r.pos + $0 }.filter(open)).max { safety($0) < safety($1) }
                if next == r.pos { next = nil }
            } else {
                next = nextStep(from: r.pos) { self.isHome($0) }
            }
        } else {
            for c in chests where c.owner == nil && c.pos.dist(r.pos) <= kind.sight { r.known.insert(c.id) }
            let targets = chests.filter { $0.owner == nil && r.known.contains($0.id) }
            // Everyone steers around trap doors they've seen spring — unless there's no other way.
            if let t = targets.min(by: { score($0, r) < score($1, r) }) {
                next = nextStep(from: r.pos, avoid: sprung) { $0 == t.pos } ?? nextStep(from: r.pos) { $0 == t.pos }
            }
            if next == nil { next = nextStep(from: r.pos, avoid: sprung) { !r.visited.contains($0) } }
            if next == nil { next = nextStep(from: r.pos) { !r.visited.contains($0) } }
            if next == nil { next = Pt.dirs.map { r.pos + $0 }.filter(open).randomElement() }
        }
        if let n = next {
            r.pos = n
            for dir in [Pt(x: 0, y: 0)] + Pt.dirs { r.visited.insert(n + dir) }
        }
        runners[i] = r
        springTrap(i)
    }

    /// Step on a trap door and you slide all the way back down to the bottom of the pyramid.
    private func springTrap(_ i: Int) {
        let from = runners[i].pos
        guard traps.contains(from), !runners[i].banked else { return }
        sprung.insert(from)
        seen.insert(from)
        runners[i].pos = start
        slide = (runners[i].id, from, Date.timeIntervalSinceReferenceDate)
        if runners[i].human {
            sfx(.slide)
            popup = HuntPopup(title: "TRAP DOOR!", amount: nil,
                              note: "Whoosh — you slid all the way back to the bottom of the pyramid.", color: .orange)
            news = "You fell through a trap door!"
        } else {
            if humanID == nil || from.dist(human?.pos ?? from) <= kind.sight { sfx(.slide) }
            news = "\(runners[i].name) fell through a trap door and slid back to the bottom!"
        }
    }

    private func score(_ c: Chest, _ r: Runner) -> Double {
        var s = c.pos.dist(r.pos) - Double(c.tier.rawValue) * r.nerve * 3
        if inBlast(c.pos) { s += (1 - r.nerve) * 4 }       // the timid avoid chests by the geyser
        return s
    }

    private func driftRafts() {
        for i in chests.indices where chests[i].owner == nil {
            let n = chests[i].pos + chests[i].drift
            if open(n) && n.dist(start) > 2 && !chests.contains(where: { $0.owner == nil && $0.pos == n }) {
                chests[i].pos = n
            } else {
                chests[i].drift = Pt.dirs.randomElement()!
            }
        }
    }

    private func geyserTick() {
        for v in vents.indices {
            vents[v].clock += 1
            switch vents[v].state {
            case .calm:
                if vents[v].clock >= vents[v].nextBlast {
                    vents[v].state = .rumbling
                    vents[v].clock = 0
                    news = "Rumble... \(vents[v].name) is about to blow!"
                    sfx(.rumble)
                }
            case .rumbling:
                if vents[v].clock >= Hunt.rumbleTicks {
                    vents[v].state = .blasting
                    vents[v].clock = 0
                    sfx(.geyser)
                    blast(v)
                }
            case .blasting:
                blast(v)
                if vents[v].clock >= Hunt.blastTicks {
                    vents[v].state = .calm
                    vents[v].clock = 0
                    vents[v].nextBlast = Int.random(in: 26...42)
                }
            }
        }
    }

    /// Anyone carrying a chest inside the spray loses it; the chest is flung somewhere nearby.
    private func blast(_ v: Int) {
        let b = vents[v].pos
        let name = vents[v].name
        for i in runners.indices {
            guard let ci = runners[i].chest, !runners[i].banked, runners[i].pos.dist(b) <= Hunt.blastRadius else { continue }
            let spots = (0..<cols * rows).map { Pt(x: $0 % cols, y: $0 / cols) }.filter { p in
                open(p) && p.dist(b) < 7.5 && !inBlast(p) && p != start
                    && !runners.contains { $0.pos == p } && !chests.contains { $0.owner == nil && $0.pos == p }
            }
            chests[ci].owner = nil
            if let spot = spots.randomElement() { chests[ci].pos = spot }
            runners[i].chest = nil
            runners[i].known.insert(ci)
            if runners[i].human {
                popup = HuntPopup(title: "THE BLOWHOLE GOT YOU!", amount: nil,
                                  note: "\(name) knocked the chest out of your hands. Go find it!", color: .cyan)
                news = "Your chest went flying!"
            } else {
                news = "\(name) knocked the chest out of \(runners[i].name)'s hands!"
            }
        }
    }

    private func waveTick() {
        nextWave -= 1
        if nextWave <= 0 {
            // Each breaker covers most of the beach, leaving a gap you can slip through.
            let width = Int(Double(cols) * Double.random(in: 0.55...0.75))
            let from = Int.random(in: 0...(cols - width))
            waveCount += 1
            waves.append(Wave(id: waveCount, y: 0, from: from, to: from + width - 1))
            nextWave = Int.random(in: 13...20)
            news = "Wave coming in!"
            sfx(.wave)
        }
        for w in waves.indices { waves[w].y += 1 }
        waves.removeAll { $0.y >= rows - Hunt.beachRows }      // it breaks on the sand
        checkWaves()
    }

    /// Anyone in the water under a breaker's crest (or the foam just behind it) gets washed back to the beach.
    private func checkWaves() {
        for i in runners.indices where !runners[i].banked && !isBeach(runners[i].pos) {
            let p = runners[i].pos
            guard waves.contains(where: { ($0.y - 1...$0.y).contains(p.y) && ($0.from...$0.to).contains(p.x) }) else { continue }
            let lost = runners[i].chest
            if let ci = lost {
                chests[ci].owner = nil          // the chest washes back out to where it was
                runners[i].known.insert(ci)
            }
            runners[i].chest = nil
            runners[i].pos = Pt(x: p.x, y: rows - Hunt.beachRows)
            wipeouts.append((runners[i].id, p, Date.timeIntervalSinceReferenceDate))
            if wipeouts.count > 12 { wipeouts.removeFirst() }
            if runners[i].human {
                sfx(.slide)
                popup = HuntPopup(title: "WIPEOUT!", amount: nil,
                                  note: lost != nil ? "A wave knocked you back to the beach and your chest washed away. Try again!"
                                                    : "A wave knocked you back to the beach. Try again!", color: .cyan)
                news = "You got hit by a wave!"
            } else {
                news = "\(runners[i].name) got hit by a wave\(lost != nil ? " and lost the chest" : "")!"
            }
        }
    }

    private func claim() {
        for i in runners.indices where runners[i].chest == nil && !runners[i].banked {
            guard let ci = chests.firstIndex(where: { $0.owner == nil && $0.pos == runners[i].pos }) else { continue }
            chests[ci].owner = runners[i].id
            runners[i].chest = ci
            if !kind.mustReturn { runners[i].banked = true }
            // Your own chest always plays; while spectating, everyone's does.
            if runners[i].human || humanID == nil { sfx(.chest(chests[ci].tier)) }
            let c = chests[ci]
            if runners[i].human {
                popup = HuntPopup(title: "\(c.tier.name.uppercased()) CHEST", amount: c.amount,
                                  note: kind == .belmar ? "Now carry it back to the beach — watch the waves!"
                                    : kind.mustReturn ? "Now carry it back to base camp!" : "That's your money card.",
                                  color: c.tier.color)
            } else {
                news = "\(runners[i].name) grabbed a \(c.tier.name.lowercased()) chest!"
            }
        }
        if runners.allSatisfy(\.banked) { finished = true }
    }

    private func bankReturns() {
        guard kind.mustReturn else { return }
        for i in runners.indices where runners[i].chest != nil && !runners[i].banked && isHome(runners[i].pos) {
            runners[i].banked = true
            let c = chests[runners[i].chest!]
            if runners[i].human {
                sfx(.bell)
                popup = HuntPopup(title: kind == .belmar ? "SAFE ON THE SAND" : "SAFE AT BASE CAMP", amount: c.amount,
                                  note: "Your money card is banked.", color: c.tier.color)
            } else {
                news = "\(runners[i].name) made it back to \(kind == .belmar ? "the beach" : "base camp") with a chest."
            }
        }
        if runners.allSatisfy(\.banked) { finished = true }
    }

    private func revealAroundHuman() {
        guard let h = human else { return }
        let r = Int(kind.sight.rounded(.up))
        for y in h.pos.y - r...h.pos.y + r {
            for x in h.pos.x - r...h.pos.x + r where Pt(x: x, y: y).dist(h.pos) <= kind.sight {
                seen.insert(Pt(x: x, y: y))
            }
        }
    }
}

// MARK: - Rendering

struct HuntCanvas: View {
    let hunt: Hunt

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                draw(&ctx, size, tl.date.timeIntervalSinceReferenceDate)
            }
        }
        .aspectRatio(CGFloat(hunt.cols) / CGFloat(hunt.rows), contentMode: .fit)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let s = min(size.width / CGFloat(hunt.cols), size.height / CGFloat(hunt.rows))
        func rect(_ p: Pt) -> CGRect { CGRect(x: CGFloat(p.x) * s, y: CGFloat(p.y) * s, width: s, height: s) }
        func center(_ p: Pt) -> CGPoint { CGPoint(x: (CGFloat(p.x) + 0.5) * s, y: (CGFloat(p.y) + 0.5) * s) }
        let me = hunt.human
        let sight = hunt.kind.sight
        func inSight(_ p: Pt) -> Bool { me.map { p.dist($0.pos) <= sight } ?? true }

        // Ground
        for y in 0..<hunt.rows {
            for x in 0..<hunt.cols {
                let p = Pt(x: x, y: y)
                let r = rect(p)
                let wall = !hunt.open(p)
                switch hunt.kind {
                case .maze:
                    if wall {
                        ctx.fill(Path(r), with: .color(Color(red: 0.13, green: 0.40, blue: 0.18)))
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.08, dy: s * 0.08)),
                                 with: .color(Color(red: 0.20, green: 0.55, blue: 0.24)))
                    } else {
                        ctx.fill(Path(r), with: .color(Color(red: 0.87, green: 0.79, blue: 0.60)))
                    }
                case .pyramid:
                    if wall {
                        // Sandstone blocks, laid in staggered courses.
                        let shade = 0.03 * Double((x * 7 + y * 3) % 4)
                        ctx.fill(Path(r), with: .color(Color(red: 0.80 - shade, green: 0.64 - shade, blue: 0.38 - shade)))
                        let mortar = Color(red: 0.52, green: 0.38, blue: 0.20)
                        ctx.fill(Path(CGRect(x: r.minX, y: r.minY, width: s, height: s * 0.07)), with: .color(mortar))
                        ctx.fill(Path(CGRect(x: r.minX, y: r.midY, width: s, height: s * 0.06)), with: .color(mortar))
                        let joint = y % 2 == 0 ? r.minX + s * 0.3 : r.minX + s * 0.75
                        ctx.fill(Path(CGRect(x: joint, y: r.minY, width: s * 0.06, height: s * 0.5)), with: .color(mortar))
                        ctx.fill(Path(CGRect(x: r.minX + s * 1.05 - (joint - r.minX), y: r.midY, width: s * 0.06, height: s * 0.5)), with: .color(mortar))
                    } else if hunt.isStairs(p) {
                        ctx.fill(Path(r), with: .color(Color(red: 0.90, green: 0.86, blue: 0.76)))
                        ctx.fill(Path(CGRect(x: r.minX, y: r.minY, width: s, height: s * 0.14)),
                                 with: .color(Color(red: 0.62, green: 0.57, blue: 0.48)))
                        if x == hunt.start.x - 1 || x == hunt.start.x + 1 {
                            let edge = x < hunt.start.x ? r.minX : r.maxX - s * 0.08
                            ctx.fill(Path(CGRect(x: edge, y: r.minY, width: s * 0.08, height: s)),
                                     with: .color(Color(red: 0.55, green: 0.50, blue: 0.42)))
                        }
                    } else {
                        // Torch-lit tunnel floor inside the pyramid.
                        ctx.fill(Path(r), with: .color(Color(red: 0.36, green: 0.26, blue: 0.16)))
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.3, dy: s * 0.3)), with: .color(Color(red: 0.42, green: 0.31, blue: 0.19)))
                    }
                case .bufadora:
                    if hunt.isSea(p) {
                        let wave = 0.5 + 0.5 * sin(t * 1.6 + Double(x) * 0.7)
                        ctx.fill(Path(r), with: .color(Color(red: 0.08, green: 0.36 + wave * 0.06, blue: 0.62 + wave * 0.08)))
                        ctx.fill(Path(CGRect(x: r.minX, y: r.maxY - s * (0.15 + 0.1 * wave), width: s, height: s * 0.12)),
                                 with: .color(.white.opacity(0.7)))
                    } else if wall {
                        ctx.fill(Path(r), with: .color(Color(red: 0.30, green: 0.25, blue: 0.23)))
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.12, dy: s * 0.16).offsetBy(dx: -s * 0.06, dy: -s * 0.06)),
                                 with: .color(Color(red: 0.42, green: 0.36, blue: 0.32)))
                    } else {
                        ctx.fill(Path(r), with: .color(Color(red: 0.74, green: 0.63, blue: 0.48)))
                    }
                case .belmar:
                    if hunt.isBeach(p) {
                        let k = Double((x * 5 + y * 3) % 4) * 0.015
                        ctx.fill(Path(r), with: .color(Color(red: 0.93 - k, green: 0.84 - k, blue: 0.62 - k)))
                    } else if wall {
                        ctx.fill(Path(r), with: .color(Color(red: 0.10, green: 0.40, blue: 0.62)))
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.06, dy: s * 0.08)), with: .color(Color(white: 0.42)))
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.22, dy: s * 0.26).offsetBy(dx: -s * 0.08, dy: -s * 0.08)),
                                 with: .color(Color(white: 0.58)))
                    } else {
                        // Deeper (darker) farther out; a ripple of light near the shore.
                        let depth = Double(hunt.rows - Hunt.beachRows - y) / Double(hunt.rows)
                        let ripple = 0.5 + 0.5 * sin(t * 1.8 + Double(x) * 0.6 + Double(y) * 0.5)
                        ctx.fill(Path(r), with: .color(Color(red: 0.12, green: 0.55 - depth * 0.25 + ripple * 0.05,
                                                             blue: 0.75 - depth * 0.15 + ripple * 0.06)))
                        if y == hunt.rows - Hunt.beachRows - 1 {
                            let lap = 0.5 + 0.5 * sin(t * 2.4 + Double(x) * 0.9)
                            ctx.fill(Path(CGRect(x: r.minX, y: r.maxY - s * (0.12 + 0.12 * lap), width: s, height: s * 0.14)),
                                     with: .color(.white.opacity(0.75)))
                        }
                    }
                case .boats:
                    let wave = 0.5 + 0.5 * sin(t * 1.6 + Double(x) * 0.7 + Double(y) * 0.45)
                    ctx.fill(Path(r), with: .color(Color(red: 0.10, green: 0.42 + wave * 0.06, blue: 0.72 + wave * 0.08)))
                    if wall {
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.1, dy: s * 0.14)), with: .color(Color(white: 0.45)))
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.25, dy: s * 0.28).offsetBy(dx: -s * 0.08, dy: -s * 0.08)),
                                 with: .color(Color(white: 0.62)))
                    }
                }
            }
        }
        // Start marker
        let sr = rect(hunt.start)
        switch hunt.kind {
        case .boats:
            ctx.fill(Path(sr.insetBy(dx: -s * 0.6, dy: s * 0.2)), with: .color(Color(red: 0.55, green: 0.36, blue: 0.18)))
        case .belmar:
            // Beach umbrellas along the sand.
            for (n, ux) in [2, 7, hunt.cols - 8, hunt.cols - 3].enumerated() {
                let c = CGPoint(x: (CGFloat(ux) + 0.5) * s, y: (CGFloat(hunt.rows) - 0.55) * s)
                ctx.fill(Path(CGRect(x: c.x - s * 0.03, y: c.y - s * 0.5, width: s * 0.06, height: s * 0.6)), with: .color(.white))
                var top = Path()
                top.addArc(center: CGPoint(x: c.x, y: c.y - s * 0.45), radius: s * 0.55, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                top.closeSubpath()
                ctx.fill(top, with: .color([Color.red, .yellow, .blue, .orange][n]))
            }
        case .bufadora:
            var tent = Path()
            tent.move(to: CGPoint(x: sr.midX, y: sr.minY + s * 0.1))
            tent.addLine(to: CGPoint(x: sr.maxX + s * 0.1, y: sr.maxY - s * 0.05))
            tent.addLine(to: CGPoint(x: sr.minX - s * 0.1, y: sr.maxY - s * 0.05))
            tent.closeSubpath()
            ctx.fill(tent, with: .color(Color(red: 0.9, green: 0.3, blue: 0.2)))
            ctx.fill(Path(CGRect(x: sr.midX - s * 0.02, y: sr.minY - s * 0.3, width: s * 0.05, height: s * 0.45)), with: .color(.white))
            ctx.fill(Path(CGRect(x: sr.midX, y: sr.minY - s * 0.3, width: s * 0.3, height: s * 0.16)), with: .color(.yellow))
        default:
            ctx.stroke(Path(ellipseIn: sr.insetBy(dx: s * 0.1, dy: s * 0.1)), with: .color(.white.opacity(0.7)), lineWidth: 2)
        }

        // Trap doors that have sprung: a gaping hatch with a chute arrow pointing home.
        for p in hunt.sprung where hunt.seen.contains(p) {
            let r = rect(p).insetBy(dx: s * 0.1, dy: s * 0.1)
            ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(Color(red: 0.08, green: 0.06, blue: 0.05)))
            ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(.orange), lineWidth: 2)
            ctx.fill(Path(CGRect(x: r.minX, y: r.minY - s * 0.08, width: r.width, height: s * 0.12)),
                     with: .color(Color(red: 0.45, green: 0.30, blue: 0.15)))
            ctx.draw(Text("↓").font(.system(size: s * 0.5, weight: .black)).foregroundStyle(.orange), at: CGPoint(x: r.midX, y: r.midY))
        }
        if let sl = hunt.slide, t - sl.at < 0.9, let r = hunt.runners.first(where: { $0.id == sl.id }),
           r.human || inSight(sl.from) {
            let fade = 1 - (t - sl.at) / 0.9
            var chute = Path()
            chute.move(to: center(sl.from))
            chute.addLine(to: center(hunt.start))
            ctx.stroke(chute, with: .color(r.color.opacity(0.8 * fade)),
                       style: StrokeStyle(lineWidth: s * 0.35, lineCap: .round, dash: [s * 0.3, s * 0.2], dashPhase: CGFloat(t * 40)))
        }

        // Chests
        for c in hunt.chests where c.owner == nil && (inSight(c.pos) || (!hunt.kind.openWater && hunt.seen.contains(c.pos))) {
            drawChest(&ctx, rect(c.pos), c.tier, raft: hunt.kind == .boats, t: t, s: s)
        }

        // Runners
        for (n, r) in hunt.runners.enumerated() where r.human || hunt.kind.openWater || inSight(r.pos) {
            var c = center(r.pos)
            if !r.human {
                c.x += CGFloat(n % 3 - 1) * s * 0.14
                c.y += CGFloat(n / 3 % 3 - 1) * s * 0.14
            }
            let rad = s * (r.human ? 0.42 : 0.34)
            let circle = Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2))
            if hunt.kind == .boats {
                var hull = Path()
                hull.move(to: CGPoint(x: c.x - rad * 1.2, y: c.y + rad * 0.2))
                hull.addLine(to: CGPoint(x: c.x + rad * 1.2, y: c.y + rad * 0.2))
                hull.addLine(to: CGPoint(x: c.x + rad * 0.7, y: c.y + rad * 0.9))
                hull.addLine(to: CGPoint(x: c.x - rad * 0.7, y: c.y + rad * 0.9))
                hull.closeSubpath()
                ctx.fill(hull, with: .color(Color(red: 0.45, green: 0.28, blue: 0.14)))
            }
            ctx.fill(circle, with: .color(r.color))
            ctx.stroke(circle, with: .color(r.human ? .white : .black.opacity(0.5)), lineWidth: r.human ? 2.5 : 1)
            ctx.draw(Text(r.human ? "YOU" : String(r.name.prefix(1)))
                        .font(.system(size: r.human ? s * 0.26 : s * 0.4, weight: .heavy))
                        .foregroundStyle(.white), at: c)
            if r.banked {
                ctx.draw(Text("✓").font(.system(size: s * 0.35, weight: .bold)).foregroundStyle(.yellow),
                         at: CGPoint(x: c.x + rad, y: c.y - rad))
            } else if let ci = r.chest {
                // Carrying it home, held overhead.
                let box = CGRect(x: c.x - s * 0.5, y: c.y - rad - s * 0.62, width: s, height: s)
                drawChest(&ctx, box, hunt.chests[ci].tier, raft: false, t: t, s: s * 0.8)
            }
        }

        // Fog of war
        if let me {
            for y in 0..<hunt.rows {
                for x in 0..<hunt.cols {
                    let p = Pt(x: x, y: y)
                    if hunt.kind.openWater {
                        if !inSight(p) { ctx.fill(Path(rect(p)), with: .color(.white.opacity(hunt.kind == .belmar ? 0.2 : 0.38))) }
                    } else if hunt.isSea(p) {
                        continue            // you can always see the ocean
                    } else if !hunt.seen.contains(p) {
                        ctx.fill(Path(rect(p)), with: .color(.black))
                    } else if !inSight(p) {
                        ctx.fill(Path(rect(p)), with: .color(.black.opacity(0.5)))
                    }
                }
            }
            if hunt.kind == .pyramid {
                // Torchlight fades into darkness outside your circle of sight.
                let full = CGRect(origin: .zero, size: CGSize(width: s * CGFloat(hunt.cols), height: s * CGFloat(hunt.rows)))
                ctx.fill(Path(full), with: .radialGradient(
                    Gradient(stops: [.init(color: .clear, location: 0.5), .init(color: .black.opacity(0.35), location: 1)]),
                    center: center(me.pos), startRadius: 0, endRadius: s * sight * 1.3))
            }
        }

        // Breakers rolling in: a curling white crest with foam trailing behind it. Seen from anywhere.
        for w in hunt.waves {
            let x0 = CGFloat(w.from) * s, x1 = CGFloat(w.to + 1) * s
            let crestY = CGFloat(w.y) * s
            ctx.fill(Path(CGRect(x: x0, y: crestY - s, width: x1 - x0, height: s * 1.2)), with: .color(.white.opacity(0.35)))
            var crest = Path()
            crest.move(to: CGPoint(x: x0, y: crestY + s * 0.6))
            var x = x0
            while x <= x1 {
                let bump = CGFloat(sin(Double(x / s) * 2.1 + t * 6)) * s * 0.18
                crest.addLine(to: CGPoint(x: x, y: crestY + s * 0.75 + bump))
                x += s * 0.25
            }
            crest.addLine(to: CGPoint(x: x1, y: crestY + s * 0.2))
            crest.addLine(to: CGPoint(x: x0, y: crestY + s * 0.2))
            crest.closeSubpath()
            ctx.fill(crest, with: .color(.white.opacity(0.92)))
            ctx.stroke(Path(CGRect(x: x0, y: crestY + s * 0.2, width: x1 - x0, height: s * 0.1)), with: .color(.cyan.opacity(0.7)), lineWidth: 2)
        }
        // A splash where someone just got wiped out.
        for wo in hunt.wipeouts where t - wo.at < 0.8 {
            let fade = 1 - (t - wo.at) / 0.8
            let c = center(wo.from)
            let rad = s * CGFloat(0.4 + (t - wo.at) * 1.4)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)),
                       with: .color(.white.opacity(0.9 * fade)), lineWidth: 3)
        }

        // The blowholes are visible (and audible) from anywhere.
        for v in hunt.vents {
            drawGeyser(&ctx, center(v.pos), v.state, big: v.id == 0, s: s, t: t + Double(v.id) * 0.7)
        }
    }

    private func drawGeyser(_ ctx: inout GraphicsContext, _ c: CGPoint, _ state: Geyser, big: Bool, s: CGFloat, t: Double) {
        let k: CGFloat = big ? 1 : 0.75
        let hole = CGRect(x: c.x - s * 0.4 * k, y: c.y - s * 0.25 * k, width: s * 0.8 * k, height: s * 0.5 * k)
        ctx.fill(Path(ellipseIn: hole), with: .color(Color(red: 0.05, green: 0.08, blue: 0.12)))
        ctx.stroke(Path(ellipseIn: hole.insetBy(dx: -s * 0.06, dy: -s * 0.05)), with: .color(.white.opacity(0.8)), lineWidth: 2)
        let zone = CGFloat(Hunt.blastRadius) * s
        let zoneRect = CGRect(x: c.x - zone, y: c.y - zone, width: zone * 2, height: zone * 2)
        switch state {
        case .calm:
            ctx.stroke(Path(ellipseIn: zoneRect), with: .color(.white.opacity(0.22)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
        case .rumbling:
            let pulse = 0.5 + 0.5 * sin(t * 18)
            ctx.fill(Path(ellipseIn: zoneRect), with: .color(.white.opacity(0.10 + 0.12 * pulse)))
            ctx.stroke(Path(ellipseIn: zoneRect), with: .color(.cyan.opacity(0.9)), lineWidth: 2.5)
            ctx.draw(Text("!").font(.system(size: s * 0.8, weight: .black)).foregroundStyle(.cyan), at: CGPoint(x: c.x, y: c.y - s * 0.9))
        case .blasting:
            ctx.fill(Path(ellipseIn: zoneRect), with: .color(.white.opacity(0.35)))
            for k in 0..<22 {
                let a = Double(k) * 2.4 + t * 3
                let d = (0.3 + Double((k * 37) % 10) / 10 * 0.75) * Double(zone) * (0.7 + 0.3 * sin(t * 11 + Double(k)))
                let r = s * (0.35 + CGFloat(k % 4) * 0.12)
                let p = CGPoint(x: c.x + CGFloat(cos(a) * d), y: c.y + CGFloat(sin(a) * d))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color((k % 3 == 0 ? Color.cyan : .white).opacity(0.75)))
            }
        }
    }

    private func drawChest(_ ctx: inout GraphicsContext, _ r: CGRect, _ tier: ChestTier, raft: Bool, t: Double, s: CGFloat) {
        var r = r
        if raft {
            let bob = CGFloat(sin(t * 2.2 + Double(r.minX))) * s * 0.05
            r = r.offsetBy(dx: 0, dy: bob)
            for k in 0..<3 {
                let plank = CGRect(x: r.minX + s * 0.05, y: r.minY + s * (0.55 + CGFloat(k) * 0.13), width: s * 0.9, height: s * 0.11)
                ctx.fill(Path(roundedRect: plank, cornerRadius: 2), with: .color(Color(red: 0.62, green: 0.44, blue: 0.24)))
            }
        }
        let inset = (r.width - s) / 2
        let body = CGRect(x: r.minX + inset + s * 0.18, y: r.minY + s * (raft ? 0.28 : 0.38), width: s * 0.64, height: s * 0.36)
        let lid = CGRect(x: body.minX, y: body.minY - s * 0.16, width: body.width, height: s * 0.2)
        ctx.fill(Path(roundedRect: body, cornerRadius: 2), with: .color(Color(red: 0.45, green: 0.26, blue: 0.10)))
        ctx.fill(Path(roundedRect: lid, cornerRadius: 4), with: .color(Color(red: 0.55, green: 0.32, blue: 0.12)))
        ctx.fill(Path(CGRect(x: body.minX, y: body.minY, width: body.width, height: s * 0.06)), with: .color(tier.color))
        ctx.fill(Path(CGRect(x: body.midX - s * 0.05, y: lid.minY, width: s * 0.1, height: body.maxY - lid.minY)), with: .color(tier.color))
        if tier == .gold {
            let glow = 0.5 + 0.5 * sin(t * 4 + Double(r.minX))
            ctx.draw(Text("✦").font(.system(size: s * 0.3)).foregroundStyle(.yellow.opacity(glow)),
                     at: CGPoint(x: lid.maxX, y: lid.minY))
        }
    }
}

// MARK: - Excursion screen

struct HuntView: View {
    let hunt: Hunt
    @FocusState private var focused: Bool
    @State private var dragStart: CGSize = .zero

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label(hunt.kind.title, systemImage: hunt.kind.symbol).font(.headline)
                Spacer()
                Label(timeText, systemImage: "timer")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(hunt.timeLeft < 10 ? .red : .primary)
            }
            HStack {
                Text("\(hunt.bankedCount) of \(hunt.runners.count) \(hunt.kind == .belmar ? "back on the sand" : hunt.kind.mustReturn ? "back at camp" : "have a chest")")
                Spacer()
                status
            }
            .font(.subheadline)

            if let p = hunt.popup { banner(p) }

            HuntCanvas(hunt: hunt)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.4)))
                .gesture(DragGesture(minimumDistance: 12)
                    .onChanged { g in
                        let dx = g.translation.width - dragStart.width
                        let dy = g.translation.height - dragStart.height
                        guard max(abs(dx), abs(dy)) > 22 else { return }
                        hunt.move(abs(dx) > abs(dy) ? Pt(x: dx > 0 ? 1 : -1, y: 0) : Pt(x: 0, y: dy > 0 ? 1 : -1))
                        dragStart = g.translation
                    }
                    .onEnded { _ in dragStart = .zero })

            Text(hunt.news).font(.caption).foregroundStyle(.secondary).frame(height: 16)

            if let h = hunt.human, !h.banked, !hunt.finished {
                dpad
            } else if !hunt.finished && hunt.canFastForward {
                Button {
                    hunt.fastForward = true
                } label: {
                    Label("Fast-forward", systemImage: "forward.fill").frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)
                .disabled(hunt.fastForward)
            } else if hunt.finished {
                Text(endText).font(.headline)
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.25), value: hunt.popup)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: [.down, .repeat]) { press in
            switch press.key {
            case .upArrow: hunt.move(Pt(x: 0, y: -1))
            case .downArrow: hunt.move(Pt(x: 0, y: 1))
            case .leftArrow: hunt.move(Pt(x: -1, y: 0))
            case .rightArrow: hunt.move(Pt(x: 1, y: 0))
            default:
                switch press.characters.lowercased() {
                case "w": hunt.move(Pt(x: 0, y: -1))
                case "s": hunt.move(Pt(x: 0, y: 1))
                case "a": hunt.move(Pt(x: -1, y: 0))
                case "d": hunt.move(Pt(x: 1, y: 0))
                default: return .ignored
                }
            }
            return .handled
        }
    }

    @ViewBuilder private var status: some View {
        if let h = hunt.human {
            if let ci = h.chest {
                let c = hunt.chests[ci]
                Text(h.banked ? "Your card: \(money(c.amount))" : "Carrying \(money(c.amount))")
                    .bold().foregroundStyle(c.tier.color)
            } else {
                Text("Find a chest!").foregroundStyle(.secondary)
            }
        } else {
            Text("Watching").foregroundStyle(.secondary)
        }
    }

    private var endText: String {
        guard let h = hunt.human else { return "Time's up!" }
        if h.banked { return "Time's up!" }
        return h.chest != nil ? "Time's up — you didn't make it back to \(hunt.kind == .belmar ? "the beach" : "camp")!" : "Time's up — you came back empty-handed!"
    }

    private var timeText: String {
        let t = Int(hunt.timeLeft.rounded(.up))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func banner(_ p: HuntPopup) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.title).font(.caption.bold()).foregroundStyle(p.color)
                if let a = p.amount {
                    Text(money(a)).font(.system(size: 26, weight: .heavy, design: .rounded))
                }
                Text(p.note).font(.caption)
            }
            Spacer()
            Button("OK") { hunt.popup = nil }.buttonStyle(.bordered)
        }
        .padding(12)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.color, lineWidth: 2))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var dpad: some View {
        VStack(spacing: 4) {
            padButton("chevron.up", Pt(x: 0, y: -1))
            HStack(spacing: 44) {
                padButton("chevron.left", Pt(x: -1, y: 0))
                padButton("chevron.right", Pt(x: 1, y: 0))
            }
            padButton("chevron.down", Pt(x: 0, y: 1))
        }
    }

    private func padButton(_ symbol: String, _ d: Pt) -> some View {
        Button { hunt.move(d) } label: {
            Image(systemName: symbol).font(.title2.bold()).frame(width: 48, height: 40)
        }
        .buttonStyle(.bordered)
        .buttonRepeatBehavior(.enabled)
    }
}
