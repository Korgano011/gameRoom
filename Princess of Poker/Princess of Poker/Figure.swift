import SwiftUI

private func circle(_ c: CGPoint, _ r: Double) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
}

private func limb(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ w: Double, _ color: Color) {
    var p = Path()
    p.move(to: a)
    p.addLine(to: b)
    ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round))
}

/// A tiny four-pointed twinkle.
func drawTwinkle(_ ctx: GraphicsContext, _ c: CGPoint, _ s: Double, _ color: Color = .white) {
    var p = Path()
    p.move(to: CGPoint(x: c.x, y: c.y - s))
    p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: c)
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: c)
    p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: c)
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: c)
    ctx.fill(p, with: .color(color))
}

private func hash(_ a: Int, _ b: Int) -> Double {
    var x = UInt64(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663)
    x ^= x >> 13; x &*= 0x5bd1e995; x ^= x >> 15
    return Double(x % 10_000) / 10_000
}

// MARK: Heads

/// Big thick curls on top of the head and around the sides, stopping above the chin.
private func drawCurlsBack(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ hair: Color) {
    let center = CGPoint(x: c.x, y: c.y - r * 0.2)
    ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 1.3, y: center.y - r * 1.1, width: r * 2.6, height: r * 1.9)),
             with: .color(hair))
    for i in 0..<16 {
        let a = Double(i) / 16 * 2 * .pi
        let p = CGPoint(x: center.x + cos(a) * r * 1.25, y: center.y + sin(a) * r * 1.0)
        // No curls under the head — only the top and the sides down to cheek level.
        guard p.y < c.y + r * 0.3 else { continue }
        ctx.fill(circle(p, r * 0.42), with: .color(hair))
        ctx.stroke(Path { $0.addArc(center: p, radius: r * 0.24, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false) },
                   with: .color(.black.opacity(0.18)), lineWidth: max(1, r * 0.06))
    }
}

/// Curly bangs across the top of the forehead.
private func drawCurlsFront(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ hair: Color) {
    for i in 0..<7 {
        let a = Double.pi * (1.08 + Double(i) / 6 * 0.84)
        let p = CGPoint(x: c.x + cos(a) * r * 0.82, y: c.y + sin(a) * r * 0.82)
        ctx.fill(circle(p, r * 0.36), with: .color(hair))
        ctx.stroke(Path { $0.addArc(center: p, radius: r * 0.18, startAngle: .degrees(20), endAngle: .degrees(200), clockwise: false) },
                   with: .color(.black.opacity(0.18)), lineWidth: max(1, r * 0.05))
    }
}

private func drawTiara(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ now: Date) {
    let base = c.y - r * 1.12
    var p = Path()
    p.move(to: CGPoint(x: c.x - r * 0.7, y: base))
    for i in 0...6 {
        let x = c.x - r * 0.7 + Double(i) * r * 1.4 / 6
        p.addLine(to: CGPoint(x: x, y: base - (i % 2 == 0 ? r * 0.12 : (i == 3 ? r * 0.55 : r * 0.35))))
    }
    p.addLine(to: CGPoint(x: c.x + r * 0.7, y: base))
    p.closeSubpath()
    ctx.fill(p, with: .color(Color(red: 1, green: 0.82, blue: 0.2)))
    ctx.fill(circle(CGPoint(x: c.x, y: base - r * 0.3), r * 0.1), with: .color(.pink))
    let tw = 0.5 + 0.5 * sin(now.timeIntervalSinceReferenceDate * 4)
    drawTwinkle(ctx, CGPoint(x: c.x + r * 0.2, y: base - r * 0.55), r * 0.22 * tw)
}

