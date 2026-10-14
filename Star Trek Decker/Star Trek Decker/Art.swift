import SwiftUI

// MARK: - Colour helpers

struct RGB {
    var r, g, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    var color: Color { Color(red: r, green: g, blue: b) }
    func mix(_ o: RGB, _ t: Double) -> RGB {
        let t = min(1, max(0, t))
        return RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)
    }
}

enum LCARS {
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let peach = Color(red: 1.0, green: 0.8, blue: 0.6)
    static let lilac = Color(red: 0.8, green: 0.6, blue: 0.85)
    static let blue = Color(red: 0.6, green: 0.65, blue: 1.0)
    static let red = Color(red: 0.95, green: 0.3, blue: 0.3)
    static let gold = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let green = Color(red: 0.4, green: 0.9, blue: 0.5)
    static let tan = Color(red: 0.85, green: 0.65, blue: 0.45)
    static let panel = Color(red: 0.06, green: 0.06, blue: 0.1)
}

/// Deterministic pseudo-random in 0..<1.
func hash01(_ i: Int, _ salt: Int = 0) -> Double {
    var x = UInt64(bitPattern: Int64(i &* 7919 &+ salt &* 104729 &+ 12345))
    x ^= x >> 33; x = x &* 0xff51afd7ed558ccd; x ^= x >> 33; x = x &* 0xc4ceb9fe1a85ec53; x ^= x >> 33
    return Double(x % 10000) / 10000
}

// MARK: - People

enum HairStyle { case short, bald, long, bun, ponytail, curly }

struct Look {
    var skin = RGB(0.95, 0.78, 0.65)
    var hair = RGB(0.35, 0.22, 0.12)
    var style: HairStyle = .short
    var top = RGB(0.3, 0.4, 0.6)
    var pants = RGB(0.15, 0.15, 0.2)
    var female = false
    var uniform = false          // Starfleet two-tone (black shoulders)
    var tie = false
    var glow = false             // the time traveller's shimmer
    var borg = 0.0               // 0 human … 1 fully assimilated
    var restored = false         // freed drone: faint scar over the eye

    static let mattWork = Look(hair: RGB(0.45, 0.28, 0.12), top: RGB(0.25, 0.4, 0.3), pants: RGB(0.3, 0.3, 0.35))
    static let mattCaptain = Look(hair: RGB(0.45, 0.28, 0.12), top: RGB(0.75, 0.1, 0.1), pants: RGB(0.08, 0.08, 0.1), uniform: true)
    static let boss = Look(skin: RGB(0.98, 0.8, 0.7), hair: RGB(0.6, 0.6, 0.6), style: .bald, top: RGB(0.9, 0.9, 0.95), pants: RGB(0.2, 0.2, 0.25), tie: true)
    static let stranger = Look(skin: RGB(0.97, 0.88, 0.82), hair: RGB(0.95, 0.92, 0.8), style: .long, top: RGB(0.85, 0.88, 0.95), pants: RGB(0.85, 0.88, 0.95), female: true, glow: true)
    static let admiral = Look(skin: RGB(0.55, 0.38, 0.28), hair: RGB(0.85, 0.85, 0.85), style: .short, top: RGB(0.75, 0.1, 0.1), pants: RGB(0.08, 0.08, 0.1), uniform: true)
    static let engineer = Look(skin: RGB(0.9, 0.72, 0.6), hair: RGB(0.15, 0.1, 0.05), top: RGB(0.85, 0.65, 0.1), pants: RGB(0.08, 0.08, 0.1), uniform: true)
    static let scientist = Look(skin: RGB(0.7, 0.5, 0.38), hair: RGB(0.1, 0.08, 0.06), style: .bun, top: RGB(0.2, 0.5, 0.6), pants: RGB(0.08, 0.08, 0.1), female: true, uniform: true)
}

