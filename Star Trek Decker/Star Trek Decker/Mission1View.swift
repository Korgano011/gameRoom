import SwiftUI

struct Mission1View: View {
    let onExit: (Bool) -> Void
    @State private var game = TrekGame()
    @State private var mode: Mode = .nav
    @State private var course = 1.0
    @State private var warp = 1.0
    @State private var torpCourse = 1.0
    @State private var phaserEnergy = 300.0
    @State private var shieldLevel = 500.0
    @State private var selected: (x: Int, y: Int)?
    @State private var lrs: [[Int?]]?
    @State private var cutscene: Cutscene?
    @State private var started = false

    private enum Cutscene: Identifiable {
        case intro, victory
        var id: Self { self }
    }
    @State private var showHelp = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    enum Mode: String, CaseIterable { case nav = "NAV", srs = "SRS", lrs = "LRS", pha = "PHA", tor = "TOR", she = "SHE", dam = "DAM", com = "COM", xxx = "XXX" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 10) {
                    header
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 10) {
                            scanner.frame(width: 420, height: 420)
                            VStack(spacing: 10) { status; commandGrid; panel }
                                .frame(maxWidth: 420)
                        }
                    } else {
                        VStack(spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                scanner.aspectRatio(1, contentMode: .fit)
                                status.frame(width: 128)
                            }
                            commandGrid
                            panel
                        }
                    }
                    logView
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            if let o = game.outcome, cutscene == nil { outcomeOverlay(o) }
        }
        .fullScreenCoverCompat(isPresented: Binding(get: { cutscene != nil }, set: { if !$0 { cutscene = nil } })) {
            switch cutscene {
            case .intro:
                CutsceneView(shots: Story.mission1Intro(klingons: game.totalKlingons, days: Int(game.totalDays), bases: game.totalBases)) { cutscene = nil }
            case .victory:
                CutsceneView(shots: Story.mission1Won) {
                    cutscene = nil
                    onExit(true)
                }
            case nil:
                EmptyView()
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            if !skipIntros { cutscene = .intro }
        }
        .sheet(isPresented: $showHelp) { Mission1Help() }
        .onChange(of: game.outcome) { _, o in
            if o == .won { Sound.shared.play(.chirp) }
        }
    }

    // MARK: header & status

    private var header: some View {
        HStack(spacing: 6) {
            Button { onExit(false) } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .black))
                    .frame(width: 44, height: 30)
                    .background(UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 15).fill(LCARS.orange))
            }
            .foregroundStyle(.black)
            Text("U.S.S. CONSTELLATION  NCC-1017-A")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).frame(height: 30)
                .background(LCARS.lilac)
                .foregroundStyle(.black)
            Button { showHelp = true } label: {
                Image(systemName: "questionmark").font(.system(size: 15, weight: .black))
                    .frame(width: 44, height: 30)
                    .background(UnevenRoundedRectangle(bottomTrailingRadius: 15, topTrailingRadius: 15).fill(LCARS.blue))
            }
            .foregroundStyle(.black)
        }
        .padding(.top, 6)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 3) {
            stat("STARDATE", game.fmt(game.stardate))
            stat("DAYS LEFT", game.fmt(game.daysLeft))
            HStack {
                Text("COND").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(LCARS.peach)
                Spacer()
                Text(game.condition).font(.system(size: 12, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(conditionColor))
                    .foregroundStyle(.black)
            }
            stat("QUADRANT", "\(game.qx + 1),\(game.qy + 1)")
            stat("SECTOR", "\(game.sx + 1),\(game.sy + 1)")
            bar("ENERGY", game.energy, game.maxEnergy, LCARS.gold)
            bar("SHIELDS", game.shields, 1500, LCARS.blue)
            stat("TORPEDOES", "\(game.torpedoes)")
            stat("KLINGONS", "\(game.klingonsLeft)")
            if !game.working(.lifeSupport) {
                stat("LIFE RES", game.fmt(game.lifeReserve)).foregroundStyle(LCARS.red)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(LCARS.panel))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LCARS.orange.opacity(0.6), lineWidth: 1))
    }

    private var conditionColor: Color {
        switch game.condition {
        case "RED": return LCARS.red
        case "YELLOW": return LCARS.gold
        case "DOCKED": return LCARS.blue
        default: return LCARS.green
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(LCARS.peach).lineLimit(1).fixedSize()
            Spacer(minLength: 2)
            Text(v).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func bar(_ k: String, _ v: Double, _ maxV: Double, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            stat(k, game.fmt(v, 0))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(c).frame(width: g.size.width * min(1, max(0, v / maxV)))
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: short range scanner

    private var scanner: some View {
        GeometryReader { g in
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    drawScanner(ctx, size: size, now: tl.date)
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { v in tapScanner(v.location, size: g.size) })
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LCARS.blue.opacity(0.7), lineWidth: 1.5))
    }

    private func tapScanner(_ p: CGPoint, size: CGSize) {
        let cell = size.width / 8
        let x = Int(p.x / cell), y = Int(p.y / cell)
        guard (0..<8).contains(x), (0..<8).contains(y), game.working(.srs) else { return }
        selected = (x, y)
        Sound.shared.play(.beep)
        guard game.working(.computer) else {
            game.say("Library computer offline — enter course manually.", .bad)
            return
        }
        guard x != game.sx || y != game.sy else { return }
        let nav = game.navTo(sectorX: x, y: y)
        let target = game.sector[y][x]
        if target == .klingon {
            torpCourse = game.torpedoCourse(to: x, y)
            mode = .tor
        } else {
            course = nav.course
            // stop one sector short of anything solid (docking next to a starbase)
            warp = target == .empty ? nav.warp : max(0.125, nav.warp - 0.125)
            mode = .nav
            warnObstacle()
        }
    }

    private func drawScanner(_ ctx: GraphicsContext, size: CGSize, now: Date) {
        let cell = size.width / 8
        let t = now.timeIntervalSinceReferenceDate
        let fxAge = now.timeIntervalSince(game.fxTime)
        var ctx = ctx
        if case .enemyFire = game.fx, fxAge < 0.4 {
            ctx.translateBy(x: CGFloat(sin(fxAge * 80) * 4), y: 0)
        }
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.01, green: 0.02, blue: 0.06)))
        guard game.working(.srs) else {
            for k in 0..<200 {
                let x = CGFloat(hash01(k, Int(t * 20))) * size.width
                let y = CGFloat(hash01(k + 999, Int(t * 20))) * size.height
                ctx.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.4)))
            }
            ctx.draw(Text("SHORT-RANGE SENSORS\nDAMAGED").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(LCARS.red), at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }
        // faint background stars
        for k in 0..<50 {
            let x = CGFloat(hash01(k, 7)) * size.width, y = CGFloat(hash01(k, 8)) * size.height
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(.white.opacity(0.3)))
        }
        for i in 1..<8 {
            let p = CGFloat(i) * cell
            ctx.stroke(Path { $0.move(to: CGPoint(x: p, y: 0)); $0.addLine(to: CGPoint(x: p, y: size.height)) }, with: .color(LCARS.blue.opacity(0.15)), lineWidth: 0.5)
            ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: p)); $0.addLine(to: CGPoint(x: size.width, y: p)) }, with: .color(LCARS.blue.opacity(0.15)), lineWidth: 0.5)
        }
        for i in 0..<8 {
            ctx.draw(Text("\(i + 1)").font(.system(size: 7, design: .monospaced)).foregroundStyle(LCARS.blue.opacity(0.5)), at: CGPoint(x: CGFloat(i) * cell + cell / 2, y: 5))
            ctx.draw(Text("\(i + 1)").font(.system(size: 7, design: .monospaced)).foregroundStyle(LCARS.blue.opacity(0.5)), at: CGPoint(x: 4, y: CGFloat(i) * cell + cell / 2))
        }
        func center(_ x: Int, _ y: Int) -> CGPoint { CGPoint(x: (CGFloat(x) + 0.5) * cell, y: (CGFloat(y) + 0.5) * cell) }
        func center(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: (CGFloat(x) + 0.5) * cell, y: (CGFloat(y) + 0.5) * cell) }

        if let s = selected {
            ctx.stroke(Path(roundedRect: CGRect(x: CGFloat(s.x) * cell + 2, y: CGFloat(s.y) * cell + 2, width: cell - 4, height: cell - 4), cornerRadius: 4), with: .color(LCARS.gold), lineWidth: 1.5)
        }
        for y in 0..<8 {
            for x in 0..<8 {
                let c = center(x, y)
                switch game.sector[y][x] {
                case .star:
                    let r = cell * 0.16 * CGFloat(1 + 0.12 * sin(t * 3 + Double(x * 8 + y)))
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 2, y: c.y - r * 2, width: r * 4, height: r * 4)), with: .radialGradient(Gradient(colors: [Color.yellow.opacity(0.5), .clear]), center: c, startRadius: 0, endRadius: r * 2))
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(red: 1, green: 0.95, blue: 0.7)))
                case .base:
                    drawStarbase(ctx, at: c, scale: cell / 190, t: t)
                case .klingon:
                    drawKlingon(ctx, at: c, scale: cell / 66, facingLeft: x > game.sx)
                    if let k = game.klingons.first(where: { $0.x == x && $0.y == y }) {
                        let w = cell * 0.7
                        ctx.fill(Path(CGRect(x: c.x - w / 2, y: c.y + cell * 0.32, width: w, height: 2.5)), with: .color(.white.opacity(0.15)))
                        ctx.fill(Path(CGRect(x: c.x - w / 2, y: c.y + cell * 0.32, width: w * CGFloat(max(0, min(1, k.energy / k.maxEnergy))), height: 2.5)), with: .color(LCARS.red))
                    }
                case .ship:
                    if game.shields > 0 {
                        let r = cell * 0.48
                        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.7, width: 2 * r, height: 1.4 * r)), with: .color(LCARS.blue.opacity(0.25 + 0.4 * min(1, game.shields / 1000))), lineWidth: 1.5)
                    }
                    drawConstellation(ctx, at: CGPoint(x: c.x + cell * 0.12, y: c.y + cell * 0.04), scale: cell / 135, t: t)
                case .empty: break
                }
            }
        }
        // effects
        switch game.fx {
        case .phasers(let targets) where fxAge < 0.7:
            for (x, y) in targets {
                beam(ctx, from: center(game.sx, game.sy), to: center(x, y), color: .orange, width: 2, alpha: 1 - fxAge / 0.7)
            }
        case .enemyFire(let shooters) where fxAge < 0.5:
            for (x, y) in shooters {
                beam(ctx, from: center(x, y), to: center(game.sx, game.sy), color: Color(red: 0.4, green: 1, blue: 0.3), width: 1.5, alpha: 1 - fxAge / 0.5)
            }
        case .torpedo(let path, let hit):
            let travel = Double(path.count) * 0.09
            if fxAge < travel, path.count > 1 {
                let f = fxAge / travel * Double(path.count - 1)
                let i = min(path.count - 2, Int(f))
                let u = f - Double(i)
                let a = path[i], b = path[i + 1]
                let p = center(a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .radialGradient(Gradient(colors: [.white, .red, .clear]), center: p, startRadius: 0, endRadius: 5))
            } else if let h = hit {
                drawExplosion(ctx, at: center(h.0, h.1), r: cell * 0.5, u: (fxAge - travel) / 0.8)
            }
        case .explosion(let x, let y):
            drawExplosion(ctx, at: center(x, y), r: cell, u: fxAge / 1.2)
        case .warp where fxAge < 0.6:
            for k in 0..<30 {
                let y = CGFloat(hash01(k, 5)) * size.height
                ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) }, with: .color(.white.opacity(0.4 * (1 - fxAge / 0.6))), lineWidth: 1)
            }
        default: break
        }
        for b in game.booms {
            let u = now.timeIntervalSince(b.at) / 0.9
            if u >= 0 && u <= 1 { drawExplosion(ctx, at: center(b.x, b.y), r: cell * 0.6, u: u) }
        }
    }

    // MARK: commands

    private var commandGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button { choose(m) } label: {
                    VStack(spacing: 0) {
                        Text(m.rawValue).font(.system(size: 15, weight: .black, design: .rounded))
                        Text(label(m)).font(.system(size: 7, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(color(m).opacity(mode == m ? 1 : 0.55)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: mode == m ? 2 : 0))
                    .foregroundStyle(.black)
                }
                .disabled(game.outcome != nil)
            }
        }
    }

    private func label(_ m: Mode) -> String {
        switch m {
        case .nav: return "WARP"
        case .srs: return "SHORT SCAN"
        case .lrs: return "LONG SCAN"
        case .pha: return "PHASERS"
        case .tor: return "TORPEDO"
        case .she: return "SHIELDS"
        case .dam: return "DAMAGE"
        case .com: return "COMPUTER"
        case .xxx: return "RESIGN"
        }
    }

    private func color(_ m: Mode) -> Color {
        switch m {
        case .nav, .srs, .lrs: return LCARS.orange
        case .pha, .tor: return LCARS.red
        case .she: return LCARS.blue
        case .dam, .com: return LCARS.lilac
        case .xxx: return LCARS.tan
        }
    }

    private func choose(_ m: Mode) {
        Sound.shared.play(.beep)
        mode = m
        switch m {
        case .srs:
            if game.working(.srs) {
                game.say("Short-range scan: \(game.klingons.count) Klingon\(game.klingons.count == 1 ? "" : "s"), \(game.quad.bases) starbase\(game.quad.bases == 1 ? "" : "s"), \(game.quad.stars) stars. Condition \(game.condition).", .info)
            } else { game.say("Short-range sensors are out.", .bad) }
        case .lrs:
            lrs = game.working(.lrs) ? game.longRangeScan() : nil
            if lrs == nil { game.say("Long-range sensors are inoperable.", .bad) }
        case .she:
            shieldLevel = game.shields
        case .pha:
            phaserEnergy = min(phaserEnergy, max(0, game.energy))
        default: break
        }
    }

    @ViewBuilder private var panel: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch mode {
            case .nav: navPanel
            case .srs: srsPanel
            case .lrs: lrsPanel
            case .pha: phaserPanel
            case .tor: torpedoPanel
            case .she: shieldPanel
            case .dam: damagePanel
            case .com: computerPanel
            case .xxx: resignPanel
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(LCARS.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color(mode).opacity(0.7), lineWidth: 1.5))
    }

    private func panelTitle(_ s: String) -> some View {
        Text(s).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(color(mode))
    }

    private func actionButton(_ title: String, _ c: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(c))
                .foregroundStyle(.black)
        }
        .disabled(game.outcome != nil)
    }

    /// Buttons on the end-of-mission card (must stay enabled once there's an outcome).
    private func overlayButton(_ title: String, _ c: Color, action: @escaping () -> Void) -> some View {
        Button {
            Sound.shared.play(.beep)
            action()
        } label: {
            Text(title).font(.system(size: 15, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(c))
                .foregroundStyle(.black)
        }
    }

    private var navPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("NAVIGATION — tap a sector, or set course & warp")
            HStack(spacing: 12) {
                CompassView(course: $course).frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("COURSE \(String(format: "%.2f", course))").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    Slider(value: $course, in: 1...8.99, step: 0.05).tint(LCARS.orange)
                    Text("WARP \(warpText)  ·  \(Int((warp * 8).rounded())) sectors  ·  \(Int((warp * 8).rounded()) + 10) energy")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    Slider(value: $warp, in: 0.1...8, step: 0.1).tint(LCARS.gold)
                }
            }
            actionButton("ENGAGE", LCARS.orange) {
                game.navigate(course: course, warp: warp)
                selected = nil
            }
        }
    }

    private var srsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            panelTitle("SHORT-RANGE SENSORS")
            Text("Tap any sector on the scanner. Tapping a Klingon loads a torpedo firing solution; tapping empty space plots a warp course there (Library Computer must be working).")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Label("You", systemImage: "circle.fill").foregroundStyle(.white)
            Label("Klingon", systemImage: "circle.fill").foregroundStyle(LCARS.green)
            Label("Starbase", systemImage: "circle.fill").foregroundStyle(Color(white: 0.75))
            Label("Star", systemImage: "circle.fill").foregroundStyle(.yellow)
        }
        .font(.system(size: 10, weight: .bold))
        .labelStyle(.titleAndIcon)
    }

    private var lrsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelTitle("LONG-RANGE SENSORS — Klingons · Bases · Stars")
            if let lrs {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(0..<3, id: \.self) { r in
                        GridRow {
                            ForEach(0..<3, id: \.self) { c in
                                let v = lrs[r][c]
                                Text(v.map { String(format: "%03d", $0) } ?? "***")
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(r == 1 && c == 1 ? LCARS.blue.opacity(0.35) : Color.white.opacity(0.06)))
                                    .foregroundStyle((v ?? 0) >= 100 ? LCARS.red : (v ?? 0) % 100 >= 10 ? LCARS.blue : .white)
                                    .onTapGesture { if let v, v >= 0, !(r == 1 && c == 1) { plotQuadrant(game.qx + c - 1, game.qy + r - 1) } }
                            }
                        }
                    }
                }
                Text("Tap a neighbouring quadrant to plot a course to it.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            } else {
                Text("LONG-RANGE SENSORS INOPERABLE").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(LCARS.red)
            }
        }
    }

    private func plotQuadrant(_ x: Int, _ y: Int) {
        guard game.working(.computer) else { game.say("Library computer offline.", .bad); return }
        let n = game.navTo(quadrantX: x, y: y)
        course = n.course
        warp = min(8, n.warp)
        mode = .nav
        Sound.shared.play(.beep)
        game.say("Computer: course \(String(format: "%.2f", course)), warp \(warpText) to quadrant \(x + 1),\(y + 1).", .info)
        warnObstacle()
    }

    private var warpText: String { String(format: (warp * 10).rounded() == warp * 10 ? "%.1f" : "%.3f", warp) }

    private func warnObstacle() {
        if let (ox, oy) = game.obstacle(course: course, warp: warp) {
            game.say("Helm: that course runs into an object at sector \(ox + 1),\(oy + 1) — the engines will stop short.", .bad)
        }
    }

    private var phaserPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelTitle("PHASERS — energy is split among all Klingons in the quadrant")
            Text("FIRE \(Int(phaserEnergy)) UNITS  (of \(Int(game.energy)) available)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            Slider(value: $phaserEnergy, in: 0...max(1, game.energy), step: 10).tint(LCARS.red)
            Text("Phasers weaken with distance. Hits under 15% of a ship's energy do nothing.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            actionButton("FIRE PHASERS", LCARS.red) { game.firePhasers(phaserEnergy) }
        }
    }

    private var torpedoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelTitle("PHOTON TORPEDOES — \(game.torpedoes) remaining")
            HStack(spacing: 12) {
                CompassView(course: $torpCourse, tint: LCARS.red).frame(width: 84, height: 84)
                VStack(alignment: .leading) {
                    Text("COURSE \(String(format: "%.2f", torpCourse))").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    Slider(value: $torpCourse, in: 1...8.99, step: 0.05).tint(LCARS.red)
                    Text("Tap a Klingon on the scanner for a firing solution. Stars block torpedoes.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                }
            }
            actionButton("FIRE TORPEDO", LCARS.red) { game.fireTorpedo(course: torpCourse) }
        }
    }

    private var shieldPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelTitle("SHIELD CONTROL")
            Text("SHIELDS \(Int(shieldLevel))  ·  MAIN \(Int(game.energy + game.shields - shieldLevel))").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            Slider(value: $shieldLevel, in: 0...max(1, game.energy + game.shields), step: 10).tint(LCARS.blue)
            Text("If Klingon fire drives the shields below zero, the ship is destroyed. Raise them before you warp into a fight.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            actionButton("SET SHIELDS", LCARS.blue) { game.setShields(shieldLevel) }
        }
    }

    private var damagePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            panelTitle("DAMAGE CONTROL")
            ForEach(TrekGame.Sys.allCases, id: \.self) { s in
                let d = game.damage[s.rawValue]
                HStack {
                    Text(s.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(d >= 0 ? "OPERATIONAL" : "REPAIR \(String(format: "%.1f", -d)) SD")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(d >= 0 ? LCARS.green : LCARS.red)
                }
            }
            if !game.working(.lifeSupport) {
                Text("Life support reserves: \(game.fmt(game.lifeReserve)) stardates — dock at a starbase!").font(.system(size: 12, weight: .bold)).foregroundStyle(LCARS.red)
            }
        }
    }

    private var computerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelTitle("LIBRARY COMPUTER — galactic record")
            if game.working(.computer) {
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    ForEach(0..<8, id: \.self) { y in
                        GridRow {
                            ForEach(0..<8, id: \.self) { x in
                                let here = x == game.qx && y == game.qy
                                let q = game.galaxy[y][x]
                                Text(game.known[y][x] ? String(format: "%03d", q.code) : "···")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(maxWidth: .infinity, minHeight: 24)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(here ? LCARS.gold.opacity(0.5) : Color.white.opacity(0.05)))
                                    .foregroundStyle(game.known[y][x] && q.klingons > 0 ? LCARS.red : game.known[y][x] && q.bases > 0 ? LCARS.blue : .white.opacity(0.8))
                                    .onTapGesture { if !here { plotQuadrant(x, y) } }
                            }
                        }
                    }
                }
                Text("Tap any quadrant to plot a warp course there.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                Divider().background(LCARS.lilac)
                Text("STATUS: \(game.klingonsLeft) Klingons · \(game.basesLeft) starbases · \(game.fmt(game.daysLeft)) stardates left")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                if !game.klingons.isEmpty {
                    Text("TORPEDO DATA").font(.system(size: 11, weight: .heavy)).foregroundStyle(LCARS.red)
                    ForEach(Array(game.klingons.enumerated()), id: \.offset) { _, k in
                        HStack {
                            Text("Klingon \(k.x + 1),\(k.y + 1)  course \(String(format: "%.2f", game.torpedoCourse(to: k.x, k.y)))  dist \(String(format: "%.1f", game.distance(to: k)))")
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white)
                            Spacer()
                            Button("LOAD") {
                                torpCourse = game.torpedoCourse(to: k.x, k.y)
                                selected = (k.x, k.y)
                                mode = .tor
                            }
                            .font(.system(size: 11, weight: .black)).foregroundStyle(.black)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(LCARS.red))
                        }
                    }
                }
            } else {
                Text("LIBRARY COMPUTER INOPERABLE").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(LCARS.red)
            }
        }
    }

    private var resignPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelTitle("ABANDON MISSION")
            Text("Surrender command and end the simulation?").font(.system(size: 13)).foregroundStyle(.white)
            actionButton("RESIGN COMMAND", LCARS.tan) { game.resign() }
        }
    }

    // MARK: log

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(game.log) { line in
                        Text(line.text)
                            .font(.system(size: 12, weight: line.kind == .alert ? .black : .regular, design: .monospaced))
                            .foregroundStyle(logColor(line.kind))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(8)
            }
            .frame(height: 150)
            .background(RoundedRectangle(cornerRadius: 12).fill(LCARS.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LCARS.peach.opacity(0.4), lineWidth: 1))
            .onChange(of: game.log.count) { _, _ in
                if let last = game.log.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func logColor(_ k: TrekGame.LogLine.Kind) -> Color {
        switch k {
        case .info: return Color(white: 0.85)
        case .good: return LCARS.green
        case .bad: return LCARS.peach
        case .alert: return LCARS.red
        case .speech: return LCARS.lilac
        }
    }

    // MARK: outcome

    private func outcomeOverlay(_ o: TrekGame.Outcome) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(o == .won ? "MISSION ACCOMPLISHED" : "MISSION FAILED")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(o == .won ? LCARS.gold : LCARS.red)
                Group {
                    if case .lost(let why) = o { Text(why) } else {
                        Text("All \(game.totalKlingons) Klingon warships destroyed in \(game.fmt(game.stardate - game.startDate)) stardates.\nEfficiency rating: \(game.rating)")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                if o == .won {
                    overlayButton("CONTINUE", LCARS.gold) { cutscene = .victory }
                } else {
                    overlayButton("TRY AGAIN", LCARS.orange) { game.newGame(); selected = nil; cutscene = .intro }
                    overlayButton("RETURN TO MISSIONS", LCARS.lilac) { onExit(false) }
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 22).fill(LCARS.panel).stroke(LCARS.orange, lineWidth: 2))
            .padding(24)
        }
    }
}

