import SwiftUI

/// Mission 3: Resistance. Rescue the Halcyon's crew from a Borg cube; a decision every turn.
final class Mission3 {
    let ui = TacticalState()

    private let frequencies = ["1.2 GHz", "2.7 GHz", "4.1 GHz", "5.6 GHz", "7.3 GHz", "8.9 GHz"]
    private var freq = 0
    private var phaserAdapt: [Int] = Array(repeating: 0, count: 6)
    private var torpAdapt = 0
    private var shieldMod = 0
    private var remods = 0
    private var cube = 100.0
    private var countdown = max(16, 24 - 2 * (Difficulty.level - 1))
    private var close = false
    private var pursuit = 0
    private var rescued = 0
    private var teamPrepped = false
    private var vinculumHit = false
    private var evasive = false
    private var repairs = 0
    private var done = false

    init() {
        ui.missionTitle = "Mission 3 · Resistance" + Difficulty.tag
        ui.enemy = .borgCube
        ui.enemyName = "Borg cube"
        ui.enemyRange = 0.15
        ui.ship.torpedoes = 20
        ui.cutscene = skipIntros ? nil : Story.mission3Intro
        ui.alert("The cube is at warp 9.9 toward the Vega colony, the Halcyon locked inside it.")
        refresh()
    }

    private var hullCritical: Bool {
        ui.ship.separated ? ui.ship.drive < 40 : (ui.ship.saucer < 40 || ui.ship.drive < 40)
    }

    private func effectiveness(_ uses: Int) -> Double { max(0, 1 - Double(uses) * 0.34) }

    private func refresh() {
        ui.enemyHealth = cube
        var s: [(label: String, value: String, color: Color)] = [
            ("VEGA COLONY IN", "\(countdown) turn\(countdown == 1 ? "" : "s")", countdown <= 4 ? LCARS.red : .white),
            ("HALCYON CREW", "\(rescued)/6 SAVED", rescued == 6 ? LCARS.green : LCARS.gold),
            ("PHASERS", "\(frequencies[freq]) \(Int(effectiveness(phaserAdapt[freq]) * 100))%", effectiveness(phaserAdapt[freq]) < 0.5 ? LCARS.red : LCARS.green),
            ("SHIELD MOD", shieldMod > 0 ? "\(shieldMod) turn\(shieldMod == 1 ? "" : "s")" : "ADAPTED", shieldMod > 0 ? LCARS.green : LCARS.red),
            ("QUANTUM TORPS", "\(ui.ship.torpedoes)", .white),
        ]
        if !close { s.append(("RANGE", "PURSUIT", LCARS.peach)) }
        ui.stats = s
        buildChoices()
    }

    private func endTurn() {
        guard !done else { return }
        ui.turn += 1
        countdown -= 1
        cube = min(100, cube + Double(Difficulty.level))   // Borg regeneration, faster each level
        if shieldMod > 0 { shieldMod -= 1; if shieldMod == 0 { ui.bad("The Borg have adapted to our shield modulation.") } }
        ui.ship.energy = min(100, ui.ship.energy + 10)
        if ui.ship.hull <= 0 {
            ui.outcome = .lost(ui.ship.separated ? "The stardrive section has been destroyed. The Halcyon's crew remain drones." : "The Constellation has been destroyed by the Borg.")
        } else if countdown <= 0 {
            ui.outcome = .lost("The cube reached the Vega colony. Nine hundred thousand more voices join the Collective.")
        } else if countdown == 3 {
            ui.alert("Three turns until the cube reaches Vega!")
        }
        if hullCritical && ui.outcome == nil { ui.alert("Hull integrity critical — consider returning to starbase or separating the saucer.") }
        refresh()
    }

    // MARK: Borg response