/// Draws a standing figure with feet at `feet`, total height `h`.
func drawPerson(_ ctx: GraphicsContext, feet: CGPoint, h: CGFloat, look: Look, t: Double = 0, facing: CGFloat = 1, talking: Bool = false) {
    let b = look.borg
    let skin = look.skin.mix(RGB(0.78, 0.8, 0.8), b).color
    let headR = h * 0.085
    let headC = CGPoint(x: feet.x, y: feet.y - h + headR)
    let shoulderY = headC.y + headR * 1.5
    let hipY = feet.y - h * 0.45
    let bodyW = h * (look.female ? 0.2 : 0.23)
    let suit = RGB(0.12, 0.12, 0.13)
    let top = look.top.mix(suit, b < 0.35 ? 0 : (b - 0.35) / 0.4).color
    let pants = look.pants.mix(suit, b < 0.35 ? 0 : (b - 0.35) / 0.4).color

    if look.glow {
        let r = h * 0.62
        let g = Gradient(colors: [Color.white.opacity(0.35 + 0.1 * sin(t * 3)), .clear])
        ctx.fill(Path(ellipseIn: CGRect(x: feet.x - r, y: feet.y - h * 0.55 - r, width: 2 * r, height: 2 * r)),
                 with: .radialGradient(g, center: CGPoint(x: feet.x, y: feet.y - h * 0.55), startRadius: 0, endRadius: r))
    }

    // legs
    let legW = bodyW * 0.36
    for s in [-1.0, 1.0] {
        let x = feet.x + CGFloat(s) * bodyW * 0.22
        ctx.fill(Path(roundedRect: CGRect(x: x - legW / 2, y: hipY - 2, width: legW, height: feet.y - hipY), cornerRadius: legW * 0.3), with: .color(pants))
        ctx.fill(Path(ellipseIn: CGRect(x: x - legW * 0.6 + CGFloat(s) * 1, y: feet.y - legW * 0.45, width: legW * 1.3, height: legW * 0.6)), with: .color(.black.opacity(0.85)))
    }
    // skirt-like dress for the stranger
    if look.glow {
        var p = Path()
        p.move(to: CGPoint(x: feet.x - bodyW * 0.45, y: hipY - 4))
        p.addLine(to: CGPoint(x: feet.x + bodyW * 0.45, y: hipY - 4))
        p.addLine(to: CGPoint(x: feet.x + bodyW * 0.8, y: feet.y - h * 0.08))
        p.addLine(to: CGPoint(x: feet.x - bodyW * 0.8, y: feet.y - h * 0.08))
        p.closeSubpath()
        ctx.fill(p, with: .color(look.top.color))
    }
    // arms
    let armW = bodyW * 0.26
    for s in [-1.0, 1.0] {
        let x = feet.x + CGFloat(s) * (bodyW / 2 + armW * 0.35)
        ctx.fill(Path(roundedRect: CGRect(x: x - armW / 2, y: shoulderY, width: armW, height: h * 0.33), cornerRadius: armW / 2), with: .color(top))
        ctx.fill(Path(ellipseIn: CGRect(x: x - armW * 0.55, y: shoulderY + h * 0.31, width: armW * 1.1, height: armW * 1.1)), with: .color(skin))
    }
    // torso
    let torso = CGRect(x: feet.x - bodyW / 2, y: shoulderY, width: bodyW, height: hipY - shoulderY + 4)
    ctx.fill(Path(roundedRect: torso, cornerRadius: bodyW * 0.25), with: .color(top))
    if look.uniform && b < 0.6 {
        // black shoulder yoke, Starfleet style
        let yoke = CGRect(x: torso.minX, y: torso.minY, width: torso.width, height: torso.height * 0.32)
        ctx.fill(Path(roundedRect: yoke, cornerRadius: bodyW * 0.25), with: .color(Color(white: 0.08)))
        // comm badge
        ctx.fill(Path(ellipseIn: CGRect(x: torso.minX + bodyW * 0.18, y: torso.minY + torso.height * 0.22, width: bodyW * 0.17, height: bodyW * 0.2)), with: .color(LCARS.gold))
    }
    if look.tie {
        var tie = Path()
        tie.move(to: CGPoint(x: feet.x, y: shoulderY + 1))
        tie.addLine(to: CGPoint(x: feet.x + bodyW * 0.07, y: shoulderY + h * 0.2))
        tie.addLine(to: CGPoint(x: feet.x, y: shoulderY + h * 0.24))
        tie.addLine(to: CGPoint(x: feet.x - bodyW * 0.07, y: shoulderY + h * 0.2))
        tie.closeSubpath()
        ctx.fill(tie, with: .color(Color(red: 0.6, green: 0.1, blue: 0.15)))
    }
    if b > 0.35 {
        // Borg armour plates and tubes
        let a = min(1, (b - 0.35) / 0.4)
        var tube = Path()
        tube.move(to: CGPoint(x: torso.minX + 3, y: torso.minY + 6))
        tube.addQuadCurve(to: CGPoint(x: torso.maxX - 3, y: torso.midY + 6), control: CGPoint(x: torso.midX, y: torso.minY - 2))
        ctx.stroke(tube, with: .color(Color(white: 0.45).opacity(a)), lineWidth: max(1, h * 0.012))
        ctx.fill(Path(roundedRect: CGRect(x: torso.midX - bodyW * 0.25, y: torso.midY - 2, width: bodyW * 0.5, height: h * 0.07), cornerRadius: 2), with: .color(Color(white: 0.35).opacity(a)))
        ctx.fill(Path(ellipseIn: CGRect(x: torso.midX - 2, y: torso.midY + 2, width: 4, height: 4)), with: .color(Color.green.opacity(a * (0.6 + 0.4 * sin(t * 4)))))
    }

    // neck + head
    ctx.fill(Path(CGRect(x: feet.x - headR * 0.35, y: headC.y + headR * 0.7, width: headR * 0.7, height: headR * 0.9)), with: .color(skin))
    let hair = look.hair.color
    let hairFade = b > 0.75 ? 1 - min(1, (b - 0.75) / 0.2) : 1
    if hairFade > 0 {
        switch look.style {
        case .long:
            ctx.fill(Path(roundedRect: CGRect(x: headC.x - headR * 1.15, y: headC.y - headR * 1.05, width: headR * 2.3, height: headR * 3.4), cornerRadius: headR), with: .color(hair.opacity(hairFade)))
        case .ponytail:
            ctx.fill(Path(ellipseIn: CGRect(x: headC.x - facing * headR * 1.6 - headR * 0.45, y: headC.y - headR * 0.2, width: headR * 0.9, height: headR * 2.0)), with: .color(hair.opacity(hairFade)))
        case .curly:
            for k in 0..<9 {
                let a = Double(k) / 8 * .pi * 1.3 - .pi * 1.15
                ctx.fill(Path(ellipseIn: CGRect(x: headC.x + cos(a) * headR * 1.05 - headR * 0.45, y: headC.y + sin(a) * headR * 1.05 - headR * 0.45, width: headR * 0.9, height: headR * 0.9)), with: .color(hair.opacity(hairFade)))
            }
        default: break
        }
    }
    ctx.fill(Path(ellipseIn: CGRect(x: headC.x - headR, y: headC.y - headR, width: headR * 2, height: headR * 2.1)), with: .color(skin))
    if hairFade > 0 {
        switch look.style {
        case .bald:
            var fringe = Path()
            fringe.addArc(center: headC, radius: headR * 1.02, startAngle: .degrees(150), endAngle: .degrees(205), clockwise: false)
            ctx.stroke(fringe, with: .color(hair.opacity(hairFade)), lineWidth: headR * 0.3)
            var fr2 = Path()
            fr2.addArc(center: headC, radius: headR * 1.02, startAngle: .degrees(-25), endAngle: .degrees(30), clockwise: false)
            ctx.stroke(fr2, with: .color(hair.opacity(hairFade)), lineWidth: headR * 0.3)
        case .short:
            var cap = Path()
            cap.addArc(center: CGPoint(x: headC.x, y: headC.y + headR * 0.05), radius: headR * 1.06, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            cap.closeSubpath()
            ctx.fill(cap, with: .color(hair.opacity(hairFade)))
        case .long, .ponytail, .bun, .curly:
            var cap = Path()
            cap.addArc(center: CGPoint(x: headC.x, y: headC.y + headR * 0.1), radius: headR * 1.08, startAngle: .degrees(185), endAngle: .degrees(-5), clockwise: false)
            cap.closeSubpath()
            ctx.fill(cap, with: .color(hair.opacity(hairFade)))
            if look.style == .bun {
                ctx.fill(Path(ellipseIn: CGRect(x: headC.x - headR * 0.5, y: headC.y - headR * 1.75, width: headR, height: headR * 0.85)), with: .color(hair.opacity(hairFade)))
            }
        }
    }
    // face
    let eyeY = headC.y + headR * 0.05
    let ex = headR * 0.38
    for s in [-1.0, 1.0] {
        ctx.fill(Path(ellipseIn: CGRect(x: headC.x + CGFloat(s) * ex - headR * 0.12 + facing * headR * 0.08, y: eyeY - headR * 0.12, width: headR * 0.24, height: headR * 0.26)), with: .color(.black))
    }
    if look.female {
        ctx.fill(Path(ellipseIn: CGRect(x: headC.x - headR * 0.25, y: headC.y + headR * 0.5, width: headR * 0.5, height: headR * (talking ? 0.28 : 0.18))), with: .color(Color(red: 0.75, green: 0.25, blue: 0.3).opacity(1 - b * 0.8)))
    } else {
        var m = Path()
        let open = talking ? headR * 0.18 * abs(sin(t * 12)) : 0
        m.addEllipse(in: CGRect(x: headC.x - headR * 0.25, y: headC.y + headR * 0.52, width: headR * 0.5, height: max(headR * 0.06, open)))
        ctx.fill(m, with: .color(Color(red: 0.4, green: 0.15, blue: 0.12)))
    }
    if talking && look.female {
        let open = headR * 0.14 * abs(sin(t * 12))
        ctx.fill(Path(ellipseIn: CGRect(x: headC.x - headR * 0.15, y: headC.y + headR * 0.56, width: headR * 0.3, height: open)), with: .color(Color(red: 0.3, green: 0.05, blue: 0.08)))
    }
    if look.restored {
        ctx.stroke(Path(ellipseIn: CGRect(x: headC.x - ex - headR * 0.3, y: eyeY - headR * 0.3, width: headR * 0.6, height: headR * 0.6)), with: .color(Color(white: 0.6).opacity(0.5)), lineWidth: 0.6)
    }
    if b > 0.25 {
        // ocular implant with red targeting laser
        let a = min(1, (b - 0.25) / 0.25)
        let eye = CGRect(x: headC.x - ex - headR * 0.32, y: eyeY - headR * 0.32, width: headR * 0.64, height: headR * 0.64)
        ctx.fill(Path(ellipseIn: eye), with: .color(Color(white: 0.3).opacity(a)))
        ctx.fill(Path(ellipseIn: eye.insetBy(dx: headR * 0.18, dy: headR * 0.18)), with: .color(Color.red.opacity(a)))
        if b > 0.9 {
            var laser = Path()
            laser.move(to: CGPoint(x: eye.midX, y: eye.midY))
            laser.addLine(to: CGPoint(x: eye.midX - facing * headR * 1.8, y: eye.midY + headR * 0.4 * sin(t * 2)))
            ctx.stroke(laser, with: .color(Color.red.opacity(0.6)), lineWidth: 0.6)
        }
    }
    if b > 0.6 {
        let a = min(1, (b - 0.6) / 0.3)
        var tube = Path()
        tube.move(to: CGPoint(x: headC.x + headR * 0.7, y: headC.y - headR * 0.6))
        tube.addQuadCurve(to: CGPoint(x: headC.x + headR * 0.4, y: headC.y + headR * 1.4), control: CGPoint(x: headC.x + headR * 1.8, y: headC.y))
        ctx.stroke(tube, with: .color(Color(white: 0.25).opacity(a)), lineWidth: headR * 0.22)
        ctx.fill(Path(roundedRect: CGRect(x: headC.x - headR * 0.9, y: headC.y - headR * 1.05, width: headR * 0.9, height: headR * 0.45), cornerRadius: 1), with: .color(Color(white: 0.3).opacity(a)))
    }
}

// MARK: - Ships and objects

/// Sovereign-class profile facing right. `split` 0…1 pulls the saucer away from the stardrive.
func drawConstellation(_ ctx: GraphicsContext, at c: CGPoint, scale s: CGFloat, split: CGFloat = 0, damage: Double = 0, t: Double = 0, saucer showSaucer: Bool = true) {
    let hull = Color(red: 0.78, green: 0.8, blue: 0.84)
    let dark = Color(red: 0.45, green: 0.47, blue: 0.52)
    // stardrive section
    var drive = Path()
    drive.move(to: CGPoint(x: c.x - 70 * s, y: c.y + 6 * s))
    drive.addCurve(to: CGPoint(x: c.x + 18 * s, y: c.y + 14 * s), control1: CGPoint(x: c.x - 40 * s, y: c.y + 20 * s), control2: CGPoint(x: c.x - 5 * s, y: c.y + 22 * s))
    drive.addLine(to: CGPoint(x: c.x + 22 * s, y: c.y + 6 * s))
    drive.addLine(to: CGPoint(x: c.x - 60 * s, y: c.y))
    drive.closeSubpath()
    ctx.fill(drive, with: .color(dark))
    // deflector dish
    ctx.fill(Path(ellipseIn: CGRect(x: c.x + 10 * s, y: c.y + 8 * s, width: 9 * s, height: 6 * s)), with: .color(Color(red: 0.4, green: 0.7, blue: 1).opacity(0.9)))
    // nacelles
    for (dy, w) in [(-9.0, 1.0), (14.0, 0.85)] {
        let y = c.y + CGFloat(dy) * s
        ctx.fill(Path(roundedRect: CGRect(x: c.x - 92 * s, y: y - 3 * s * w, width: 62 * s, height: 6 * s * w), cornerRadius: 3 * s), with: .color(hull))
        ctx.fill(Path(roundedRect: CGRect(x: c.x - 88 * s, y: y - 1.2 * s, width: 50 * s, height: 2.4 * s), cornerRadius: 1), with: .color(Color(red: 0.35, green: 0.6, blue: 1).opacity(0.7 + 0.3 * sin(t * 5))))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 33 * s, y: y - 2.5 * s * w, width: 5 * s, height: 5 * s * w)), with: .color(Color(red: 1, green: 0.3, blue: 0.2)))
        var pylon = Path()
        pylon.move(to: CGPoint(x: c.x - 55 * s, y: y))
        pylon.addLine(to: CGPoint(x: c.x - 40 * s, y: c.y + 6 * s))
        ctx.stroke(pylon, with: .color(dark), lineWidth: 3 * s)
    }
    // neck
    if split < 0.05 {
        ctx.fill(Path(CGRect(x: c.x - 8 * s, y: c.y - 2 * s, width: 22 * s, height: 8 * s)), with: .color(dark))
    }
    guard showSaucer else {
        // exposed docking clamps where the saucer was
        ctx.fill(Path(CGRect(x: c.x - 8 * s, y: c.y - 1 * s, width: 22 * s, height: 3 * s)), with: .color(dark))
        return
    }
    // saucer (elongated ellipse, flat profile)
    let sc = CGPoint(x: c.x + 10 * s + split * 70 * s, y: c.y - 6 * s - split * 30 * s)
    let saucer = CGRect(x: sc.x - 38 * s, y: sc.y - 6 * s, width: 80 * s, height: 11 * s)
    ctx.fill(Path(ellipseIn: saucer), with: .color(hull))
    ctx.fill(Path(ellipseIn: CGRect(x: sc.x - 6 * s, y: sc.y - 9 * s, width: 16 * s, height: 6 * s)), with: .color(hull))
    // window lines
    for k in 0..<12 {
        let x = saucer.minX + 10 * s + CGFloat(k) * 5 * s
        ctx.fill(Path(CGRect(x: x, y: sc.y - 0.5 * s, width: 2 * s, height: 1 * s)), with: .color(Color.yellow.opacity(0.7)))
    }
    if damage > 0 {
        // scorch marks + venting atmosphere on the saucer
        for k in 0..<Int(damage * 6 + 1) {
            let x = saucer.minX + CGFloat(hash01(k, 3)) * saucer.width
            let y = saucer.minY + CGFloat(hash01(k, 4)) * saucer.height
            ctx.fill(Path(ellipseIn: CGRect(x: x - 4 * s, y: y - 2 * s, width: 8 * s, height: 4 * s)), with: .color(Color.black.opacity(0.6)))
            let flick = 0.5 + 0.5 * sin(t * 9 + Double(k))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5 * s, y: y - 1.5 * s, width: 3 * s, height: 3 * s)), with: .color(Color.orange.opacity(flick * damage)))
        }
    }
}

