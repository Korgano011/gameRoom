import SwiftUI

/// Mission 2: The Doomsday Machine. A decision every turn.
final class Mission2 {
    let ui = TacticalState()

    enum Phase { case response, firstStrike, retreat, starbase, search, found, hunt, done }
    enum Mount { case none, deflector, phasers }

    private var phase: Phase = .response
    private let planets: [(String, RGB)] = [
        ("Rigel VII", RGB(0.6, 0.45, 0.3)), ("Tessen III", RGB(0.35, 0.55, 0.75)), ("Valo II", RGB(0.7, 0.65, 0.45)),
        ("Dorvan V", RGB(0.4, 0.6, 0.35)), ("Kessik IV", RGB(0.75, 0.4, 0.3)), ("Arcadia Colony", RGB(0.3, 0.55, 0.85)),
    ]
    private var target = 0
    /// Turns between planets consumed: 4, then 3 from level 3 on.
    private let consumeEvery = Difficulty.level >= 3 ? 3 : 4
    private lazy var clock = consumeEvery
    private var lost: [String] = []
    private var podsRescued = 0
    private var intel = false
    private var strikeTurns = 0
    private var retreatTurnsLeft = 0
    private var patched = false
    private var restocked = false
    private var progress = 0.0
    private var ferengiOffered = false
    private var copernicusCrew = false
    private var mount: Mount = .none
    private var rayCharge = 100.0
    private var weakened = 0
    private var pk = 100.0
    private var evasive = false
    private var lured = false

    init() {
        ui.missionTitle = "Mission 2 · The Doomsday Machine" + Difficulty.tag
        ui.enemy = .planetKiller
        ui.enemyName = "Planet killer"
        ui.enemyRange = 0.2
        ui.cutscene = skipIntros ? nil : Story.mission2Intro
        ui.say("Red alert. Course laid in for the Exeter's last position.", LCARS.red)
        refresh()
    }

    // MARK: shared bookkeeping

    private var currentPlanet: (String, RGB) { planets[min(target, planets.count - 1)] }

    private func refresh() {
        ui.enemyHealth = pk
        ui.enemyWeakened = weakened > 0
        let p = currentPlanet
        ui.planet = target < planets.count ? (p.0, Double(consumeEvery - clock) / Double(consumeEvery) * 0.35, p.1) : nil
        var s: [(label: String, value: String, color: Color)] = [
            ("NEXT PLANET", target < planets.count ? p.0 : "—", .white),
            ("CONSUMED IN", "\(clock) turn\(clock == 1 ? "" : "s")", clock <= 1 ? LCARS.red : .white),
            ("PLANETS LOST", "\(lost.count)", lost.isEmpty ? LCARS.green : LCARS.red),
            ("TORPEDOES", "\(ui.ship.torpedoes)", .white),
        ]
        if mount != .none {
            s.append(("DISRUPTOR RAY", rayCharge >= 100 ? "READY" : "\(Int(rayCharge))%", rayCharge >= 100 ? LCARS.green : LCARS.gold))
            if weakened > 0 { s.append(("HULL WEAKENED", "\(weakened) turn\(weakened == 1 ? "" : "s")", LCARS.lilac)) }
        }
        if podsRescued > 0 { s.append(("EXETER SURVIVORS", "\(podsRescued)", LCARS.green)) }
        ui.stats = s
        buildChoices()
    }

    /// The machine keeps eating while you work.
    private func machineAdvances(paused: Bool = false) {
        guard target < planets.count, !paused else { return }
        clock -= 1
        if clock <= 1 && clock > 0 { ui.alert("Long-range sensors: the machine is closing on \(currentPlanet.0).") }
        if clock <= 0 {
            let name = currentPlanet.0
            lost.append(name)
            ui.alert("\(name) has been consumed by the planet killer.")
            Sound.shared.play(.explosion)
            target += 1
            clock = consumeEvery
            if target >= planets.count {
                ui.outcome = .lost("The planet killer has devoured the Arcadia Colony and its two million people.")
            }
        }
    }