private func drawEyes(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, girl: Bool, mood: Mood) {
    for s in [-1.0, 1.0] {
        let e = CGPoint(x: c.x + s * r * 0.36, y: c.y - r * 0.05)
        let big = mood == .shocked ? 1.35 : (mood == .scared ? 1.3 : 1.0)
        ctx.fill(Path(ellipseIn: CGRect(x: e.x - r * 0.17 * big, y: e.y - r * 0.2 * big, width: r * 0.34 * big, height: r * 0.4 * big)),
                 with: .color(.white))
        if mood == .scared {
            // Tiny pinpoint pupils.
            ctx.fill(circle(CGPoint(x: e.x, y: e.y + r * 0.02), r * 0.055), with: .color(Color(red: 0.2, green: 0.15, blue: 0.1)))
        } else {
            ctx.fill(circle(CGPoint(x: e.x, y: e.y + r * 0.03), r * 0.1), with: .color(Color(red: 0.2, green: 0.15, blue: 0.1)))
            ctx.fill(circle(CGPoint(x: e.x + r * 0.04, y: e.y - r * 0.02), r * 0.035), with: .color(.white))
        }
        if girl {
            for k in 0..<3 {
                let a = Double.pi * (1.15 + Double(k) * 0.35)
                limb(ctx, CGPoint(x: e.x + cos(a) * r * 0.17, y: e.y + sin(a) * r * 0.2),
                     CGPoint(x: e.x + cos(a) * r * 0.3, y: e.y + sin(a) * r * 0.33), max(1, r * 0.05), .black)
            }
        }
        // Brows
        if mood == .scared {
            // Steep and raised toward the middle.
            var b = Path()
            b.move(to: CGPoint(x: e.x + s * r * 0.17, y: e.y - r * 0.3))
            b.addQuadCurve(to: CGPoint(x: e.x - s * r * 0.12, y: e.y - r * 0.52), control: CGPoint(x: e.x, y: e.y - r * 0.36))
            ctx.stroke(b, with: .color(.black.opacity(0.75)), style: StrokeStyle(lineWidth: max(1, r * (girl ? 0.05 : 0.08)), lineCap: .round))
            continue
        }
        let lift = mood == .shocked ? r * 0.12 : (mood == .worried ? r * 0.05 : 0)
        var b = Path()
        b.move(to: CGPoint(x: e.x - r * 0.16, y: e.y - r * 0.3 - lift + (mood == .worried ? s * -r * 0.04 : 0)))
        b.addQuadCurve(to: CGPoint(x: e.x + r * 0.16, y: e.y - r * 0.3 - lift), control: CGPoint(x: e.x, y: e.y - r * 0.4 - lift))
        ctx.stroke(b, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: max(1, r * (girl ? 0.05 : 0.08)), lineCap: .round))
    }
}

private func drawMouth(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, lips: Color?, open: Double, mood: Mood) {
    let m = CGPoint(x: c.x, y: c.y + r * 0.48)
    if mood == .scared {
        // A wide, wobbly grimace with clenched teeth.
        let w = r * 0.26, h = r * 0.14
        var g = Path()
        g.move(to: CGPoint(x: m.x - w, y: m.y))
        g.addCurve(to: CGPoint(x: m.x + w, y: m.y), control1: CGPoint(x: m.x - w * 0.4, y: m.y - h * 1.1), control2: CGPoint(x: m.x + w * 0.4, y: m.y - h * 0.5))
        g.addCurve(to: CGPoint(x: m.x - w, y: m.y), control1: CGPoint(x: m.x + w * 0.4, y: m.y + h * 1.4), control2: CGPoint(x: m.x - w * 0.4, y: m.y + h * 0.8))
        ctx.fill(g, with: .color(Color(red: 0.35, green: 0.05, blue: 0.08)))
        var teeth = ctx
        teeth.clip(to: g)
        teeth.fill(Path(CGRect(x: m.x - w, y: m.y - h, width: w * 2, height: h * 1.05)), with: .color(.white))
        teeth.fill(Path(CGRect(x: m.x - w, y: m.y + h * 0.35, width: w * 2, height: h)), with: .color(.white.opacity(0.9)))
        for k in 1..<6 {
            let x = m.x - w + Double(k) * w / 3
            teeth.stroke(Path { $0.move(to: CGPoint(x: x, y: m.y - h)); $0.addLine(to: CGPoint(x: x, y: m.y + h * 1.4)) },
                         with: .color(.gray.opacity(0.6)), lineWidth: max(0.5, r * 0.02))
        }
        ctx.stroke(g, with: .color(lips ?? Color(red: 0.45, green: 0.15, blue: 0.12)), lineWidth: max(1, r * 0.05))
        return
    }
    if mood == .shocked {
        ctx.fill(Path(ellipseIn: CGRect(x: m.x - r * 0.13, y: m.y - r * 0.12, width: r * 0.26, height: r * 0.3)), with: .color(Color(red: 0.35, green: 0.05, blue: 0.08)))
        if let lips {
            ctx.stroke(Path(ellipseIn: CGRect(x: m.x - r * 0.15, y: m.y - r * 0.14, width: r * 0.3, height: r * 0.34)), with: .color(lips), lineWidth: max(1.5, r * 0.08))
        }
        return
    }
    if open > 0.05 {
        let h = r * 0.22 * open
        ctx.fill(Path(ellipseIn: CGRect(x: m.x - r * 0.2, y: m.y - h / 2, width: r * 0.4, height: h + r * 0.04)), with: .color(Color(red: 0.35, green: 0.05, blue: 0.08)))
    }
    if let lips {
        var top = Path()
        top.move(to: CGPoint(x: m.x - r * 0.24, y: m.y))
        top.addQuadCurve(to: CGPoint(x: m.x, y: m.y - r * 0.07), control: CGPoint(x: m.x - r * 0.12, y: m.y - r * 0.14))
        top.addQuadCurve(to: CGPoint(x: m.x + r * 0.24, y: m.y), control: CGPoint(x: m.x + r * 0.12, y: m.y - r * 0.14))
        top.addQuadCurve(to: CGPoint(x: m.x - r * 0.24, y: m.y), control: CGPoint(x: m.x, y: m.y + r * 0.02 - r * 0.11 * open))
        ctx.fill(top, with: .color(lips))
        var bottom = Path()
        bottom.move(to: CGPoint(x: m.x - r * 0.24, y: m.y))
        bottom.addQuadCurve(to: CGPoint(x: m.x + r * 0.24, y: m.y), control: CGPoint(x: m.x, y: m.y + r * 0.05 + r * 0.15 * open))
        bottom.addQuadCurve(to: CGPoint(x: m.x - r * 0.24, y: m.y), control: CGPoint(x: m.x, y: m.y + r * 0.26 + r * 0.15 * open))
        ctx.fill(bottom, with: .color(lips))
        ctx.fill(circle(CGPoint(x: m.x - r * 0.06, y: m.y + r * 0.1 + r * 0.1 * open), r * 0.035), with: .color(.white.opacity(0.6)))
    } else {
        var p = Path()
        p.move(to: CGPoint(x: m.x - r * 0.2, y: m.y))
        p.addQuadCurve(to: CGPoint(x: m.x + r * 0.2, y: m.y), control: CGPoint(x: m.x, y: m.y + (mood == .worried ? -r * 0.08 : r * 0.14)))
        ctx.stroke(p, with: .color(Color(red: 0.45, green: 0.15, blue: 0.12)), style: StrokeStyle(lineWidth: max(1, r * 0.07), lineCap: .round))
    }
}

