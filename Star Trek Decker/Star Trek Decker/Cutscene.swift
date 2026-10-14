import SwiftUI

enum Viewscreen { case stars, admiral, planetKiller, cube, klingons, halcyonCaptain }

enum SceneKind {
    case office, contest, evictionDoor, morningDoor, timeTunnel, starbaseReveal
    case bridge(Viewscreen)
    case quarters
    case pkEatsPlanet, pkVsExeter, escapePods, constellationVsPK, saucerHit
    case starbaseBriefing, separation, pkDestroyed, reunion
    case halcyonCruise, halcyonDeck, borgArrives, borgChase, tractorBeam
    case assimilation(Int), allDrones, cubeDestroyed, sickbay(Int)
    case klingonFleet, victory
}

struct Shot {
    var scene: SceneKind
    var speaker: String? = nil
    var text: String
    var voice: Sound.Voice = .narrator
    var sfx: Sound.Effect? = nil
}

/// The women of the U.S.S. Halcyon (Mission 3).
struct CrewWoman {
    let name: String
    let rank: String
    let designation: String
    let look: Look
}

let halcyonCrew: [CrewWoman] = [
    CrewWoman(name: "Elena Vasquez", rank: "Captain", designation: "One of Six",
              look: Look(skin: RGB(0.85, 0.65, 0.5), hair: RGB(0.12, 0.08, 0.05), style: .bun, top: RGB(0.75, 0.1, 0.1), pants: RGB(0.08, 0.08, 0.1), female: true, uniform: true)),
    CrewWoman(name: "Mira Okafor", rank: "Commander", designation: "Two of Six",
              look: Look(skin: RGB(0.45, 0.3, 0.22), hair: RGB(0.08, 0.06, 0.05), style: .curly, top: RGB(0.75, 0.1, 0.1), pants: RGB(0.08, 0.08, 0.1), female: true, uniform: true)),
    CrewWoman(name: "Jenna Park", rank: "Lieutenant", designation: "Three of Six",
              look: Look(skin: RGB(0.95, 0.82, 0.68), hair: RGB(0.1, 0.08, 0.08), style: .long, top: RGB(0.85, 0.65, 0.1), pants: RGB(0.08, 0.08, 0.1), female: true, uniform: true)),
    CrewWoman(name: "Sarah Lindqvist", rank: "Doctor", designation: "Four of Six",
              look: Look(skin: RGB(0.98, 0.86, 0.78), hair: RGB(0.95, 0.85, 0.55), style: .ponytail, top: RGB(0.2, 0.5, 0.6), pants: RGB(0.08, 0.08, 0.1), female: true, uniform: true)),
    CrewWoman(name: "Talia Reyes", rank: "Ensign", designation: "Five of Six",
              look: Look(skin: RGB(0.8, 0.6, 0.45), hair: RGB(0.35, 0.15, 0.08), style: .long, top: RGB(0.85, 0.65, 0.1), pants: RGB(0.08, 0.08, 0.1), female: true, uniform: true)),
    CrewWoman(name: "Nadia Petrova", rank: "Lieutenant", designation: "Six of Six",
              look: Look(skin: RGB(0.97, 0.84, 0.75), hair: RGB(0.6, 0.15, 0.08), style: .ponytail, top: RGB(0.2, 0.5, 0.6), pants: RGB(0.08, 0.08, 0.1), female: true, uniform: true)),
]

// MARK: - View

struct CutsceneView: View {
    let shots: [Shot]
    let onFinish: () -> Void
    @State private var index = 0
    @State private var shotStart = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("STARDATE \(String(format: "%.1f", 32000 + Double(index) * 0.4))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(LCARS.orange)
                Spacer()
                Button("Skip ›") { finish() }
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(LCARS.lilac))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(shotStart)
                    let s = min(size.width / 400, size.height / 260)
                    var c = ctx
                    c.translateBy(x: (size.width - 400 * s) / 2, y: (size.height - 260 * s) / 2)
                    c.scaleBy(x: s, y: s)
                    c.clip(to: Path(CGRect(x: 0, y: 0, width: 400, height: 260)))
                    drawScene(shots[index].scene, c, t: t, talking: shots[index].speaker)
                }
            }
            .aspectRatio(400 / 260, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 8)

            dialogue
                .padding(16)
            Spacer(minLength: 0)
        }
        .background(Color.black.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .onAppear { begin() }
    }

    private var dialogue: some View {
        let shot = shots[index]
        return VStack(alignment: .leading, spacing: 8) {
            if let who = shot.speaker {
                Text(who.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(LCARS.orange))
                    .foregroundStyle(.black)
            }
            Text(shot.text)
                .font(.system(size: 18, weight: shot.speaker == nil ? .regular : .semibold, design: .serif))
                .italic(shot.speaker == nil)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Text(index == shots.count - 1 ? "Tap to begin ›" : "Tap to continue ›")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(LCARS.peach.opacity(0.7))
            }
        }
        .padding(14)
        .frame(maxWidth: 700, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(LCARS.panel).stroke(LCARS.lilac.opacity(0.5), lineWidth: 1.5))
    }

    private func begin() {
        shotStart = Date()
        if autoplayCutscenes {
            // debug recording: advance on a timer sized to the line's length
            let shown = index
            let wait = max(5.0, Double(shots[index].text.count) * 0.075 + 1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                if index == shown { advance() }
            }
        }
        let shot = shots[index]
        if let fx = shot.sfx { Sound.shared.play(fx) }
        Sound.shared.say(shot.text, as: shot.voice)
    }

    private func advance() {
        if index + 1 < shots.count {
            index += 1
            begin()
        } else {
            finish()
        }
    }

    private func finish() {
        Sound.shared.stopSpeaking()
        onFinish()
    }
}

