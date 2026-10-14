import SwiftUI

enum Place {
    case targetLot, casinoOutside, casino, street, sidewalk, salon, town, venue, home, bedroom, bathroom
}

enum SalonSpot {
    static let chairX: [Double] = [280, 500, 720]
    static let button = CGPoint(x: 905, y: 352)
    /// The oval mirror on the wall beside the poker-room door; a girl stands right under it to look.
    static let mirrorX = 150.0
    static let mirrorY = 215.0
    static let mirrorStand = 150.0
    /// Where the new girls line up, side by side, under the retractable mirror.
    static let lineUp: [Double] = [330, 500, 670]
    /// The retractable mirror's glass when fully lowered.
    static let retractRect = CGRect(x: 240, y: 80, width: 520, height: 140)
}

/// The flying beauty salon's position: x, and the height of its floor (bottom edge) on stage.
struct SalonShip {
    var x = 500.0
    var y0 = -300.0
    var y1 = -300.0
    var t0 = Date.distantPast
    var dur = 0.0
    var doorOpen = false
    var flying = true

    func bottom(at now: Date) -> Double {
        let t = now.timeIntervalSince(t0)
        if dur <= 0 || t >= dur { return y1 }
        if t <= 0 { return y0 }
        let u = t / dur
        return y0 + (y1 - y0) * u * u * (3 - 2 * u)
    }

    mutating func move(to y: Double, over seconds: Double) {
        let now = Date.now
        y0 = bottom(at: now)
        y1 = y
        t0 = now
        dur = seconds
    }
}

struct Beam {
    var x: Double
    var top: Double
    var bottom: Double
}

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path { Path(CGRect(x: x, y: y, width: w, height: h)) }
private func oval(_ c: CGPoint, _ r: Double) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }

private func label(_ ctx: GraphicsContext, _ s: String, _ at: CGPoint, size: Double, color: Color, weight: Font.Weight = .black) {
    ctx.draw(Text(s).font(.system(size: size, weight: weight, design: .rounded)).foregroundStyle(color), at: at)
}

private func sky(_ ctx: GraphicsContext, _ colors: [Color], to y: Double = Stage.H) {
    ctx.fill(rect(0, 0, Stage.W, y), with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: y)))
}

private func stars(_ ctx: GraphicsContext, _ now: Date, below: Double = 260) {
    let t = now.timeIntervalSinceReferenceDate
    for i in 0..<40 {
        let x = Double((i * 7919) % 1000)
        let y = Double((i * 104_729) % Int(below))
        let tw = 0.5 + 0.5 * sin(t * 2 + Double(i))
        ctx.fill(oval(CGPoint(x: x, y: y), 1 + tw), with: .color(.white.opacity(0.4 + 0.5 * tw)))
    }
}

// MARK: Target

func drawCart(_ ctx: GraphicsContext, _ x: Double, _ y: Double) {
    var basket = Path()
    basket.move(to: CGPoint(x: x - 30, y: y - 64))
    basket.addLine(to: CGPoint(x: x + 26, y: y - 64))
    basket.addLine(to: CGPoint(x: x + 20, y: y - 28))
    basket.addLine(to: CGPoint(x: x - 20, y: y - 28))
    basket.closeSubpath()
    ctx.fill(basket, with: .color(Color(red: 0.85, green: 0.05, blue: 0.1).opacity(0.85)))
    for k in 1..<5 {
        let gx = x - 30 + Double(k) * 11
        var p = Path()
        p.move(to: CGPoint(x: gx, y: y - 64))
        p.addLine(to: CGPoint(x: gx - (gx - x) * 0.25, y: y - 28))
        ctx.stroke(p, with: .color(.white.opacity(0.35)), lineWidth: 1)
    }
    ctx.stroke(basket, with: .color(Color(red: 0.6, green: 0, blue: 0.05)), lineWidth: 2)
    var frame = Path()
    frame.move(to: CGPoint(x: x + 26, y: y - 64))
    frame.addLine(to: CGPoint(x: x + 36, y: y - 74))
    frame.move(to: CGPoint(x: x - 18, y: y - 28))
    frame.addLine(to: CGPoint(x: x - 18, y: y - 8))
    frame.move(to: CGPoint(x: x + 16, y: y - 28))
    frame.addLine(to: CGPoint(x: x + 16, y: y - 8))
    frame.move(to: CGPoint(x: x - 22, y: y - 10))
    frame.addLine(to: CGPoint(x: x + 20, y: y - 10))
    ctx.stroke(frame, with: .color(.gray), lineWidth: 3)
    ctx.stroke(rect(x + 30, y - 78, 12, 4), with: .color(.red), lineWidth: 3)
    for wx in [x - 18, x + 16] {
        ctx.fill(oval(CGPoint(x: wx, y: y - 5), 5), with: .color(.black))
    }
}

private func drawTargetLot(_ ctx: GraphicsContext, _ now: Date) {
    sky(ctx, [Color(red: 0.35, green: 0.25, blue: 0.6), Color(red: 1, green: 0.55, blue: 0.4), Color(red: 1, green: 0.8, blue: 0.5)], to: 440)
    ctx.fill(oval(CGPoint(x: 860, y: 170), 50), with: .color(Color(red: 1, green: 0.75, blue: 0.35)))
    // Store
    ctx.fill(rect(60, 140, 880, 300), with: .color(Color(red: 0.9, green: 0.84, blue: 0.75)))
    ctx.fill(rect(60, 140, 880, 18), with: .color(Color(red: 0.75, green: 0.68, blue: 0.6)))
    let logo = CGPoint(x: 500, y: 225)
    ctx.fill(oval(logo, 46), with: .color(Color(red: 0.8, green: 0, blue: 0.08)))
    ctx.fill(oval(logo, 31), with: .color(.white))
    ctx.fill(oval(logo, 16), with: .color(Color(red: 0.8, green: 0, blue: 0.08)))
    label(ctx, "TARGET", CGPoint(x: 500, y: 302), size: 38, color: Color(red: 0.8, green: 0, blue: 0.08))
    for dx in [210.0, 700.0] {
        ctx.fill(rect(dx, 335, 90, 105), with: .color(Color(red: 0.55, green: 0.7, blue: 0.8)))
        ctx.stroke(Path { $0.move(to: CGPoint(x: dx + 45, y: 335)); $0.addLine(to: CGPoint(x: dx + 45, y: 440)) }, with: .color(.gray), lineWidth: 3)
        ctx.fill(rect(dx - 10, 322, 110, 14), with: .color(Color(red: 0.8, green: 0, blue: 0.08)))
    }
    // Lot
    ctx.fill(rect(0, 440, Stage.W, 160), with: .linearGradient(Gradient(colors: [Color(red: 0.42, green: 0.42, blue: 0.45), Color(red: 0.3, green: 0.3, blue: 0.33)]),
                                                               startPoint: CGPoint(x: 0, y: 440), endPoint: CGPoint(x: 0, y: 600)))
    for i in 0..<14 {
        let x = Double(i) * 80 - 20
        ctx.fill(oval(CGPoint(x: x + 40, y: 452), 11), with: .color(Color(red: 0.85, green: 0.05, blue: 0.1)))
    }
    for i in 0..<9 {
        var p = Path()
        p.move(to: CGPoint(x: Double(i) * 120 + 20, y: 560))
        p.addLine(to: CGPoint(x: Double(i) * 120 + 60, y: 600))
        ctx.stroke(p, with: .color(.white.opacity(0.8)), lineWidth: 4)
    }
    // Cart corral
    ctx.stroke(Path { p in
        p.move(to: CGPoint(x: 70, y: 490)); p.addLine(to: CGPoint(x: 290, y: 490))
        p.move(to: CGPoint(x: 70, y: 520)); p.addLine(to: CGPoint(x: 290, y: 520))
        for x in [70.0, 180, 290] { p.move(to: CGPoint(x: x, y: 482)); p.addLine(to: CGPoint(x: x, y: 545)) }
    }, with: .color(Color(red: 0.75, green: 0.75, blue: 0.78)), lineWidth: 5)
    ctx.fill(rect(177, 440, 6, 50), with: .color(Color(white: 0.7)))
    ctx.fill(rect(150, 416, 60, 24), with: .color(Color(red: 0.8, green: 0, blue: 0.08)))
    label(ctx, "CARTS", CGPoint(x: 180, y: 428), size: 13, color: .white)
    // Time clock on the wall by the doors
    let tc = TargetSpot.clock
    ctx.fill(Path(roundedRect: CGRect(x: tc.x - 20, y: tc.y - 42, width: 40, height: 56), cornerRadius: 5), with: .color(Color(white: 0.3)))
    ctx.fill(oval(CGPoint(x: tc.x, y: tc.y - 24), 12), with: .color(.white))
    ctx.stroke(Path { $0.move(to: CGPoint(x: tc.x, y: tc.y - 24)); $0.addLine(to: CGPoint(x: tc.x, y: tc.y - 32)) }, with: .color(.black), lineWidth: 1.5)
    ctx.stroke(Path { $0.move(to: CGPoint(x: tc.x, y: tc.y - 24)); $0.addLine(to: CGPoint(x: tc.x + 6, y: tc.y - 22)) }, with: .color(.black), lineWidth: 1.5)
    ctx.fill(rect(tc.x - 12, tc.y - 4, 24, 4), with: .color(.black))
    ctx.fill(rect(tc.x - 9, tc.y - 14, 18, 10), with: .color(Color(red: 0.95, green: 0.9, blue: 0.75)))
    label(ctx, "TIME", CGPoint(x: tc.x, y: tc.y + 24), size: 10, color: Color(white: 0.25))
}

enum TargetSpot {
    /// Where Larry's hand punches the time clock on the store wall.
    static let clock = CGPoint(x: 640, y: 372)
}

// MARK: Casino