    private func borgTurn(droppedShields: Bool = false) {
        guard close else { return }
        var dmg = Double.random(in: 13...22) * (1 + (100 - cube) / 400) * Difficulty.power
        if shieldMod > 0 && !droppedShields { dmg *= 0.35 }
        if ui.ship.separated { dmg *= 0.8 }
        if evasive {
            evasive = false
            if Double.random(in: 0..<1) < 0.4 {
                ui.good("Evasive maneuvers — the cutting beam sweeps past us.")
                return
            }
            dmg *= 0.6
        }
        var savedShields = 0.0
        if droppedShields { savedShields = ui.ship.shields; ui.ship.shields = 0 }
        let hull = ui.hitShip(dmg, saucerBias: 0.55)
        if droppedShields { ui.ship.shields = savedShields }
        ui.bad("Borg cutting beam — \(Int(dmg)) damage\(hull > 0 ? ", \(Int(hull)) to the hull" : "").")
        ui.addFX(.cuttingBeam, 1.0)
        ui.addFX(.hitUs, 1.2)
        if Double.random(in: 0..<1) < 0.25 {
            ui.addFX(.tractor, 1.5)
            let drain = Double.random(in: 8...15)
            ui.ship.energy = max(0, ui.ship.energy - drain)
            ui.bad("Tractor beam! The Borg drain \(Int(drain))% of our energy before we break free.")
        }
    }

    // MARK: choices

    private func buildChoices() {
        guard ui.outcome == nil, !done else { ui.choices = []; return }
        if !close { pursuitChoices() } else { combatChoices() }
        if hullCritical {
            ui.choices.insert(Choice(title: "Return to Starbase 74", detail: "Full repairs and rejoin the saucer — costs 3 turns, and the cube regenerates.", icon: "cross.case.fill", tint: LCARS.green, enabled: repairs < 2) { [self] in
                returnToStarbase()
            }, at: 0)
            if !ui.ship.separated {
                ui.choices.insert(Choice(title: "Separate the saucer section", detail: "The saucer warps clear with the civilians. The stardrive fights on — smaller, faster, harder to hit.", icon: "square.split.2x1.fill", tint: LCARS.orange) { [self] in
                    separate()
                }, at: 1)
            }
        }
    }

    private func pursuitChoices() {
        ui.phase = "Pursuit"
        ui.objective = "The cube is ahead of us at transwarp. Catch it before it reaches the Vega colony."
        ui.choices = [
            Choice(title: "Pursue at maximum warp", detail: "Warp 9.9 — redline the engines.", icon: "bolt.fill", tint: LCARS.orange) { [self] in
                pursuit += Int.random(in: 1...2)
                ui.play([(.warp, 0)])
                ui.say("Warp 9.9. Engineering reports the core at 112%.")
                if Double.random(in: 0..<1) < 0.3 { ui.ship.drive = max(1, ui.ship.drive - 5); ui.bad("A plasma conduit ruptures in engineering.") }
                checkCatch()
            },
            Choice(title: "Plot an intercept through the Typhon Expanse", detail: "Cut the corner — risky subspace eddies, but a chance to cut it off.", icon: "point.topleft.down.to.point.bottomright.curvepath", tint: LCARS.blue) { [self] in
                ui.play([(.warp, 0)])
                if Double.random(in: 0..<1) < 0.55 {
                    pursuit += 3
                    ui.good("The shortcut pays off — we come out of the Expanse right on its tail!")
                } else {
                    pursuit += 1
                    ui.hitShip(10)
                    ui.bad("Subspace eddies batter the hull. We lost ground.")
                }
                checkCatch()
            },
            Choice(title: "Remodulate shields in advance", detail: "Shields enter combat already tuned against the Borg (3 turns).", icon: "shield.lefthalf.filled", tint: LCARS.lilac, enabled: shieldMod == 0) { [self] in
                shieldMod = 4; remods += 1
                pursuit += 1
                ui.good("Shield harmonics randomized. The Borg will need time to adapt.")
                checkCatch()
            },
            Choice(title: "Brief the away team", detail: "Train for a rescue on the cube — better odds later.", icon: "person.3.fill", tint: LCARS.green, enabled: !teamPrepped) { [self] in
                teamPrepped = true
                pursuit += 1
                ui.good("Lt. Okoro's security team drills on the Halcyon's deck plans. Rescue odds improved.")
                checkCatch()
            },
        ]
    }

    private func checkCatch() {
        if pursuit >= 3 {
            close = true
            ui.enemyRange = 0.85
            ui.alert("We've caught the cube! Dropping out of warp — it's turning to engage.")
            ui.speak("The Borg", "Constellation. Your vessel will be assimilated. Resistance is futile.")
            Sound.shared.play(.alert)
        } else {
            ui.enemyRange = min(0.6, 0.15 + Double(pursuit) * 0.15)
        }
        endTurn()
    }