/// Debug-only: `-autoplay` advances cutscenes without taps (for screen recordings).
var autoplayCutscenes: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("-autoplay")
    #else
    false
    #endif
}

// MARK: - Scene drawing (400 × 260 design space)

func drawScene(_ kind: SceneKind, _ ctx: GraphicsContext, t: Double, talking: String?) {
    let size = CGSize(width: 400, height: 260)
    func talks(_ name: String) -> Bool { talking?.contains(name) ?? false }

    switch kind {
    case .office:
        drawRoom(ctx, wall: RGB(0.82, 0.76, 0.62), floor: RGB(0.45, 0.35, 0.28))
        // window with blinds
        ctx.fill(Path(CGRect(x: 250, y: 40, width: 110, height: 80)), with: .color(Color(red: 0.6, green: 0.8, blue: 0.95)))
        for k in 0..<9 { ctx.fill(Path(CGRect(x: 250, y: 42 + CGFloat(k) * 9, width: 110, height: 3)), with: .color(Color(white: 0.92))) }
        ctx.fill(Path(roundedRect: CGRect(x: 120, y: 50, width: 70, height: 22), cornerRadius: 2), with: .color(Color(red: 0.5, green: 0.35, blue: 0.2)))
        ctx.draw(Text("MANAGER").font(.system(size: 9, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.4)), at: CGPoint(x: 155, y: 61))
        drawPerson(ctx, feet: CGPoint(x: 290, y: 215), h: 130, look: .boss, t: t, facing: -1, talking: talks("Boss"))
        // desk in front of the boss
        ctx.fill(Path(CGRect(x: 220, y: 165, width: 150, height: 60)), with: .color(Color(red: 0.4, green: 0.25, blue: 0.15)))
        ctx.fill(Path(CGRect(x: 215, y: 160, width: 160, height: 8)), with: .color(Color(red: 0.5, green: 0.32, blue: 0.2)))
        ctx.fill(Path(CGRect(x: 240, y: 150, width: 30, height: 12)), with: .color(.white)) // the contract
        drawPerson(ctx, feet: CGPoint(x: 110, y: 230), h: 135, look: .mattWork, t: t, facing: 1, talking: talks("Matt"))

    case .contest:
        drawRoom(ctx, wall: RGB(0.55, 0.45, 0.35), floor: RGB(0.6, 0.45, 0.3))
        ctx.fill(Path(CGRect(x: 60, y: 22, width: 280, height: 26)), with: .color(Color(red: 0.15, green: 0.3, blue: 0.6)))
        ctx.draw(Text("BEST FURNITURE CONTEST").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white), at: CGPoint(x: 200, y: 35))
        drawChair(ctx, at: CGPoint(x: 230, y: 220))
        // blue ribbon
        ctx.fill(Path(ellipseIn: CGRect(x: 256, y: 120, width: 18, height: 18)), with: .color(Color.blue))
        ctx.fill(Path(CGRect(x: 260, y: 136, width: 4, height: 14)), with: .color(Color.blue))
        ctx.fill(Path(CGRect(x: 266, y: 136, width: 4, height: 14)), with: .color(Color.blue))
        ctx.draw(Text("1st").font(.system(size: 7, weight: .bold)).foregroundStyle(.white), at: CGPoint(x: 265, y: 129))
        for k in 0..<6 {
            let x = 30 + CGFloat(k) * 65
            if k == 2 || k == 3 { continue }
            drawPerson(ctx, feet: CGPoint(x: x, y: 250), h: 90, look: Look(skin: RGB(0.3, 0.3, 0.3), hair: RGB(0.2, 0.2, 0.2), top: RGB(0.25, 0.25, 0.28), pants: RGB(0.2, 0.2, 0.2)), t: t)
        }
        drawPerson(ctx, feet: CGPoint(x: 150, y: 225), h: 130, look: .mattWork, t: t, talking: talks("Matt"))

    case .evictionDoor:
        drawRoom(ctx, wall: RGB(0.35, 0.33, 0.4), floor: RGB(0.25, 0.22, 0.22))
        drawDoor(ctx, open: 0)
        // eviction notice
        ctx.fill(Path(CGRect(x: 185, y: 90, width: 40, height: 52)), with: .color(Color(white: 0.95)))
        ctx.fill(Path(CGRect(x: 185, y: 90, width: 40, height: 10)), with: .color(Color.red))
        ctx.draw(Text("EVICTION").font(.system(size: 6, weight: .heavy)).foregroundStyle(.white), at: CGPoint(x: 205, y: 95))
        ctx.draw(Text("VACATE\nIN 2 DAYS").font(.system(size: 6, weight: .bold)).foregroundStyle(.black), at: CGPoint(x: 205, y: 115))
        drawPerson(ctx, feet: CGPoint(x: 120, y: 235), h: 135, look: .mattWork, t: t, facing: 1, talking: talks("Matt"))
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0, green: 0, blue: 0.15).opacity(0.3)))

    case .morningDoor:
        drawRoom(ctx, wall: RGB(0.75, 0.72, 0.68), floor: RGB(0.45, 0.4, 0.38))
        drawDoor(ctx, open: 1)
        // the stranger materialises in a column of sparkles
        let m = min(1, t / 2.5)
        var c = ctx
        c.opacity = m
        drawPerson(c, feet: CGPoint(x: 290, y: 232), h: 130, look: .stranger, t: t, facing: -1, talking: talks("Stranger"))
        if m < 1 {
            for k in 0..<40 {
                let x = 290 + CGFloat(hash01(k, 61) - 0.5) * 50
                let y = 232 - CGFloat((hash01(k, 62) + t * 0.6).truncatingRemainder(dividingBy: 1)) * 140
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(Color(red: 0.8, green: 0.9, blue: 1).opacity(1 - m)))
            }
        }
        drawPerson(ctx, feet: CGPoint(x: 205, y: 235), h: 135, look: .mattWork, t: t, facing: 1, talking: talks("Matt"))

    case .timeTunnel:
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        for k in (0..<16).reversed() {
            let r = CGFloat((Double(k) * 18 + t * 70).truncatingRemainder(dividingBy: 290))
            let hue = (Double(k) / 16 + t * 0.1).truncatingRemainder(dividingBy: 1)
            ctx.stroke(Path(ellipseIn: CGRect(x: 200 - r, y: 130 - r * 0.65, width: 2 * r, height: 1.3 * r)), with: .color(Color(hue: hue, saturation: 0.7, brightness: 1).opacity(0.7)), lineWidth: 3 + r / 30)
        }
        let years = Int(2025 + min(1, t / 5) * 330)
        ctx.draw(Text(String(years)).font(.system(size: 34, weight: .black, design: .monospaced)).foregroundStyle(.white), at: CGPoint(x: 200, y: 40))
        var small = ctx
        small.opacity = 0.9
        drawPerson(small, feet: CGPoint(x: 188, y: 160), h: 55, look: .mattWork, t: t)
        drawPerson(small, feet: CGPoint(x: 212, y: 160), h: 55, look: .stranger, t: t)

    case .starbaseReveal:
        drawStarfield(ctx, size: size, t: t, speed: 0.1)
        drawPlanet(ctx, at: CGPoint(x: 340, y: 220), r: 70, base: RGB(0.3, 0.5, 0.8))
        drawStarbase(ctx, at: CGPoint(x: 90, y: 130), scale: 0.9, t: t)
        drawConstellation(ctx, at: CGPoint(x: 250 + CGFloat(min(t, 6)) * 4, y: 110), scale: 1.25, t: t)
        ctx.draw(Text("U.S.S. CONSTELLATION  NCC-1017-A").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(LCARS.peach), at: CGPoint(x: 260, y: 160))

    case .bridge(let screen):
        drawBridge(ctx, screen: screen, t: t, talking: talking)

    case .quarters:
        drawRoom(ctx, wall: RGB(0.4, 0.38, 0.45), floor: RGB(0.3, 0.28, 0.32))
        // big window
        ctx.fill(Path(roundedRect: CGRect(x: 40, y: 30, width: 320, height: 110), cornerRadius: 20), with: .color(.black))
        var win = ctx
        win.clip(to: Path(roundedRect: CGRect(x: 40, y: 30, width: 320, height: 110), cornerRadius: 20))
        drawStarfield(win, size: CGSize(width: 400, height: 140), t: t, speed: 0.15)
        // bed with Matt asleep
        ctx.fill(Path(roundedRect: CGRect(x: 90, y: 185, width: 220, height: 40), cornerRadius: 6), with: .color(Color(red: 0.3, green: 0.3, blue: 0.5)))
        ctx.fill(Path(roundedRect: CGRect(x: 95, y: 175, width: 50, height: 18), cornerRadius: 8), with: .color(.white))
        var lie2 = ctx
        lie2.translateBy(x: 285, y: 186)
        lie2.rotate(by: .degrees(-90))
        drawPerson(lie2, feet: .zero, h: 170, look: .mattCaptain, t: t)
        ctx.fill(Path(roundedRect: CGRect(x: 150, y: 178, width: 160, height: 22), cornerRadius: 6), with: .color(Color(red: 0.5, green: 0.55, blue: 0.75)))
        if Int(t * 1.5) % 2 == 0 {
            ctx.draw(Text("z Z z").font(.system(size: 14, weight: .bold)).foregroundStyle(.white), at: CGPoint(x: 120, y: 150))
        }

    case .pkEatsPlanet:
        drawStarfield(ctx, size: size, t: t, speed: 0.1)
        let eaten = min(1, max(0, (t - 1.5) / 4))
        drawPlanet(ctx, at: CGPoint(x: 90, y: 130), r: 45, base: RGB(0.3, 0.6, 0.35), eaten: eaten, t: t)
        // the antiproton beam
        if t > 0.8 && eaten < 1 {
            beam(ctx, from: CGPoint(x: 210, y: 130), to: CGPoint(x: 95, y: 130), color: .orange, width: 4, alpha: 0.6 + 0.4 * sin(t * 20))
        }
        drawPlanetKiller(ctx, at: CGPoint(x: 280, y: 130), scale: 1.1, t: t)

    case .pkVsExeter:
        drawStarfield(ctx, size: size, t: t, speed: 0.2)
        drawPlanetKiller(ctx, at: CGPoint(x: 120, y: 140), scale: 0.9, t: t, facingLeft: false)
        let ship = CGPoint(x: 300, y: 110)
        drawSmallShip(ctx, at: ship, scale: 1.2, t: t)
        let ph = t.truncatingRemainder(dividingBy: 2.4)
        if ph < 0.6 { beam(ctx, from: CGPoint(x: ship.x - 20, y: ship.y), to: CGPoint(x: 160, y: 140), color: .orange, width: 2, alpha: 1 - ph / 0.6) }
        if ph > 1.2 && ph < 1.9 {
            beam(ctx, from: CGPoint(x: 60, y: 140), to: ship, color: Color(red: 1, green: 0.5, blue: 0.1), width: 5, alpha: 1)
            drawExplosion(ctx, at: ship, r: 20, u: (ph - 1.2) / 0.7)
        }
        ctx.draw(Text("U.S.S. EXETER").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(LCARS.peach), at: CGPoint(x: 300, y: 140))

    case .escapePods:
        drawStarfield(ctx, size: size, t: t, speed: 0.2)
        drawSmallShip(ctx, at: CGPoint(x: 220, y: 100), scale: 1.2, hull: Color(white: 0.55), t: t)
        drawExplosion(ctx, at: CGPoint(x: 230, y: 98), r: 14, u: (t * 0.7).truncatingRemainder(dividingBy: 1))
        for k in 0..<10 {
            let a = Double(k) / 10 * 2 * .pi
            let d = CGFloat(min(t, 6) * 20) * CGFloat(0.6 + hash01(k, 71))
            let p = CGPoint(x: 220 + cos(a) * d * 1.5, y: 100 + sin(a) * d)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 2, width: 6, height: 4)), with: .color(Color(white: 0.9)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)), with: .color(Color.orange.opacity(0.5 + 0.5 * sin(t * 8 + Double(k)))))
        }

    case .constellationVsPK:
        drawStarfield(ctx, size: size, t: t, speed: 0.3)
        drawPlanetKiller(ctx, at: CGPoint(x: 290, y: 140), scale: 0.9, t: t)
        drawConstellation(ctx, at: CGPoint(x: 110, y: 120), scale: 0.95, t: t)
        let ph = t.truncatingRemainder(dividingBy: 1.6)
        if ph < 0.7 { beam(ctx, from: CGPoint(x: 150, y: 114), to: CGPoint(x: 240, y: 140), color: .orange, width: 2, alpha: 1 - ph / 0.7) }
        if ph > 0.7 && ph < 0.9 {
            ctx.draw(Text("NO EFFECT").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.red), at: CGPoint(x: 280, y: 95))
        }

    case .saucerHit:
        drawStarfield(ctx, size: size, t: t, speed: 0.3)
        drawPlanetKiller(ctx, at: CGPoint(x: 300, y: 140), scale: 0.9, t: t)
        let shake = t < 2 ? CGFloat(sin(t * 60) * 3) : 0
        drawConstellation(ctx, at: CGPoint(x: 110 + shake, y: 120), scale: 0.95, damage: min(1, t / 1.2), t: t)
        if t < 1.8 {
            beam(ctx, from: CGPoint(x: 236, y: 140), to: CGPoint(x: 120, y: 112), color: Color(red: 1, green: 0.5, blue: 0.1), width: 6, alpha: 1)
            drawExplosion(ctx, at: CGPoint(x: 125, y: 112), r: 26, u: t / 1.8)
        }

    case .starbaseBriefing:
        drawRoom(ctx, wall: RGB(0.3, 0.32, 0.4), floor: RGB(0.2, 0.2, 0.25))
        ctx.fill(Path(roundedRect: CGRect(x: 30, y: 25, width: 340, height: 100), cornerRadius: 14), with: .color(.black))
        var win = ctx
        win.clip(to: Path(roundedRect: CGRect(x: 30, y: 25, width: 340, height: 100), cornerRadius: 14))
        drawStarfield(win, size: CGSize(width: 400, height: 130), t: t, speed: 0.05)
        drawConstellation(win, at: CGPoint(x: 220, y: 80), scale: 0.7, damage: 0.9, t: t)
        // hologram of the ray emitter
        ctx.fill(Path(roundedRect: CGRect(x: 160, y: 170, width: 80, height: 8), cornerRadius: 3), with: .color(Color(white: 0.4)))
        var holo = ctx
        holo.opacity = 0.6 + 0.2 * sin(t * 4)
        holo.stroke(Path(roundedRect: CGRect(x: 185, y: 130, width: 30, height: 38), cornerRadius: 4), with: .color(.cyan), lineWidth: 1.5)
        holo.stroke(Path { p in p.move(to: CGPoint(x: 200, y: 130)); p.addLine(to: CGPoint(x: 200, y: 112)) }, with: .color(.purple), lineWidth: 3)
        drawPerson(ctx, feet: CGPoint(x: 80, y: 235), h: 130, look: .mattCaptain, t: t, talking: talks("Decker"))
        drawPerson(ctx, feet: CGPoint(x: 290, y: 235), h: 128, look: .admiral, t: t, facing: -1, talking: talks("Commodore"))
        drawPerson(ctx, feet: CGPoint(x: 345, y: 235), h: 120, look: .scientist, t: t, facing: -1, talking: talks("Dr."))

    case .separation:
        drawStarfield(ctx, size: size, t: t, speed: 0.15)
        drawStarbase(ctx, at: CGPoint(x: 360, y: 120), scale: 0.6, t: t)
        let split = CGFloat(min(1, max(0, (t - 1) / 3)))
        drawConstellation(ctx, at: CGPoint(x: 150 - split * 30, y: 140), scale: 1.1, split: split, damage: 0.8, t: t)
        if split > 0 && split < 1 {
            for k in 0..<8 {
                let x = 165 + CGFloat(k) * 4
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: 128 - split * 15, width: 2, height: 2)), with: .color(Color.white.opacity(0.7)))
            }
        }

    case .pkDestroyed:
        drawStarfield(ctx, size: size, t: t, speed: 0.1)
        if t < 2.5 { drawPlanetKiller(ctx, at: CGPoint(x: 220, y: 130), scale: 1.0, t: t, weakened: true) }
        for k in 0..<5 {
            let u = (t - Double(k) * 0.35) / 1.6
            drawExplosion(ctx, at: CGPoint(x: 180 + CGFloat(k) * 25, y: 120 + CGFloat(hash01(k, 81)) * 30), r: 40, u: u)
        }
        if t > 2.5 {
            for k in 0..<30 {
                let a = hash01(k, 82) * 2 * .pi
                let d = CGFloat(t - 2.5) * 30 * CGFloat(0.5 + hash01(k, 83))
                ctx.fill(Path(CGRect(x: 220 + cos(a) * d, y: 130 + sin(a) * d, width: 3, height: 2)), with: .color(Color(white: 0.5)))
            }
        }
        drawConstellation(ctx, at: CGPoint(x: 70, y: 200), scale: 0.45, split: 0, t: t)

    case .reunion:
        drawStarfield(ctx, size: size, t: t, speed: 0.15)
        let split = CGFloat(max(0, 1 - t / 3.5))
        drawConstellation(ctx, at: CGPoint(x: 160, y: 140), scale: 1.1, split: split, t: t)

    case .halcyonCruise:
        drawStarfield(ctx, size: size, t: t, speed: 0.25)
        drawPlanet(ctx, at: CGPoint(x: 320, y: 210), r: 60, base: RGB(0.8, 0.55, 0.35))
        drawSmallShip(ctx, at: CGPoint(x: 170, y: 110), scale: 1.6, t: t)
        ctx.draw(Text("U.S.S. HALCYON  NCC-74921").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(LCARS.peach), at: CGPoint(x: 170, y: 150))

    case .halcyonDeck:
        drawRoom(ctx, wall: RGB(0.75, 0.82, 0.78), floor: RGB(0.5, 0.6, 0.5))
        ctx.fill(Path(roundedRect: CGRect(x: 30, y: 25, width: 340, height: 85), cornerRadius: 14), with: .color(.black))
        var win = ctx
        win.clip(to: Path(roundedRect: CGRect(x: 30, y: 25, width: 340, height: 85), cornerRadius: 14))
        drawStarfield(win, size: CGSize(width: 400, height: 120), t: t, speed: 0.2)
        for k in 0..<5 { drawPlant(ctx, at: CGPoint(x: 20 + CGFloat(k) * 92, y: 200), t: t + Double(k)) }
        for (i, w) in halcyonCrew.enumerated() {
            let x = 45 + CGFloat(i) * 62
            drawPerson(ctx, feet: CGPoint(x: x, y: 240 - CGFloat(i % 2) * 6), h: 112, look: w.look, t: t, facing: i < 3 ? 1 : -1, talking: talks(w.name.components(separatedBy: " ").first ?? ""))
        }

    case .borgArrives:
        drawStarfield(ctx, size: size, t: t, speed: 0.25)
        let grow = CGFloat(min(1, t / 4))
        drawBorgCube(ctx, at: CGPoint(x: 300, y: 120), size: 40 + grow * 110, t: t)
        drawSmallShip(ctx, at: CGPoint(x: 100, y: 140), scale: 1.0, t: t)

    case .borgChase:
        drawStarfield(ctx, size: size, t: t, speed: 1.4, streak: 1)
        let gain = CGFloat(min(1, t / 5))
        drawSmallShip(ctx, at: CGPoint(x: 280, y: 130), scale: 1.0, t: t)
        drawBorgCube(ctx, at: CGPoint(x: 60 + gain * 120, y: 120), size: 100, t: t)

    case .tractorBeam:
        drawStarfield(ctx, size: size, t: t, speed: 0.1)
        drawBorgCube(ctx, at: CGPoint(x: 120, y: 125), size: 150, t: t)
        let pull = CGFloat(min(1, t / 4))
        let ship = CGPoint(x: 320 - pull * 70, y: 120)
        var tr = Path()
        tr.move(to: CGPoint(x: 190, y: 105)); tr.addLine(to: CGPoint(x: ship.x - 10, y: ship.y - 15)); tr.addLine(to: CGPoint(x: ship.x - 10, y: ship.y + 15)); tr.addLine(to: CGPoint(x: 190, y: 140)); tr.closeSubpath()
        ctx.fill(tr, with: .color(Color.green.opacity(0.25 + 0.1 * sin(t * 8))))
        drawSmallShip(ctx, at: ship, scale: 0.9, t: t)

    case .assimilation(let i):
        drawRoom(ctx, wall: RGB(0.2, 0.25, 0.22), floor: RGB(0.12, 0.14, 0.12))
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.green.opacity(0.06 + 0.04 * sin(t * 3))))
        // the crew already taken stand behind as drones
        for k in 0..<i {
            drawPerson(ctx, feet: CGPoint(x: 30 + CGFloat(k) * 34, y: 200), h: 90, look: drone(halcyonCrew[k].look, 1), t: t)
        }
        let w = halcyonCrew[i]
        let u = min(1, max(0, (t - 1.2) / 3.5))
        // a drone reaches out with assimilation tubules
        drawPerson(ctx, feet: CGPoint(x: 330, y: 240), h: 140, look: Look(skin: RGB(0.8, 0.8, 0.8), hair: RGB(0, 0, 0), style: .bald, top: RGB(0.12, 0.12, 0.13), pants: RGB(0.12, 0.12, 0.13), borg: 1), t: t, facing: -1)
        if t > 0.6 && t < 2.2 {
            beam(ctx, from: CGPoint(x: 305, y: 150), to: CGPoint(x: 232, y: 128), color: Color(white: 0.6), width: 1, alpha: 0.9)
        }
        drawPerson(ctx, feet: CGPoint(x: 220, y: 240), h: 140, look: drone(w.look, u), t: t, facing: 1)
        ctx.draw(Text(u < 1 ? "\(w.rank.uppercased()) \(w.name.uppercased())" : w.designation.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(u < 1 ? LCARS.peach : Color.green),
                 at: CGPoint(x: 220, y: 252))

    case .allDrones:
        drawRoom(ctx, wall: RGB(0.18, 0.22, 0.2), floor: RGB(0.1, 0.12, 0.1))
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.green.opacity(0.08)))
        for (k, w) in halcyonCrew.enumerated() {
            drawPerson(ctx, feet: CGPoint(x: 45 + CGFloat(k) * 62, y: 238), h: 120, look: drone(w.look, 1), t: t + Double(k))
        }

    case .cubeDestroyed:
        drawStarfield(ctx, size: size, t: t, speed: 0.1)
        if t < 2.4 { drawBorgCube(ctx, at: CGPoint(x: 240, y: 125), size: 140, t: t, damage: min(1, t / 2)) }
        for k in 0..<6 {
            drawExplosion(ctx, at: CGPoint(x: 190 + CGFloat(hash01(k, 91)) * 110, y: 80 + CGFloat(hash01(k, 92)) * 100), r: 45, u: (t - Double(k) * 0.3) / 1.6)
        }
        drawConstellation(ctx, at: CGPoint(x: 70, y: 210), scale: 0.45, t: t)

    case .sickbay(let rescued):
        drawRoom(ctx, wall: RGB(0.82, 0.85, 0.9), floor: RGB(0.6, 0.62, 0.68))
        for k in 0..<3 {
            ctx.fill(Path(roundedRect: CGRect(x: 30 + CGFloat(k) * 125, y: 150, width: 90, height: 18), cornerRadius: 5), with: .color(Color(white: 0.5)))
            ctx.fill(Path(CGRect(x: 60 + CGFloat(k) * 125, y: 40, width: 30, height: 20)), with: .color(Color(red: 0.2, green: 0.6, blue: 0.9)))
        }
        for k in 0..<max(1, rescued) where k < halcyonCrew.count {
            var look = halcyonCrew[k].look
            look.restored = true
            drawPerson(ctx, feet: CGPoint(x: 45 + CGFloat(k) * 62, y: 240), h: 118, look: look, t: t + Double(k), facing: k < 3 ? 1 : -1, talking: talks(halcyonCrew[k].name.components(separatedBy: " ").first ?? ""))
        }

    case .klingonFleet:
        drawStarfield(ctx, size: size, t: t, speed: 0.4)
        for k in 0..<5 {
            let x = 380 - CGFloat(t * 18).truncatingRemainder(dividingBy: 60) - CGFloat(k) * 70
            drawKlingon(ctx, at: CGPoint(x: x, y: 70 + CGFloat(hash01(k, 95)) * 130), scale: 0.8 + CGFloat(hash01(k, 96)) * 0.5, facingLeft: true)
        }

    case .victory:
        drawStarfield(ctx, size: size, t: t, speed: 0.2)
        drawStarbase(ctx, at: CGPoint(x: 330, y: 130), scale: 0.8, t: t)
        drawConstellation(ctx, at: CGPoint(x: 150, y: 130), scale: 1.1, t: t)
        for k in 0..<12 {
            let u = (t * 0.5 + hash01(k, 97)).truncatingRemainder(dividingBy: 1)
            drawExplosion(ctx, at: CGPoint(x: 40 + CGFloat(hash01(k, 98)) * 320, y: 30 + CGFloat(hash01(k, 99)) * 80), r: 10, u: u)
        }
    }
}