private func drawCasinoOutside(_ ctx: GraphicsContext, _ now: Date) {
    sky(ctx, [Color(red: 0.02, green: 0.02, blue: 0.12), Color(red: 0.12, green: 0.05, blue: 0.25)], to: 540)
    stars(ctx, now, below: 130)
    ctx.fill(rect(110, 110, 780, 430), with: .color(Color(red: 0.4, green: 0.05, blue: 0.15)))
    let t = now.timeIntervalSinceReferenceDate
    let marquee = CGRect(x: 170, y: 150, width: 660, height: 120)
    ctx.fill(Path(roundedRect: marquee, cornerRadius: 16), with: .color(Color(red: 0.15, green: 0.0, blue: 0.2)))
    ctx.stroke(Path(roundedRect: marquee, cornerRadius: 16), with: .color(.yellow), lineWidth: 5)
    for i in 0..<44 {
        let u = Double(i) / 44
        let per = 2 * (marquee.width + marquee.height)
        var d = u * per
        var p: CGPoint
        if d < marquee.width { p = CGPoint(x: marquee.minX + d, y: marquee.minY) }
        else if (d - marquee.width) < marquee.height { d -= marquee.width; p = CGPoint(x: marquee.maxX, y: marquee.minY + d) }
        else if (d - marquee.width - marquee.height) < marquee.width { d -= marquee.width + marquee.height; p = CGPoint(x: marquee.maxX - d, y: marquee.maxY) }
        else { d -= 2 * marquee.width + marquee.height; p = CGPoint(x: marquee.minX, y: marquee.maxY - d) }
        let on = (i + Int(t * 6)) % 3 == 0
        ctx.fill(oval(p, 5), with: .color(on ? Color.yellow : Color.orange.opacity(0.4)))
    }
    label(ctx, "PRINCESS PALACE", CGPoint(x: 500, y: 195), size: 52, color: Color(red: 1, green: 0.4, blue: 0.75))
    label(ctx, "C A S I N O", CGPoint(x: 500, y: 245), size: 26, color: .yellow)
    // Crown
    var crown = Path()
    crown.move(to: CGPoint(x: 450, y: 140)); crown.addLine(to: CGPoint(x: 440, y: 95)); crown.addLine(to: CGPoint(x: 470, y: 118))
    crown.addLine(to: CGPoint(x: 500, y: 85)); crown.addLine(to: CGPoint(x: 530, y: 118)); crown.addLine(to: CGPoint(x: 560, y: 95))
    crown.addLine(to: CGPoint(x: 550, y: 140)); crown.closeSubpath()
    ctx.fill(crown, with: .color(.yellow))
    // Doors
    ctx.fill(rect(430, 380, 140, 160), with: .color(Color(red: 1, green: 0.85, blue: 0.5).opacity(0.85)))
    ctx.stroke(rect(430, 380, 140, 160), with: .color(.yellow), lineWidth: 5)
    ctx.stroke(Path { $0.move(to: CGPoint(x: 500, y: 380)); $0.addLine(to: CGPoint(x: 500, y: 540)) }, with: .color(.yellow), lineWidth: 3)
    for x in [180.0, 300, 640, 760] {
        ctx.fill(rect(x, 330, 70, 90), with: .color(Color(red: 1, green: 0.7, blue: 0.4).opacity(0.5)))
    }
    ctx.fill(rect(0, 540, Stage.W, 60), with: .color(Color(red: 0.25, green: 0.25, blue: 0.3)))
    ctx.fill(rect(420, 540, 160, 60), with: .color(Color(red: 0.7, green: 0.05, blue: 0.15)))
}

/// `second`: after you've been changed, your picture shows up on the machine next to the Princess.
private func drawCasino(_ ctx: GraphicsContext, _ now: Date, empty: Bool, second: (Color, GirlLook)? = nil) {
    ctx.fill(rect(0, 0, Stage.W, 380), with: .linearGradient(Gradient(colors: [Color(red: 0.3, green: 0.02, blue: 0.1), Color(red: 0.5, green: 0.08, blue: 0.15)]),
                                                             startPoint: .zero, endPoint: CGPoint(x: 0, y: 380)))
    ctx.fill(rect(0, 372, Stage.W, 8), with: .color(Color(red: 0.85, green: 0.65, blue: 0.2)))
    ctx.fill(rect(0, 380, Stage.W, 220), with: .color(Color(red: 0.22, green: 0.05, blue: 0.3)))
    for i in 0..<20 { for j in 0..<5 {
        let c = CGPoint(x: Double(i) * 55 + (j % 2 == 0 ? 0 : 27), y: 400 + Double(j) * 45)
        var d = Path()
        d.move(to: CGPoint(x: c.x, y: c.y - 10)); d.addLine(to: CGPoint(x: c.x + 12, y: c.y))
        d.addLine(to: CGPoint(x: c.x, y: c.y + 10)); d.addLine(to: CGPoint(x: c.x - 12, y: c.y)); d.closeSubpath()
        ctx.fill(d, with: .color(Color(red: 0.85, green: 0.6, blue: 0.2).opacity(0.35)))
    } }
    let t = now.timeIntervalSinceReferenceDate
    for cx in [250.0, 750] {
        ctx.stroke(Path { $0.move(to: CGPoint(x: cx, y: 0)); $0.addLine(to: CGPoint(x: cx, y: 40)) }, with: .color(.yellow), lineWidth: 2)
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 50, y: 40, width: 100, height: 30)), with: .color(Color.yellow.opacity(empty ? 0.25 : 0.9)))
        if !empty {
            for k in 0..<6 { drawTwinkle(ctx, CGPoint(x: cx - 40 + Double(k) * 16, y: 78 + 6 * sin(t * 2 + Double(k))), 5, .white) }
        }
    }
    for (i, mx) in [110.0, 270, 500, 730, 890].enumerated() {
        let princess = i == 2
        let cab = CGRect(x: mx - 60, y: 210, width: 120, height: 280)
        ctx.fill(Path(roundedRect: cab, cornerRadius: 14), with: .color(princess ? Color(red: 0.55, green: 0.1, blue: 0.5) : Color(red: 0.15, green: 0.15, blue: 0.25)))
        ctx.fill(Path(roundedRect: CGRect(x: mx - 55, y: 180, width: 110, height: 40), cornerRadius: 10), with: .color(princess ? .pink : .blue))
        label(ctx, princess ? "PRINCESS" : "POKER", CGPoint(x: mx, y: 200), size: 15, color: .white)
        let screen = CGRect(x: mx - 48, y: 232, width: 96, height: 90)
        let lit = !empty || princess
        ctx.fill(Path(roundedRect: screen, cornerRadius: 6), with: .color(lit ? Color(red: 0.05, green: 0.05, blue: 0.45) : Color(white: 0.05)))
        if princess {
            var sub = ctx
            sub.clip(to: Path(roundedRect: screen, cornerRadius: 6))
            sub.translateBy(x: screen.minX, y: screen.minY)
            if let (skin, look) = second {
                let half = CGSize(width: screen.width / 2, height: screen.height)
                drawGirlBust(sub, size: half, skin: .princessSkin, look: .princess, talking: false, now: now)
                var right = sub
                right.translateBy(x: half.width, y: 0)
                drawGirlBust(right, size: half, skin: skin, look: look, talking: false, now: now)
            } else {
                drawGirlBust(sub, size: screen.size, skin: .princessSkin, look: .princess, talking: false, now: now)
            }
        } else if lit {
            for k in 0..<5 {
                ctx.fill(rect(screen.minX + 6 + Double(k) * 18, screen.midY, 14, 22), with: .color(.white))
            }
        }
        ctx.fill(rect(mx - 50, 335, 100, 20), with: .color(Color(white: 0.3)))
        for k in 0..<4 {
            ctx.fill(oval(CGPoint(x: mx - 36 + Double(k) * 24, y: 345), 6), with: .color(lit ? [Color.red, .yellow, .green, .blue][k] : .gray))
        }
    }
    if empty {
        ctx.fill(rect(0, 0, Stage.W, Stage.H), with: .color(.black.opacity(0.35)))
    }
}

/// A gold arm from the Princess machine holding a pink atomizer bottle, and its mist.
private func drawPerfume(_ ctx: GraphicsContext, _ p: PerfumeBlast, now: Date) {
    let r = p.reach(at: now)
    let tip = CGPoint(x: p.cabinet.x + (p.nozzle.x - p.cabinet.x) * r, y: p.cabinet.y + (p.nozzle.y - p.cabinet.y) * r)
    var arm = Path()
    arm.move(to: p.cabinet)
    arm.addQuadCurve(to: CGPoint(x: tip.x + 18, y: tip.y + 26), control: CGPoint(x: (p.cabinet.x + tip.x) / 2 + 10, y: p.cabinet.y + 30))
    ctx.stroke(arm, with: .color(Color(red: 0.85, green: 0.65, blue: 0.2)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
    // Bottle: faceted pink glass, gold collar, nozzle pointing at the face.
    let bottle = CGRect(x: tip.x - 2, y: tip.y + 4, width: 36, height: 40)
    ctx.fill(Path(roundedRect: bottle, cornerRadius: 9), with: .color(Color(red: 1, green: 0.55, blue: 0.78).opacity(0.9)))
    ctx.fill(Path(roundedRect: bottle.insetBy(dx: 8, dy: 10), cornerRadius: 5), with: .color(.white.opacity(0.35)))
    ctx.fill(rect(tip.x + 8, tip.y - 6, 16, 11), with: .color(Color(red: 0.95, green: 0.78, blue: 0.3)))
    ctx.fill(rect(tip.x - 8, tip.y - 3, 18, 5), with: .color(Color(red: 0.95, green: 0.78, blue: 0.3)))
    let spray = p.spray(at: now)
    if spray != nil { drawTwinkle(ctx, CGPoint(x: tip.x + 32, y: tip.y - 2), 6, .white) }
    guard let t = spray else { return }
    let mouth = CGPoint(x: tip.x - 8, y: tip.y - 1)
    let fade = min(1, (p.dur - t) / 0.6)
    let mist = Color(red: 1, green: 0.72, blue: 0.9)
    // A soft cone from the nozzle, then the cloud gathering around the face.
    var cone = Path()
    cone.move(to: mouth)
    cone.addLine(to: CGPoint(x: p.target.x - 10, y: p.target.y - 40))
    cone.addLine(to: CGPoint(x: p.target.x - 10, y: p.target.y + 40))
    cone.closeSubpath()
    ctx.fill(cone, with: .linearGradient(Gradient(colors: [mist.opacity(0.55 * fade), mist.opacity(0.12 * fade)]), startPoint: mouth, endPoint: p.target))
    let cloud = min(1, t / 4) * fade
    ctx.fill(Path(ellipseIn: CGRect(x: p.target.x - 70, y: p.target.y - 60, width: 140, height: 120)), with: .color(mist.opacity(0.28 * cloud)))
    for i in 0..<48 {
        let seed = Double(i) * 12.9898
        let ph = (t * 1.6 + Double(i) / 48).truncatingRemainder(dividingBy: 1)
        let wob = sin(seed) * 0.5 + 0.5
        let spread = (wob - 0.5) * 90 * ph
        let x = mouth.x + (p.target.x - 20 - mouth.x) * ph
        let y = mouth.y + (p.target.y - mouth.y) * ph + spread + sin(t * 5 + seed) * 4
        let size = 3 + 7 * ph
        ctx.fill(Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)),
                 with: .color((i % 3 == 0 ? Color.white : mist).opacity((1 - ph * 0.7) * 0.8 * fade)))
    }
}

// MARK: Running home