func drawPlanetKiller(_ ctx: GraphicsContext, at c: CGPoint, scale s: CGFloat, t: Double, weakened: Bool = false, facingLeft: Bool = true) {
    var ctx = ctx
    ctx.translateBy(x: c.x, y: c.y)
    if !facingLeft { ctx.scaleBy(x: -1, y: 1) }
    // long tapering horn; wide maw on the left
    var body = Path()
    body.move(to: CGPoint(x: -60 * s, y: -32 * s))
    body.addCurve(to: CGPoint(x: 120 * s, y: -3 * s), control1: CGPoint(x: 10 * s, y: -26 * s), control2: CGPoint(x: 80 * s, y: -10 * s))
    body.addLine(to: CGPoint(x: 120 * s, y: 3 * s))
    body.addCurve(to: CGPoint(x: -60 * s, y: 32 * s), control1: CGPoint(x: 80 * s, y: 10 * s), control2: CGPoint(x: 10 * s, y: 26 * s))
    body.closeSubpath()
    let skin = weakened ? Color(red: 0.55, green: 0.42, blue: 0.6) : Color(red: 0.55, green: 0.52, blue: 0.48)
    ctx.fill(body, with: .linearGradient(Gradient(colors: [skin, Color(white: 0.25)]), startPoint: CGPoint(x: 0, y: -30 * s), endPoint: CGPoint(x: 0, y: 30 * s)))
    // texture ridges
    for k in 0..<7 {
        let x = CGFloat(-40 + k * 22) * s
        var r = Path()
        r.move(to: CGPoint(x: x, y: -26 * s + CGFloat(k) * 3.4 * s))
        r.addLine(to: CGPoint(x: x + 6 * s, y: 26 * s - CGFloat(k) * 3.4 * s))
        ctx.stroke(r, with: .color(.black.opacity(0.25)), lineWidth: 1.2 * s)
    }
    // glowing maw
    let pulse = 0.7 + 0.3 * sin(t * 4)
    ctx.fill(Path(ellipseIn: CGRect(x: -66 * s, y: -30 * s, width: 22 * s, height: 60 * s)), with: .color(Color(white: 0.15)))
    ctx.fill(Path(ellipseIn: CGRect(x: -62 * s, y: -24 * s, width: 16 * s, height: 48 * s)),
             with: .radialGradient(Gradient(colors: [Color.yellow.opacity(pulse), Color.orange.opacity(pulse * 0.8), Color.red.opacity(0.2)]), center: CGPoint(x: -54 * s, y: 0), startRadius: 0, endRadius: 26 * s))
    if weakened {
        for k in 0..<5 {
            let x = CGFloat(-30 + k * 28) * s
            var crack = Path()
            crack.move(to: CGPoint(x: x, y: -18 * s))
            crack.addLine(to: CGPoint(x: x + 5 * s, y: -4 * s))
            crack.addLine(to: CGPoint(x: x - 3 * s, y: 8 * s))
            ctx.stroke(crack, with: .color(Color(red: 0.8, green: 0.5, blue: 1).opacity(0.5 + 0.5 * sin(t * 6 + Double(k)))), lineWidth: 1.5 * s)
        }
    }
}