    private func combatChoices() {
        ui.phase = "Battle with the cube"
        ui.objective = rescued < 6
            ? "Rescue the Halcyon's crew and destroy the cube. Watch the Borg adapt — vary your tactics."
            : "All six women are safe aboard. Destroy the cube."
        let eff = effectiveness(phaserAdapt[freq])
        var c: [Choice] = [
            Choice(title: "Fire phasers (\(frequencies[freq]))", detail: eff >= 0.66 ? "Full effect at this frequency." : eff > 0 ? "The Borg are adapting — reduced effect." : "The Borg have fully adapted to this frequency.", icon: "scope", tint: LCARS.red, enabled: ui.ship.energy >= 12) { [self] in
                firePhasers()
            },
            Choice(title: "Rotate phaser frequency", detail: "Switch to an untried frequency. Shore up shields while engineering retunes (+15).", icon: "dial.medium.fill", tint: LCARS.gold) { [self] in
                rotate()
            },
            Choice(title: "Quantum torpedo volley", detail: "Two quantum torpedoes. The Borg adapt to these slowly.", icon: "flame.fill", tint: LCARS.red, enabled: ui.ship.torpedoes >= 2) { [self] in
                fireTorpedoes()
            },
            Choice(title: "Remodulate shields", detail: shieldMod > 0 ? "Shields still effective (\(shieldMod) turns)." : "Cut the cutting beam's damage until they adapt again.", icon: "shield.lefthalf.filled", tint: LCARS.lilac) { [self] in
                shieldMod = max(2, 4 - remods); remods += 1
                ui.good("Shields remodulated — \(shieldMod) turns before they adapt.")
                borgTurn()
                endTurn()
            },
            Choice(title: "Evasive maneuvers", detail: "Make the cube work to hit us.", icon: "arrow.triangle.swap", tint: LCARS.tan) { [self] in
                evasive = true
                ui.say("Helm: evasive pattern Sierra.")
                borgTurn()
                endTurn()
            },
        ]
        if rescued < 6 {
            let chance = rescueChance
            c.insert(Choice(title: "Beam the away team onto the cube", detail: "Drop shields to transport. Rescue chance \(Int(chance * 100))% — the cube gets a clean shot at us.", icon: "person.wave.2.fill", tint: LCARS.green) { [self] in
                rescue()
            }, at: 0)
        }
        if cube <= 60 && !vinculumHit {
            c.insert(Choice(title: "Target the vinculum", detail: "Sensors have found the cube's central plexus. One massive strike.", icon: "target", tint: LCARS.orange, enabled: ui.ship.torpedoes >= 4) { [self] in
                vinculum()
            }, at: rescued < 6 ? 1 : 0)
        }
        ui.choices = c
    }

    private var rescueChance: Double {
        var c = 0.55
        if teamPrepped { c += 0.15 }
        if cube < 50 { c += 0.15 }
        if cube < 25 { c += 0.15 }
        return min(0.95, c)
    }

    private func firePhasers() {
        ui.ship.energy -= 12
        let eff = effectiveness(phaserAdapt[freq])
        phaserAdapt[freq] += 1
        let d = Double.random(in: 12...18) * eff
        cube = max(0, cube - d)
        ui.play([(.phaser, 0)] + (d > 0 ? [(.hitEnemy, 0.4)] : []))
        if d <= 0 {
            ui.bad("The phaser beams splash harmlessly off the cube's shields — the Borg have adapted to \(frequencies[freq]).")
        } else {
            ui.good("Phasers carve into the cube — \(Int(d))% damage.\(phaserAdapt[freq] >= 2 ? " Their shields are adapting." : "")")
        }
        afterAttack()
    }

    private func rotate() {
        let fresh = phaserAdapt.indices.filter { $0 != freq }.min { phaserAdapt[$0] < phaserAdapt[$1] } ?? 0
        freq = fresh
        ui.ship.shields = min(ui.ship.maxShields, ui.ship.shields + 15)
        ui.say("Phasers retuned to \(frequencies[freq]). Shields reinforced.")
        borgTurn()
        endTurn()
    }