/// A small compass that shows (and sets) a classic 1–9 course.
struct CompassView: View {
    @Binding var course: Double
    var tint: Color = LCARS.orange

    var body: some View {
        GeometryReader { g in
            let r = min(g.size.width, g.size.height) / 2
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            ZStack {
                Circle().stroke(tint.opacity(0.5), lineWidth: 2)
                ForEach(1...8, id: \.self) { n in
                    let (dx, dy) = TrekGame.vector(course: Double(n))
                    Text("\(n)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white)
                        .position(x: c.x + dx * (r - 9), y: c.y + dy * (r - 9))
                }
                Path { p in
                    let (dx, dy) = TrekGame.vector(course: course)
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + dx * (r - 18), y: c.y + dy * (r - 18)))
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Circle().fill(tint).frame(width: 8, height: 8).position(c)
            }
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let dx = v.location.x - c.x, dy = v.location.y - c.y
                guard hypot(dx, dy) > 6 else { return }
                course = (TrekGame.course(dx: dx, dy: dy) * 20).rounded() / 20
                if course >= 9 { course = 1 }
            })
        }
    }
}

struct Mission1Help: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Goal") {
                    Text("Destroy every Klingon warship before the stardates run out. The galaxy is 8×8 quadrants; each quadrant is 8×8 sectors.")
                }
                Section("Commands") {
                    row("NAV", "Warp. Course 1 = right, 3 = up, 5 = left, 7 = down (fractions allowed). Warp 1 = one quadrant, 0.1 = one sector. Costs sectors + 10 energy.")
                    row("SRS", "Short-range scan of your quadrant. Tap a sector to plot a course or a torpedo solution.")
                    row("LRS", "Long-range scan: 3-digit codes — Klingons, starbases, stars (e.g. 214).")
                    row("PHA", "Phasers. Energy is divided among every Klingon in the quadrant and weakens with distance.")
                    row("TOR", "Photon torpedo along a course. Destroys a Klingon outright. Stars block it.")
                    row("SHE", "Move energy between main reserves and shields.")
                    row("DAM", "Damage report. Systems repair as stardates pass, or instantly when docked.")
                    row("COM", "Library computer: galactic record, status, torpedo data, course plotting.")
                    row("XXX", "Resign command.")
                }
                Section("Senior rules") {
                    Text("Klingons manoeuvre and fire after every action you take. Run from a fight with shields under 200 and they may chase you into the next quadrant. If life support is damaged you have 5 stardates of reserves to repair it or dock.")
                    Text("Dock by stopping next to a starbase: full energy and torpedoes and every system repaired.")
                }
            }
            .navigationTitle("Mission 1 Help")
            .toolbar { ToolbarItem { Button("Done") { dismiss() } } }
        }
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.system(.body, design: .monospaced).weight(.black)).frame(width: 48, alignment: .leading)
            Text(v)
        }
    }
}