func drawBorgCube(_ ctx: GraphicsContext, at c: CGPoint, size: CGFloat, t: Double, damage: Double = 0) {
    let a = size / 2
    let d = size * 0.35
    let front = CGRect(x: c.x - a, y: c.y - a + d * 0.4, width: size, height: size)
    var top = Path()
    top.move(to: CGPoint(x: front.minX, y: front.minY))
    top.addLine(to: CGPoint(x: front.minX + d, y: front.minY - d * 0.6))
    top.addLine(to: CGPoint(x: front.maxX + d, y: front.minY - d * 0.6))
    top.addLine(to: CGPoint(x: front.maxX, y: front.minY))
    top.closeSubpath()
    var side = Path()
    side.move(to: CGPoint(x: front.maxX, y: front.minY))
    side.addLine(to: CGPoint(x: front.maxX + d, y: front.minY - d * 0.6))
    side.addLine(to: CGPoint(x: front.maxX + d, y: front.maxY - d * 0.6))
    side.addLine(to: CGPoint(x: front.maxX, y: front.maxY))
    side.closeSubpath()
    ctx.fill(Path(front), with: .color(Color(white: 0.18)))
    ctx.fill(top, with: .color(Color(white: 0.28)))
    ctx.fill(side, with: .color(Color(white: 0.11)))
    // circuitry
    let n = 7
    for i in 0..<n {
        for j in 0..<n {
            let h = hash01(i * 13 + j, 9)
            guard h > 0.45 else { continue }
            let r = CGRect(x: front.minX + CGFloat(i) * size / CGFloat(n) + 1, y: front.minY + CGFloat(j) * size / CGFloat(n) + 1, width: size / CGFloat(n) - 2, height: size / CGFloat(n) * CGFloat(0.3 + h * 0.5))
            ctx.fill(Path(r), with: .color(Color(white: 0.08 + h * 0.15)))
            if h > 0.85 {
                let glow = 0.4 + 0.6 * abs(sin(t * 2 + Double(i * 7 + j)))
                ctx.fill(Path(r.insetBy(dx: r.width * 0.3, dy: r.height * 0.3)), with: .color(Color(red: 0.2, green: 1, blue: 0.4).opacity(glow * (1 - damage * 0.7))))
            }
        }
    }
    for k in 1..<n {
        let x = front.minX + CGFloat(k) * size / CGFloat(n)
        ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: front.minY)); p.addLine(to: CGPoint(x: x, y: front.maxY)) }, with: .color(Color(red: 0.2, green: 0.8, blue: 0.3).opacity(0.25)), lineWidth: 0.6)
        let y = front.minY + CGFloat(k) * size / CGFloat(n)
        ctx.stroke(Path { p in p.move(to: CGPoint(x: front.minX, y: y)); p.addLine(to: CGPoint(x: front.maxX, y: y)) }, with: .color(Color(red: 0.2, green: 0.8, blue: 0.3).opacity(0.25)), lineWidth: 0.6)
    }
    if damage > 0 {
        for k in 0..<Int(damage * 8) {
            let p = CGPoint(x: front.minX + CGFloat(hash01(k, 21)) * size, y: front.minY + CGFloat(hash01(k, 22)) * size)
            let r = size * 0.06 * CGFloat(0.6 + 0.4 * sin(t * 7 + Double(k)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(Color.orange.opacity(0.8)))
        }
    }
}