    private func endTurn(machinePaused: Bool = false) {
        ui.turn += 1
        machineAdvances(paused: machinePaused)
        ui.ship.energy = min(100, ui.ship.energy + 8)
        if ui.ship.hull <= 0 && ui.outcome == nil {
            ui.outcome = .lost(ui.ship.separated ? "The stardrive section has been destroyed." : "The Constellation has been destroyed.")
        }
        refresh()
    }

    private func machineFires(_ base: ClosedRange<Double>, saucerBias: Double = 0.5, delay: Double = 0.9) -> Double {
        var dmg = Double.random(in: base) * Difficulty.power
        if evasive {
            if Double.random(in: 0..<1) < 0.45 { ui.good("Evasive pattern — the antiproton beam misses!"); evasive = false; return 0 }
            dmg *= 0.5
        }
        evasive = false
        let hull = ui.hitShip(dmg, saucerBias: saucerBias)
        ui.bad("Antiproton beam strikes us — \(Int(dmg)) damage\(hull > 0 ? ", \(Int(hull)) through to the hull" : ", shields holding").")
        ui.addFX(.enemyBeam, delay)
        ui.addFX(.hitUs, delay + 0.2)
        return dmg
    }

    // MARK: choices

    private func buildChoices() {
        guard ui.outcome == nil else { ui.choices = []; return }
        switch phase {
        case .response: responseChoices()
        case .firstStrike: firstStrikeChoices()
        case .retreat: retreatChoices()
        case .starbase: starbaseChoices()
        case .search: searchChoices()
        case .found: foundChoices()
        case .hunt: huntChoices()
        case .done: ui.choices = []
        }
    }

    private func responseChoices() {
        ui.phase = "Responding to the Exeter"
        ui.objective = "The Exeter has been abandoned. The machine is heading into the Rigel colonies. How do you go in?"
        ui.choices = [
            Choice(title: "Maximum warp, straight in", detail: "Get there fast. No time to study it.", icon: "bolt.fill", tint: LCARS.orange) { [self] in
                ui.play([(.warp, 0)])
                ui.say("Warp 9.5. We arrive while the Exeter's escape pods are still in range.")
                strikeTurns = 0
                beginFirstStrike()
            },
            Choice(title: "Warp 7 with long-range scans", detail: "Arrive later, but learn what we're facing.", icon: "dot.radiowaves.left.and.right", tint: LCARS.blue) { [self] in
                ui.play([(.warp, 0)])
                intel = true
                ui.good("Science: the hull is solid neutronium. Phasers and torpedoes will be useless. Its beam is pure antiprotons.")
                ui.say("We should keep our shields strong and not waste ordnance.")
                machineAdvances()
                beginFirstStrike()
            },
            Choice(title: "Hail Starfleet for the Exeter's logs", detail: "Their sensor logs may show a weakness.", icon: "antenna.radiowaves.left.and.right", tint: LCARS.lilac) { [self] in
                ui.speak("Starfleet", "The Exeter's final log shows every weapon failed. Its beam targets the largest energy source in range.")
                intel = true
                ui.ship.maxShields = 100
                beginFirstStrike()
            },
        ]
    }

    private func beginFirstStrike() {
        phase = .firstStrike
        ui.enemyRange = 0.75
        ui.alert("The planet killer comes about to face us.")
        endTurn(machinePaused: true)
    }