private func drawStreet(_ ctx: GraphicsContext, _ now: Date, offset: Double) {
    sky(ctx, [Color(red: 0.02, green: 0.03, blue: 0.15), Color(red: 0.1, green: 0.1, blue: 0.3)], to: 470)
    stars(ctx, now, below: 200)
    ctx.fill(oval(CGPoint(x: 820, y: 90), 34), with: .color(Color(red: 1, green: 0.97, blue: 0.85)))
    let spacing = 280.0
    let shift = offset.truncatingRemainder(dividingBy: spacing)
    let base = Int(offset / spacing)
    let colors = [Color(red: 0.55, green: 0.35, blue: 0.3), Color(red: 0.3, green: 0.4, blue: 0.55), Color(red: 0.45, green: 0.5, blue: 0.35), Color(red: 0.6, green: 0.55, blue: 0.4)]
    for k in -1...5 {
        let x = Double(k) * spacing - shift
        let c = colors[((k + base) % 4 + 4) % 4]
        ctx.fill(rect(x + 30, 300, 200, 170), with: .color(c))
        var roof = Path()
        roof.move(to: CGPoint(x: x + 15, y: 300)); roof.addLine(to: CGPoint(x: x + 130, y: 220)); roof.addLine(to: CGPoint(x: x + 245, y: 300)); roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.2, green: 0.12, blue: 0.12)))
        for wx in [x + 55, x + 160] {
            ctx.fill(rect(wx, 330, 45, 40), with: .color(Color(red: 1, green: 0.85, blue: 0.45)))
        }
        ctx.fill(rect(x + 110, 390, 40, 80), with: .color(Color(red: 0.3, green: 0.18, blue: 0.1)))
        let lamp = x + spacing - 10
        ctx.fill(rect(lamp - 3, 360, 6, 160), with: .color(Color(white: 0.2)))
        ctx.fill(oval(CGPoint(x: lamp, y: 356), 10), with: .color(Color(red: 1, green: 0.95, blue: 0.7)))
    }
    ctx.fill(rect(0, 470, Stage.W, 50), with: .color(Color(red: 0.15, green: 0.35, blue: 0.15)))
    ctx.fill(rect(0, 520, Stage.W, 40), with: .color(Color(white: 0.55)))
    ctx.fill(rect(0, 560, Stage.W, 40), with: .color(Color(white: 0.18)))
    let dash = (offset * 1.0).truncatingRemainder(dividingBy: 80)
    for i in 0..<15 {
        ctx.fill(rect(Double(i) * 80 - dash, 578, 40, 4), with: .color(.yellow))
    }
}

// MARK: Downtown

private func drawStorefronts(_ ctx: GraphicsContext, _ now: Date, shops: [(String, Color, Double, Double)]) {
    sky(ctx, [Color(red: 0.25, green: 0.15, blue: 0.45), Color(red: 0.95, green: 0.5, blue: 0.45)], to: 520)
    for (name, color, x, w) in shops {
        ctx.fill(rect(x, 280, w - 10, 240), with: .color(color))
        ctx.fill(rect(x + 10, 290, w - 30, 36), with: .color(Color(white: 0.12)))
        label(ctx, name, CGPoint(x: x + (w - 10) / 2, y: 308), size: min(20, (w - 40) / Double(max(name.count, 1)) * 1.7), color: .yellow)
        // Striped awning
        for k in 0..<Int((w - 10) / 20) {
            ctx.fill(rect(x + Double(k) * 20, 336, 20, 22), with: .color(k % 2 == 0 ? .white : color.opacity(0.6)))
        }
        ctx.fill(rect(x + 18, 370, (w - 10) * 0.45, 100), with: .color(Color(red: 0.7, green: 0.85, blue: 0.95).opacity(0.85)))
        ctx.fill(rect(x + (w - 10) * 0.62, 400, (w - 10) * 0.25, 120), with: .color(Color(red: 0.3, green: 0.18, blue: 0.12)))
    }
    ctx.fill(rect(0, 520, Stage.W, 40), with: .color(Color(white: 0.6)))
    ctx.fill(rect(0, 556, Stage.W, 4), with: .color(Color(white: 0.4)))
    ctx.fill(rect(0, 560, Stage.W, 40), with: .color(Color(white: 0.22)))
}

private func drawDowntown(_ ctx: GraphicsContext, _ now: Date) {
    // Four shops; the Princess's salon parks in the last spot (x 680–1000) at night.
    drawStorefronts(ctx, now, shops: [("DINER", Color(red: 0.2, green: 0.55, blue: 0.6), 0, 170), ("BOOKS", Color(red: 0.55, green: 0.3, blue: 0.2), 170, 170),
                                      ("PIZZA", Color(red: 0.75, green: 0.2, blue: 0.15), 340, 170), ("HARDWARE", Color(red: 0.35, green: 0.4, blue: 0.3), 510, 170)])
}

private func drawTown(_ ctx: GraphicsContext, _ now: Date) {
    drawStorefronts(ctx, now, shops: [("FRESH MARKET", Color(red: 0.25, green: 0.55, blue: 0.25), 60, 380),
                                      ("FIRST NATIONAL BANK", Color(red: 0.55, green: 0.55, blue: 0.6), 560, 400)])
    for x in [600.0, 660, 880, 940] {
        ctx.fill(rect(x, 370, 16, 150), with: .color(Color(white: 0.85)))
    }
}

// MARK: The flying beauty salon

func drawSalonShip(_ ctx: GraphicsContext, _ ship: SalonShip, now: Date, scale s: Double, neon: Bool) {
    let bottom = ship.bottom(at: now)
    let cx = ship.x
    let W = 400 * s, H = 240 * s
    let top = bottom - 22 * s - H
    let t = now.timeIntervalSinceReferenceDate
    if ship.flying {
        for dx in [-130.0, 0, 130] {
            let flicker = 0.8 + 0.2 * sin(t * 30 + dx)
            ctx.fill(Path(ellipseIn: CGRect(x: cx + dx * s - 26 * s, y: bottom - 4 * s, width: 52 * s, height: 46 * s * flicker)),
                     with: .radialGradient(Gradient(colors: [.white, .yellow, .pink.opacity(0)]), center: CGPoint(x: cx + dx * s, y: bottom + 6 * s), startRadius: 2, endRadius: 30 * s))
        }
    } else {
        for dx in [-150.0, 150] {
            ctx.stroke(Path { $0.move(to: CGPoint(x: cx + dx * s, y: bottom - 10 * s)); $0.addLine(to: CGPoint(x: cx + dx * 1.1 * s, y: bottom + 8 * s)) },
                       with: .color(Color(white: 0.6)), lineWidth: 6 * s)
        }
    }
    ctx.fill(Path(roundedRect: CGRect(x: cx - W / 2 - 14 * s, y: bottom - 24 * s, width: W + 28 * s, height: 24 * s), cornerRadius: 10 * s),
             with: .color(Color(red: 0.35, green: 0.1, blue: 0.45)))
    for i in 0..<9 {
        let on = (i + Int(t * 4)) % 2 == 0
        ctx.fill(oval(CGPoint(x: cx - W / 2 + Double(i) * W / 8, y: bottom - 12 * s), 4 * s), with: .color(on ? .yellow : .pink))
    }
    // Walls
    ctx.fill(rect(cx - W / 2, top, W, H), with: .color(Color(red: 1, green: 0.76, blue: 0.86)))
    for k in 0..<10 where k % 2 == 0 {
        ctx.fill(rect(cx - W / 2 + Double(k) * W / 10, top + 70 * s, W / 10, H - 70 * s), with: .color(.white.opacity(0.35)))
    }
    // Cornice + crown
    ctx.fill(rect(cx - W / 2 - 8 * s, top - 14 * s, W + 16 * s, 18 * s), with: .color(Color(red: 0.5, green: 0.15, blue: 0.6)))
    var crown = Path()
    let cy = top - 14 * s
    crown.move(to: CGPoint(x: cx - 34 * s, y: cy)); crown.addLine(to: CGPoint(x: cx - 42 * s, y: cy - 34 * s)); crown.addLine(to: CGPoint(x: cx - 18 * s, y: cy - 16 * s))
    crown.addLine(to: CGPoint(x: cx, y: cy - 42 * s)); crown.addLine(to: CGPoint(x: cx + 18 * s, y: cy - 16 * s)); crown.addLine(to: CGPoint(x: cx + 42 * s, y: cy - 34 * s))
    crown.addLine(to: CGPoint(x: cx + 34 * s, y: cy)); crown.closeSubpath()
    ctx.fill(crown, with: .color(.yellow))
    // Sign
    let sign = CGRect(x: cx - 160 * s, y: top + 8 * s, width: 320 * s, height: 56 * s)
    if neon {
        let glow = 0.7 + 0.3 * sin(t * 9)
        ctx.stroke(Path(roundedRect: sign.insetBy(dx: -6 * s, dy: -6 * s), cornerRadius: 14 * s), with: .color(Color.pink.opacity(0.35 * glow)), lineWidth: 14 * s)
        ctx.stroke(Path(roundedRect: sign.insetBy(dx: -6 * s, dy: -6 * s), cornerRadius: 14 * s), with: .color(Color(red: 1, green: 0.5, blue: 0.9).opacity(glow)), lineWidth: 3 * s)
    }
    ctx.fill(Path(roundedRect: sign, cornerRadius: 10 * s), with: .color(Color(red: 0.45, green: 0.1, blue: 0.55)))
    label(ctx, "PRINCESS OF POKER", CGPoint(x: cx, y: sign.minY + 22 * s), size: 26 * s, color: .yellow)
    label(ctx, "BEAUTY SALON", CGPoint(x: cx, y: sign.minY + 45 * s), size: 14 * s, color: .white, weight: .heavy)
    // Awning
    let awY = top + 76 * s
    for k in 0..<16 {
        let x = cx - W / 2 + Double(k) * W / 16
        ctx.fill(rect(x, awY, W / 16, 18 * s), with: .color(k % 2 == 0 ? Color.pink : .white))
        ctx.fill(oval(CGPoint(x: x + W / 32, y: awY + 18 * s), W / 32), with: .color(k % 2 == 0 ? Color.pink : .white))
    }
    // Windows with hood dryers
    for side in [-1.0, 1.0] {
        let win = CGRect(x: cx + side * 120 * s - 60 * s, y: top + 112 * s, width: 120 * s, height: 90 * s)
        ctx.fill(Path(roundedRect: win, cornerRadius: 8 * s), with: .color(Color(red: 1, green: 0.93, blue: 0.75)))
        for k in 0..<2 {
            let dx = win.minX + 32 * s + Double(k) * 56 * s
            ctx.fill(Path(ellipseIn: CGRect(x: dx - 20 * s, y: win.minY + 12 * s, width: 40 * s, height: 34 * s)), with: .color(Color(red: 0.75, green: 0.5, blue: 0.85)))
            ctx.fill(rect(dx - 3 * s, win.minY + 44 * s, 6 * s, 40 * s), with: .color(Color(white: 0.5)))
        }
        ctx.stroke(Path(roundedRect: win, cornerRadius: 8 * s), with: .color(.white), lineWidth: 4 * s)
    }
    // Door
    let door = CGRect(x: cx - 36 * s, y: bottom - 22 * s - 120 * s, width: 72 * s, height: 120 * s)
    if ship.doorOpen {
        ctx.fill(Path(roundedRect: door, cornerRadius: 30 * s), with: .linearGradient(Gradient(colors: [Color(red: 1, green: 0.9, blue: 0.6), Color(red: 1, green: 0.6, blue: 0.8)]),
                                                                                       startPoint: CGPoint(x: door.midX, y: door.minY), endPoint: CGPoint(x: door.midX, y: door.maxY)))
    } else {
        ctx.fill(Path(roundedRect: door, cornerRadius: 30 * s), with: .color(Color(red: 0.55, green: 0.15, blue: 0.6)))
        drawTwinkle(ctx, CGPoint(x: door.midX, y: door.minY + 40 * s), 14 * s, .yellow)
        ctx.fill(oval(CGPoint(x: door.maxX - 14 * s, y: door.midY + 10 * s), 5 * s), with: .color(.yellow))
    }
    ctx.stroke(Path(roundedRect: door, cornerRadius: 30 * s), with: .color(.white), lineWidth: 4 * s)
}

