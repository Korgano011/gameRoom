import Foundation
import Observation

/// Mission 1: a "Star Trek Senior"-style rebuild of the classic mainframe Super Star Trek.
@Observable
final class TrekGame {
    enum Sys: Int, CaseIterable {
        case warp, srs, lrs, phasers, torpedoes, damageControl, shields, computer, lifeSupport
        var name: String {
            ["Warp Engines", "Short-Range Sensors", "Long-Range Sensors", "Phaser Control", "Photon Tubes",
             "Damage Control", "Shield Control", "Library Computer", "Life Support"][rawValue]
        }
        var short: String { ["WARP", "SRS", "LRS", "PHA", "TOR", "DMG", "SHE", "COM", "LIFE"][rawValue] }
    }

    struct Quad { var klingons = 0, bases = 0, stars = 0
        var code: Int { klingons * 100 + bases * 10 + stars }
    }
    enum Cell: Equatable { case empty, ship, klingon, base, star }
    struct Klingon { var x: Int, y: Int, energy: Double, maxEnergy: Double }

    struct LogLine: Identifiable {
        let id = UUID()
        let text: String
        let kind: Kind
        enum Kind { case info, good, bad, alert, speech }
    }

    enum FX {
        case phasers([(Int, Int)])
        case torpedo([(Double, Double)], hit: (Int, Int)?)
        case enemyFire([(Int, Int)])
        case explosion(Int, Int)
        case warp
    }

    enum Outcome: Equatable { case won, lost(String) }