/// A small, graceful starship (the Halcyon / the Exeter).
func drawSmallShip(_ ctx: GraphicsContext, at c: CGPoint, scale s: CGFloat, hull: Color = Color(red: 0.85, green: 0.86, blue: 0.9), t: Double = 0, borg: Double = 0) {
    let h = borg > 0 ? Color(white: 0.85 - borg * 0.55) : hull
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 10 * s, y: c.y - 7 * s, width: 50 * s, height: 10 * s)), with: .color(h))
    ctx.fill(Path(roundedRect: CGRect(x: c.x - 40 * s, y: c.y, width: 40 * s, height: 8 * s), cornerRadius: 4 * s), with: .color(h.opacity(0.85)))
    ctx.fill(Path(roundedRect: CGRect(x: c.x - 50 * s, y: c.y - 12 * s, width: 34 * s, height: 4 * s), cornerRadius: 2 * s), with: .color(h))
    ctx.fill(Path(roundedRect: CGRect(x: c.x - 48 * s, y: c.y - 11 * s, width: 28 * s, height: 2 * s), cornerRadius: 1), with: .color(Color(red: 0.4, green: 0.6, blue: 1).opacity(0.6 + 0.4 * sin(t * 6))))
    ctx.stroke(Path { p in p.move(to: CGPoint(x: c.x - 30 * s, y: c.y - 8 * s)); p.addLine(to: CGPoint(x: c.x - 22 * s, y: c.y + 1 * s)) }, with: .color(h), lineWidth: 2 * s)
    if borg > 0.3 {
        for k in 0..<6 {
            let x = c.x - 40 * s + CGFloat(k) * 14 * s
            ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: c.y - 6 * s)); p.addLine(to: CGPoint(x: x + 6 * s, y: c.y + 7 * s)) }, with: .color(Color.green.opacity(borg * 0.6)), lineWidth: 0.8 * s)
        }
    }
}