func drawBeam(_ ctx: GraphicsContext, _ b: Beam, now: Date) {
    var p = Path()
    p.move(to: CGPoint(x: b.x - 30, y: b.top))
    p.addLine(to: CGPoint(x: b.x + 30, y: b.top))
    p.addLine(to: CGPoint(x: b.x + 80, y: b.bottom))
    p.addLine(to: CGPoint(x: b.x - 80, y: b.bottom))
    p.closeSubpath()
    ctx.fill(p, with: .linearGradient(Gradient(colors: [Color.yellow.opacity(0.55), Color.pink.opacity(0.3)]),
                                      startPoint: CGPoint(x: b.x, y: b.top), endPoint: CGPoint(x: b.x, y: b.bottom)))
    let t = now.timeIntervalSinceReferenceDate
    var ctx2 = ctx
    ctx2.clip(to: p)
    for k in 0..<8 {
        let u = (Double(k) / 8 + t * 0.5).truncatingRemainder(dividingBy: 1)
        let y = b.bottom - u * (b.bottom - b.top)
        ctx2.fill(rect(b.x - 90, y, 180, 3), with: .color(.white.opacity(0.35)))
        drawTwinkle(ctx2, CGPoint(x: b.x + sin(t * 3 + Double(k) * 2) * 50, y: y - 10), 6, .white)
    }
}

// MARK: Inside the salon

private func drawSalonInside(_ ctx: GraphicsContext, _ d: Director, _ now: Date) {
    let owned = d.save.owned
    ctx.fill(rect(0, 0, Stage.W, 440), with: .color(Color(red: 1, green: 0.78, blue: 0.88)))
    for k in 0..<25 where k % 2 == 0 {
        ctx.fill(rect(Double(k) * 40, 30, 40, 390), with: .color(.white.opacity(0.3)))
    }
    ctx.fill(rect(0, 0, Stage.W, 30), with: .color(Color(red: 0.45, green: 0.12, blue: 0.55)))
    ctx.fill(rect(0, 418, Stage.W, 22), with: .color(Color(red: 0.85, green: 0.65, blue: 0.2)))
    for i in 0..<20 { for j in 0..<4 {
        ctx.fill(rect(Double(i) * 50, 440 + Double(j) * 40, 50, 40), with: .color((i + j) % 2 == 0 ? Color(white: 0.95) : Color(white: 0.12)))
    } }
    // Poker-room door
    ctx.fill(Path(roundedRect: CGRect(x: 18, y: 290, width: 78, height: 150), cornerRadius: 6), with: .color(Color(red: 0.45, green: 0.12, blue: 0.55)))
    ctx.fill(Path(roundedRect: CGRect(x: 22, y: 262, width: 70, height: 22), cornerRadius: 4), with: .color(.yellow))
    label(ctx, "POKER ROOM", CGPoint(x: 57, y: 273), size: 10, color: .black)
    ctx.fill(oval(CGPoint(x: 84, y: 370), 4), with: .color(.yellow))
    let t = now.timeIntervalSinceReferenceDate
    if owned.contains(.chandelier) {
        let c = CGPoint(x: 160, y: 30)
        ctx.stroke(Path { $0.move(to: c); $0.addLine(to: CGPoint(x: c.x, y: 70)) }, with: .color(.yellow), lineWidth: 2)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 45, y: 70, width: 90, height: 24)), with: .color(Color.yellow.opacity(0.85)))
        for k in 0..<7 {
            let x = c.x - 42 + Double(k) * 14
            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 92)); $0.addLine(to: CGPoint(x: x, y: 112 + Double(k % 3) * 6)) }, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
            drawTwinkle(ctx, CGPoint(x: x, y: 114 + Double(k % 3) * 6), 5 * (0.5 + 0.5 * sin(t * 3 + Double(k))), .white)
        }
    }
    if owned.contains(.champagne) {
        let base = CGPoint(x: 150, y: 540)
        for (k, w) in [70.0, 50, 32].enumerated() {
            let y = base.y - 40 - Double(k) * 38
            ctx.fill(Path(ellipseIn: CGRect(x: base.x - w / 2, y: y, width: w, height: 12)), with: .color(Color(red: 1, green: 0.9, blue: 0.6).opacity(0.85)))
            ctx.stroke(Path(ellipseIn: CGRect(x: base.x - w / 2, y: y, width: w, height: 12)), with: .color(.white), lineWidth: 1.5)
        }
        ctx.fill(rect(base.x - 4, base.y - 120, 8, 120), with: .color(Color(white: 0.8)))
        for k in 0..<5 {
            let u = (t * 0.8 + Double(k) / 5).truncatingRemainder(dividingBy: 1)
            ctx.fill(oval(CGPoint(x: base.x - 30 + Double(k) * 15, y: base.y - 110 + u * 70), 2.5), with: .color(.yellow.opacity(1 - u)))
        }
    }
    // Chairs with transformation hoods
    let plush = owned.contains(.plushChairs)
    for x in SalonSpot.chairX {
        let g = Stage.ground
        ctx.fill(Path(roundedRect: CGRect(x: x - 64, y: g - 230, width: 128, height: 205), cornerRadius: 26),
                 with: .color(plush ? Color(red: 0.45, green: 0.1, blue: 0.55) : Color(red: 0.8, green: 0.1, blue: 0.2)))
        if plush {
            for k in 0..<6 {
                ctx.fill(oval(CGPoint(x: x - 34 + Double(k % 3) * 34, y: g - 190 + Double(k / 3) * 60), 4), with: .color(.yellow))
            }
        }
        ctx.fill(rect(x - 70, g - 75, 140, 18), with: .color(Color(white: 0.75)))
        ctx.fill(rect(x - 14, g - 30, 28, 30), with: .color(Color(white: 0.7)))
        ctx.fill(Path(ellipseIn: CGRect(x: x - 44, y: g - 8, width: 88, height: 14)), with: .color(Color(white: 0.55)))
        // Hood ring over the head
        var hood = Path()
        hood.addArc(center: CGPoint(x: x, y: g - 205), radius: 82, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        let active = now < d.machineOnUntil
        ctx.stroke(hood, with: .color(Color(white: 0.8)), lineWidth: 16)
        ctx.stroke(hood, with: .color(active ? Color.yellow.opacity(0.6 + 0.4 * sin(t * 12)) : Color(white: 0.55)), lineWidth: 5)
        ctx.fill(rect(x - 6, g - 300, 12, 18), with: .color(Color(white: 0.7)))
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: g - 300)); $0.addLine(to: CGPoint(x: x, y: 30)) }, with: .color(Color(white: 0.6)), lineWidth: 4)
    }
    drawWallMirror(ctx, d, now, at: CGPoint(x: SalonSpot.mirrorX, y: SalonSpot.mirrorY), stand: SalonSpot.mirrorStand)
    drawRetractMirror(ctx, d, now)
    // Console with the yellow button
    let b = SalonSpot.button
    ctx.fill(Path(roundedRect: CGRect(x: b.x - 48, y: b.y + 10, width: 96, height: Stage.ground - b.y - 10), cornerRadius: 10), with: .color(Color(red: 0.4, green: 0.3, blue: 0.5)))
    for k in 0..<3 {
        let on = (k + Int(t * 3)) % 3 == 0
        ctx.fill(oval(CGPoint(x: b.x - 24 + Double(k) * 24, y: b.y + 60), 7), with: .color(on ? .green : Color(white: 0.3)))
    }
    label(ctx, "FINAL GAME", CGPoint(x: b.x, y: b.y + 100), size: 11, color: .yellow)
    let pressed = now.timeIntervalSince(d.buttonPressT0) < 0.4
    ctx.fill(Path(ellipseIn: CGRect(x: b.x - 26, y: b.y - (pressed ? 4 : 10), width: 52, height: 22)), with: .color(Color(red: 0.75, green: 0.6, blue: 0)))
    ctx.fill(Path(ellipseIn: CGRect(x: b.x - 24, y: b.y - (pressed ? 8 : 18), width: 48, height: 20)), with: .color(.yellow))
    if now.timeIntervalSince(d.buttonPressT0) < 1.2 {
        ctx.fill(oval(CGPoint(x: b.x, y: b.y - 8), 40), with: .color(Color.yellow.opacity(0.25)))
    }
}

/// The retractable mirror: lowers on two cables from a slot in the ceiling and shows everyone standing under it at once.
private func drawRetractMirror(_ ctx: GraphicsContext, _ d: Director, _ now: Date) {
    let drop = d.retractMirror.drop(at: now)
    let full = SalonSpot.retractRect
    // Ceiling slot it retracts into.
    ctx.fill(rect(full.minX - 14, 30, full.width + 28, 8), with: .color(Color(white: 0.3)))
    guard drop > 0.001 else { return }
    let glass = full.offsetBy(dx: 0, dy: -(full.maxY - 30) * (1 - drop))
    var c = ctx
    c.clip(to: rect(0, 34, Stage.W, Stage.H))
    for x in [glass.minX + 40, glass.maxX - 40] {
        c.stroke(Path { $0.move(to: CGPoint(x: x, y: 30)); $0.addLine(to: CGPoint(x: x, y: glass.minY)) }, with: .color(Color(white: 0.45)), lineWidth: 2.5)
    }
    let gold = d.save.has(.goldMirror)
    let frame = gold ? Color(red: 0.9, green: 0.7, blue: 0.2) : Color(white: 0.85)
    c.fill(Path(roundedRect: glass.insetBy(dx: -10, dy: -10), cornerRadius: 14), with: .color(frame))
    c.stroke(Path(roundedRect: glass.insetBy(dx: -10, dy: -10), cornerRadius: 14), with: .color(.black.opacity(0.15)), lineWidth: 1.5)
    if gold {
        for k in 0..<16 {
            c.fill(oval(CGPoint(x: glass.minX + Double(k) / 15 * glass.width, y: glass.minY - 5), 3.5), with: .color(k % 2 == 0 ? .pink : .white))
            c.fill(oval(CGPoint(x: glass.minX + Double(k) / 15 * glass.width, y: glass.maxY + 5), 3.5), with: .color(k % 2 == 0 ? .white : .pink))
        }
    }
    c.fill(Path(roundedRect: glass, cornerRadius: 8), with: .linearGradient(Gradient(colors: [Color(red: 0.85, green: 0.93, blue: 1), Color(red: 0.6, green: 0.75, blue: 0.9)]),
                                                                          startPoint: CGPoint(x: glass.minX, y: glass.minY), endPoint: CGPoint(x: glass.maxX, y: glass.maxY)))
    // Reflections: head and shoulders of everyone standing (not strapped in) under the glass, each above herself.
    var r = c
    r.clip(to: Path(roundedRect: glass, cornerRadius: 8))
    for p in d.people where p.visible && !p.strapped && p.x(at: now) > glass.minX + 30 && p.x(at: now) < glass.maxX - 30 {
        let face = p.face(at: now)
        var m = r
        m.translateBy(x: face.x, y: glass.midY - 4)
        m.scaleBy(x: -0.8, y: 0.8)
        m.translateBy(x: -face.x, y: -face.y)
        drawPerson(m, p, now: now)
    }
    for k in 0..<3 {
        let x = glass.minX + 40 + Double(k) * 170
        c.stroke(Path { $0.move(to: CGPoint(x: x, y: glass.minY + 18)); $0.addLine(to: CGPoint(x: x + 24, y: glass.minY + 52)) },
                 with: .color(.white.opacity(0.5)), lineWidth: 4)
    }
}