/// A girl's head with thick curls (behind and front), lashes, blush and coloured lips.
func drawGirlHead(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, skin: Color, look: GirlLook, open: Double, mood: Mood, now: Date, back: Bool = true) {
    if back { drawCurlsBack(ctx, c, r, look.hair) }
    ctx.fill(circle(c, r), with: .color(skin))
    for s in [-1.0, 1.0] {
        ctx.fill(circle(CGPoint(x: c.x + s * r * 0.55, y: c.y + r * 0.3), r * 0.15), with: .color(.pink.opacity(0.45)))
    }
    drawEyes(ctx, c, r, girl: true, mood: mood)
    drawMouth(ctx, c, r, lips: look.lips, open: open, mood: mood)
    drawCurlsFront(ctx, c, r, look.hair)
    if look.tiara { drawTiara(ctx, c, r, now) }
}

private func drawGuyHead(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, skin: Color, look: GuyLook, open: Double, mood: Mood, powder: Double) {
    for s in [-1.0, 1.0] {
        ctx.fill(circle(CGPoint(x: c.x + s * r * 0.98, y: c.y + r * 0.05), r * 0.2), with: .color(skin))
    }
    ctx.fill(circle(c, r), with: .color(skin))
    var hair = Path()
    hair.addArc(center: c, radius: r * 1.04, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
    hair.addQuadCurve(to: CGPoint(x: c.x - r * 1.0, y: c.y - r * 0.05), control: CGPoint(x: c.x, y: c.y - r * 0.55))
    ctx.fill(hair, with: .color(look.hair))
    drawEyes(ctx, c, r, girl: false, mood: mood)
    drawMouth(ctx, c, r, lips: nil, open: open, mood: mood)
    if open > 0.05 && mood != .shocked {
        let m = CGPoint(x: c.x, y: c.y + r * 0.5)
        ctx.fill(Path(ellipseIn: CGRect(x: m.x - r * 0.15, y: m.y - r * 0.05, width: r * 0.3, height: r * 0.2 * open + r * 0.04)), with: .color(Color(red: 0.35, green: 0.05, blue: 0.08)))
    }
    if powder > 0 {
        ctx.fill(circle(c, r * 1.02), with: .color(.white.opacity(0.85 * powder)))
        for i in 0..<12 {
            let a = Double(i) * 2.4
            let p = CGPoint(x: c.x + cos(a) * r * (0.3 + 0.6 * hash(i, 7)), y: c.y + sin(a) * r * (0.3 + 0.6 * hash(i, 9)))
            ctx.fill(circle(p, r * 0.08), with: .color(.white.opacity(powder)))
        }
    }
    if mood == .scared {
        // Keep the fright readable through any powder, and add beads of sweat.
        if powder > 0 {
            drawEyes(ctx, c, r, girl: false, mood: mood)
            drawMouth(ctx, c, r, lips: nil, open: open, mood: mood)
        }
        for (dx, dy) in [(1.08, -0.45), (-1.12, -0.2), (1.18, 0.05)] {
            let d = CGPoint(x: c.x + dx * r, y: c.y + dy * r)
            var drop = Path()
            drop.move(to: CGPoint(x: d.x, y: d.y - r * 0.16))
            drop.addQuadCurve(to: CGPoint(x: d.x, y: d.y + r * 0.08), control: CGPoint(x: d.x + r * 0.14, y: d.y + r * 0.06))
            drop.addQuadCurve(to: CGPoint(x: d.x, y: d.y - r * 0.16), control: CGPoint(x: d.x - r * 0.14, y: d.y + r * 0.06))
            ctx.fill(drop, with: .color(Color(red: 0.6, green: 0.85, blue: 1)))
        }
    }
}

/// A face part-way between guy and girl (`m` 0…1): his hair, ears and brows fade away while
/// her curls grow in around the head and the lashes, blush and lipstick fade up.
private func drawMorphHead(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, skin: Color, guy: GuyLook, girl: GirlLook,
                           m: Double, open: Double, mood: Mood, back: Bool) {
    let grow = 0.35 + 0.65 * m
    func curls(_ draw: (GraphicsContext) -> Void) {
        ctx.drawLayer { l in
            l.opacity = min(1, m * 1.6)
            l.translateBy(x: c.x, y: c.y)
            l.scaleBy(x: grow, y: grow)
            l.translateBy(x: -c.x, y: -c.y)
            draw(l)
        }
    }
    if back {
        curls { drawCurlsBack($0, c, r, girl.hair) }
        return
    }
    ctx.drawLayer { l in
        l.opacity = 1 - m
        for s in [-1.0, 1.0] {
            l.fill(circle(CGPoint(x: c.x + s * r * 0.98, y: c.y + r * 0.05), r * 0.2), with: .color(skin))
        }
    }
    ctx.fill(circle(c, r), with: .color(skin))
    ctx.drawLayer { l in
        l.opacity = 1 - m
        var hair = Path()
        hair.addArc(center: c, radius: r * 1.04, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
        hair.addQuadCurve(to: CGPoint(x: c.x - r * 1.0, y: c.y - r * 0.05), control: CGPoint(x: c.x, y: c.y - r * 0.55))
        l.fill(hair, with: .color(guy.hair))
        drawEyes(l, c, r, girl: false, mood: mood)
        drawMouth(l, c, r, lips: nil, open: open, mood: mood)
    }
    ctx.drawLayer { l in
        l.opacity = m
        for s in [-1.0, 1.0] {
            l.fill(circle(CGPoint(x: c.x + s * r * 0.55, y: c.y + r * 0.3), r * 0.15), with: .color(.pink.opacity(0.45)))
        }
        drawEyes(l, c, r, girl: true, mood: mood)
        drawMouth(l, c, r, lips: girl.lips, open: open, mood: mood)
    }
    curls { drawCurlsFront($0, c, r, girl.hair) }
}

// MARK: Bodies

private struct Frame {
    let x, foot, H, r: Double
    var top: Double { foot - H }
    var head: CGPoint { CGPoint(x: x, y: top + r) }
    var shoulderY: Double { top + 2 * r + H * 0.035 }
    var shoulderW: Double { H * 0.115 }
    var waistY: Double { foot - H * 0.48 }
    var kneeY: Double { foot - H * 0.25 }
}

private func drawGirlBody(_ ctx: GraphicsContext, _ f: Frame, _ p: Person, _ phase: Double, walking: Bool, now: Date, open: Double, head: Bool = true) {
    let look = p.girl
    if head { drawCurlsBack(ctx, f.head, f.r, look.hair) }
    let H = f.H
    // Legs + heels
    if p.seated {
        // Sitting: thighs come forward to the knees, shins drop to the floor.
        let floor = f.foot - H * 0.2
        for s in [-1.0, 1.0] {
            let hip = CGPoint(x: f.x + s * H * 0.045, y: f.waistY + H * 0.01)
            let knee = CGPoint(x: f.x + s * H * 0.08, y: f.waistY + H * 0.05)
            let ankle = CGPoint(x: f.x + s * H * 0.06, y: floor - H * 0.035)
            limb(ctx, hip, knee, H * 0.065, p.skin)
            limb(ctx, knee, ankle, H * 0.05, p.skin)
            var heel = Path()
            heel.addRoundedRect(in: CGRect(x: ankle.x - H * 0.03, y: ankle.y - H * 0.01, width: H * 0.06, height: H * 0.035), cornerSize: CGSize(width: 3, height: 3))
            ctx.fill(heel, with: .color(look.dress.opacity(0.9)))
            limb(ctx, CGPoint(x: ankle.x + s * H * 0.02, y: ankle.y + H * 0.02), CGPoint(x: ankle.x + s * H * 0.022, y: ankle.y + H * 0.04), H * 0.012, .black)
        }
    } else {
        for s in [-1.0, 1.0] {
            let lift = walking ? max(0, sin(phase + (s > 0 ? .pi : 0))) * H * 0.05 : 0
            let hip = CGPoint(x: f.x + s * H * 0.04, y: f.waistY)
            let ankle = CGPoint(x: f.x + s * H * 0.045, y: f.foot - H * 0.035 - lift)
            limb(ctx, hip, ankle, H * 0.05, p.skin)
            var heel = Path()
            heel.addRoundedRect(in: CGRect(x: ankle.x - H * 0.03, y: ankle.y - H * 0.01, width: H * 0.06, height: H * 0.035), cornerSize: CGSize(width: 3, height: 3))
            ctx.fill(heel, with: .color(look.dress.opacity(0.9)))
            limb(ctx, CGPoint(x: ankle.x + s * H * 0.02, y: ankle.y + H * 0.02), CGPoint(x: ankle.x + s * H * 0.022, y: ankle.y + H * 0.04), H * 0.012, .black)
        }
    }
    // Arms
    for s in [-1.0, 1.0] {
        let sh = CGPoint(x: f.x + s * f.shoulderW * 0.85, y: f.shoulderY + H * 0.02)
        var hand = CGPoint(x: f.x + s * (f.shoulderW + H * 0.03), y: f.waistY + H * 0.06)
        if walking { hand.x += sin(phase + (s > 0 ? 0 : .pi)) * H * 0.03 }
        if p.seated { hand = CGPoint(x: f.x + s * H * 0.07, y: f.waistY + H * 0.045) }
        if p.handsToFace { hand = CGPoint(x: f.x + s * f.r * 1.05, y: f.head.y + f.r * 0.35 + sin(now.timeIntervalSinceReferenceDate * 14) * 3) }
        if s > 0, let reach = p.reachTo { hand = reach }
        let elbow = CGPoint(x: (sh.x + hand.x) / 2 + s * H * 0.02, y: (sh.y + hand.y) / 2)
        limb(ctx, sh, elbow, H * 0.042, p.skin)
        limb(ctx, elbow, hand, H * 0.038, p.skin)
        ctx.fill(circle(hand, H * 0.024), with: .color(p.skin))
    }
    // Bare shoulders and chest above the neckline, so nothing shows through around the neck.
    var chest = Path()
    chest.addRoundedRect(in: CGRect(x: f.x - f.shoulderW * 0.9, y: f.shoulderY - H * 0.005, width: f.shoulderW * 1.8, height: f.waistY - f.shoulderY),
                         cornerSize: CGSize(width: H * 0.03, height: H * 0.03))
    ctx.fill(chest, with: .color(p.skin))
    // Sparkling dress: fitted bodice, flared skirt to the knee.
    var dress = Path()
    let bw = f.shoulderW * 0.8
    dress.move(to: CGPoint(x: f.x - bw, y: f.shoulderY + H * 0.03))
    dress.addQuadCurve(to: CGPoint(x: f.x + bw, y: f.shoulderY + H * 0.03), control: CGPoint(x: f.x, y: f.shoulderY + H * 0.08))
    dress.addLine(to: CGPoint(x: f.x + H * 0.07, y: f.waistY))
    // Seated, the skirt drapes over the lap and stops just past the knees.
    let hemY = p.seated ? f.waistY + H * 0.075 : f.kneeY + H * 0.03
    let hemW = p.seated ? H * 0.15 : H * 0.17
    dress.addLine(to: CGPoint(x: f.x + hemW, y: hemY))
    dress.addQuadCurve(to: CGPoint(x: f.x - hemW, y: hemY), control: CGPoint(x: f.x, y: hemY + H * 0.04))
    dress.addLine(to: CGPoint(x: f.x - H * 0.07, y: f.waistY))
    dress.closeSubpath()
    ctx.fill(dress, with: .linearGradient(Gradient(colors: [look.dressHi, look.dress, look.dress.opacity(0.85)]),
                                          startPoint: CGPoint(x: f.x - H * 0.15, y: f.shoulderY), endPoint: CGPoint(x: f.x + H * 0.15, y: f.kneeY)))
    for s in [-1.0, 1.0] {
        limb(ctx, CGPoint(x: f.x + s * bw * 0.8, y: f.shoulderY + H * 0.035), CGPoint(x: f.x + s * bw * 0.7, y: f.shoulderY - H * 0.005), H * 0.012, look.dress)
    }
    let t = now.timeIntervalSinceReferenceDate
    for i in 0..<16 {
        let u = hash(p.seed, i), v = hash(i, p.seed)
        let y = f.shoulderY + H * 0.05 + v * (hemY - H * 0.03 - f.shoulderY)
        let half = H * (0.06 + 0.1 * max(0, (y - f.waistY) / (f.kneeY - f.waistY)))
        let tw = 0.5 + 0.5 * sin(t * 3 + Double(i) * 1.7)
        drawTwinkle(ctx, CGPoint(x: f.x + (u * 2 - 1) * half, y: y), H * 0.018 * (0.4 + tw), .white.opacity(0.4 + 0.6 * tw))
    }
    // Neck + head
    limb(ctx, CGPoint(x: f.x, y: f.top + 2 * f.r - 2), CGPoint(x: f.x, y: f.shoulderY + H * 0.01), H * 0.045, p.skin)
    if head { drawGirlHead(ctx, f.head, f.r, skin: p.skin, look: look, open: open, mood: p.mood, now: now, back: false) }
}

private func drawGuyBody(_ ctx: GraphicsContext, _ f: Frame, _ p: Person, _ phase: Double, walking: Bool, now: Date, open: Double, head: Bool = true) {
    let look = p.guy
    let H = f.H
    for s in [-1.0, 1.0] {
        let lift = walking ? max(0, sin(phase + (s > 0 ? .pi : 0))) * H * 0.05 : 0
        let hip = CGPoint(x: f.x + s * H * 0.045, y: f.waistY)
        let ankle = CGPoint(x: f.x + s * H * 0.05, y: f.foot - H * 0.035 - lift)
        limb(ctx, hip, ankle, H * 0.075, look.pants)
        ctx.fill(Path(ellipseIn: CGRect(x: ankle.x - H * 0.045 + s * H * 0.01, y: ankle.y - H * 0.005, width: H * 0.09, height: H * 0.045)),
                 with: .color(Color(red: 0.25, green: 0.17, blue: 0.1)))
    }
    for s in [-1.0, 1.0] {
        let sh = CGPoint(x: f.x + s * f.shoulderW * 0.95, y: f.shoulderY + H * 0.03)
        var hand = CGPoint(x: f.x + s * (f.shoulderW + H * 0.035), y: f.waistY + H * 0.07)
        if walking { hand.x += sin(phase + (s > 0 ? 0 : .pi)) * H * (p.running ? 0.06 : 0.03) }
        if p.handsToFace { hand = CGPoint(x: f.x + s * f.r * 1.05, y: f.head.y + f.r * 0.35 + sin(now.timeIntervalSinceReferenceDate * 14) * 3) }
        if s > 0, let reach = p.reachTo { hand = reach }
        let elbow = CGPoint(x: (sh.x + hand.x) / 2 + s * H * 0.025, y: (sh.y + hand.y) / 2)
        limb(ctx, sh, elbow, H * 0.06, look.shirt)
        limb(ctx, elbow, hand, H * 0.045, p.skin)
        ctx.fill(circle(hand, H * 0.026), with: .color(p.skin))
    }
    var torso = Path()
    torso.addRoundedRect(in: CGRect(x: f.x - f.shoulderW, y: f.shoulderY, width: 2 * f.shoulderW, height: f.waistY - f.shoulderY + H * 0.05),
                         cornerSize: CGSize(width: H * 0.04, height: H * 0.04))
    ctx.fill(torso, with: .color(look.shirt))
    var collar = Path()
    collar.move(to: CGPoint(x: f.x - H * 0.04, y: f.shoulderY))
    collar.addLine(to: CGPoint(x: f.x, y: f.shoulderY + H * 0.05))
    collar.addLine(to: CGPoint(x: f.x + H * 0.04, y: f.shoulderY))
    ctx.stroke(collar, with: .color(.black.opacity(0.35)), lineWidth: max(1, H * 0.01))
    if look.nameTag {
        let tag = CGRect(x: f.x + H * 0.03, y: f.shoulderY + H * 0.07, width: H * 0.07, height: H * 0.035)
        ctx.fill(Path(roundedRect: tag, cornerRadius: 2), with: .color(.white))
        ctx.fill(circle(CGPoint(x: tag.midX, y: tag.midY), H * 0.012), with: .color(.red))
    }
    limb(ctx, CGPoint(x: f.x, y: f.top + 2 * f.r - 2), CGPoint(x: f.x, y: f.shoulderY + H * 0.01), H * 0.05, p.skin)
    if head { drawGuyHead(ctx, f.head, f.r, skin: p.skin, look: look, open: open, mood: p.mood, powder: p.powderLevel(at: now)) }
}

/// Draws a person standing (or walking) with their feet at `baseY - rise`. A part-way change shows
/// the girl from the feet up to a glowing line and the guy above it. `faceOnly` redraws just a leaning
/// kisser's face, so her lips show on top of the cheek she's kissing while her curls stay behind.
func drawPerson(_ ctx: GraphicsContext, _ p: Person, now: Date, faceOnly: Bool = false) {
    guard p.visible, p.opacity > 0 else { return }
    var ctx = ctx
    ctx.opacity = p.opacity
    let r = p.height * (p.isKid ? 0.12 : 0.095)
    // Sitting lowers everything above the knees; the legs fold down to the floor.
    let drop = p.seated ? p.height * 0.2 : 0
    let f = Frame(x: p.x(at: now), foot: p.baseY - p.rise(at: now) + drop, H: p.height, r: r)
    let walking = p.isWalking(at: now)
    let phase = now.timeIntervalSinceReferenceDate * (p.running ? 15 : 8)
    let talking = now < p.talkingUntil
    let open = talking ? 0.5 + 0.5 * sin(now.timeIntervalSinceReferenceDate * 18) : 0
    let g = p.girlness(at: now)
    // Shadow
    if !faceOnly { ctx.fill(Path(ellipseIn: CGRect(x: f.x - p.height * 0.13, y: p.baseY - 5, width: p.height * 0.26, height: 10)), with: .color(.black.opacity(0.18))) }
    // Leaning in for a kiss tips the whole figure about the feet.
    let lean = p.lean(at: now)
    if lean != 0 {
        let pivot = CGPoint(x: f.x, y: f.foot - drop)
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: .radians(lean))
        ctx.translateBy(x: -pivot.x, y: -pivot.y)
    }
    if faceOnly {
        drawGirlHead(ctx, f.head, r, skin: p.skin, look: p.girl, open: open, mood: p.mood, now: now, back: false)
        return
    }

    if g <= 0 {
        drawGuyBody(ctx, f, p, phase, walking: walking, now: now, open: open)
    } else if g >= 1 {
        drawGirlBody(ctx, f, p, phase, walking: walking, now: now, open: open)
    } else {
        let bandY = f.foot - g * (p.height + r * 1.0)
        // Once the line passes the chin, the whole face morphs instead of being wiped.
        let chinY = f.top + 2 * r
        let morphing = bandY < chinY
        let m = min(1, max(0, (chinY - bandY) / (chinY - (f.top - r))))
        if morphing {
            drawMorphHead(ctx, f.head, r, skin: p.skin, guy: p.guy, girl: p.girl, m: m, open: open, mood: p.mood, back: true)
        }
        ctx.drawLayer { layer in
            layer.clip(to: Path(CGRect(x: f.x - 300, y: -2000, width: 600, height: 2000 + bandY)))
            drawGuyBody(layer, f, p, phase, walking: walking, now: now, open: open, head: !morphing)
        }
        ctx.drawLayer { layer in
            layer.clip(to: Path(CGRect(x: f.x - 300, y: bandY, width: 600, height: 2000)))
            drawGirlBody(layer, f, p, phase, walking: walking, now: now, open: open, head: !morphing)
        }
        if morphing {
            drawMorphHead(ctx, f.head, r, skin: p.skin, guy: p.guy, girl: p.girl, m: m, open: open, mood: p.mood, back: false)
        }
        let w = p.height * 0.32
        var line = Path()
        line.move(to: CGPoint(x: f.x - w, y: bandY))
        line.addLine(to: CGPoint(x: f.x + w, y: bandY))
        ctx.stroke(line, with: .color(Color.yellow.opacity(0.35)), lineWidth: 14)
        ctx.stroke(line, with: .color(.white), lineWidth: 3)
        let t = now.timeIntervalSinceReferenceDate
        for i in 0..<6 {
            let u = (t * 0.9 + Double(i) / 6).truncatingRemainder(dividingBy: 1)
            drawTwinkle(ctx, CGPoint(x: f.x - w + 2 * w * hash(i, Int(t * 3)), y: bandY - 6 - u * 24), 6 * (1 - u), .yellow)
        }
    }
    if let kiss = p.kissMark {
        drawKissMark(ctx, CGPoint(x: f.head.x + r * 0.7, y: f.head.y + r * 0.28), r * 0.42, kiss)
    }
    if p.strapped {
        for y in [f.shoulderY + p.height * 0.12, f.foot - p.height * 0.1] {
            let rect = CGRect(x: f.x - p.height * 0.16, y: y - p.height * 0.018, width: p.height * 0.32, height: p.height * 0.036)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color(red: 0.25, green: 0.2, blue: 0.25)))
            ctx.fill(Path(CGRect(x: rect.midX - 5, y: rect.minY - 1, width: 10, height: rect.height + 2)), with: .color(.gray))
        }
    }
}