func drawStarbase(_ ctx: GraphicsContext, at c: CGPoint, scale s: CGFloat, t: Double) {
    let hull = Color(red: 0.7, green: 0.72, blue: 0.78)
    ctx.fill(Path(CGRect(x: c.x - 4 * s, y: c.y - 90 * s, width: 8 * s, height: 180 * s)), with: .color(hull.opacity(0.9)))
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 70 * s, y: c.y - 60 * s, width: 140 * s, height: 30 * s)), with: .color(hull))
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 40 * s, y: c.y - 20 * s, width: 80 * s, height: 18 * s)), with: .color(hull.opacity(0.85)))
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 55 * s, y: c.y + 30 * s, width: 110 * s, height: 24 * s)), with: .color(hull))
    for k in 0..<18 {
        let x = c.x - 60 * s + CGFloat(k) * 7 * s
        let on = hash01(k, Int(t * 0.5)) > 0.3
        ctx.fill(Path(CGRect(x: x, y: c.y - 46 * s, width: 3 * s, height: 2 * s)), with: .color(Color.yellow.opacity(on ? 0.8 : 0.3)))
        ctx.fill(Path(CGRect(x: x + 5 * s, y: c.y + 41 * s, width: 3 * s, height: 2 * s)), with: .color(Color.yellow.opacity(on ? 0.3 : 0.8)))
    }
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3 * s, y: c.y - 94 * s, width: 6 * s, height: 6 * s)), with: .color(Color.red.opacity(0.5 + 0.5 * sin(t * 3))))
}