/// An oval mirror hung on the wall, showing whoever stands right under it (at `stand`).
private func drawWallMirror(_ ctx: GraphicsContext, _ d: Director, _ now: Date, at c: CGPoint, stand: Double) {
    let glass = CGRect(x: c.x - 40, y: c.y - 72, width: 80, height: 144)
    let gold = d.save.has(.goldMirror)
    let frame = gold ? Color(red: 0.9, green: 0.7, blue: 0.2) : Color(white: 0.85)
    // Hook and wire
    ctx.stroke(Path { $0.move(to: CGPoint(x: c.x - 22, y: glass.minY + 6)); $0.addLine(to: CGPoint(x: c.x, y: glass.minY - 26)); $0.addLine(to: CGPoint(x: c.x + 22, y: glass.minY + 6)) },
               with: .color(Color(white: 0.45)), lineWidth: 2)
    ctx.fill(oval(CGPoint(x: c.x, y: glass.minY - 26), 4), with: .color(Color(white: 0.45)))
    ctx.fill(Path(ellipseIn: glass.insetBy(dx: -9, dy: -9)), with: .color(frame))
    ctx.stroke(Path(ellipseIn: glass.insetBy(dx: -9, dy: -9)), with: .color(.black.opacity(0.15)), lineWidth: 1.5)
    if gold {
        for k in 0..<12 {
            let a = Double(k) / 12 * 2 * .pi
            ctx.fill(oval(CGPoint(x: c.x + cos(a) * (glass.width / 2 + 5), y: c.y + sin(a) * (glass.height / 2 + 5)), 3.5), with: .color(k % 2 == 0 ? .pink : .white))
        }
    }
    ctx.fill(Path(ellipseIn: glass), with: .linearGradient(Gradient(colors: [Color(red: 0.85, green: 0.93, blue: 1), Color(red: 0.6, green: 0.75, blue: 0.9)]),
                                                         startPoint: CGPoint(x: glass.minX, y: glass.minY), endPoint: CGPoint(x: glass.maxX, y: glass.maxY)))
    // The reflection: head and shoulders of whoever stands under the mirror, flipped.
    var r = ctx
    r.clip(to: Path(ellipseIn: glass))
    for p in d.people where p.visible && abs(p.x(at: now) - stand) < 15 {
        let face = p.face(at: now)
        var m = r
        m.translateBy(x: c.x, y: c.y - 6)
        m.scaleBy(x: -0.8, y: 0.8)
        m.translateBy(x: -face.x, y: -face.y)
        drawPerson(m, p, now: now)
    }
    ctx.stroke(Path { $0.move(to: CGPoint(x: glass.minX + 14, y: glass.minY + 30)); $0.addLine(to: CGPoint(x: glass.minX + 26, y: glass.minY + 62)) },
               with: .color(.white.opacity(0.55)), lineWidth: 4)
}

// MARK: Speech bubbles

private func drawBubble(_ ctx: GraphicsContext, _ text: String, anchor: CGPoint, k: Double, bounds: CGSize, color: Color = .white) {
    let resolved = ctx.resolve(Text(text).font(.system(size: 17 * k, weight: .bold, design: .rounded)).foregroundStyle(Color.black))
    let maxW = 300 * k
    let m = resolved.measure(in: CGSize(width: maxW, height: 600 * k))
    let pad = 10 * k
    var box = CGRect(x: anchor.x - m.width / 2 - pad, y: anchor.y - m.height - 2 * pad - 16 * k, width: m.width + 2 * pad, height: m.height + 2 * pad)
    box.origin.x = min(max(box.minX, 6), bounds.width - box.width - 6)
    box.origin.y = max(box.minY, 6)
    var tail = Path()
    let tx = min(max(anchor.x, box.minX + 14 * k), box.maxX - 14 * k)
    tail.move(to: CGPoint(x: tx - 8 * k, y: box.maxY - 1))
    tail.addLine(to: CGPoint(x: anchor.x, y: min(anchor.y - 2 * k, box.maxY + 14 * k)))
    tail.addLine(to: CGPoint(x: tx + 8 * k, y: box.maxY - 1))
    ctx.fill(tail, with: .color(color))
    ctx.fill(Path(roundedRect: box, cornerRadius: 12 * k), with: .color(color))
    ctx.stroke(Path(roundedRect: box, cornerRadius: 12 * k), with: .color(.black.opacity(0.25)), lineWidth: 1.5)
    ctx.draw(resolved, in: box.insetBy(dx: pad, dy: pad))
}

// MARK: Inside the little bathroom

enum BathSpot {
    static let toiletX = 500.0
    static let handle = CGPoint(x: 566, y: 378)
}

func drawBathroom(_ ctx: GraphicsContext, _ now: Date) {
    // Pale blue tiles, a pink border and a checkered floor.
    ctx.fill(rect(0, 0, Stage.W, 470), with: .color(Color(red: 0.82, green: 0.93, blue: 0.98)))
    for x in stride(from: 0.0, through: Stage.W, by: 40) {
        ctx.fill(rect(x, 0, 1.5, 470), with: .color(.white))
    }
    for y in stride(from: 0.0, through: 470, by: 40) {
        ctx.fill(rect(0, y, Stage.W, 1.5), with: .color(.white))
    }
    ctx.fill(rect(0, 300, Stage.W, 14), with: .color(Color(red: 0.95, green: 0.5, blue: 0.72)))
    for i in 0..<25 { for j in 0..<4 {
        ctx.fill(rect(Double(i) * 40, 470 + Double(j) * 32.5, 40, 32.5),
                 with: .color((i + j) % 2 == 0 ? Color(white: 0.96) : Color(red: 0.85, green: 0.7, blue: 0.85)))
    } }
    // Door back to the bedroom (left)
    ctx.fill(Path(roundedRect: CGRect(x: 30, y: 250, width: 120, height: 220), cornerRadius: 4), with: .color(Color(red: 0.92, green: 0.92, blue: 0.96)))
    ctx.stroke(Path(CGRect(x: 30, y: 250, width: 120, height: 220)), with: .color(Color(red: 0.45, green: 0.12, blue: 0.55)), lineWidth: 6)
    ctx.fill(oval(CGPoint(x: 132, y: 370), 6), with: .color(.yellow))
    // Little porthole with the night sky
    let c = CGPoint(x: 290, y: 150)
    var w = ctx
    w.clip(to: oval(c, 44))
    w.fill(oval(c, 44), with: .color(Color(red: 0.05, green: 0.05, blue: 0.22)))
    stars(w, now, below: 260)
    ctx.stroke(oval(c, 44), with: .color(.yellow), lineWidth: 7)
    // Toilet paper on the wall
    ctx.fill(rect(612, 404, 30, 4), with: .color(Color(white: 0.7)))
    ctx.fill(Path(roundedRect: CGRect(x: 614, y: 396, width: 30, height: 34), cornerRadius: 6), with: .color(.white))
    ctx.fill(rect(624, 430, 16, 26), with: .color(.white))
    // Toilet: tank against the wall, seat and bowl in front.
    let tx = BathSpot.toiletX
    let white = Color.white, line = Color(white: 0.75)
    ctx.fill(Path(roundedRect: CGRect(x: tx - 62, y: 350, width: 124, height: 100), cornerRadius: 10), with: .color(white))
    ctx.stroke(Path(roundedRect: CGRect(x: tx - 62, y: 350, width: 124, height: 100), cornerRadius: 10), with: .color(line), lineWidth: 2)
    ctx.fill(Path(roundedRect: CGRect(x: tx - 68, y: 340, width: 136, height: 16), cornerRadius: 6), with: .color(white))
    ctx.stroke(Path(roundedRect: CGRect(x: tx - 68, y: 340, width: 136, height: 16), cornerRadius: 6), with: .color(line), lineWidth: 2)
    ctx.fill(Path(roundedRect: CGRect(x: BathSpot.handle.x - 16, y: BathSpot.handle.y - 4, width: 22, height: 8), cornerRadius: 4), with: .color(Color(white: 0.7)))
    ctx.fill(Path(roundedRect: CGRect(x: tx - 34, y: 486, width: 68, height: 54), cornerRadius: 10), with: .color(white))
    ctx.stroke(Path(roundedRect: CGRect(x: tx - 34, y: 486, width: 68, height: 54), cornerRadius: 10), with: .color(line), lineWidth: 2)
    ctx.fill(Path(ellipseIn: CGRect(x: tx - 66, y: 474, width: 132, height: 28)), with: .color(Color(red: 1, green: 0.8, blue: 0.9)))
    ctx.stroke(Path(ellipseIn: CGRect(x: tx - 66, y: 474, width: 132, height: 28)), with: .color(line), lineWidth: 2)
    // Pink rug
    ctx.fill(Path(ellipseIn: CGRect(x: tx - 90, y: 545, width: 180, height: 34)), with: .color(Color(red: 0.95, green: 0.5, blue: 0.72).opacity(0.85)))
    // Sink with a mirror above it (right)
    ctx.fill(Path(roundedRect: CGRect(x: 790, y: 160, width: 130, height: 150), cornerRadius: 12), with: .color(Color(red: 0.7, green: 0.85, blue: 0.95)))
    ctx.stroke(Path(roundedRect: CGRect(x: 790, y: 160, width: 130, height: 150), cornerRadius: 12), with: .color(.yellow), lineWidth: 6)
    drawTwinkle(ctx, CGPoint(x: 820, y: 190), 9)
    ctx.fill(rect(838, 400, 34, 140), with: .color(white))
    ctx.fill(Path(roundedRect: CGRect(x: 780, y: 360, width: 150, height: 44), cornerRadius: 14), with: .color(white))
    ctx.stroke(Path(roundedRect: CGRect(x: 780, y: 360, width: 150, height: 44), cornerRadius: 14), with: .color(line), lineWidth: 2)
    ctx.fill(rect(851, 336, 8, 26), with: .color(Color(white: 0.7)))
    // Towel on a rail
    ctx.fill(rect(680, 300, 70, 5), with: .color(Color(white: 0.7)))
    ctx.fill(Path(roundedRect: CGRect(x: 688, y: 302, width: 54, height: 90), cornerRadius: 4), with: .color(Color(red: 0.95, green: 0.6, blue: 0.8)))
    ctx.fill(rect(688, 372, 54, 6), with: .color(.white.opacity(0.7)))
}

// MARK: Stage

