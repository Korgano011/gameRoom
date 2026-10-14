import SwiftUI
import Observation

struct Choice: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    var tint: Color = LCARS.orange
    var enabled = true
    let run: () -> Void
}

struct ShipState {
    var saucer = 100.0
    var drive = 100.0
    var shields = 100.0
    var maxShields = 100.0
    var energy = 100.0
    var torpedoes = 24
    var separated = false

    var hull: Double { separated ? drive : min(saucer, drive) }
}

enum EnemyKind { case none, planetKiller, borgCube }
enum Backdrop { case space, nebula, starbase }

enum TacFX {
    case phaser, torpedo, ray, enemyBeam, cuttingBeam, tractor, hitEnemy, hitUs, transporter, warp, enemyDestroyed
}

struct TacLog: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

/// Everything the tactical screen shows. Each decision mission drives one of these.
@Observable
final class TacticalState {
    enum Outcome: Equatable { case won, lost(String) }

    var missionTitle = ""
    var phase = ""
    var objective = ""
    var turn = 0
    var log: [TacLog] = []
    var choices: [Choice] = []
    var ship = ShipState()
    var enemy: EnemyKind = .none
    var enemyName = ""
    var enemyHealth = 100.0
    var enemyRange = 0.5          // 0 far … 1 point blank
    var enemyWeakened = false
    var backdrop: Backdrop = .space
    var planet: (name: String, eaten: Double, color: RGB)?
    var stats: [(label: String, value: String, color: Color)] = []
    var cutscene: [Shot]?
    var winShots: [Shot] = []
    var playingOutro = false
    var outcome: Outcome?
    var summary = ""
    var fx: [(kind: TacFX, delay: Double)] = []
    var fxTime = Date()

    func say(_ s: String, _ c: Color = Color(white: 0.88)) {
        log.append(TacLog(text: s, color: c))
        if log.count > 60 { log.removeFirst(log.count - 60) }
    }
    func good(_ s: String) { say(s, LCARS.green) }
    func bad(_ s: String) { say(s, LCARS.peach) }
    func alert(_ s: String) { say(s, LCARS.red) }
    func speak(_ who: String, _ s: String) { say("\(who): “\(s)”", LCARS.lilac) }

    func play(_ list: [(TacFX, Double)]) {
        fx = list.map { (kind: $0.0, delay: $0.1) }
        fxTime = Date()
        for (k, d) in list {
            if let effect = sound(for: k) {
                DispatchQueue.main.asyncAfter(deadline: .now() + d) { Sound.shared.play(effect) }
            }
        }
    }

    /// Adds an effect to the current volley (starts a new volley if the last one is over).
    func addFX(_ k: TacFX, _ delay: Double) {
        if Date().timeIntervalSince(fxTime) > 0.3 {
            fx = []
            fxTime = Date()
        }
        let start = delay + Date().timeIntervalSince(fxTime)
        fx.append((kind: k, delay: start))
        if let e = sound(for: k) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { Sound.shared.play(e) }
        }
    }

    private func sound(for k: TacFX) -> Sound.Effect? {
        switch k {
        case .phaser: .phaser
        case .torpedo: .torpedo
        case .ray: .ray
        case .enemyBeam, .cuttingBeam: .hit
        case .transporter: .transporter
        case .warp: .warp
        case .enemyDestroyed: .explosion
        case .tractor, .hitEnemy, .hitUs: nil
        }
    }

    /// Damage to shields first, then hull. Returns hull damage taken.
    @discardableResult
    func hitShip(_ amount: Double, saucerBias: Double = 0.5) -> Double {
        var dmg = amount
        if ship.shields > 0 {
            let absorbed = min(ship.shields, dmg * 0.8)
            ship.shields -= absorbed
            dmg -= absorbed
        }
        guard dmg > 0 else { return 0 }
        if ship.separated {
            ship.drive = max(0, ship.drive - dmg)
        } else if Double.random(in: 0..<1) < saucerBias {
            ship.saucer = max(0, ship.saucer - dmg)
        } else {
            ship.drive = max(0, ship.drive - dmg)
        }
        return dmg
    }
}