    private func firstStrikeChoices() {
        ui.phase = "First contact with the planet killer"
        ui.objective = intel
            ? "Our weapons won't hurt it. Save who you can and decide when to break off."
            : "A machine the size of a moon. Stop it."
        ui.choices = [
            Choice(title: "Fire all phasers", detail: "Full spread at the maw.", icon: "scope", tint: LCARS.red, enabled: ui.ship.energy >= 10) { [self] in
                ui.ship.energy -= 10
                ui.play([(.phaser, 0)])
                ui.bad("Phasers strike the hull — no effect. It's solid neutronium.")
                firstStrikeEnemyTurn()
            },
            Choice(title: "Photon torpedo spread", detail: "Three torpedoes into the maw.", icon: "flame.fill", tint: LCARS.red, enabled: ui.ship.torpedoes >= 3) { [self] in
                ui.ship.torpedoes -= 3
                ui.play([(.torpedo, 0)])
                ui.bad("Three direct hits — the detonations don't even scorch it.")
                firstStrikeEnemyTurn()
            },
            Choice(title: "Rescue the Exeter's escape pods", detail: "Tractor in survivors while it's focused on us.", icon: "lifepreserver", tint: LCARS.green) { [self] in
                let n = Int.random(in: 28...64)
                podsRescued += n
                ui.play([(.transporter, 0)])
                ui.good("\(n) Exeter crew beamed aboard from the escape pods.")
                firstStrikeEnemyTurn(saucerBias: 0.9)
            },
            Choice(title: "Evasive pattern Delta", detail: "Make it work for every hit.", icon: "arrow.triangle.swap", tint: LCARS.blue) { [self] in
                evasive = true
                ui.say("Helm throws the ship into an evasive spiral.")
                firstStrikeEnemyTurn()
            },
            Choice(title: "Break off now", detail: "Run for Starbase 11 before it lands a full hit.", icon: "arrow.uturn.backward", tint: LCARS.tan, enabled: strikeTurns >= 1) { [self] in
                ui.say("Hard about! Full impulse!")
                saucerCrippled()
            },
        ]
    }

    private func firstStrikeEnemyTurn(saucerBias: Double = 0.85) {
        strikeTurns += 1
        _ = machineFires(intel ? 10...16 : 14...22, saucerBias: saucerBias)
        if strikeTurns >= 3 || ui.ship.saucer < 35 {
            saucerCrippled()
        } else {
            endTurn(machinePaused: true)
        }
    }

    /// Scripted: the saucer takes the full force of the beam.
    private func saucerCrippled() {
        ui.ship.saucer = min(ui.ship.saucer, max(12, ui.ship.saucer - (intel ? 38 : 48)))
        ui.ship.shields = max(0, ui.ship.shields - 30)
        ui.play([(.enemyBeam, 0), (.hitUs, 0.2)])
        ui.alert("Heavy damage to the saucer section! Decks 4 through 11 venting!")
        phase = .retreat
        retreatTurnsLeft = 0
        ui.cutscene = Story.mission2FirstTry
        ui.enemyRange = 0.35
        endTurn(machinePaused: true)
    }

    private func retreatChoices() {
        ui.phase = "Limping to Starbase 11"
        ui.objective = "The saucer is crippled. Every turn you spend, the machine moves on to its next world."
        if retreatTurnsLeft > 0 {
            ui.choices = [
                Choice(title: "Hold warp 6", detail: "One more turn to Starbase 11.", icon: "arrow.right", tint: LCARS.orange) { [self] in
                    ui.play([(.warp, 0)])
                    arriveStarbase()
                },
                Choice(title: "Damage control teams to the saucer", detail: "Shore up the hull on the way (+10 saucer).", icon: "wrench.and.screwdriver.fill", tint: LCARS.gold) { [self] in
                    ui.ship.saucer = min(100, ui.ship.saucer + 10)
                    ui.good("Emergency bulkheads hold. Saucer integrity improving.")
                    arriveStarbase()
                },
            ]
            return
        }
        ui.choices = [
            Choice(title: "Warp 6 — safe and steady", detail: "Two turns to the starbase. No strain on the hull.", icon: "tortoise.fill", tint: LCARS.blue) { [self] in
                ui.play([(.warp, 0)])
                ui.say("Warp 6. The saucer's spaceframe groans, but holds.")
                ui.enemy = .none
                retreatTurnsLeft = 1
                endTurn()
            },
            Choice(title: "Warp 8 — push her", detail: "One turn, but the saucer may buckle.", icon: "hare.fill", tint: LCARS.orange) { [self] in
                ui.play([(.warp, 0)])
                if Double.random(in: 0..<1) < 0.45 {
                    ui.ship.saucer = max(5, ui.ship.saucer - 10)
                    ui.ship.drive = max(5, ui.ship.drive - 6)
                    ui.bad("Structural stress! The saucer loses another deck before we drop out of warp.")
                } else {
                    ui.good("She holds together. Starbase 11 dead ahead.")
                }
                arriveStarbase()
            },
            Choice(title: "Stay and keep rescuing pods", detail: "Risky: one more pass for Exeter survivors, then run.", icon: "lifepreserver", tint: LCARS.green) { [self] in
                let n = Int.random(in: 15...40)
                podsRescued += n
                ui.play([(.transporter, 0)])
                ui.good("\(n) more survivors aboard.")
                _ = machineFires(12...20, saucerBias: 0.3)
                endTurn()
            },
        ]
    }