func drawStage(_ ctx: GraphicsContext, size: CGSize, director d: Director, now: Date) {
    let k = size.width / Stage.W
    var world = ctx
    world.scaleBy(x: k, y: k)
    let (center, zoom) = d.camera.shot(at: now)
    world.translateBy(x: Stage.W / 2, y: Stage.H / 2)
    world.scaleBy(x: zoom, y: zoom)
    world.translateBy(x: -center.x, y: -center.y)

    switch d.place {
    case .targetLot: drawTargetLot(world, now)
    case .casinoOutside: drawCasinoOutside(world, now)
    case .casino: drawCasino(world, now, empty: d.casinoEmpty, second: d.casinoSecondGirl ? (d.you.skin, d.you.girl) : nil)
    case .street: drawStreet(world, now, offset: d.streetOffset(at: now))
    case .sidewalk: drawDowntown(world, now)
    case .salon: drawSalonInside(world, d, now)
    case .town: drawTown(world, now)
    case .venue: drawVenue(world, d.venue, now: now)
    case .home: drawHome(world, d, now)
    case .bedroom: drawBedroom(world, d, now)
    case .bathroom: drawBathroom(world, now)
    }
    if d.place == .targetLot {
        for i in 0..<d.corralCarts {
            drawCart(world, 110 + Double(i) * 22, 540)
        }
    }
    if let beam = d.beam { drawBeam(world, beam, now: now) }
    if d.shipShown { drawSalonShip(world, d.ship, now: now, scale: d.shipScale, neon: d.save.has(.neonSign)) }
    if d.place == .targetLot, d.pushingCarts > 0 {
        let x = d.you.x(at: now)
        for i in 0..<d.pushingCarts {
            drawCart(world, x - 74 - Double(i) * 24, 540)
        }
    }
    // A kisser leaning in goes behind the one she's kissing; then her face is drawn on top.
    let kissers = d.people.filter { $0.lean(at: now) != 0 }
    func order(_ p: Person) -> (Double, Int) { (p.baseY, kissers.contains { $0 === p } ? 0 : 1) }
    for p in d.people.sorted(by: { order($0) < order($1) }) {
        drawPerson(world, p, now: now)
    }
    for p in kissers { drawPerson(world, p, now: now, faceOnly: true) }
    for puff in d.puffs {
        guard let c = puff.position(at: now) else { continue }
        world.fill(Path(ellipseIn: CGRect(x: c.x - 26, y: c.y - 20, width: 52, height: 40)), with: .color(puff.color))
        for i in 0..<10 {
            let a = Double(i) / 10 * 2 * .pi
            world.fill(Path(ellipseIn: CGRect(x: c.x + cos(a) * 24 - 6, y: c.y + sin(a) * 18 - 6, width: 12, height: 12)), with: .color(puff.color))
        }
        world.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.8)))
        drawTwinkle(world, CGPoint(x: c.x + 20, y: c.y - 20), 7, .white)
    }
    if let p = d.perfume { drawPerfume(world, p, now: now) }
    for p in d.sprays { drawPerfume(world, p, now: now) }
    // Game 10: the casino lights drop to half.
    if d.place == .casino, d.casinoEmpty { world.fill(rect(-Stage.W, -Stage.H, 3 * Stage.W, 3 * Stage.H), with: .color(.black.opacity(0.5))) }
    if d.place == .bedroom, d.lightsOut > 0 { world.fill(rect(0, 0, Stage.W, Stage.H), with: .color(Color(red: 0.02, green: 0.0, blue: 0.08).opacity(0.72 * d.lightsOut))) }

    // Speech in screen space so it stays readable in close-ups.
    func toScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: ((p.x - center.x) * zoom + Stage.W / 2) * k, y: ((p.y - center.y) * zoom + Stage.H / 2) * k)
    }
    for p in d.people where p.visible {
        if let s = p.says, now < p.saysUntil {
            drawBubble(ctx, s, anchor: toScreen(p.headTop(at: now)), k: k, bounds: size)
        }
    }
    if let s = d.shipSays, now < d.shipSaysUntil, d.shipShown {
        let b = d.ship.bottom(at: now)
        drawBubble(ctx, s, anchor: toScreen(CGPoint(x: d.ship.x + 210 * d.shipScale, y: b - 230 * d.shipScale)), k: k, bounds: size, color: Color(red: 1, green: 0.85, blue: 0.95))
    }
}

// MARK: Venues the flying salon tours

/// Night 1 is Main Street, night 2 the co-workers' night outside the casino; from night 3 the salon tours.
enum Venue: Int, CaseIterable {
    case london, stonehenge, maui, aruba, kailua, mesquite, laughlin, grandCanyon, cancun, paradisePlaza, mainStreet

    static func forNight(_ n: Int) -> Venue {
        n <= 2 ? .mainStreet : Venue(rawValue: (n - 3) % allCases.count)!
    }

    var name: String {
        switch self {
        case .london: "London"
        case .stonehenge: "Stonehenge"
        case .maui: "Maui"
        case .aruba: "Aruba"
        case .kailua: "Kailua"
        case .mesquite: "Mesquite"
        case .laughlin: "Laughlin"
        case .grandCanyon: "Grand Canyon"
        case .cancun: "Cancun"
        case .paradisePlaza: "Paradise Plaza"
        case .mainStreet: "Main Street"
        }
    }

    var icon: String {
        switch self {
        case .london: "clock.fill"
        case .stonehenge: "square.grid.3x1.below.line.grid.1x2"
        case .maui, .kailua: "beach.umbrella.fill"
        case .aruba: "sun.max.fill"
        case .mesquite, .laughlin: "suit.diamond.fill"
        case .grandCanyon: "mountain.2.fill"
        case .cancun: "triangle.fill"
        case .paradisePlaza: "bag.fill"
        case .mainStreet: "storefront.fill"
        }
    }

    /// Where the salon parks, as a phrase ("by Big Ben in London").
    var whereAt: String {
        switch self {
        case .london: "by Big Ben in London"
        case .stonehenge: "at Stonehenge"
        case .maui: "on the beach in Maui"
        case .aruba: "on the beach in Aruba"
        case .kailua: "at Kailua Beach"
        case .mesquite: "in Mesquite"
        case .laughlin: "on the riverwalk in Laughlin"
        case .grandCanyon: "on the rim of the Grand Canyon"
        case .cancun: "in Cancun"
        case .paradisePlaza: "at Paradise Plaza"
        case .mainStreet: "at the end of Main Street"
        }
    }
}

private func palm(_ ctx: GraphicsContext, _ x: Double, _ base: Double, _ h: Double, lean: Double = 30) {
    var trunk = Path()
    trunk.move(to: CGPoint(x: x, y: base))
    trunk.addQuadCurve(to: CGPoint(x: x + lean, y: base - h), control: CGPoint(x: x - lean * 0.3, y: base - h * 0.5))
    ctx.stroke(trunk, with: .color(Color(red: 0.5, green: 0.35, blue: 0.2)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
    let top = CGPoint(x: x + lean, y: base - h)
    for a in stride(from: 0.0, to: 360, by: 45) {
        let r = a * .pi / 180
        var leaf = Path()
        leaf.move(to: top)
        let tip = CGPoint(x: top.x + cos(r) * 75, y: top.y + sin(r) * 34 + 22)
        leaf.addQuadCurve(to: tip, control: CGPoint(x: top.x + cos(r) * 40, y: top.y + sin(r) * 30 - 22))
        ctx.stroke(leaf, with: .color(Color(red: 0.1, green: 0.5, blue: 0.2)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
    }
    for k in 0..<3 { ctx.fill(oval(CGPoint(x: top.x - 8 + Double(k) * 8, y: top.y + 8), 6), with: .color(Color(red: 0.4, green: 0.25, blue: 0.1))) }
}

private func beach(_ ctx: GraphicsContext, sky top: Color, sea: Color, sand: Color, horizon: Double = 330) {
    sky(ctx, [top, Color(red: 0.85, green: 0.93, blue: 1)], to: horizon)
    ctx.fill(rect(0, horizon, Stage.W, 470 - horizon), with: .linearGradient(Gradient(colors: [sea.opacity(0.85), sea]),
                                                                              startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: 470)))
    for i in 0..<12 {
        let x = Double(i) * 90 + 20
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 400 + Double(i % 3) * 20)); $0.addLine(to: CGPoint(x: x + 40, y: 400 + Double(i % 3) * 20)) },
                   with: .color(.white.opacity(0.6)), lineWidth: 3)
    }
    ctx.fill(Path { p in
        p.move(to: CGPoint(x: 0, y: 470))
        p.addQuadCurve(to: CGPoint(x: Stage.W, y: 465), control: CGPoint(x: 500, y: 452))
        p.addLine(to: CGPoint(x: Stage.W, y: Stage.H)); p.addLine(to: CGPoint(x: 0, y: Stage.H)); p.closeSubpath()
    }, with: .color(sand))
}

private func casinoTower(_ ctx: GraphicsContext, _ x: Double, _ w: Double, _ top: Double, _ color: Color, sign: String, _ now: Date) {
    ctx.fill(rect(x, top, w, 520 - top), with: .color(color))
    let t = now.timeIntervalSinceReferenceDate
    for row in stride(from: top + 50, to: 500, by: 26) {
        for col in stride(from: x + 10, to: x + w - 14, by: 22) {
            let on = (Int(row + col) / 3 % 5) != 0
            ctx.fill(rect(col, row, 12, 14), with: .color(on ? Color(red: 1, green: 0.85, blue: 0.5) : Color(white: 0.2)))
        }
    }
    let glow = 0.75 + 0.25 * sin(t * 5 + x)
    ctx.fill(Path(roundedRect: CGRect(x: x - 6, y: top - 4, width: w + 12, height: 40), cornerRadius: 8), with: .color(Color(red: 0.2, green: 0, blue: 0.25)))
    label(ctx, sign, CGPoint(x: x + w / 2, y: top + 16), size: min(26, w / Double(max(sign.count, 1)) * 1.6), color: Color(red: 1, green: 0.35, blue: 0.75).opacity(glow))
}

private func walkway(_ ctx: GraphicsContext, _ color: Color) {
    ctx.fill(rect(0, 520, Stage.W, 80), with: .color(color))
    ctx.fill(rect(0, 520, Stage.W, 4), with: .color(.black.opacity(0.15)))
}