// MARK: - View

struct TacticalView: View {
    let ui: TacticalState
    let onExit: (Bool) -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 10) {
                    header
                    sceneView
                    statusPanel
                    phasePanel
                    choiceList
                    logView
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            if let o = ui.outcome, ui.cutscene == nil { outcomeOverlay(o) }
        }
        .fullScreenCoverCompat(isPresented: Binding(get: { ui.cutscene != nil }, set: { if !$0 { ui.cutscene = nil } })) {
            if let shots = ui.cutscene {
                CutsceneView(shots: shots) {
                    let outro = ui.playingOutro
                    ui.cutscene = nil
                    if outro { onExit(true) }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button { onExit(false) } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .black))
                    .frame(width: 44, height: 30)
                    .background(UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 15).fill(LCARS.orange))
            }
            .foregroundStyle(.black)
            Text(ui.missionTitle.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).frame(height: 30)
                .background(LCARS.lilac)
                .foregroundStyle(.black)
            Text("TURN \(ui.turn)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .frame(width: 76, height: 30)
                .background(UnevenRoundedRectangle(bottomTrailingRadius: 15, topTrailingRadius: 15).fill(LCARS.blue))
                .foregroundStyle(.black)
        }
        .padding(.top, 6)
    }

    // MARK: scene

    private var sceneView: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let s = min(size.width / 400, size.height / 200)
                var c = ctx
                c.translateBy(x: (size.width - 400 * s) / 2, y: (size.height - 200 * s) / 2)
                c.scaleBy(x: s, y: s)
                drawTactical(c, now: tl.date)
            }
        }
        .aspectRatio(2, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LCARS.blue.opacity(0.6), lineWidth: 1.5))
    }

    private func drawTactical(_ ctx: GraphicsContext, now: Date) {
        let size = CGSize(width: 400, height: 200)
        let t = now.timeIntervalSinceReferenceDate
        let age = now.timeIntervalSince(ui.fxTime)
        func active(_ k: TacFX, _ dur: Double) -> Double? {
            for f in ui.fx where f.kind == k {
                let u = (age - f.delay) / dur
                if u >= 0 && u <= 1 { return u }
            }
            return nil
        }
        var ctx = ctx
        if let u = active(.hitUs, 0.5) { ctx.translateBy(x: CGFloat(sin(u * 60) * 4 * (1 - u)), y: 0) }
        drawStarfield(ctx, size: size, t: t, speed: active(.warp, 1.2) != nil ? 3 : 0.3, streak: active(.warp, 1.2).map { 1 - $0 } ?? 0)
        if ui.backdrop == .nebula { drawNebula(ctx, size: size, t: t) }
        if ui.backdrop == .starbase { drawStarbase(ctx, at: CGPoint(x: 330, y: 100), scale: 0.75, t: t) }

        let ship = CGPoint(x: 105, y: 108)
        let damage = ui.ship.separated ? max(0, 1 - ui.ship.drive / 100) : max(0, 1 - ui.ship.saucer / 100)
        if ui.ship.shields > 0, let u = active(.hitUs, 0.6) {
            ctx.stroke(Path(ellipseIn: CGRect(x: ship.x - 90, y: ship.y - 40, width: 170, height: 75)), with: .color(LCARS.blue.opacity(1 - u)), lineWidth: 3)
        }
        drawConstellation(ctx, at: ship, scale: 0.75, damage: damage, t: t, saucer: !ui.ship.separated)

        var enemyPoint = CGPoint(x: 310, y: 100)
        if let p = ui.planet {
            drawPlanet(ctx, at: CGPoint(x: 372, y: 160), r: 26, base: p.color, eaten: p.eaten, t: t)
            ctx.draw(Text(p.name.uppercased()).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(LCARS.peach), at: CGPoint(x: 372, y: 193))
        }
        let scale = CGFloat(0.45 + ui.enemyRange * 0.45)
        switch ui.enemy {
        case .planetKiller:
            enemyPoint = CGPoint(x: 300 + (1 - CGFloat(ui.enemyRange)) * 30, y: 95)
            if active(.enemyDestroyed, 2.5) == nil || age < 0.5 + (ui.fx.first { $0.kind == .enemyDestroyed }?.delay ?? 0) {
                drawPlanetKiller(ctx, at: enemyPoint, scale: scale, t: t, weakened: ui.enemyWeakened)
            }
        case .borgCube:
            enemyPoint = CGPoint(x: 300 + (1 - CGFloat(ui.enemyRange)) * 30, y: 100)
            if ui.outcome != .won { drawBorgCube(ctx, at: enemyPoint, size: 60 + CGFloat(ui.enemyRange) * 70, t: t, damage: 1 - ui.enemyHealth / 100) }
        case .none: break
        }
        let maw = CGPoint(x: enemyPoint.x - 55 * scale, y: enemyPoint.y)
        let fire = CGPoint(x: ship.x + 30, y: ship.y - 8)
        if let u = active(.phaser, 0.7) { beam(ctx, from: fire, to: enemyPoint, color: .orange, width: 2.5, alpha: 1 - u) }
        if let u = active(.ray, 1.2) {
            beam(ctx, from: CGPoint(x: ship.x + 18, y: ship.y + 12), to: enemyPoint, color: Color(red: 0.75, green: 0.35, blue: 1), width: 5 + CGFloat(sin(u * 30)) * 2, alpha: 1 - u * 0.6)
        }
        if let u = active(.torpedo, 0.8) {
            for k in 0..<3 {
                let uu = min(1, max(0, u * 1.3 - Double(k) * 0.12))
                let p = CGPoint(x: fire.x + (enemyPoint.x - fire.x) * uu, y: fire.y + (enemyPoint.y - fire.y) * uu + CGFloat(k - 1) * 6 * (1 - uu))
                if uu < 1 { ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .radialGradient(Gradient(colors: [.white, Color(red: 0.4, green: 0.6, blue: 1), .clear]), center: p, startRadius: 0, endRadius: 5)) }
            }
        }
        if let u = active(.enemyBeam, 0.8) { beam(ctx, from: maw, to: ship, color: Color(red: 1, green: 0.5, blue: 0.1), width: 6, alpha: 1 - u * 0.5) }
        if let u = active(.cuttingBeam, 0.8) { beam(ctx, from: enemyPoint, to: CGPoint(x: ship.x + 10, y: ship.y), color: Color(red: 0.3, green: 1, blue: 0.4), width: 3, alpha: 1 - u * 0.5) }
        if let u = active(.tractor, 1.2) {
            var p = Path()
            p.move(to: CGPoint(x: enemyPoint.x - 30, y: enemyPoint.y - 10)); p.addLine(to: CGPoint(x: ship.x + 20, y: ship.y - 25))
            p.addLine(to: CGPoint(x: ship.x + 20, y: ship.y + 25)); p.addLine(to: CGPoint(x: enemyPoint.x - 30, y: enemyPoint.y + 10)); p.closeSubpath()
            ctx.fill(p, with: .color(Color.green.opacity(0.25 * (1 - u))))
        }
        if let u = active(.hitEnemy, 0.9) { drawExplosion(ctx, at: CGPoint(x: enemyPoint.x - 10, y: enemyPoint.y + 4), r: 22, u: u) }
        if let u = active(.hitUs, 0.9) { drawExplosion(ctx, at: CGPoint(x: ship.x + 10, y: ship.y - 4), r: 18, u: u) }
        if let u = active(.transporter, 1.4) {
            for k in 0..<24 {
                let x = ship.x + 20 + (enemyPoint.x - ship.x - 20) * CGFloat(hash01(k, 3))
                let y = ship.y - 20 + CGFloat(hash01(k, 4)) * 40 + CGFloat(sin(u * 10 + Double(k))) * 4
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)), with: .color(Color(red: 0.7, green: 0.85, blue: 1).opacity(sin(u * .pi))))
            }
        }
        if let u = active(.enemyDestroyed, 2.5) {
            for k in 0..<5 { drawExplosion(ctx, at: CGPoint(x: enemyPoint.x - 40 + CGFloat(k) * 22, y: enemyPoint.y + CGFloat(hash01(k, 7) - 0.5) * 40), r: 40, u: u * 1.4 - Double(k) * 0.08) }
        }
    }

    // MARK: status

    private var statusPanel: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 5) {
                    if !ui.ship.separated {
                        meter("SAUCER", ui.ship.saucer, 100, ui.ship.saucer < 35 ? LCARS.red : LCARS.peach)
                    } else {
                        HStack {
                            Text("SAUCER").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(LCARS.peach)
                            Spacer()
                            Text("SEPARATED").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(LCARS.blue)
                        }
                    }
                    meter("STARDRIVE", ui.ship.drive, 100, ui.ship.drive < 35 ? LCARS.red : LCARS.peach)
                    meter("SHIELDS", ui.ship.shields, 100, LCARS.blue)
                    meter("ENERGY", ui.ship.energy, 100, LCARS.gold)
                }
                VStack(spacing: 5) {
                    if ui.enemy != .none {
                        meter(ui.enemyName.uppercased(), ui.enemyHealth, 100, ui.enemyWeakened ? LCARS.lilac : LCARS.red)
                    }
                    ForEach(Array(ui.stats.enumerated()), id: \.offset) { _, s in
                        HStack {
                            Text(s.label).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(LCARS.peach).lineLimit(1).fixedSize()
                            Spacer(minLength: 4)
                            Text(s.value).font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(s.color).lineLimit(1).minimumScaleFactor(0.55)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(LCARS.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LCARS.orange.opacity(0.5), lineWidth: 1))
    }

    private func meter(_ k: String, _ v: Double, _ maxV: Double, _ c: Color) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(k).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(LCARS.peach).lineLimit(1)
                Spacer()
                Text("\(Int(v.rounded()))%").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(c).frame(width: g.size.width * min(1, max(0, v / maxV)))
                        .animation(.easeOut(duration: 0.5), value: v)
                }
            }
            .frame(height: 6)
        }
    }

    private var phasePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ui.phase.uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(LCARS.orange)
            Text(ui.objective)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var choiceList: some View {
        VStack(spacing: 8) {
            Text("CAPTAIN — YOUR ORDERS?")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(LCARS.lilac)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(ui.choices) { c in
                Button {
                    Sound.shared.play(.beep)
                    c.run()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: c.icon)
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(c.tint))
                            .foregroundStyle(.black)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            Text(c.detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(c.tint.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.tint.opacity(0.7), lineWidth: 1.2))
                    .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .disabled(!c.enabled || ui.outcome != nil)
                .opacity(c.enabled ? 1 : 0.4)
            }
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(ui.log) { l in
                        Text(l.text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(l.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(l.id)
                    }
                }
                .padding(8)
            }
            .frame(height: 170)
            .background(RoundedRectangle(cornerRadius: 12).fill(LCARS.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LCARS.peach.opacity(0.4), lineWidth: 1))
            .onChange(of: ui.log.count) { _, _ in
                if let last = ui.log.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func outcomeOverlay(_ o: TacticalState.Outcome) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(o == .won ? "MISSION ACCOMPLISHED" : "MISSION FAILED")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(o == .won ? LCARS.gold : LCARS.red)
                Group {
                    if case .lost(let why) = o { Text(why) } else { Text(ui.summary) }
                }
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                if o == .won {
                    bigButton("CONTINUE", LCARS.gold) {
                        let shots = ui.winShots
                        ui.winShots = []
                        if shots.isEmpty { onExit(true) } else { ui.playingOutro = true; ui.cutscene = shots }
                    }
                } else {
                    bigButton("TRY AGAIN", LCARS.orange) { onRetry() }
                    bigButton("RETURN TO MISSIONS", LCARS.lilac) { onExit(false) }
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 22).fill(LCARS.panel).stroke(LCARS.orange, lineWidth: 2))
            .padding(24)
        }
    }

    private func bigButton(_ title: String, _ c: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(c))
                .foregroundStyle(.black)
        }
    }
}

extension View {
    /// Full-screen cover on iOS, a sheet elsewhere.
    @ViewBuilder
    func fullScreenCoverCompat<C: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> C) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}