    private func arriveStarbase() {
        phase = .starbase
        ui.enemy = .none
        ui.backdrop = .starbase
        ui.ship.shields = ui.ship.maxShields
        ui.ship.energy = 100
        ui.good("Docked at Starbase 11. Shields and energy restored.")
        if podsRescued > 0 { ui.good("\(podsRescued) Exeter survivors transferred to the starbase infirmary.") }
        ui.cutscene = Story.mission2Starbase
        endTurn()
    }

    private func starbaseChoices() {
        ui.phase = "Starbase 11"
        ui.objective = "The saucer stays for repairs. Each turn docked, the machine keeps eating. Prepare the stardrive — then separate and go."
        ui.choices = [
            Choice(title: "Separate the saucer and depart", detail: "Leave the saucer for repairs. Take the stardrive to the Mutara Nebula.", icon: "square.split.2x1.fill", tint: LCARS.orange) { [self] in
                ui.ship.separated = true
                ui.cutscene = Story.mission2Separation
                ui.play([(.warp, 1.0)])
                ui.good("Saucer separation complete. The stardrive section is away.")
                phase = .search
                ui.backdrop = .nebula
                endTurn()
            },
            Choice(title: "Patch the stardrive hull", detail: "Spacedock crews add +30 stardrive integrity. Costs a turn.", icon: "hammer.fill", tint: LCARS.gold, enabled: !patched && ui.ship.drive < 100) { [self] in
                patched = true
                ui.ship.drive = min(100, ui.ship.drive + 30)
                ui.good("Stardrive hull reinforced.")
                endTurn()
            },
            Choice(title: "Restock photon torpedoes", detail: "Fill the magazines to 30. Costs a turn.", icon: "shippingbox.fill", tint: LCARS.red, enabled: !restocked) { [self] in
                restocked = true
                ui.ship.torpedoes = 30
                ui.good("Torpedo magazines full: 30.")
                endTurn()
            },
            Choice(title: "Upgrade the shield emitters", detail: "Fit antiproton-tuned emitters: shields absorb more. Costs a turn.", icon: "shield.lefthalf.filled", tint: LCARS.blue, enabled: ui.ship.maxShields < 130) { [self] in
                ui.ship.maxShields = 130
                ui.ship.shields = 130
                ui.good("Shield emitters retuned to antiproton frequencies.")
                endTurn()
            },
        ]
    }

    private static let searchPool: [(String, String, String)] = [
        ("Follow the Copernicus's ion trail", "Slow but sure.", "point.topleft.down.to.point.bottomright.curvepath"),
        ("Tachyon sweep of the nebula core", "Fast — but nebula discharges can hit us.", "waveform.path.ecg"),
        ("Launch a probe spread", "Safe. Covers a little ground.", "paperplane.fill"),
        ("Scan for the emergency beacon", "Could be nothing, could be everything.", "dot.radiowaves.right"),
        ("Shortcut through the ion storm", "Big leap forward — the storm will batter the hull.", "cloud.bolt.fill"),
        ("Board the drifting freighter", "It may have seen the Copernicus.", "shippingbox.circle"),
    ]