func drone(_ look: Look, _ amount: Double) -> Look {
    var l = look
    l.borg = amount
    return l
}

// MARK: - Scenery helpers

func drawRoom(_ ctx: GraphicsContext, wall: RGB, floor: RGB) {
    ctx.fill(Path(CGRect(x: 0, y: 0, width: 400, height: 190)), with: .linearGradient(Gradient(colors: [wall.mix(RGB(1, 1, 1), 0.1).color, wall.color]), startPoint: .zero, endPoint: CGPoint(x: 0, y: 190)))
    ctx.fill(Path(CGRect(x: 0, y: 185, width: 400, height: 75)), with: .linearGradient(Gradient(colors: [floor.color, floor.mix(RGB(0, 0, 0), 0.4).color]), startPoint: CGPoint(x: 0, y: 185), endPoint: CGPoint(x: 0, y: 260)))
    ctx.fill(Path(CGRect(x: 0, y: 183, width: 400, height: 4)), with: .color(floor.mix(RGB(0, 0, 0), 0.5).color))
}

func drawDoor(_ ctx: GraphicsContext, open: Double) {
    let frame = CGRect(x: 160, y: 50, width: 90, height: 140)
    ctx.fill(Path(frame.insetBy(dx: -5, dy: -5)), with: .color(Color(white: 0.9)))
    if open > 0 {
        ctx.fill(Path(frame), with: .color(Color(red: 0.95, green: 0.9, blue: 0.75)))
        ctx.fill(Path(CGRect(x: frame.minX, y: frame.minY, width: 18, height: frame.height)), with: .color(Color(red: 0.45, green: 0.28, blue: 0.15)))
    } else {
        ctx.fill(Path(frame), with: .color(Color(red: 0.45, green: 0.28, blue: 0.15)))
        ctx.fill(Path(ellipseIn: CGRect(x: frame.maxX - 16, y: frame.midY, width: 7, height: 7)), with: .color(LCARS.gold))
        ctx.draw(Text("4B").font(.system(size: 9, weight: .bold)).foregroundStyle(LCARS.gold), at: CGPoint(x: frame.midX, y: frame.minY + 14))
    }
}