/// A lipstick kiss: two puckered lips with a crease between them, `w` wide.
func drawKissMark(_ ctx: GraphicsContext, _ c: CGPoint, _ w: Double, _ color: Color) {
    let p = c
    var top = Path()
    top.move(to: CGPoint(x: p.x - w / 2, y: p.y))
    top.addQuadCurve(to: CGPoint(x: p.x, y: p.y - w * 0.18), control: CGPoint(x: p.x - w * 0.25, y: p.y - w * 0.42))
    top.addQuadCurve(to: CGPoint(x: p.x + w / 2, y: p.y), control: CGPoint(x: p.x + w * 0.25, y: p.y - w * 0.42))
    top.addQuadCurve(to: CGPoint(x: p.x - w / 2, y: p.y), control: CGPoint(x: p.x, y: p.y + w * 0.05))
    var bottom = Path()
    bottom.move(to: CGPoint(x: p.x - w / 2, y: p.y + w * 0.04))
    bottom.addQuadCurve(to: CGPoint(x: p.x + w / 2, y: p.y + w * 0.04), control: CGPoint(x: p.x, y: p.y + w * 0.12))
    bottom.addQuadCurve(to: CGPoint(x: p.x - w / 2, y: p.y + w * 0.04), control: CGPoint(x: p.x, y: p.y + w * 0.55))
    ctx.fill(top, with: .color(color.opacity(0.85)))
    ctx.fill(bottom, with: .color(color.opacity(0.85)))
}