func drawVenue(_ ctx: GraphicsContext, _ v: Venue, now: Date) {
    let t = now.timeIntervalSinceReferenceDate
    switch v {
    case .london:
        sky(ctx, [Color(red: 0.15, green: 0.2, blue: 0.45), Color(red: 0.95, green: 0.6, blue: 0.45)], to: 520)
        let stone = Color(red: 0.8, green: 0.7, blue: 0.48)
        ctx.fill(rect(30, 340, 620, 180), with: .color(stone))
        for x in stride(from: 40.0, to: 640, by: 34) {
            ctx.fill(Path { p in p.move(to: CGPoint(x: x, y: 340)); p.addLine(to: CGPoint(x: x + 8, y: 312)); p.addLine(to: CGPoint(x: x + 16, y: 340)) }, with: .color(stone))
            ctx.fill(rect(x + 4, 370, 10, 40), with: .color(Color(red: 0.35, green: 0.3, blue: 0.25)))
            ctx.fill(rect(x + 4, 440, 10, 40), with: .color(Color(red: 0.35, green: 0.3, blue: 0.25)))
        }
        // Big Ben
        ctx.fill(rect(440, 110, 70, 410), with: .color(stone))
        ctx.fill(Path { p in p.move(to: CGPoint(x: 436, y: 112)); p.addLine(to: CGPoint(x: 475, y: 30)); p.addLine(to: CGPoint(x: 514, y: 112)) }, with: .color(Color(red: 0.3, green: 0.35, blue: 0.3)))
        let face = CGPoint(x: 475, y: 175)
        ctx.fill(oval(face, 27), with: .color(Color(red: 0.95, green: 0.88, blue: 0.6)))
        ctx.stroke(oval(face, 27), with: .color(Color(red: 0.6, green: 0.45, blue: 0.1)), lineWidth: 4)
        let mins = t.truncatingRemainder(dividingBy: 3600) / 60
        for (len, ang) in [(20.0, mins / 60 * 2 * .pi), (13.0, (mins / 720 + 0.8) * 2 * .pi)] {
            ctx.stroke(Path { $0.move(to: face); $0.addLine(to: CGPoint(x: face.x + sin(ang) * len, y: face.y - cos(ang) * len)) }, with: .color(.black), lineWidth: 3)
        }
        for y in stride(from: 230.0, to: 500, by: 40) { ctx.fill(rect(462, y, 26, 22), with: .color(Color(red: 0.35, green: 0.3, blue: 0.25))) }
        // Red phone box
        ctx.fill(Path(roundedRect: CGRect(x: 90, y: 420, width: 44, height: 100), cornerRadius: 6), with: .color(Color(red: 0.8, green: 0.05, blue: 0.05)))
        for k in 0..<3 { ctx.fill(rect(97, 440 + Double(k) * 20, 30, 14), with: .color(Color(red: 1, green: 0.95, blue: 0.75))) }
        walkway(ctx, Color(white: 0.55))
    case .stonehenge:
        sky(ctx, [Color(red: 0.45, green: 0.6, blue: 0.85), Color(red: 0.92, green: 0.9, blue: 0.85)], to: 400)
        ctx.fill(Path { p in p.move(to: CGPoint(x: 0, y: 380)); p.addQuadCurve(to: CGPoint(x: Stage.W, y: 370), control: CGPoint(x: 500, y: 330))
            p.addLine(to: CGPoint(x: Stage.W, y: Stage.H)); p.addLine(to: CGPoint(x: 0, y: Stage.H)); p.closeSubpath() }, with: .color(Color(red: 0.35, green: 0.6, blue: 0.25)))
        let grey = Color(red: 0.55, green: 0.55, blue: 0.52)
        for (x, y, h) in [(90.0, 430.0, 120.0), (170, 410, 105), (260, 405, 110), (350, 410, 105), (440, 425, 115), (540, 440, 125)] {
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y - h, width: 34, height: h), cornerRadius: 6), with: .color(grey))
            ctx.fill(Path(roundedRect: CGRect(x: x + 46, y: y - h, width: 34, height: h), cornerRadius: 6), with: .color(grey.opacity(0.92)))
            ctx.fill(Path(roundedRect: CGRect(x: x - 6, y: y - h - 22, width: 92, height: 24), cornerRadius: 5), with: .color(grey))
        }
        ctx.fill(Path(roundedRect: CGRect(x: 300, y: 470, width: 120, height: 30), cornerRadius: 6), with: .color(grey))
        walkway(ctx, Color(red: 0.8, green: 0.75, blue: 0.62))
    case .maui:
        beach(ctx, sky: Color(red: 0.98, green: 0.55, blue: 0.4), sea: Color(red: 0.1, green: 0.4, blue: 0.7), sand: Color(red: 0.93, green: 0.82, blue: 0.6))
        ctx.fill(oval(CGPoint(x: 560, y: 335), 48), with: .color(Color(red: 1, green: 0.8, blue: 0.3)))
        ctx.fill(Path { p in p.move(to: CGPoint(x: -20, y: 345)); p.addQuadCurve(to: CGPoint(x: 420, y: 345), control: CGPoint(x: 160, y: 170)) }, with: .color(Color(red: 0.35, green: 0.25, blue: 0.4)))
        ctx.fill(rect(0, 330, Stage.W, 15), with: .color(Color(red: 0.1, green: 0.4, blue: 0.7)))
        palm(ctx, 90, 520, 210, lean: 40)
        palm(ctx, 600, 520, 170, lean: -30)
    case .aruba:
        beach(ctx, sky: Color(red: 0.3, green: 0.65, blue: 0.95), sea: Color(red: 0.1, green: 0.75, blue: 0.75), sand: Color(red: 0.98, green: 0.95, blue: 0.88))
        ctx.fill(oval(CGPoint(x: 120, y: 90), 40), with: .color(.yellow))
        // Divi-divi tree, bent by the trade winds
        var trunk = Path()
        trunk.move(to: CGPoint(x: 220, y: 520)); trunk.addQuadCurve(to: CGPoint(x: 420, y: 380), control: CGPoint(x: 230, y: 400))
        ctx.stroke(trunk, with: .color(Color(red: 0.45, green: 0.32, blue: 0.2)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: 300, y: 330, width: 230, height: 70)), with: .color(Color(red: 0.2, green: 0.5, blue: 0.2)))
        // Palapa umbrella
        ctx.fill(rect(557, 420, 6, 100), with: .color(Color(red: 0.5, green: 0.35, blue: 0.2)))
        ctx.fill(Path { p in p.move(to: CGPoint(x: 500, y: 430)); p.addLine(to: CGPoint(x: 560, y: 385)); p.addLine(to: CGPoint(x: 620, y: 430)); p.closeSubpath() },
                 with: .color(Color(red: 0.8, green: 0.65, blue: 0.35)))
    case .kailua:
        beach(ctx, sky: Color(red: 0.35, green: 0.7, blue: 0.98), sea: Color(red: 0.15, green: 0.7, blue: 0.8), sand: Color(red: 0.98, green: 0.93, blue: 0.8))
        // The Mokulua islands offshore
        for (x, w, h) in [(260.0, 130.0, 60.0), (420, 90, 42)] {
            ctx.fill(Path { p in p.move(to: CGPoint(x: x, y: 345)); p.addQuadCurve(to: CGPoint(x: x + w, y: 345), control: CGPoint(x: x + w / 2, y: 345 - h * 2)) },
                     with: .color(Color(red: 0.25, green: 0.45, blue: 0.3)))
        }
        for (x, c) in [(140.0, Color.yellow), (330, Color.red)] {
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: 492, width: 120, height: 20)), with: .color(c))
        }
        palm(ctx, 40, 520, 200, lean: 50)
    case .mesquite:
        sky(ctx, [Color(red: 0.05, green: 0.03, blue: 0.2), Color(red: 0.45, green: 0.2, blue: 0.4)], to: 520)
        stars(ctx, now, below: 180)
        ctx.fill(Path { p in p.move(to: CGPoint(x: 0, y: 380)); p.addLine(to: CGPoint(x: 160, y: 270)); p.addLine(to: CGPoint(x: 300, y: 350)); p.addLine(to: CGPoint(x: 470, y: 250))
            p.addLine(to: CGPoint(x: 700, y: 380)); p.closeSubpath() }, with: .color(Color(red: 0.3, green: 0.15, blue: 0.3)))
        ctx.fill(rect(0, 380, Stage.W, 140), with: .color(Color(red: 0.6, green: 0.45, blue: 0.35)))
        casinoTower(ctx, 80, 200, 250, Color(red: 0.85, green: 0.75, blue: 0.6), sign: "MESQUITE", now)
        casinoTower(ctx, 340, 160, 300, Color(red: 0.75, green: 0.55, blue: 0.45), sign: "CASINO", now)
        walkway(ctx, Color(white: 0.3))
    case .laughlin:
        sky(ctx, [Color(red: 0.2, green: 0.15, blue: 0.4), Color(red: 1, green: 0.55, blue: 0.35)], to: 400)
        ctx.fill(rect(0, 300, Stage.W, 100), with: .color(Color(red: 0.55, green: 0.35, blue: 0.3)))
        casinoTower(ctx, 40, 150, 200, Color(red: 0.95, green: 0.9, blue: 0.8), sign: "LAUGHLIN", now)
        casinoTower(ctx, 240, 130, 240, Color(red: 0.7, green: 0.2, blue: 0.2), sign: "CASINO", now)
        casinoTower(ctx, 420, 140, 220, Color(red: 0.4, green: 0.55, blue: 0.75), sign: "RIVER", now)
        // The Colorado River
        ctx.fill(rect(0, 400, Stage.W, 90), with: .color(Color(red: 0.15, green: 0.35, blue: 0.6)))
        for i in 0..<10 {
            let x = (Double(i) * 110 + t * 20).truncatingRemainder(dividingBy: 1100) - 50
            ctx.fill(rect(x, 430 + Double(i % 3) * 15, 50, 3), with: .color(.white.opacity(0.5)))
        }
        ctx.fill(rect(0, 490, Stage.W, 30), with: .color(Color(white: 0.75)))
        for x in stride(from: 0.0, to: Stage.W, by: 40) { ctx.fill(rect(x, 470, 4, 22), with: .color(Color(white: 0.85))) }
        ctx.fill(rect(0, 468, Stage.W, 5), with: .color(Color(white: 0.85)))
        walkway(ctx, Color(red: 0.7, green: 0.6, blue: 0.5))
    case .grandCanyon:
        sky(ctx, [Color(red: 0.4, green: 0.6, blue: 0.95), Color(red: 0.95, green: 0.85, blue: 0.75)], to: 300)
        let bands: [(Double, Color)] = [(230, Color(red: 0.75, green: 0.45, blue: 0.3)), (290, Color(red: 0.85, green: 0.55, blue: 0.35)),
                                        (350, Color(red: 0.7, green: 0.35, blue: 0.25)), (410, Color(red: 0.6, green: 0.3, blue: 0.22)), (460, Color(red: 0.5, green: 0.25, blue: 0.2))]
        for (k, (y, c)) in bands.enumerated() {
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                for x in stride(from: 0.0, through: Stage.W, by: 50) {
                    p.addLine(to: CGPoint(x: x, y: y + (Int(x / 50 + Double(k)) % 3 == 0 ? -30 : 0)))
                }
                p.addLine(to: CGPoint(x: Stage.W, y: Stage.H)); p.addLine(to: CGPoint(x: 0, y: Stage.H)); p.closeSubpath()
            }, with: .color(c))
        }
        walkway(ctx, Color(red: 0.75, green: 0.65, blue: 0.5))
        ctx.fill(rect(0, 488, Stage.W, 5), with: .color(Color(red: 0.4, green: 0.3, blue: 0.2)))
        for x in stride(from: 0.0, to: Stage.W, by: 60) { ctx.fill(rect(x, 488, 5, 32), with: .color(Color(red: 0.4, green: 0.3, blue: 0.2))) }
    case .cancun:
        beach(ctx, sky: Color(red: 0.25, green: 0.6, blue: 0.95), sea: Color(red: 0.05, green: 0.75, blue: 0.7), sand: Color(red: 0.98, green: 0.95, blue: 0.85))
        for (x, h) in [(30.0, 260.0), (120, 200.0)] {
            ctx.fill(rect(x, 460 - h, 80, h), with: .color(.white))
            for row in stride(from: 470 - h, to: 450, by: 18) { ctx.fill(rect(x + 8, row, 64, 6), with: .color(Color(red: 0.4, green: 0.7, blue: 0.85))) }
        }
        // Mayan pyramid
        let stone = Color(red: 0.75, green: 0.7, blue: 0.58)
        for k in 0..<5 {
            let w = 260 - Double(k) * 44
            ctx.fill(rect(450 - w / 2, 470 - Double(k + 1) * 30, w, 30), with: .color(k % 2 == 0 ? stone : stone.opacity(0.85)))
        }
        ctx.fill(rect(425, 290, 50, 30), with: .color(stone))
        ctx.fill(rect(441, 300, 18, 20), with: .color(Color(red: 0.3, green: 0.25, blue: 0.2)))
        ctx.fill(rect(436, 320, 28, 150), with: .color(stone.opacity(0.75)))
        palm(ctx, 620, 520, 160, lean: -25)
    case .paradisePlaza:
        drawStorefronts(ctx, now, shops: [("BOUTIQUE", Color(red: 0.85, green: 0.4, blue: 0.55), 0, 170), ("GELATO", Color(red: 0.3, green: 0.65, blue: 0.6), 170, 170),
                                          ("JEWELRY", Color(red: 0.55, green: 0.45, blue: 0.75), 340, 170), ("SURF SHOP", Color(red: 0.95, green: 0.6, blue: 0.2), 510, 170)])
        ctx.fill(Path(roundedRect: CGRect(x: 150, y: 190, width: 380, height: 60), cornerRadius: 30), with: .color(Color(red: 0.1, green: 0.55, blue: 0.6)))
        label(ctx, "PARADISE PLAZA", CGPoint(x: 340, y: 220), size: 34, color: .white)
        palm(ctx, 120, 520, 230, lean: 20)
        palm(ctx, 580, 520, 230, lean: -20)
    case .mainStreet:
        drawDowntown(ctx, now)
    }
}