    private func searchChoices() {
        ui.phase = "Searching the Mutara Nebula"
        ui.objective = "Find the Copernicus and the disruptor ray. Search progress: \(Int(min(100, progress)))%."
        var picks = Mission2.searchPool.shuffled().prefix(3).map { $0 }
        if !ferengiOffered && ui.turn % 2 == 0 { picks[2] = ("Hail the Ferengi trader", "DaiMon Gral claims he knows where the Copernicus is.", "bubble.left.and.bubble.right.fill") }
        ui.choices = picks.map { p in
            Choice(title: p.0, detail: p.1, icon: p.2, tint: LCARS.blue) { [self] in search(p.0) }
        }
        ui.choices.append(Choice(title: "Divert power to shields", detail: "Recharge shields +35 while sensors keep sweeping (+8%).", icon: "shield.fill", tint: LCARS.lilac) { [self] in
            ui.ship.shields = min(ui.ship.maxShields, ui.ship.shields + 35)
            progress += 8
            ui.good("Shields recharged.")
            afterSearch()
        })
    }

    private func search(_ what: String) {
        switch what {
        case "Follow the Copernicus's ion trail":
            let g = Double.random(in: 20...32); progress += g
            ui.say("The ion trail bends deeper into the nebula. (+\(Int(g))%)")
        case "Tachyon sweep of the nebula core":
            let g = Double.random(in: 25...45); progress += g
            ui.say("The tachyon pulse lights up the nebula core. (+\(Int(g))%)")
            if Double.random(in: 0..<1) < 0.5 {
                let d = Double.random(in: 10...22)
                ui.hitShip(d, saucerBias: 0)
                ui.bad("A nebula discharge arcs across the stardrive — \(Int(d)) damage.")
                ui.play([(.hitUs, 0)])
            }
        case "Launch a probe spread":
            let g = Double.random(in: 14...24); progress += g
            ui.say("Probes report back from four sectors. (+\(Int(g))%)")
        case "Scan for the emergency beacon":
            let g = Double.random(in: 0...50); progress += g
            ui.say(g < 12 ? "Nothing but static. (+\(Int(g))%)" : "A faint Starfleet beacon pattern! (+\(Int(g))%)")
        case "Shortcut through the ion storm":
            let g = Double.random(in: 35...50); progress += g
            let d = Double.random(in: 10...18)
            ui.ship.drive = max(1, ui.ship.drive - d)
            ui.bad("The ion storm hammers the hull — \(Int(d)) stardrive damage. (+\(Int(g))%)")
            ui.play([(.hitUs, 0)])
        case "Board the drifting freighter":
            ui.play([(.transporter, 0)])
            if Double.random(in: 0..<1) < 0.5 {
                progress += 45
                ui.good("The freighter's logs show the Copernicus fleeing toward the nebula's eye! (+45%)")
            } else {
                ui.bad("The freighter is empty — and its reactor goes critical as we beam back.")
                ui.hitShip(10, saucerBias: 0)
            }
        default: // Ferengi
            ferengiOffered = true
            ui.speak("DaiMon Gral", "Coordinates for six of your photon torpedoes. A bargain, Captain.")
            ui.choices = [
                Choice(title: "Pay him: six torpedoes", detail: "Torpedoes you may need against the machine.", icon: "dollarsign.circle.fill", tint: LCARS.gold, enabled: ui.ship.torpedoes >= 6) { [self] in
                    ui.ship.torpedoes -= 6
                    progress += 50
                    ui.good("The coordinates check out. (+50%)")
                    afterSearch()
                },
                Choice(title: "Refuse and scan his ship instead", detail: "His sensor logs might give it away anyway.", icon: "eye.fill", tint: LCARS.blue) { [self] in
                    let g = Double.random(in: 5...30); progress += g
                    ui.say("Gral cuts the channel, but we caught part of his sensor log. (+\(Int(g))%)")
                    afterSearch()
                },
            ]
            return
        }
        afterSearch()
    }

    private func afterSearch() {
        if progress >= 100 {
            phase = .found
            ui.good("Contact! The U.S.S. Copernicus, adrift with her engines dark. Life signs: 23.")
        }
        endTurn()
    }