// MARK: Portraits

/// Head and shoulders of a girl in the sparkling dress, filling `size`.
func drawGirlBust(_ ctx: GraphicsContext, size: CGSize, skin: Color, look: GirlLook, talking: Bool, mood: Mood = .happy, now: Date) {
    let r = min(size.width, size.height) * 0.25
    let c = CGPoint(x: size.width / 2, y: size.height * 0.5)
    drawCurlsBack(ctx, c, r, look.hair)
    var shoulders = Path()
    let sy = c.y + r * 1.25
    shoulders.move(to: CGPoint(x: c.x - r * 1.5, y: size.height))
    shoulders.addQuadCurve(to: CGPoint(x: c.x - r * 0.4, y: sy), control: CGPoint(x: c.x - r * 1.4, y: sy))
    shoulders.addLine(to: CGPoint(x: c.x + r * 0.4, y: sy))
    shoulders.addQuadCurve(to: CGPoint(x: c.x + r * 1.5, y: size.height), control: CGPoint(x: c.x + r * 1.4, y: sy))
    shoulders.closeSubpath()
    ctx.fill(shoulders, with: .color(skin))
    var dress = Path()
    dress.move(to: CGPoint(x: c.x - r * 1.2, y: size.height))
    dress.addLine(to: CGPoint(x: c.x - r * 0.95, y: sy + r * 0.45))
    dress.addQuadCurve(to: CGPoint(x: c.x + r * 0.95, y: sy + r * 0.45), control: CGPoint(x: c.x, y: sy + r * 0.85))
    dress.addLine(to: CGPoint(x: c.x + r * 1.2, y: size.height))
    dress.closeSubpath()
    ctx.fill(dress, with: .linearGradient(Gradient(colors: [look.dressHi, look.dress]), startPoint: CGPoint(x: c.x - r, y: sy), endPoint: CGPoint(x: c.x + r, y: size.height)))
    let t = now.timeIntervalSinceReferenceDate
    for i in 0..<7 {
        let tw = 0.5 + 0.5 * sin(t * 3 + Double(i) * 2.1)
        drawTwinkle(ctx, CGPoint(x: c.x + (hash(i, 3) * 2 - 1) * r * 0.9, y: sy + r * 0.6 + hash(3, i) * (size.height - sy - r * 0.6)), r * 0.09 * (0.4 + tw))
    }
    ctx.fill(Path(CGRect(x: c.x - r * 0.25, y: c.y + r * 0.7, width: r * 0.5, height: r * 0.6)), with: .color(skin))
    let open = talking ? 0.5 + 0.5 * sin(t * 18) : 0
    drawGirlHead(ctx, c, r, skin: skin, look: look, open: open, mood: mood, now: now, back: false)
}

extension Color {
    static let princessSkin = Color(red: 0.98, green: 0.84, blue: 0.74)
}

/// The Princess of Poker's portrait (machine screen, Sneaky Queens cards, the dealer's chair).
struct PrincessFace: View {
    var talking: Bool
    var mood: Mood = .happy

    var body: some View {
        TimelineView(.animation(paused: !talking)) { tl in
            Canvas { ctx, size in
                drawGirlBust(ctx, size: size, skin: .princessSkin, look: .princess, talking: talking, mood: mood, now: tl.date)
            }
        }
    }
}

/// A seat portrait at the poker table.
struct GirlPortrait: View {
    var skin: Color
    var look: GirlLook
    var talking = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { tl in
            Canvas { ctx, size in
                drawGirlBust(ctx, size: size, skin: skin, look: look, talking: talking, now: tl.date)
            }
        }
    }
}
