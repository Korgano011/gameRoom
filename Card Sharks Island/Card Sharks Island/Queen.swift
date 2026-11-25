import SwiftUI

// MARK: - The Queen of Spades

/// The Queen of Spades: a pin-up queen with long, wavy blond hair, smoky eyes and red lips.
/// `wink` closes one eye, `pucker` purses her lips, `hand` raises her hand to her lips
/// and `flick` sends it out toward the viewer — everything blowing a kiss needs.
/// `laugh` (how wide her mouth is open) has her squeeze her eyes shut and laugh at you.
struct QueenPortrait: View {
    var wink = 0.0
    var pucker = 0.0
    var hand = 0.0
    var flick = 0.0
    var laugh = 0.0

    static let skin = Color(red: 0.98, green: 0.82, blue: 0.72)
    static let hair = Color(red: 0.62, green: 0.45, blue: 0.2)        // brows: a darker honey blond
    static let blond = Color(red: 0.98, green: 0.84, blue: 0.45)
    static let blondShade = Color(red: 0.85, green: 0.64, blue: 0.27)
    static let blondShine = Color(red: 1, green: 0.95, blue: 0.75)
    static let lips = Color(red: 0.82, green: 0.04, blue: 0.14)

    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width / 100, size.height / 140)
            ctx.translateBy(x: (size.width - 100 * k) / 2, y: (size.height - 140 * k) / 2)
            ctx.scaleBy(x: k, y: k)
            draw(&ctx)
        }
    }

    private func draw(_ ctx: inout GraphicsContext) {
        let skin = Self.skin, hairColor = Self.hair
        // Backdrop: deep crimson fading to black, with a soft spotlight behind her.
        ctx.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 140)),
                 with: .linearGradient(Gradient(colors: [Color(red: 0.5, green: 0.03, blue: 0.1), Color(red: 0.08, green: 0.01, blue: 0.04)]),
                                       startPoint: CGPoint(x: 50, y: 0), endPoint: CGPoint(x: 50, y: 140)))
        ctx.fill(Path(ellipseIn: CGRect(x: 10, y: 14, width: 80, height: 90)),
                 with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.4, blue: 0.45).opacity(0.45), .clear]),
                                       center: CGPoint(x: 50, y: 58), startRadius: 0, endRadius: 45))

        // Long blond waves falling behind her shoulders.
        var back = Path()
        back.move(to: CGPoint(x: 50, y: 16))
        back.addCurve(to: CGPoint(x: 24, y: 50), control1: CGPoint(x: 32, y: 16), control2: CGPoint(x: 24, y: 32))
        back.addCurve(to: CGPoint(x: 20, y: 86), control1: CGPoint(x: 24, y: 64), control2: CGPoint(x: 16, y: 72))
        back.addCurve(to: CGPoint(x: 18, y: 122), control1: CGPoint(x: 24, y: 100), control2: CGPoint(x: 12, y: 110))
        back.addQuadCurve(to: CGPoint(x: 34, y: 118), control: CGPoint(x: 26, y: 126))
        back.addLine(to: CGPoint(x: 66, y: 118))
        back.addQuadCurve(to: CGPoint(x: 82, y: 122), control: CGPoint(x: 74, y: 126))
        back.addCurve(to: CGPoint(x: 80, y: 86), control1: CGPoint(x: 88, y: 110), control2: CGPoint(x: 76, y: 100))
        back.addCurve(to: CGPoint(x: 76, y: 50), control1: CGPoint(x: 84, y: 72), control2: CGPoint(x: 76, y: 64))
        back.addCurve(to: CGPoint(x: 50, y: 16), control1: CGPoint(x: 76, y: 32), control2: CGPoint(x: 68, y: 16))
        ctx.fill(back, with: .linearGradient(Gradient(colors: [Self.blond, Self.blondShade]),
                                             startPoint: CGPoint(x: 50, y: 20), endPoint: CGPoint(x: 50, y: 124)))

        // Bare shoulders and neck.
        var shoulders = Path()
        shoulders.move(to: CGPoint(x: 6, y: 140))
        shoulders.addCurve(to: CGPoint(x: 44, y: 94), control1: CGPoint(x: 6, y: 108), control2: CGPoint(x: 30, y: 100))
        shoulders.addLine(to: CGPoint(x: 44, y: 76))
        shoulders.addLine(to: CGPoint(x: 56, y: 76))
        shoulders.addLine(to: CGPoint(x: 56, y: 94))
        shoulders.addCurve(to: CGPoint(x: 94, y: 140), control1: CGPoint(x: 70, y: 100), control2: CGPoint(x: 94, y: 108))
        shoulders.closeSubpath()
        ctx.fill(shoulders, with: .color(skin))
        ctx.fill(Path(ellipseIn: CGRect(x: 43, y: 80, width: 14, height: 8)), with: .color(.black.opacity(0.08)))  // under the chin

        // Strapless black gown with a sweetheart neckline and a red satin edge.
        var gown = Path()
        gown.move(to: CGPoint(x: 10, y: 140))
        gown.addLine(to: CGPoint(x: 12, y: 124))
        gown.addQuadCurve(to: CGPoint(x: 32, y: 117), control: CGPoint(x: 20, y: 113))
        gown.addQuadCurve(to: CGPoint(x: 50, y: 127), control: CGPoint(x: 44, y: 116))
        gown.addQuadCurve(to: CGPoint(x: 68, y: 117), control: CGPoint(x: 56, y: 116))
        gown.addQuadCurve(to: CGPoint(x: 88, y: 124), control: CGPoint(x: 80, y: 113))
        gown.addLine(to: CGPoint(x: 90, y: 140))
        gown.closeSubpath()
        ctx.fill(gown, with: .color(Color(white: 0.05)))
        var edge = Path()
        edge.move(to: CGPoint(x: 12, y: 124))
        edge.addQuadCurve(to: CGPoint(x: 32, y: 117), control: CGPoint(x: 20, y: 113))
        edge.addQuadCurve(to: CGPoint(x: 50, y: 127), control: CGPoint(x: 44, y: 116))
        edge.addQuadCurve(to: CGPoint(x: 68, y: 117), control: CGPoint(x: 56, y: 116))
        edge.addQuadCurve(to: CGPoint(x: 88, y: 124), control: CGPoint(x: 80, y: 113))
        ctx.stroke(edge, with: .color(Self.lips), lineWidth: 1.2)
        // A little spade pendant on a gold chain.
        var chain = Path()
        chain.move(to: CGPoint(x: 44, y: 92))
        chain.addQuadCurve(to: CGPoint(x: 56, y: 92), control: CGPoint(x: 50, y: 106))
        ctx.stroke(chain, with: .color(gold), lineWidth: 0.6)
        ctx.draw(Text("♠").font(.system(size: 6)).foregroundStyle(.black), at: CGPoint(x: 50, y: 101))

        // Head.
        let head = Path(ellipseIn: CGRect(x: 31, y: 20, width: 38, height: 46))
        ctx.fill(head, with: .color(skin))

        // Face.
        var face = Path()
        face.move(to: CGPoint(x: 50, y: 36))
        face.addCurve(to: CGPoint(x: 34, y: 58), control1: CGPoint(x: 39, y: 36), control2: CGPoint(x: 34, y: 45))
        face.addCurve(to: CGPoint(x: 50, y: 84), control1: CGPoint(x: 34, y: 72), control2: CGPoint(x: 42, y: 84))
        face.addCurve(to: CGPoint(x: 66, y: 58), control1: CGPoint(x: 58, y: 84), control2: CGPoint(x: 66, y: 72))
        face.addCurve(to: CGPoint(x: 50, y: 36), control1: CGPoint(x: 66, y: 45), control2: CGPoint(x: 61, y: 36))
        ctx.fill(face, with: .color(skin))
        for x in [39.0, 61.0] {   // blush
            ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: 63, width: 10, height: 6)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.4, blue: 0.5).opacity(0.5), .clear]),
                                           center: CGPoint(x: x, y: 66), startRadius: 0, endRadius: 5))
        }

        // Blond hair on top: a soft side part with a sweeping wave over her forehead
        // and long curls framing her face down past her shoulders.
        var crown = Path()
        crown.move(to: CGPoint(x: 30, y: 62))
        crown.addCurve(to: CGPoint(x: 50, y: 17), control1: CGPoint(x: 26, y: 36), control2: CGPoint(x: 34, y: 17))
        crown.addCurve(to: CGPoint(x: 70, y: 62), control1: CGPoint(x: 66, y: 17), control2: CGPoint(x: 74, y: 36))
        crown.addCurve(to: CGPoint(x: 64, y: 44), control1: CGPoint(x: 68, y: 52), control2: CGPoint(x: 66, y: 46))
        crown.addCurve(to: CGPoint(x: 42, y: 41), control1: CGPoint(x: 58, y: 38), control2: CGPoint(x: 50, y: 37))
        crown.addCurve(to: CGPoint(x: 36, y: 48), control1: CGPoint(x: 38, y: 43), control2: CGPoint(x: 37, y: 45))
        crown.addCurve(to: CGPoint(x: 30, y: 62), control1: CGPoint(x: 34, y: 52), control2: CGPoint(x: 32, y: 56))
        ctx.fill(crown, with: .linearGradient(Gradient(colors: [Self.blondShine, Self.blond, Self.blondShade]),
                                              startPoint: CGPoint(x: 40, y: 18), endPoint: CGPoint(x: 60, y: 60)))
        for (x, dir) in [(31.0, -1.0), (69.0, 1.0)] {
            var lock = Path()
            lock.move(to: CGPoint(x: x + 1 * dir, y: 46))
            lock.addCurve(to: CGPoint(x: x - 1 * dir, y: 76), control1: CGPoint(x: x + 4 * dir, y: 58), control2: CGPoint(x: x - 4 * dir, y: 66))
            lock.addCurve(to: CGPoint(x: x + 2 * dir, y: 104), control1: CGPoint(x: x + 3 * dir, y: 86), control2: CGPoint(x: x - 3 * dir, y: 96))
            lock.addQuadCurve(to: CGPoint(x: x + 9 * dir, y: 98), control: CGPoint(x: x + 8 * dir, y: 106))
            lock.addCurve(to: CGPoint(x: x + 5 * dir, y: 72), control1: CGPoint(x: x + 5 * dir, y: 90), control2: CGPoint(x: x + 9 * dir, y: 80))
            lock.addCurve(to: CGPoint(x: x + 1 * dir, y: 46), control1: CGPoint(x: x + 2 * dir, y: 62), control2: CGPoint(x: x + 5 * dir, y: 54))
            ctx.fill(lock, with: .color(Self.blond))
            // curl lines for the waves
            for y in stride(from: 58.0, through: 96, by: 12) {
                var wave = Path()
                wave.move(to: CGPoint(x: x + 1 * dir, y: y))
                wave.addQuadCurve(to: CGPoint(x: x + 6 * dir, y: y + 4), control: CGPoint(x: x + 5 * dir, y: y - 2))
                ctx.stroke(wave, with: .color(Self.blondShade), lineWidth: 0.6)
            }
        }
        // a few shiny strands in the sweep
        for k in 0..<3 {
            var strand = Path()
            strand.move(to: CGPoint(x: 40 + Double(k) * 5, y: 21 + Double(k)))
            strand.addQuadCurve(to: CGPoint(x: 62 - Double(k) * 2, y: 42), control: CGPoint(x: 64 - Double(k) * 3, y: 24))
            ctx.stroke(strand, with: .color(Self.blondShade.opacity(0.7)), lineWidth: 0.5)
        }
        var gleam = ctx
        gleam.addFilter(.blur(radius: 1.2))
        gleam.fill(Path(ellipseIn: CGRect(x: 38, y: 22, width: 12, height: 5)), with: .color(Self.blondShine.opacity(0.8)))

        // Eyes: smoky shadow, green irises, winged lashes. The left one winks.
        for (x, left) in [(42.0, true), (58.0, false)] {
            let laughing = laugh > 0
            let closed = laughing ? 1 : left ? wink : 0
            let dir = left ? -1.0 : 1.0
            ctx.fill(Path(ellipseIn: CGRect(x: x - 5.5, y: 52, width: 11, height: 6)), with: .color(Color(red: 0.45, green: 0.2, blue: 0.45).opacity(0.55)))
            let h = 3.2 * (1 - closed)
            var lid = Path()
            lid.move(to: CGPoint(x: x - 4.6, y: 57))
            lid.addQuadCurve(to: CGPoint(x: x + 4.6, y: 57), control: CGPoint(x: x, y: 57 - 2 * h))
            if h > 0.15 {
                var eye = lid
                eye.addQuadCurve(to: CGPoint(x: x - 4.6, y: 57), control: CGPoint(x: x, y: 57 + h * 0.8))
                ctx.fill(eye, with: .color(.white))
                var iris = ctx
                iris.clip(to: eye)
                iris.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: 54.3, width: 4.8, height: 4.8)), with: .color(Color(red: 0.15, green: 0.5, blue: 0.3)))
                iris.fill(Path(ellipseIn: CGRect(x: x - 1.1, y: 55.6, width: 2.2, height: 2.2)), with: .color(.black))
                iris.fill(Path(ellipseIn: CGRect(x: x - 0.1, y: 55, width: 1, height: 1)), with: .color(.white))
                ctx.stroke(lid, with: .color(.black), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                for j in 0..<4 {   // long lashes sweeping outward
                    let u = 0.35 + Double(j) * 0.2
                    let lx = x + 4.6 * dir * (2 * u - 1)
                    let ly = 57 - 2 * h * 2 * u * (1 - u)
                    var lash = Path()
                    lash.move(to: CGPoint(x: lx, y: ly))
                    lash.addLine(to: CGPoint(x: lx + dir * 0.8 * u, y: ly - 1.4 - 0.6 * u))
                    ctx.stroke(lash, with: .color(.black), style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
                }
            } else if laughing {
                // Laughing: eyes squeezed into happy upturned arches.
                var shut = Path()
                shut.move(to: CGPoint(x: x - 4, y: 57.5))
                shut.addQuadCurve(to: CGPoint(x: x + 4, y: 57.5), control: CGPoint(x: x, y: 53.5))
                ctx.stroke(shut, with: .color(.black), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            } else {
                // Closed: a happy downward curve of lashes.
                var shut = Path()
                shut.move(to: CGPoint(x: x - 4, y: 56.5))
                shut.addQuadCurve(to: CGPoint(x: x + 4, y: 56.5), control: CGPoint(x: x, y: 59))
                ctx.stroke(shut, with: .color(.black), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                for j in 0..<4 {
                    let lx = x - 3 + Double(j) * 2
                    var lash = Path()
                    lash.move(to: CGPoint(x: lx, y: 57.6))
                    lash.addLine(to: CGPoint(x: lx - 0.4, y: 59.4))
                    ctx.stroke(lash, with: .color(.black), lineWidth: 0.5)
                }
            }
            // The cat-eye wing at the outer corner.
            var wing = Path()
            let outer = x + 4.6 * dir
            wing.move(to: CGPoint(x: outer, y: 57 - (h > 0.15 ? 0 : -0.5)))
            wing.addLine(to: CGPoint(x: outer + 2 * dir, y: 54.6))
            ctx.stroke(wing, with: .color(.black), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            // Arched brow, dropping a touch when she winks.
            var brow = Path()
            let by = laughing ? 48 : 49.5 + 1.2 * closed
            brow.move(to: CGPoint(x: x - 4.5 * dir, y: by + 1.5))
            brow.addQuadCurve(to: CGPoint(x: x + 5 * dir, y: by + 1), control: CGPoint(x: x + 1.5 * dir, y: by - 2))
            ctx.stroke(brow, with: .color(hairColor), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }

        // Nose.
        var nose = Path()
        nose.move(to: CGPoint(x: 50.5, y: 60))
        nose.addQuadCurve(to: CGPoint(x: 49, y: 67.5), control: CGPoint(x: 51.5, y: 65))
        nose.addQuadCurve(to: CGPoint(x: 52, y: 67.5), control: CGPoint(x: 50.5, y: 68.5))
        ctx.stroke(nose, with: .color(Color(red: 0.75, green: 0.5, blue: 0.42)), lineWidth: 0.6)

        if laugh > 0 {
            // A big open-mouthed laugh: red lips, white teeth, pink tongue.
            let mw = 7.5, mh = 2 + 6 * laugh, my = 72.0
            var mouth = Path()
            mouth.move(to: CGPoint(x: 50 - mw, y: my))
            mouth.addQuadCurve(to: CGPoint(x: 50 + mw, y: my), control: CGPoint(x: 50, y: my - 2))
            mouth.addCurve(to: CGPoint(x: 50 - mw, y: my), control1: CGPoint(x: 50 + mw * 0.7, y: my + mh * 1.3), control2: CGPoint(x: 50 - mw * 0.7, y: my + mh * 1.3))
            ctx.fill(mouth, with: .color(Self.lips))
            let inner = mouth.applying(CGAffineTransform(translationX: -50, y: -my)
                .concatenating(CGAffineTransform(scaleX: 0.8, y: 0.72))
                .concatenating(CGAffineTransform(translationX: 50, y: my + 0.9)))
            ctx.fill(inner, with: .color(Color(red: 0.35, green: 0, blue: 0.06)))
            var mouthInside = ctx
            mouthInside.clip(to: inner)
            mouthInside.fill(Path(CGRect(x: 40, y: my, width: 20, height: 2.4)), with: .color(.white))
            mouthInside.fill(Path(ellipseIn: CGRect(x: 45, y: my + mh * 0.7, width: 10, height: 6)), with: .color(Color(red: 0.95, green: 0.45, blue: 0.5)))
            for x in [50 - mw - 0.6, 50 + mw + 0.6] {   // laugh lines
                var line = Path()
                line.move(to: CGPoint(x: x, y: my - 2.5))
                line.addQuadCurve(to: CGPoint(x: x, y: my + 2.5), control: CGPoint(x: x + (x < 50 ? -1.2 : 1.2), y: my))
                ctx.stroke(line, with: .color(Color(red: 0.8, green: 0.55, blue: 0.48)), lineWidth: 0.5)
            }
        } else {
        // Full red lips — puckered for the kiss.
        let lw = 6.2 * (1 - 0.45 * pucker), lh = 2.4 * (1 + 0.45 * pucker), ly = 73.5
        var upper = Path()
        upper.move(to: CGPoint(x: 50 - lw, y: ly))
        upper.addQuadCurve(to: CGPoint(x: 50 - lw * 0.35, y: ly - lh), control: CGPoint(x: 50 - lw * 0.75, y: ly - lh * 0.8))
        upper.addQuadCurve(to: CGPoint(x: 50, y: ly - lh * 0.6), control: CGPoint(x: 50 - lw * 0.15, y: ly - lh))
        upper.addQuadCurve(to: CGPoint(x: 50 + lw * 0.35, y: ly - lh), control: CGPoint(x: 50 + lw * 0.15, y: ly - lh))
        upper.addQuadCurve(to: CGPoint(x: 50 + lw, y: ly), control: CGPoint(x: 50 + lw * 0.75, y: ly - lh * 0.8))
        upper.addQuadCurve(to: CGPoint(x: 50 - lw, y: ly), control: CGPoint(x: 50, y: ly + 0.6))
        var lower = Path()
        lower.move(to: CGPoint(x: 50 - lw, y: ly))
        lower.addQuadCurve(to: CGPoint(x: 50 + lw, y: ly), control: CGPoint(x: 50, y: ly + 0.6))
        lower.addCurve(to: CGPoint(x: 50 - lw, y: ly), control1: CGPoint(x: 50 + lw * 0.6, y: ly + lh * 1.7), control2: CGPoint(x: 50 - lw * 0.6, y: ly + lh * 1.7))
        ctx.fill(upper, with: .color(Self.lips))
        ctx.fill(lower, with: .color(Self.lips))
        var parting = Path()
        parting.move(to: CGPoint(x: 50 - lw, y: ly))
        parting.addQuadCurve(to: CGPoint(x: 50 + lw, y: ly), control: CGPoint(x: 50, y: ly + 0.6))
        ctx.stroke(parting, with: .color(Color(red: 0.45, green: 0, blue: 0.06)), lineWidth: 0.5)
        ctx.fill(Path(ellipseIn: CGRect(x: 50 - lw * 0.3, y: ly + lh * 0.45, width: lw * 0.45, height: 0.9)), with: .color(.white.opacity(0.55)))
        }
        // Beauty mark.
        ctx.fill(Path(ellipseIn: CGRect(x: 58.2, y: 68.6, width: 1.2, height: 1.2)), with: .color(Color(red: 0.25, green: 0.12, blue: 0.1)))

        // Pearl drop earrings peeking out from her curls.
        for x in [35.0, 65.0] {
            ctx.fill(Path(ellipseIn: CGRect(x: x - 0.8, y: 63, width: 1.6, height: 1.6)), with: .color(gold))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.4, y: 65, width: 2.8, height: 3.4)), with: .color(Color(white: 0.96)))
        }

        // Her hand: up to her lips, then flicked out toward you.
        if hand > 0 {
            let lift = min(1, hand)
            let x = 50 + 22 * flick, y = 140 + (86 - 140) * lift + 6 * flick
            var h = ctx
            h.translateBy(x: x, y: y)
            h.rotate(by: .degrees(-10 - 25 * flick))
            h.scaleBy(x: 1 + 0.25 * flick, y: 1 + 0.25 * flick)
            var palm = Path(roundedRect: CGRect(x: -6, y: -4, width: 12, height: 14), cornerRadius: 5)
            palm.addPath(Path(roundedRect: CGRect(x: -9.5, y: -1, width: 4, height: 9), cornerRadius: 2)
                .applying(CGAffineTransform(rotationAngle: -0.5)))   // thumb
            let spread = flick * 1.2
            for j in 0..<4 {
                let fx = -5.0 + Double(j) * 3.2 + (Double(j) - 1.5) * spread
                let len = [8.5, 10, 9.5, 7.5][j]
                palm.addPath(Path(roundedRect: CGRect(x: fx - 0.2, y: -4 - len, width: 2.8, height: len + 2), cornerRadius: 1.4))
            }
            h.fill(palm, with: .color(skin))
            h.stroke(palm, with: .color(Color(red: 0.8, green: 0.6, blue: 0.5)), lineWidth: 0.4)
            for j in 0..<4 {   // nails on top
                let fx = -5.0 + Double(j) * 3.2 + (Double(j) - 1.5) * spread
                let len = [8.5, 10, 9.5, 7.5][j]
                h.fill(Path(roundedRect: CGRect(x: fx + 0.2, y: -4 - len + 0.2, width: 2, height: 2.6), cornerRadius: 1), with: .color(Self.lips))
            }
        }
    }
}