    private func fireTorpedoes() {
        ui.ship.torpedoes -= 2
        let eff = max(0.3, 1 - Double(torpAdapt) * 0.15)
        torpAdapt += 1
        let d = Double.random(in: 18...26) * eff
        cube = max(0, cube - d)
        ui.play([(.torpedo, 0), (.hitEnemy, 0.7)])
        ui.good("Quantum torpedoes impact — \(Int(d))% damage.")
        afterAttack()
    }

    private func vinculum() {
        vinculumHit = true
        ui.ship.torpedoes -= 4
        let d = Double.random(in: 28...36)
        cube = max(0, cube - d)
        ui.play([(.torpedo, 0), (.hitEnemy, 0.6), (.hitEnemy, 0.9)])
        ui.good("Direct hit on the vinculum! Drones all over the cube go still — \(Int(d))% damage!")
        afterAttack()
    }

    private func rescue() {
        ui.play([(.transporter, 0)])
        if Double.random(in: 0..<1) < rescueChance {
            let n = min(6 - rescued, cube < 25 ? 3 : Int.random(in: 2...3))
            let names = halcyonCrew[rescued..<(rescued + n)].map { "\($0.designation) — \($0.rank) \($0.name)" }
            rescued += n
            ui.good("Away team reports: we have them! \(names.joined(separator: "; ")). Sickbay is severing their link to the Collective.")
            if rescued == 6 { ui.good("All six women of the Halcyon are aboard!") }
        } else {
            let d = Double.random(in: 5...10)
            ui.ship.drive = max(1, ui.ship.drive - d)
            ui.bad("The drones adapted to our transporter frequency — the away team is forced back empty-handed.")
        }
        borgTurn(droppedShields: true)
        endTurn()
    }

    private func afterAttack() {
        if cube <= 0 {
            win()
            return
        }
        borgTurn()
        endTurn()
    }

    private func separate() {
        ui.ship.separated = true
        ui.play([(.warp, 0.4)])
        ui.good("Saucer separation! The saucer section warps clear with every civilian aboard.")
        ui.say("The stardrive section comes about — lighter, faster, and still fighting.")
        borgTurn()
        endTurn()
    }

    private func returnToStarbase() {
        repairs += 1
        ui.play([(.warp, 0)])
        ui.ship.saucer = max(ui.ship.saucer, 85)
        ui.ship.drive = max(ui.ship.drive, 85)
        ui.ship.shields = ui.ship.maxShields
        ui.ship.energy = 100
        ui.ship.torpedoes = max(ui.ship.torpedoes, 14)
        if ui.ship.separated { ui.ship.separated = false; ui.good("The saucer section rejoins at Starbase 74.") }
        ui.good("Starbase 74 crews patch the hull and reload torpedoes.")
        countdown -= 2      // plus the normal turn below = 3 turns
        cube = min(100, cube + 15)
        phaserAdapt = phaserAdapt.map { max(0, $0 - 1) }
        close = false
        pursuit = 1
        ui.enemyRange = 0.3
        ui.bad("While we were gone the cube regenerated, and gained ground on Vega.")
        endTurn()
    }

    private func win() {
        done = true
        ui.play([(.enemyDestroyed, 0.5)])
        ui.enemyHealth = 0
        ui.choices = []
        var lines = ["The Borg cube is destroyed with \(countdown) turns to spare."]
        lines.append(rescued == 6 ? "All six Halcyon crew rescued!" : "\(rescued) of 6 Halcyon crew rescued.")
        if ui.ship.separated { lines.append("The saucer section rejoins at Starbase 74.") }
        lines.append("Completed in \(ui.turn + 1) turns.")
        ui.summary = lines.joined(separator: "\n")
        ui.winShots = Story.mission3Won(rescued: rescued)
        ui.turn += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [self] in ui.outcome = .won }
    }
}

struct Mission3View: View {
    let onExit: (Bool) -> Void
    @State private var mission = Mission3()

    var body: some View {
        TacticalView(ui: mission.ui, onExit: onExit) { mission = Mission3() }
            .id(ObjectIdentifier(mission))
    }
}