func drawChair(_ ctx: GraphicsContext, at p: CGPoint) {
    let wood = Color(red: 0.55, green: 0.32, blue: 0.15)
    ctx.fill(Path(roundedRect: CGRect(x: p.x - 30, y: p.y - 50, width: 60, height: 10), cornerRadius: 3), with: .color(wood))
    for x in [p.x - 26, p.x + 22] {
        ctx.fill(Path(CGRect(x: x, y: p.y - 42, width: 5, height: 42)), with: .color(wood))
    }
    ctx.fill(Path(CGRect(x: p.x + 22, y: p.y - 110, width: 6, height: 62)), with: .color(wood))
    ctx.fill(Path(CGRect(x: p.x - 26, y: p.y - 110, width: 6, height: 62)), with: .color(wood))
    for k in 0..<4 {
        ctx.fill(Path(CGRect(x: p.x - 20, y: p.y - 104 + CGFloat(k) * 14, width: 42, height: 5)), with: .color(wood.opacity(0.9)))
    }
}

func drawPlant(_ ctx: GraphicsContext, at p: CGPoint, t: Double) {
    ctx.fill(Path(CGRect(x: p.x - 12, y: p.y - 18, width: 24, height: 18)), with: .color(Color(red: 0.6, green: 0.4, blue: 0.3)))
    for k in 0..<6 {
        let a = -Double.pi / 2 + (Double(k) - 2.5) * 0.35 + sin(t * 0.8) * 0.05
        var leaf = Path()
        leaf.move(to: CGPoint(x: p.x, y: p.y - 18))
        leaf.addQuadCurve(to: CGPoint(x: p.x + cos(a) * 40, y: p.y - 18 + sin(a) * 50), control: CGPoint(x: p.x + cos(a) * 10 - 8, y: p.y - 40))
        ctx.stroke(leaf, with: .color(Color(red: 0.2, green: 0.55, blue: 0.25)), lineWidth: 4)
    }
}