// MARK: A kid's home

func drawHome(_ ctx: GraphicsContext, _ d: Director, _ now: Date) {
    ctx.fill(rect(0, 0, Stage.W, 470), with: .color(Color(red: 0.93, green: 0.88, blue: 0.75)))
    for x in stride(from: 0.0, to: Stage.W, by: 60) { ctx.fill(rect(x, 0, 24, 470), with: .color(Color(red: 0.88, green: 0.8, blue: 0.66).opacity(0.6))) }
    ctx.fill(rect(0, 440, Stage.W, 30), with: .color(Color(red: 0.6, green: 0.45, blue: 0.3)))
    for i in 0..<10 { ctx.fill(rect(Double(i) * 100, 470, 98, 130), with: .color(i % 2 == 0 ? Color(red: 0.62, green: 0.42, blue: 0.25) : Color(red: 0.56, green: 0.38, blue: 0.22))) }
    // Front door
    ctx.fill(rect(20, 250, 120, 220), with: .color(Color(red: 0.45, green: 0.25, blue: 0.15)))
    ctx.fill(oval(CGPoint(x: 120, y: 370), 6), with: .color(.yellow))
    // Window at night
    let win = CGRect(x: 230, y: 110, width: 200, height: 150)
    ctx.fill(Path(win), with: .color(Color(red: 0.05, green: 0.05, blue: 0.2)))
    var w = ctx
    w.clip(to: Path(win))
    stars(w, now, below: 260)
    ctx.stroke(Path(win), with: .color(.white), lineWidth: 8)
    ctx.stroke(Path { $0.move(to: CGPoint(x: win.midX, y: win.minY)); $0.addLine(to: CGPoint(x: win.midX, y: win.maxY)) }, with: .color(.white), lineWidth: 5)
    // Couch and lamp
    ctx.fill(Path(roundedRect: CGRect(x: 520, y: 360, width: 300, height: 110), cornerRadius: 20), with: .color(Color(red: 0.35, green: 0.5, blue: 0.4)))
    ctx.fill(Path(roundedRect: CGRect(x: 540, y: 330, width: 260, height: 60), cornerRadius: 18), with: .color(Color(red: 0.3, green: 0.45, blue: 0.35)))
    ctx.fill(rect(905, 300, 6, 170), with: .color(Color(white: 0.3)))
    ctx.fill(Path { p in p.move(to: CGPoint(x: 870, y: 300)); p.addLine(to: CGPoint(x: 885, y: 240)); p.addLine(to: CGPoint(x: 931, y: 240)); p.addLine(to: CGPoint(x: 946, y: 300)); p.closeSubpath() },
             with: .color(Color(red: 1, green: 0.9, blue: 0.6)))
    // Wall clock showing story time
    let c = CGPoint(x: 680, y: 150)
    ctx.fill(oval(c, 52), with: .color(.white))
    ctx.stroke(oval(c, 52), with: .color(Color(red: 0.35, green: 0.2, blue: 0.1)), lineWidth: 7)
    for k in 0..<12 {
        let a = Double(k) / 12 * 2 * .pi
        ctx.fill(oval(CGPoint(x: c.x + sin(a) * 42, y: c.y - cos(a) * 42), 3), with: .color(.black))
    }
    let m = d.clockMinutes(at: now)
    let minuteA = m.truncatingRemainder(dividingBy: 60) / 60 * 2 * .pi
    let hourA = (m / 60).truncatingRemainder(dividingBy: 12) / 12 * 2 * .pi
    ctx.stroke(Path { $0.move(to: c); $0.addLine(to: CGPoint(x: c.x + sin(hourA) * 26, y: c.y - cos(hourA) * 26)) }, with: .color(.black), style: StrokeStyle(lineWidth: 6, lineCap: .round))
    ctx.stroke(Path { $0.move(to: c); $0.addLine(to: CGPoint(x: c.x + sin(minuteA) * 40, y: c.y - cos(minuteA) * 40)) }, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    let h = Int(m / 60) % 24, mm = Int(m) % 60
    label(ctx, String(format: "%d:%02d %@", h % 12 == 0 ? 12 : h % 12, mm, h < 12 ? "AM" : "PM"), CGPoint(x: c.x, y: c.y + 76), size: 18, color: Color(red: 0.35, green: 0.2, blue: 0.1))
}

// MARK: Your room aboard the salon

enum BedroomSpot {
    static let mirrorX = 860.0
    static let mirrorY = 215.0
    /// Where Lavender stands to see herself in the bedroom mirror.
    static let mirrorStand = 860.0
}

func drawBedroom(_ ctx: GraphicsContext, _ d: Director, _ now: Date) {
    // Pink striped wallpaper and a soft carpet.
    ctx.fill(rect(0, 0, Stage.W, 470), with: .color(Color(red: 1, green: 0.84, blue: 0.9)))
    for x in stride(from: 0.0, to: Stage.W, by: 50) { ctx.fill(rect(x, 0, 20, 470), with: .color(.white.opacity(0.35))) }
    ctx.fill(rect(0, 0, Stage.W, 24), with: .color(Color(red: 0.45, green: 0.12, blue: 0.55)))
    ctx.fill(rect(0, 452, Stage.W, 18), with: .color(Color(red: 0.85, green: 0.65, blue: 0.2)))
    ctx.fill(rect(0, 470, Stage.W, 130), with: .color(Color(red: 0.75, green: 0.55, blue: 0.75)))
    // Hall door (left)
    ctx.fill(Path(roundedRect: CGRect(x: 18, y: 270, width: 92, height: 200), cornerRadius: 6), with: .color(Color(red: 0.45, green: 0.12, blue: 0.55)))
    ctx.fill(oval(CGPoint(x: 96, y: 375), 5), with: .color(.yellow))
    // Porthole window with the night sky
    let c = CGPoint(x: 210, y: 150)
    var w = ctx
    w.clip(to: oval(c, 62))
    w.fill(oval(c, 62), with: .color(Color(red: 0.05, green: 0.05, blue: 0.22)))
    stars(w, now, below: 260)
    ctx.fill(oval(CGPoint(x: c.x + 22, y: c.y - 18), 14), with: .color(Color(red: 1, green: 0.97, blue: 0.8)))
    ctx.stroke(oval(c, 62), with: .color(.yellow), lineWidth: 9)
    // Bed with a pink quilt and heart pillows
    ctx.fill(Path(roundedRect: CGRect(x: 300, y: 300, width: 24, height: 210), cornerRadius: 6), with: .color(.white))
    ctx.fill(Path(roundedRect: CGRect(x: 300, y: 280, width: 24, height: 30), cornerRadius: 12), with: .color(.white))
    ctx.fill(Path(roundedRect: CGRect(x: 318, y: 400, width: 330, height: 70), cornerRadius: 12), with: .color(.white))
    ctx.fill(Path(roundedRect: CGRect(x: 360, y: 392, width: 290, height: 82), cornerRadius: 14), with: .color(Color(red: 0.95, green: 0.45, blue: 0.7)))
    for k in 0..<5 { ctx.fill(oval(CGPoint(x: 400 + Double(k) * 55, y: 432), 7), with: .color(.white.opacity(0.7))) }
    ctx.fill(Path(roundedRect: CGRect(x: 326, y: 370, width: 60, height: 34), cornerRadius: 14), with: .color(.white))
    ctx.fill(rect(330, 470, 10, 40), with: .color(.white))
    ctx.fill(rect(632, 470, 10, 40), with: .color(.white))
    // Nightstand and lamp
    ctx.fill(Path(roundedRect: CGRect(x: 662, y: 400, width: 70, height: 108), cornerRadius: 6), with: .color(Color(red: 0.55, green: 0.3, blue: 0.6)))
    ctx.fill(rect(694, 352, 6, 48), with: .color(.yellow))
    ctx.fill(Path { p in p.move(to: CGPoint(x: 672, y: 356)); p.addLine(to: CGPoint(x: 684, y: 316)); p.addLine(to: CGPoint(x: 710, y: 316)); p.addLine(to: CGPoint(x: 722, y: 356)); p.closeSubpath() },
             with: .color(Color(red: 1, green: 0.9, blue: 0.6)))
    // A vanity table (right) with the bedroom's oval wall mirror above it.
    let vx = BedroomSpot.mirrorX
    ctx.fill(Path(roundedRect: CGRect(x: vx - 70, y: 392, width: 140, height: 18), cornerRadius: 5), with: .color(.white))
    ctx.fill(Path(roundedRect: CGRect(x: vx - 64, y: 408, width: 128, height: 40), cornerRadius: 4), with: .color(Color(red: 0.95, green: 0.75, blue: 0.88)))
    ctx.fill(oval(CGPoint(x: vx, y: 428), 4), with: .color(.yellow))
    ctx.fill(rect(vx - 60, 448, 9, 60), with: .color(.white))
    ctx.fill(rect(vx + 51, 448, 9, 60), with: .color(.white))
    // Perfume bottles and a powder puff on top.
    ctx.fill(Path(roundedRect: CGRect(x: vx - 52, y: 372, width: 14, height: 20), cornerRadius: 3), with: .color(Color(red: 0.75, green: 0.6, blue: 0.95)))
    ctx.fill(Path(roundedRect: CGRect(x: vx - 32, y: 378, width: 12, height: 14), cornerRadius: 3), with: .color(.pink))
    ctx.fill(Path(ellipseIn: CGRect(x: vx + 30, y: 380, width: 28, height: 12)), with: .color(Color(red: 1, green: 0.9, blue: 0.95)))
    drawWallMirror(ctx, d, now, at: CGPoint(x: vx, y: BedroomSpot.mirrorY), stand: BedroomSpot.mirrorStand)
}