/// When you turn her over, the Queen of Spades rises up to fill the screen, winks,
/// blows you a kiss that flies right out at you — then has a big laugh at your expense.
struct QueenKissView: View {
    static let blowAt = 2.6      // when the kiss leaves her fingertips (the sound plays here)
    static let laughAt = 4.1     // when she bursts out laughing (the laugh sound plays here)
    static let laughLength = 2.6 // the "ha"s come every `haBeat` seconds, matching the sound
    static let haBeat = 0.22
    static let length = 7.2      // how long the whole moment lasts

    /// Shown from the title screen: plays its own sounds, and a tap closes it early.
    var demo = false
    var onFinish: (() -> Void)? = nil

    @State private var start = Date()

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation) { tl in
                Self.scene(t: tl.date.timeIntervalSince(start), size: g.size)
            }
        }
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .onTapGesture { if demo { onFinish?() } }
        .task {
            guard demo else { return }
            try? await Task.sleep(for: .seconds(Self.blowAt))
            Sound.shared.play(.kiss)
            try? await Task.sleep(for: .seconds(Self.laughAt - Self.blowAt))
            Sound.shared.play(.queenLaugh)
            try? await Task.sleep(for: .seconds(Self.length - Self.laughAt))
            if !Task.isCancelled { onFinish?() }
        }
    }


    /// One moment of the scene, `t` seconds in — also used to render it as a video.
    @ViewBuilder static func scene(t: Double, size: CGSize) -> some View {
        let rise = ease(t / 0.8)
        let wink = t < 1.0 ? 0 : t < 1.25 ? (t - 1.0) / 0.25 : t < 1.6 ? 1 : max(0, 1 - (t - 1.6) / 0.2)
        let pucker = clamp((t - 1.7) / 0.3) * (1 - clamp((t - 3.6) / 0.4))
        let hand = ease((t - 1.9) / 0.5) * (1 - ease((t - 3.4) / 0.6))
        let flick = ease((t - Self.blowAt) / 0.35)
        let cardW = min(size.width * 0.78, size.height * 0.7 * 0.78, 380)
        let fly = clamp((t - Self.blowAt) / 1.6)
        // Laughing: her mouth opens wide on each "ha", her shoulders shake and her head tips back.
        let lt = t - Self.laughAt
        let laughing = lt > 0 && lt < Self.laughLength
        let ha = laughing ? 0.45 + 0.55 * abs(sin(.pi * lt / Self.haBeat)) : 0
        let tipBack = laughing ? ease(lt / 0.3) * (1 - ease((lt - Self.laughLength + 0.4) / 0.4)) : 0
        ZStack {
            Color.black.opacity(0.65 * rise).ignoresSafeArea()
            QueenPortrait(wink: wink, pucker: pucker, hand: hand, flick: flick, laugh: ha)
                .frame(width: cardW, height: cardW / 0.7)
                .clipShape(RoundedRectangle(cornerRadius: cardW * 0.06))
                .overlay(RoundedRectangle(cornerRadius: cardW * 0.06).stroke(gold, lineWidth: 4))
                .shadow(color: Color(red: 1, green: 0.2, blue: 0.4).opacity(0.6), radius: 30)
                .scaleEffect(0.18 + 0.82 * rise)
                .rotation3DEffect(.degrees(-180 * (1 - rise)), axis: (x: 0, y: 1, z: 0))
                .offset(y: size.height * 0.25 * (1 - rise))
                .rotationEffect(.degrees(-5 * tipBack + (laughing ? 1.5 * sin(2 * .pi * lt / Self.haBeat) : 0)))
                .offset(y: laughing ? -6 * abs(sin(.pi * lt / Self.haBeat)) * tipBack : 0)
            if fly > 0 && fly < 1 {
                // The kiss: a lipstick print flying out of the card at you, with little hearts.
                let start = CGPoint(x: cardW * 0.22, y: cardW / 0.7 * 0.1)
                ZStack {
                    Text("💋").font(.system(size: 40))
                    ForEach(0..<6, id: \.self) { j in
                        let a = Double(j) / 6 * 2 * .pi
                        Image(systemName: "heart.fill").foregroundStyle(.pink)
                            .font(.system(size: 12))
                            .offset(x: cos(a) * 40 * fly, y: sin(a) * 40 * fly)
                    }
                }
                .scaleEffect(0.3 + 5 * fly * fly)
                .offset(x: start.x * (1 - fly), y: start.y * (1 - fly))
                .opacity(fly < 0.7 ? 1 : (1 - fly) / 0.3)
            }
            if t > Self.blowAt + 0.1 && t < Self.laughAt {
                Text("Mwah!")
                    .font(.system(size: 44, weight: .black, design: .serif)).italic()
                    .foregroundStyle(LinearGradient(colors: [.pink, QueenPortrait.lips], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.6), radius: 4)
                    .rotationEffect(.degrees(-8))
                    .scaleEffect(0.6 + 0.4 * ease((t - Self.blowAt - 0.1) / 0.3))
                    .offset(y: -cardW / 0.7 * 0.5 - 10)
            }
            if lt > 0 {
                // "HA HA HA!" — each HA pops in on its beat.
                let count = min(4, Int(lt / (Self.haBeat * 2)) + 1)
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { j in
                        Text("HA")
                            .rotationEffect(.degrees(j % 2 == 0 ? -10 : 8))
                            .offset(y: j % 2 == 0 ? 0 : -8)
                    }
                    if count == 4 { Text("!") }
                }
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [gold, .orange], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.7), radius: 4)
                .offset(y: -cardW / 0.7 * 0.5 - 10)
                .opacity(1 - clamp((lt - Self.laughLength) / 0.4))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    private static func ease(_ x: Double) -> Double { let c = clamp(x); return c * c * (3 - 2 * c) }
}

#Preview("Queen of Spades kiss") {
    QueenKissView(demo: true)
        .background(Color(red: 0.05, green: 0.25, blue: 0.15))
}