    // Galaxy
    var galaxy: [[Quad]] = Array(repeating: Array(repeating: Quad(), count: 8), count: 8)
    var known: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 8)
    var qx = 0
    var qy = 0
    var sx = 0
    var sy = 0
    var sector: [[Cell]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
    var klingons: [Klingon] = []

    // Ship
    let maxEnergy = 3000.0
    let maxTorpedoes = 10
    var energy = 3000.0
    var shields = 0.0
    var torpedoes = 10
    var damage: [Double] = Array(repeating: 0, count: Sys.allCases.count)
    var docked = false
    var lifeReserve = 5.0

    // Time
    var startDate = 0.0
    var stardate = 0.0
    var totalDays = 0.0
    var totalKlingons = 0
    var totalBases = 0

    var log: [LogLine] = []
    var fx: FX?
    var fxTime = Date()
    var booms: [(x: Int, y: Int, at: Date)] = []
    var outcome: Outcome?

    var klingonsLeft: Int { galaxy.joined().reduce(0) { $0 + $1.klingons } }
    var basesLeft: Int { galaxy.joined().reduce(0) { $0 + $1.bases } }
    var daysLeft: Double { max(0, startDate + totalDays - stardate) }
    var quad: Quad { galaxy[qy][qx] }

    var condition: String {
        if docked { return "DOCKED" }
        if !klingons.isEmpty { return "RED" }
        if energy < maxEnergy * 0.1 { return "YELLOW" }
        return "GREEN"
    }

    func working(_ s: Sys) -> Bool { damage[s.rawValue] >= 0 }

    init() { newGame() }

    func newGame() {
        galaxy = Array(repeating: Array(repeating: Quad(), count: 8), count: 8)
        known = Array(repeating: Array(repeating: false, count: 8), count: 8)
        var k = 0, b = 0
        for y in 0..<8 {
            for x in 0..<8 {
                let r = Double.random(in: 0..<1)
                let kl = r > 0.98 ? 3 : r > 0.95 ? 2 : r > 0.80 ? 1 : 0
                let base = Double.random(in: 0..<1) > 0.96 ? 1 : 0
                galaxy[y][x] = Quad(klingons: kl, bases: base, stars: Int.random(in: 1...8))
                k += kl; b += base
            }
        }
        if b == 0 {
            let x = Int.random(in: 0..<8), y = Int.random(in: 0..<8)
            galaxy[y][x].bases = 1; b = 1
        }
        while b < 3 {
            let x = Int.random(in: 0..<8), y = Int.random(in: 0..<8)
            if galaxy[y][x].bases == 0 { galaxy[y][x].bases = 1; b += 1 }
        }
        while k < min(40, 14 + 4 * (Difficulty.level - 1)) {
            let x = Int.random(in: 0..<8), y = Int.random(in: 0..<8)
            if galaxy[y][x].klingons < 3 { galaxy[y][x].klingons += 1; k += 1 }
        }
        totalKlingons = k
        totalBases = b
        startDate = Double(Int.random(in: 32000...32500))
        stardate = startDate
        totalDays = Double(max(32 + Int.random(in: 0...8), k + max(8, 15 - 2 * (Difficulty.level - 1))))
        energy = maxEnergy; shields = 0; torpedoes = maxTorpedoes
        damage = Array(repeating: 0, count: Sys.allCases.count)
        lifeReserve = 5
        outcome = nil
        log = []
        qx = Int.random(in: 0..<8); qy = Int.random(in: 0..<8)
        // never start in a hot quadrant
        galaxy[qy][qx].klingons = 0
        totalKlingons = klingonsLeft
        sx = Int.random(in: 0..<8); sy = Int.random(in: 0..<8)
        enterQuadrant(followers: [])
        say("Captain's log, stardate \(fmt(stardate))\(Difficulty.tag). \(totalKlingons) Klingon warships, \(fmt(totalDays, 0)) stardates, \(totalBases) starbases.", .info)
    }

    // MARK: quadrant setup

    private func enterQuadrant(followers: [Klingon]) {
        sector = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        klingons = []
        known[qy][qx] = true
        sector[sy][sx] = .ship
        let q = galaxy[qy][qx]
        let native = q.klingons - followers.count
        for f in followers {
            let (x, y) = emptySpot(near: (f.x, f.y))
            sector[y][x] = .klingon
            klingons.append(Klingon(x: x, y: y, energy: f.energy, maxEnergy: f.maxEnergy))
        }
        for _ in 0..<max(0, native) {
            let (x, y) = emptySpot()
            sector[y][x] = .klingon
            let e = 200 * Difficulty.power * (0.5 + Double.random(in: 0..<1))
            klingons.append(Klingon(x: x, y: y, energy: e, maxEnergy: e))
        }
        for _ in 0..<q.bases { let (x, y) = emptySpot(); sector[y][x] = .base }
        for _ in 0..<q.stars { let (x, y) = emptySpot(); sector[y][x] = .star }
        if !klingons.isEmpty {
            say("COMBAT AREA — CONDITION RED", .alert)
            Sound.shared.play(.alert)
            if shields <= 200 { say("Shields dangerously low!", .bad) }
        }
        checkDocked()
    }

    private func emptySpot(near: (Int, Int)? = nil) -> (Int, Int) {
        if let (nx, ny) = near, (0..<8).contains(nx), (0..<8).contains(ny), sector[ny][nx] == .empty { return (nx, ny) }
        while true {
            let x = Int.random(in: 0..<8), y = Int.random(in: 0..<8)
            if sector[y][x] == .empty { return (x, y) }
        }
    }

    // MARK: helpers

    func fmt(_ v: Double, _ d: Int = 1) -> String { String(format: "%.\(d)f", v) }

    func say(_ s: String, _ k: LogLine.Kind = .info) {
        log.append(LogLine(text: s, kind: k))
        if log.count > 80 { log.removeFirst(log.count - 80) }
    }

    func distance(to k: Klingon) -> Double {
        hypot(Double(k.x - sx), Double(k.y - sy))
    }

    /// Course 1 = east (right), 3 = north (up), 5 = west, 7 = south, fractional allowed.
    /// As in the classic game, each step moves exactly one sector along the major axis.
    static func vector(course: Double) -> (Double, Double) {
        let a = (course - 1) * .pi / 4
        let (x, y) = (cos(a), -sin(a))
        let m = max(abs(x), abs(y))
        return (x / m, y / m)
    }

    static func course(dx: Double, dy: Double) -> Double {
        var a = atan2(-dy, dx) * 4 / .pi
        if a < 0 { a += 8 }
        return a + 1
    }

    /// Library computer: course + warp from the ship to an absolute galactic sector position.
    func navTo(absX: Double, absY: Double) -> (course: Double, warp: Double) {
        let dx = absX - Double(qx * 8 + sx)
        let dy = absY - Double(qy * 8 + sy)
        let c = TrekGame.course(dx: dx, dy: dy)
        let steps = max(abs(dx), abs(dy)).rounded()
        return (c, max(0.125, steps / 8))
    }

    func navTo(sectorX x: Int, y: Int) -> (course: Double, warp: Double) {
        navTo(absX: Double(qx * 8 + x), absY: Double(qy * 8 + y))
    }

    func navTo(quadrantX x: Int, y: Int) -> (course: Double, warp: Double) {
        navTo(absX: Double(x * 8) + 3.5, absY: Double(y * 8) + 3.5)
    }

    /// First solid object a warp along this course would hit inside the current quadrant.
    func obstacle(course: Double, warp: Double) -> (Int, Int)? {
        let (dx, dy) = TrekGame.vector(course: course)
        var x = Double(sx), y = Double(sy)
        for _ in 0..<Int((warp * 8).rounded()) {
            x += dx; y += dy
            let ix = Int(x.rounded()), iy = Int(y.rounded())
            guard (0..<8).contains(ix), (0..<8).contains(iy) else { return nil }
            if sector[iy][ix] != .empty && sector[iy][ix] != .ship { return (ix, iy) }
        }
        return nil
    }

    func torpedoCourse(to x: Int, _ y: Int) -> Double {
        TrekGame.course(dx: Double(x - sx), dy: Double(y - sy))
    }

    private func checkDocked() {
        docked = false
        for y in max(0, sy - 1)...min(7, sy + 1) {
            for x in max(0, sx - 1)...min(7, sx + 1) where sector[y][x] == .base {
                docked = true
            }
        }
        if docked {
            energy = maxEnergy
            torpedoes = maxTorpedoes
            if shields > 0 { say("Shields dropped for docking purposes.", .info) }
            shields = 0
            let wasDamaged = damage.contains { $0 < 0 }
            damage = damage.map { _ in 0 }
            lifeReserve = 5
            say("DOCKED — energy and torpedoes replenished\(wasDamaged ? ", all systems repaired" : "").", .good)
            Sound.shared.play(.chirp)
        }
    }

    private func setFX(_ f: FX) {
        fx = f
        fxTime = Date()
    }

    // MARK: Klingon action

    /// Klingons in Senior manoeuvre before they fire.
    private func klingonsManeuver() {
        for i in klingons.indices {
            guard Double.random(in: 0..<1) < 0.45 else { continue }
            let k = klingons[i]
            // close in when strong, back off when hurt
            let toward = k.energy > k.maxEnergy * 0.4
            var best = (k.x, k.y)
            var bestScore = toward ? distance(to: k) : -distance(to: k)
            for dy in -1...1 { for dx in -1...1 {
                let nx = k.x + dx, ny = k.y + dy
                guard (0..<8).contains(nx), (0..<8).contains(ny), sector[ny][nx] == .empty else { continue }
                let d = hypot(Double(nx - sx), Double(ny - sy))
                guard d >= 2.5 else { continue }
                let score = toward ? d : -d
                if score < bestScore - 0.1 { best = (nx, ny); bestScore = score }
            } }
            if best != (k.x, k.y) {
                sector[k.y][k.x] = .empty
                sector[best.1][best.0] = .klingon
                klingons[i].x = best.0; klingons[i].y = best.1
            }
        }
    }

    private func klingonsFire() {
        guard !klingons.isEmpty, outcome == nil else { return }
        if docked { say("Starbase shields protect the Constellation.", .good); return }
        var shooters: [(Int, Int)] = []
        for i in klingons.indices where klingons[i].energy > 0 {
            let k = klingons[i]
            let h = (k.energy / max(1.5, distance(to: k))) * (2 + Double.random(in: 0..<1))
            shields -= h
            klingons[i].energy = k.energy / (3 + Double.random(in: 0..<1)) + k.maxEnergy * 0.05
            shooters.append((k.x, k.y))
            say("\(fmt(h, 0)) unit hit on Constellation from sector \(k.x + 1),\(k.y + 1)  (shields \(fmt(max(0, shields), 0)))", .bad)
            if shields < 0 {
                outcome = .lost("The Constellation has been destroyed by Klingon fire.")
                setFX(.explosion(sx, sy))
                Sound.shared.play(.explosion)
                return
            }
            if h >= 20, Double.random(in: 0..<1) < 0.6, h / max(1, shields) > 0.02 {
                let s = Sys.allCases.randomElement()!
                damage[s.rawValue] -= h / max(1, shields) + 0.5 * Double.random(in: 0..<1)
                say("Damage control: \(s.name) damaged by the hit.", .bad)
                if s == .lifeSupport { say("WARNING: life support failing — \(fmt(lifeReserve)) stardates of reserves.", .alert) }
            }
        }
        if !shooters.isEmpty {
            setFX(.enemyFire(shooters))
            Sound.shared.play(.hit)
        }
    }

    /// Time passes: repairs, life support, the clock.
    private func passTime(_ t: Double) {
        stardate += t
        var repaired: [String] = []
        for i in damage.indices where damage[i] < 0 {
            let rate = working(.damageControl) || i == Sys.damageControl.rawValue ? 1.0 : 0.5
            damage[i] = min(0, damage[i] + t * rate)
            if damage[i] >= 0 { repaired.append(Sys(rawValue: i)!.name) }
        }
        if !repaired.isEmpty { say("Damage control: \(repaired.joined(separator: ", ")) repaired.", .good) }
        if !working(.lifeSupport) && !docked {
            lifeReserve -= t
            if lifeReserve <= 0 {
                outcome = .lost("Life support reserves exhausted. The crew of the Constellation is lost.")
                return
            }
            say("Life support reserves: \(fmt(max(0, lifeReserve))) stardates.", .alert)
        } else if working(.lifeSupport) {
            lifeReserve = min(5, lifeReserve + t)
        }
        if daysLeft <= 0 && outcome == nil {
            outcome = .lost("Time has run out. \(klingonsLeft) Klingon warships remain in Federation space.")
        }
    }

    private func endTurnCheck() {
        if outcome != nil { return }
        if klingonsLeft == 0 {
            outcome = .won
            return
        }
        if energy + shields < 10 || (energy < 10 && !working(.shields)) {
            outcome = .lost("The Constellation is dead in space — out of energy.")
        }
    }

    // MARK: Commands

    func navigate(course: Double, warp requested: Double) {
        guard outcome == nil else { return }
        let warpMax = working(.warp) ? 8.0 : 0.2
        let warp = min(requested, warpMax)
        if requested > warpMax { say("Warp engines damaged — maximum speed is warp 0.2.", .bad) }
        guard warp > 0 else { return }
        let n = Int((warp * 8).rounded())
        let cost = Double(n + 10)
        guard energy >= cost else {
            say("Engineering: insufficient energy for warp \(fmt(warp)). \(fmt(energy, 0)) available\(shields > 0 ? ", \(fmt(shields, 0)) in shields" : "").", .bad)
            return
        }
        // Klingons get a shot before you can leave
        if !klingons.isEmpty {
            klingonsManeuver()
            klingonsFire()
            if outcome != nil { return }
        }
        let (dx, dy) = TrekGame.vector(course: course)
        sector[sy][sx] = .empty
        var x = Double(sx), y = Double(sy)
        var leftQuadrant = false
        for _ in 0..<n {
            let nx = x + dx, ny = y + dy
            let ix = Int(nx.rounded()), iy = Int(ny.rounded())
            if !(0..<8).contains(ix) || !(0..<8).contains(iy) { leftQuadrant = true; break }
            if sector[iy][ix] != .empty && sector[iy][ix] != .ship {
                say("Warp engines shut down at sector \(Int(x.rounded()) + 1),\(Int(y.rounded()) + 1) — obstacle ahead.", .bad)
                break
            }
            x = nx; y = ny
        }
        energy -= cost
        let time = warp >= 1 ? 1.0 : (warp * 10).rounded() / 10
        if leftQuadrant {
            // galactic jump
            var ax = Double(qx * 8 + sx) + dx * Double(n)
            var ay = Double(qy * 8 + sy) + dy * Double(n)
            var hitEdge = false
            if ax < 0 { ax = 0; hitEdge = true }
            if ay < 0 { ay = 0; hitEdge = true }
            if ax > 63 { ax = 63; hitEdge = true }
            if ay > 63 { ay = 63; hitEdge = true }
            if hitEdge { say("Starfleet denies permission to leave the sector. Stopped at the galactic barrier.", .bad) }
            let nqx = Int(ax.rounded()) / 8, nqy = Int(ay.rounded()) / 8
            let nsx = Int(ax.rounded()) % 8, nsy = Int(ay.rounded()) % 8
            if nqx == qx && nqy == qy {
                sx = nsx; sy = nsy
                if sector[sy][sx] != .empty { (sx, sy) = emptySpot(near: (sx, sy)) }
                sector[sy][sx] = .ship
            } else {
                // Senior: Klingons chase a ship that runs with its shields down
                var followers: [Klingon] = []
                if shields < 200 {
                    for k in klingons where Double.random(in: 0..<1) < 0.5 {
                        followers.append(k)
                    }
                }
                galaxy[qy][qx].klingons -= followers.count
                galaxy[nqy][nqx].klingons += followers.count
                qx = nqx; qy = nqy; sx = nsx; sy = nsy
                say("Warp \(fmt(warp)) to quadrant \(qx + 1),\(qy + 1).", .info)
                Sound.shared.play(.warp)
                setFX(.warp)
                enterQuadrant(followers: followers)
                if !followers.isEmpty { say("\(followers.count) Klingon\(followers.count == 1 ? " has" : "s have") followed you — you ran with your shields down!", .alert) }
                passTime(time)
                randomEvent()
                endTurnCheck()
                return
            }
        } else {
            sx = Int(x.rounded()); sy = Int(y.rounded())
            sector[sy][sx] = .ship
            say("Moved to sector \(sx + 1),\(sy + 1).", .info)
        }
        checkDocked()
        passTime(time)
        randomEvent()
        endTurnCheck()
    }

    private func randomEvent() {
        guard outcome == nil, !docked, Double.random(in: 0..<1) < 0.2 else { return }
        let s = Sys.allCases.randomElement()!
        if Double.random(in: 0..<1) < 0.6 {
            damage[s.rawValue] -= Double.random(in: 1...5)
            say("Damage control report: \(s.name) damaged by an ion storm.", .bad)
        } else if damage[s.rawValue] < 0 {
            damage[s.rawValue] = min(0, damage[s.rawValue] + Double.random(in: 1...3))
            say("Damage control report: \(s.name) state of repair improved.", .good)
        }
    }

    func firePhasers(_ amount: Double) {
        guard outcome == nil else { return }
        guard working(.phasers) else { say("Phaser control is disabled.", .bad); return }
        guard !klingons.isEmpty else { say("Science officer: sensors show no enemy ships in this quadrant.", .info); return }
        let x = min(amount, energy)
        guard x > 0 else { return }
        energy -= x
        let accuracy = working(.computer) ? 1.0 : 0.6
        if !working(.computer) { say("Computer failure hampers accuracy.", .bad) }
        let each = x / Double(klingons.count)
        let targets = klingons.map { ($0.x, $0.y) }
        setFX(.phasers(targets))
        Sound.shared.play(.phaser)
        var survivors: [Klingon] = []
        for var k in klingons {
            let h = (each / max(1, distance(to: k))) * (Double.random(in: 0..<1) + 2) * accuracy
            if h <= 0.15 * k.energy {
                say("Sensors show no damage to enemy at \(k.x + 1),\(k.y + 1).", .info)
                survivors.append(k)
                continue
            }
            k.energy -= h
            if k.energy <= 0 {
                destroyKlingon(k)
            } else {
                say("\(fmt(h, 0)) unit hit on Klingon at \(k.x + 1),\(k.y + 1) — \(fmt(k.energy, 0)) left.", .good)
                survivors.append(k)
            }
        }
        klingons = survivors
        afterCombatAction()
    }

    private func destroyKlingon(_ k: Klingon, delay: Double = 0.25) {
        booms.append((k.x, k.y, Date().addingTimeInterval(delay)))
        if booms.count > 6 { booms.removeFirst() }
        say("*** KLINGON DESTROYED at sector \(k.x + 1),\(k.y + 1) ***", .good)
        sector[k.y][k.x] = .empty
        galaxy[qy][qx].klingons -= 1
        Sound.shared.play(.explosion)
    }

    func fireTorpedo(course: Double) {
        guard outcome == nil else { return }
        guard working(.torpedoes) else { say("Photon tubes are not operational.", .bad); return }
        guard torpedoes > 0 else { say("All photon torpedoes expended.", .bad); return }
        torpedoes -= 1
        Sound.shared.play(.torpedo)
        let (dx, dy) = TrekGame.vector(course: course)
        var x = Double(sx), y = Double(sy)
        var path: [(Double, Double)] = [(x, y)]
        var hit: (Int, Int)?
        while true {
            x += dx; y += dy
            let ix = Int(x.rounded()), iy = Int(y.rounded())
            guard (0..<8).contains(ix), (0..<8).contains(iy) else {
                say("Torpedo missed.", .info); break
            }
            path.append((Double(ix), Double(iy)))
            switch sector[iy][ix] {
            case .klingon:
                if let i = klingons.firstIndex(where: { $0.x == ix && $0.y == iy }) {
                    destroyKlingon(klingons[i], delay: Double(path.count) * 0.09)
                    klingons.remove(at: i)
                }
                hit = (ix, iy)
            case .star:
                say("Star at \(ix + 1),\(iy + 1) absorbed the torpedo energy.", .info)
                hit = (ix, iy)
            case .base:
                say("*** STARBASE DESTROYED *** Starfleet is reviewing your court-martial.", .bad)
                sector[iy][ix] = .empty
                galaxy[qy][qx].bases -= 1
                hit = (ix, iy)
                Sound.shared.play(.explosion)
            default: continue
            }
            break
        }
        setFX(.torpedo(path, hit: hit))
        checkDocked()
        afterCombatAction()
    }

    private func afterCombatAction() {
        if klingonsLeft == 0 { endTurnCheck(); return }
        if !klingons.isEmpty {
            klingonsManeuver()
            klingonsFire()
        }
        endTurnCheck()
    }

    func setShields(_ level: Double) {
        guard outcome == nil else { return }
        guard working(.shields) else { say("Shield control inoperable.", .bad); return }
        let total = energy + shields
        let l = max(0, min(level, total))
        if l == shields { return }
        energy = total - l
        shields = l
        say("Deflector control: shields now at \(fmt(shields, 0)). Main energy \(fmt(energy, 0)).", .good)
        Sound.shared.play(.chirp)
        endTurnCheck()
    }

    /// Classic LRS triples for the 3×3 around the ship; nil when outside the galaxy.
    func longRangeScan() -> [[Int?]] {
        var out: [[Int?]] = []
        for y in (qy - 1)...(qy + 1) {
            var row: [Int?] = []
            for x in (qx - 1)...(qx + 1) {
                if (0..<8).contains(x) && (0..<8).contains(y) {
                    known[y][x] = true
                    row.append(galaxy[y][x].code)
                } else { row.append(nil) }
            }
            out.append(row)
        }
        return out
    }

    func resign() {
        outcome = .lost("You resigned your command. \(klingonsLeft) Klingon warships remain.")
    }

    var rating: Int {
        let killed = Double(totalKlingons - klingonsLeft)
        let used = max(1, stardate - startDate)
        return Int(1000 * killed / used)
    }
}