    private func foundChoices() {
        ui.phase = "The Copernicus"
        ui.objective = "The disruptor ray prototype is intact. Install it — the planet killer is already moving on \(currentPlanet.0)."
        var c: [Choice] = [
            Choice(title: "Mount it on the main deflector", detail: "Stronger ray (weakens the hull 4 turns, recharges fast), but max shields drop.", icon: "dot.circle.and.hand.point.up.left.fill", tint: LCARS.lilac) { [self] in
                install(.deflector)
            },
            Choice(title: "Mount it on the phaser array", detail: "Weaker ray (3 turns, slower recharge). Shields stay at full strength.", icon: "scope", tint: LCARS.red) { [self] in
                install(.phasers)
            },
        ]
        if !copernicusCrew {
            c.insert(Choice(title: "Beam the Copernicus crew aboard first", detail: "23 lives. Costs a turn.", icon: "person.3.fill", tint: LCARS.green) { [self] in
                copernicusCrew = true
                ui.play([(.transporter, 0)])
                ui.good("All 23 Copernicus crew safely aboard.")
                endTurn()
            }, at: 0)
        }
        ui.choices = c
    }

    private func install(_ m: Mount) {
        mount = m
        rayCharge = 100
        if m == .deflector {
            ui.ship.maxShields = max(60, ui.ship.maxShields - 35)
            ui.ship.shields = min(ui.ship.shields, ui.ship.maxShields)
        }
        ui.good("Disruptor ray installed on the \(m == .deflector ? "main deflector" : "phaser array"). Charged and ready.")
        phase = .hunt
        ui.backdrop = .space
        ui.enemy = .planetKiller
        ui.enemyRange = 0.8
        ui.play([(.warp, 0)])
        ui.alert("Intercept course. The planet killer is bearing down on \(currentPlanet.0).")
        endTurn()
    }

    // MARK: the hunt

    private func huntChoices() {
        ui.phase = "Stop the planet killer"
        ui.objective = weakened > 0
            ? "The neutronium is destabilized for \(weakened) more turn\(weakened == 1 ? "" : "s") — hit it with everything!"
            : "Its hull is impervious until the disruptor ray weakens it."
        let rayReady = rayCharge >= 100
        var c: [Choice] = [
            Choice(title: "Fire the disruptor ray", detail: rayReady ? "Destabilize the neutronium hull." : "Recharging — \(Int(rayCharge))%.", icon: "rays", tint: LCARS.lilac, enabled: rayReady && ui.ship.energy >= 20) { [self] in
                fireRay()
            },
            Choice(title: "Fire phasers", detail: weakened > 0 ? "It's vulnerable — maximum power." : "Useless against intact neutronium.", icon: "scope", tint: LCARS.red, enabled: ui.ship.energy >= 12) { [self] in
                firePhasers()
            },
            Choice(title: "Photon torpedo spread", detail: weakened > 0 ? "Three torpedoes into the weakened hull." : "Will do nothing unless the hull is weakened.", icon: "flame.fill", tint: LCARS.red, enabled: ui.ship.torpedoes >= 3) { [self] in
                fireTorpedoes()
            },
            Choice(title: "Lure it away from \(currentPlanet.0)", detail: "Draw its fire so it can't feed this turn.", icon: "arrow.left.and.right", tint: LCARS.gold) { [self] in
                lured = true
                ui.say("We sweep across its bow. The machine turns to follow us — away from \(currentPlanet.0).")
                huntEnemyTurn()
            },
            Choice(title: "Divert power to shields", detail: "Shields +40 and the ray charges faster this turn.", icon: "shield.fill", tint: LCARS.blue) { [self] in
                ui.ship.shields = min(ui.ship.maxShields, ui.ship.shields + 40)
                rayCharge += 15
                ui.good("Shields reinforced.")
                huntEnemyTurn()
            },
            Choice(title: "Evasive maneuvers", detail: "Good chance its next beam misses.", icon: "arrow.triangle.swap", tint: LCARS.tan) { [self] in
                evasive = true
                ui.say("Evasive pattern Omega.")
                huntEnemyTurn()
            },
        ]
        if weakened > 0 && pk <= 45 {
            c.insert(Choice(title: "Eject the warp core into its maw", detail: "Decker's gambit. It will finish the machine — and leave us dead in space.", icon: "exclamationmark.triangle.fill", tint: LCARS.gold) { [self] in
                warpCoreGambit()
            }, at: 0)
        }
        ui.choices = c
    }