func drawKlingon(_ ctx: GraphicsContext, at c: CGPoint, scale s: CGFloat, facingLeft: Bool = true) {
    var ctx = ctx
    ctx.translateBy(x: c.x, y: c.y)
    if !facingLeft { ctx.scaleBy(x: -1, y: 1) }
    let hull = Color(red: 0.35, green: 0.45, blue: 0.32)
    var wings = Path()
    wings.move(to: CGPoint(x: 0, y: 0))
    wings.addLine(to: CGPoint(x: 22 * s, y: -18 * s))
    wings.addLine(to: CGPoint(x: 30 * s, y: -16 * s))
    wings.addLine(to: CGPoint(x: 14 * s, y: 2 * s))
    wings.addLine(to: CGPoint(x: 30 * s, y: 18 * s))
    wings.addLine(to: CGPoint(x: 22 * s, y: 20 * s))
    wings.closeSubpath()
    ctx.fill(wings, with: .color(hull))
    ctx.fill(Path(roundedRect: CGRect(x: -22 * s, y: -2 * s, width: 26 * s, height: 4 * s), cornerRadius: 2), with: .color(hull))
    ctx.fill(Path(ellipseIn: CGRect(x: -30 * s, y: -5 * s, width: 12 * s, height: 10 * s)), with: .color(hull))
    ctx.fill(Path(ellipseIn: CGRect(x: -29 * s, y: -1.5 * s, width: 4 * s, height: 3 * s)), with: .color(Color.red))
}