func drawPlanet(_ ctx: GraphicsContext, at c: CGPoint, r: CGFloat, base: RGB, eaten: Double = 0, t: Double = 0) {
    guard eaten < 1 else {
        // debris field
        for k in 0..<14 {
            let a = hash01(k, 31) * 2 * .pi
            let d = r * CGFloat(0.4 + hash01(k, 32) * 1.4)
            let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(Color(white: 0.5)))
        }
        return
    }
    let rr = r * CGFloat(1 - eaten * 0.6)
    let rect = CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr)
    ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [base.mix(RGB(1, 1, 1), 0.3).color, base.color, base.mix(RGB(0, 0, 0), 0.7).color]), center: CGPoint(x: c.x - rr * 0.4, y: c.y - rr * 0.4), startRadius: 0, endRadius: rr * 1.6))
    if eaten > 0 {
        ctx.fill(Path(ellipseIn: rect.insetBy(dx: rr * 0.3, dy: rr * 0.3)), with: .color(Color.orange.opacity(eaten * (0.6 + 0.4 * sin(t * 10)))))
    }
}

func drawStarfield(_ ctx: GraphicsContext, size: CGSize, t: Double, speed: Double = 0.4, streak: Double = 0) {
    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
    for i in 0..<140 {
        let depth = 0.3 + hash01(i, 2) * 0.7
        let w = Double(size.width) + 60
        var x = hash01(i, 1) * w - t * speed * 40 * depth
        x = x.truncatingRemainder(dividingBy: w)
        if x < 0 { x += w }
        let y = hash01(i, 3) * Double(size.height)
        let a = 0.3 + depth * 0.7
        if streak > 0 {
            let len = streak * 50 * depth
            ctx.stroke(Path { p in p.move(to: CGPoint(x: x - 30, y: y)); p.addLine(to: CGPoint(x: x - 30 + len, y: y)) }, with: .color(.white.opacity(a)), lineWidth: depth * 1.4)
        } else {
            let r = depth * 1.2
            ctx.fill(Path(ellipseIn: CGRect(x: x - 30 - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(.white.opacity(a)))
        }
    }
}

func drawNebula(_ ctx: GraphicsContext, size: CGSize, t: Double) {
    var layer = ctx
    layer.addFilter(.blur(radius: 30))
    for k in 0..<7 {
        let x = CGFloat(hash01(k, 41)) * size.width
        let y = CGFloat(hash01(k, 42)) * size.height
        let r = size.width * CGFloat(0.2 + hash01(k, 43) * 0.25)
        let c = k % 2 == 0 ? Color(red: 0.8, green: 0.3, blue: 0.6) : Color(red: 0.3, green: 0.3, blue: 0.8)
        layer.fill(Path(ellipseIn: CGRect(x: x - r + CGFloat(sin(t * 0.2 + Double(k)) * 10), y: y - r * 0.6, width: 2 * r, height: r * 1.2)), with: .color(c.opacity(0.35)))
    }
}

func drawExplosion(_ ctx: GraphicsContext, at c: CGPoint, r: CGFloat, u: Double) {
    guard u >= 0, u <= 1 else { return }
    let rr = r * CGFloat(0.3 + u)
    let a = 1 - u
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr)),
             with: .radialGradient(Gradient(colors: [Color.white.opacity(a), Color.yellow.opacity(a), Color.orange.opacity(a * 0.7), .clear]), center: c, startRadius: 0, endRadius: rr))
    for k in 0..<10 {
        let ang = Double(k) / 10 * 2 * .pi + hash01(k, 51)
        let d = rr * 1.3
        ctx.fill(Path(ellipseIn: CGRect(x: c.x + cos(ang) * d - 1.5, y: c.y + sin(ang) * d - 1.5, width: 3, height: 3)), with: .color(Color.orange.opacity(a)))
    }
}

func beam(_ ctx: GraphicsContext, from a: CGPoint, to b: CGPoint, color: Color, width: CGFloat, alpha: Double) {
    var p = Path(); p.move(to: a); p.addLine(to: b)
    ctx.stroke(p, with: .color(color.opacity(alpha * 0.35)), lineWidth: width * 3)
    ctx.stroke(p, with: .color(color.opacity(alpha)), lineWidth: width)
    ctx.stroke(p, with: .color(.white.opacity(alpha * 0.8)), lineWidth: width * 0.35)
}