    private func fireRay() {
        rayCharge = 0
        ui.ship.energy -= 20
        weakened = mount == .deflector ? 4 : 3
        pk = max(0, pk - 5)
        ui.play([(.ray, 0), (.hitEnemy, 0.8)])
        ui.good("Disruptor ray on target! The neutronium lattice is destabilizing — its hull is vulnerable!")
        huntEnemyTurn(fromRay: true)
    }

    private func firePhasers() {
        ui.ship.energy -= 12
        if weakened > 0 {
            let d = Double.random(in: 13...20)
            pk = max(0, pk - d / Difficulty.power)
            ui.play([(.phaser, 0), (.hitEnemy, 0.4)])
            ui.good("Phasers burn into the weakened hull — \(Int(d))% damage!")
        } else {
            ui.play([(.phaser, 0)])
            ui.bad("Phasers splash off the neutronium. No effect.")
        }
        huntEnemyTurn()
    }

    private func fireTorpedoes() {
        ui.ship.torpedoes -= 3
        if weakened > 0 {
            let d = Double.random(in: 20...30)
            pk = max(0, pk - d / Difficulty.power)
            ui.play([(.torpedo, 0), (.hitEnemy, 0.7)])
            ui.good("Three torpedoes detonate inside the weakened hull — \(Int(d))% damage!")
        } else {
            ui.play([(.torpedo, 0)])
            ui.bad("The torpedoes detonate harmlessly against the neutronium.")
        }
        huntEnemyTurn()
    }

    private func warpCoreGambit() {
        pk = 0
        ui.ship.energy = 0
        ui.ship.shields = 0
        ui.play([(.torpedo, 0), (.enemyDestroyed, 0.8)])
        ui.good("The warp core tumbles into the maw… and detonates. The planet killer is tearing itself apart!")
        win(gambit: true)
    }

    private func huntEnemyTurn(fromRay: Bool = false) {
        if pk <= 0 {
            ui.addFX(.enemyDestroyed, 0.9)
            win(gambit: false)
            return
        }
        let rate = mount == .deflector ? 40.0 : 28.0
        if !fromRay { rayCharge = min(100, rayCharge + rate) }
        if weakened > 0 && !fromRay { weakened -= 1 }
        ui.enemyRange = lured ? 0.95 : 0.8
        _ = machineFires(lured ? 14...24 : 10...20, saucerBias: 0, delay: 1.0)
        let paused = lured
        lured = false
        endTurn(machinePaused: paused)
    }

    private func win(gambit: Bool) {
        phase = .done
        ui.enemyHealth = 0
        let saved = planets.count - lost.count
        var lines = ["The planet killer is destroyed. \(saved) of \(planets.count) worlds saved."]
        if podsRescued > 0 { lines.append("\(podsRescued) Exeter survivors rescued.") }
        if copernicusCrew { lines.append("The Copernicus crew are safe.") }
        if gambit { lines.append("The stardrive drifts without a core until Starbase 11 tows her home.") }
        lines.append("Completed in \(ui.turn + 1) turns.")
        ui.summary = lines.joined(separator: "\n")
        ui.winShots = Story.mission2Won
        ui.turn += 1
        ui.choices = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [self] in ui.outcome = .won }
    }
}

struct Mission2View: View {
    let onExit: (Bool) -> Void
    @State private var mission = Mission2()

    var body: some View {
        TacticalView(ui: mission.ui, onExit: onExit) { mission = Mission2() }
            .id(ObjectIdentifier(mission))
    }
}