func drawBridge(_ ctx: GraphicsContext, screen: Viewscreen, t: Double, talking: String?) {
    drawRoom(ctx, wall: RGB(0.28, 0.27, 0.3), floor: RGB(0.35, 0.22, 0.2))
    let vs = CGRect(x: 80, y: 18, width: 240, height: 120)
    ctx.fill(Path(roundedRect: vs.insetBy(dx: -6, dy: -6), cornerRadius: 10), with: .color(Color(white: 0.15)))
    var v = ctx
    v.clip(to: Path(roundedRect: vs, cornerRadius: 6))
    v.translateBy(x: vs.minX, y: vs.minY)
    let vsize = vs.size
    switch screen {
    case .stars:
        drawStarfield(v, size: vsize, t: t, speed: 0.6)
    case .admiral:
        v.fill(Path(CGRect(origin: .zero, size: vsize)), with: .color(Color(red: 0.25, green: 0.25, blue: 0.35)))
        drawPerson(v, feet: CGPoint(x: 120, y: 190), h: 175, look: .admiral, t: t, talking: talking?.contains("Admiral") ?? false)
    case .planetKiller:
        drawStarfield(v, size: vsize, t: t, speed: 0.2)
        drawPlanetKiller(v, at: CGPoint(x: 130, y: 60), scale: 0.6, t: t)
    case .cube:
        drawStarfield(v, size: vsize, t: t, speed: 0.2)
        drawBorgCube(v, at: CGPoint(x: 120, y: 60), size: 70, t: t)
    case .klingons:
        drawStarfield(v, size: vsize, t: t, speed: 0.2)
        drawKlingon(v, at: CGPoint(x: 90, y: 50), scale: 1.2)
        drawKlingon(v, at: CGPoint(x: 170, y: 80), scale: 0.8)
    case .halcyonCaptain:
        v.fill(Path(CGRect(origin: .zero, size: vsize)), with: .color(Color(red: 0.2, green: 0.25, blue: 0.3)))
        let flicker = Int(t * 8) % 7 == 0
        if !flicker { drawPerson(v, feet: CGPoint(x: 120, y: 190), h: 175, look: halcyonCrew[0].look, t: t, talking: true) }
        for k in 0..<12 {
            v.fill(Path(CGRect(x: 0, y: CGFloat(hash01(k, Int(t * 10))) * vsize.height, width: vsize.width, height: 2)), with: .color(.white.opacity(0.15)))
        }
    }
    // LCARS side consoles
    let bars: [(Color, CGFloat)] = [(LCARS.orange, 40), (LCARS.lilac, 70), (LCARS.blue, 100), (LCARS.peach, 130)]
    for (c, y) in bars {
        ctx.fill(Path(roundedRect: CGRect(x: 10, y: y, width: 55, height: 18), cornerRadius: 9), with: .color(c))
        ctx.fill(Path(roundedRect: CGRect(x: 335, y: y, width: 55, height: 18), cornerRadius: 9), with: .color(c))
    }
    // helm console + chair
    ctx.fill(Path(roundedRect: CGRect(x: 120, y: 200, width: 160, height: 22), cornerRadius: 8), with: .color(Color(white: 0.2)))
    for k in 0..<10 {
        ctx.fill(Path(CGRect(x: 128 + CGFloat(k) * 15, y: 205, width: 10, height: 5)), with: .color([LCARS.orange, LCARS.blue, LCARS.lilac][k % 3].opacity(hash01(k, Int(t * 2)) > 0.3 ? 1 : 0.3)))
    }
    drawPerson(ctx, feet: CGPoint(x: 200, y: 250), h: 105, look: .mattCaptain, t: t, talking: (talking?.contains("Decker") ?? false) || (talking?.contains("Matt") ?? false))
    drawPerson(ctx, feet: CGPoint(x: 330, y: 250), h: 100, look: .engineer, t: t, facing: -1, talking: talking?.contains("Chief") ?? false)
    drawPerson(ctx, feet: CGPoint(x: 70, y: 250), h: 100, look: .scientist, t: t, facing: 1, talking: talking?.contains("Commander") ?? false)
}
