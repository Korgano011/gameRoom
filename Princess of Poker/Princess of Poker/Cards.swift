import SwiftUI

enum Suit: Int, CaseIterable, Codable, Hashable {
    case clubs, diamonds, hearts, spades

    var symbol: String { ["♣", "♦", "♥", "♠"][rawValue] }
    var isRed: Bool { self == .diamonds || self == .hearts }
}

struct Card: Identifiable, Hashable, Codable {
    /// 2…14 (ace high); 0 is the joker.
    let rank: Int
    let suit: Suit
    /// Sneaky Queens: the Princess of Poker's picture is on this queen (winning hands pay 2×).
    var princess = false

    var id: Int { rank == 0 ? 52 : (rank - 2) * 4 + suit.rawValue }
    var isJoker: Bool { rank == 0 }

    static let joker = Card(rank: 0, suit: .spades)

    var rankText: String {
        switch rank {
        case 14: "A"
        case 13: "K"
        case 12: "Q"
        case 11: "J"
        case 0: "★"
        default: "\(rank)"
        }
    }

    var text: String { isJoker ? "Joker" : rankText + suit.symbol }
}

enum Deck {
    static func shuffled(joker: Bool = false) -> [Card] {
        var cards = Suit.allCases.flatMap { s in (2...14).map { Card(rank: $0, suit: s) } }
        if joker { cards.append(.joker) }
        return cards.shuffled()
    }
}

/// A playing card face (or back). `wild` tints wild cards; `held` shows the HELD banner.
struct CardView: View {
    let card: Card?
    var faceUp = true
    var held = false
    var wild = false
    var dim = false
    /// Hearts: the queen of spades drawn as a blonde pin-up.
    var pinup = false
    var width: CGFloat = 64

    private var height: CGFloat { width * 1.42 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.1)
                .fill(faceUp && card != nil ? Color.white : Color.clear)
            if let card, faceUp {
                face(card)
            } else if card != nil {
                back
            } else {
                RoundedRectangle(cornerRadius: width * 0.1)
                    .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .frame(width: width, height: height)
        .overlay {
            if wild && faceUp && card != nil {
                RoundedRectangle(cornerRadius: width * 0.1)
                    .strokeBorder(Color.yellow, lineWidth: 3)
            }
        }
        .overlay(alignment: .bottom) {
            // Wild deuces (Deuces Wild and Deuces Joker Wild) say so on the card.
            if wild && faceUp, let card, card.rank == 2 {
                Text("WILD")
                    .font(.system(size: width * 0.2, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .background(Color.yellow, in: Capsule())
                    .padding(.bottom, width * 0.08)
            }
        }
        .overlay(alignment: .top) {
            if held {
                Text("HELD")
                    .font(.system(size: width * 0.2, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .background(Color.yellow, in: Capsule())
                    .offset(y: -width * 0.16)
            }
        }
        .opacity(dim ? 0.45 : 1)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
    }

    @ViewBuilder private func face(_ card: Card) -> some View {
        let color: Color = card.isJoker ? .purple : (card.suit.isRed ? .red : .black)
        if card.isJoker {
            VStack(spacing: 2) {
                Text("★").font(.system(size: width * 0.42))
                Text("JOKER").font(.system(size: width * 0.17, weight: .black, design: .rounded))
            }
            .foregroundStyle(color)
        } else if pinup {
            ZStack {
                PinupQueen()
                VStack {
                    HStack {
                        corner(card, color)
                            .padding(.horizontal, width * 0.03)
                            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: width * 0.06))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(width * 0.05)
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.1))
        } else if card.princess {
            ZStack {
                PrincessFace(talking: false)
                    .padding(width * 0.08)
                VStack {
                    HStack {
                        corner(card, color)
                        Spacer()
                    }
                    Spacer()
                    Text("2×")
                        .font(.system(size: width * 0.2, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .background(Color.pink, in: Capsule())
                }
                .padding(width * 0.06)
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.1))
        } else {
            ZStack {
                VStack {
                    HStack {
                        corner(card, color)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(width * 0.06)
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.5))
                    .foregroundStyle(color)
                    .offset(y: width * 0.12)
            }
        }
    }

    private func corner(_ card: Card, _ color: Color) -> some View {
        VStack(spacing: -2) {
            Text(card.rankText).font(.system(size: width * 0.28, weight: .bold, design: .rounded))
            Text(card.suit.symbol).font(.system(size: width * 0.2))
        }
        .foregroundStyle(color)
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: width * 0.1)
            .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.1, blue: 0.45), Color(red: 0.3, green: 0.05, blue: 0.35)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.07)
                    .strokeBorder(Color.yellow.opacity(0.8), lineWidth: 1.5)
                    .padding(width * 0.07)
            }
            .overlay {
                Text("♛").font(.system(size: width * 0.42)).foregroundStyle(Color.yellow.opacity(0.85))
            }
    }
}

/// The Hearts queen of spades: a glamorous blonde with blue eyes, red lips and a beauty mark.
struct PinupQueen: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func r(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double) -> CGRect {
                CGRect(x: w * x, y: h * y, width: w * rw, height: h * rh)
            }
            let skin = Color(red: 1.0, green: 0.86, blue: 0.76)
            let gold = Color(red: 0.98, green: 0.82, blue: 0.35)
            let goldDark = Color(red: 0.85, green: 0.64, blue: 0.2)
            let lipRed = Color(red: 0.85, green: 0.05, blue: 0.18)

            // Backdrop: a rosy glow.
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.75, blue: 0.85), Color(red: 0.75, green: 0.2, blue: 0.45)]),
                                           center: CGPoint(x: w * 0.5, y: h * 0.42), startRadius: 0, endRadius: h * 0.7))

            // Big blonde hair behind the face, falling to the shoulders.
            ctx.fill(Path(ellipseIn: r(0.1, 0.12, 0.8, 0.62)), with: .color(gold))
            for (x, y, d) in [(0.06, 0.48, 0.24), (0.7, 0.48, 0.24), (0.1, 0.6, 0.2), (0.7, 0.6, 0.2)] {
                ctx.fill(Path(ellipseIn: r(x, y, d, d * w / h * 1.0)), with: .color(gold))
                ctx.stroke(Path(ellipseIn: r(x + 0.04, y + 0.02, d * 0.5, d * 0.5 * w / h)), with: .color(goldDark), lineWidth: w * 0.015)
            }

            // Bare shoulders and a black strapless gown.
            ctx.fill(Path(ellipseIn: r(0.08, 0.72, 0.84, 0.4)), with: .color(skin))
            ctx.fill(Path(r(0.42, 0.6, 0.16, 0.16)), with: .color(skin))
            var gown = Path()
            gown.move(to: CGPoint(x: w * 0.12, y: h * 0.86))
            gown.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.84), control: CGPoint(x: w * 0.32, y: h * 0.78))
            gown.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.86), control: CGPoint(x: w * 0.68, y: h * 0.78))
            gown.addLine(to: CGPoint(x: w, y: h))
            gown.addLine(to: CGPoint(x: 0, y: h))
            gown.closeSubpath()
            ctx.fill(gown, with: .color(.black))
            // A little spade pendant.
            ctx.draw(Text("♠").font(.system(size: w * 0.12)).foregroundStyle(.black), at: CGPoint(x: w * 0.5, y: h * 0.78))

            // Face.
            ctx.fill(Path(ellipseIn: r(0.27, 0.26, 0.46, 0.42)), with: .color(skin))
            // Side-swept bangs.
            var bangs = Path()
            bangs.move(to: CGPoint(x: w * 0.22, y: h * 0.42))
            bangs.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.3), control: CGPoint(x: w * 0.35, y: h * 0.14))
            bangs.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.32), control: CGPoint(x: w * 0.6, y: h * 0.24))
            bangs.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.42), control: CGPoint(x: w * 0.28, y: h * 0.33))
            ctx.fill(bangs, with: .color(gold))
            ctx.stroke(bangs, with: .color(goldDark), lineWidth: w * 0.012)

            // Tiara.
            var tiara = Path()
            tiara.move(to: CGPoint(x: w * 0.32, y: h * 0.2))
            for (k, x) in [0.38, 0.44, 0.5, 0.56, 0.62].enumerated() {
                tiara.addLine(to: CGPoint(x: w * x, y: h * (k == 2 ? 0.08 : 0.13)))
                tiara.addLine(to: CGPoint(x: w * (x + 0.03), y: h * 0.19))
            }
            tiara.addLine(to: CGPoint(x: w * 0.68, y: h * 0.2))
            tiara.closeSubpath()
            ctx.fill(tiara, with: .color(Color(red: 1, green: 0.88, blue: 0.4)))
            ctx.fill(Path(ellipseIn: r(0.48, 0.13, 0.04, 0.03)), with: .color(.pink))

            // Eyes: blue shadow, open, with lashes.
            for flip in [false, true] {
                func fx(_ x: Double) -> Double { flip ? 1 - x : x }
                ctx.fill(Path(ellipseIn: r(fx(0.33) - (flip ? 0.14 : 0), 0.37, 0.14, 0.06)), with: .color(Color(red: 0.55, green: 0.7, blue: 1).opacity(0.7)))
                ctx.fill(Path(ellipseIn: r(fx(0.35) - (flip ? 0.1 : 0), 0.39, 0.1, 0.05)), with: .color(.white))
                ctx.fill(Path(ellipseIn: r(fx(0.38) - (flip ? 0.045 : 0), 0.395, 0.045, 0.04)), with: .color(Color(red: 0.2, green: 0.45, blue: 0.85)))
                var lashes = Path()
                lashes.move(to: CGPoint(x: w * fx(0.34), y: h * 0.41))
                lashes.addQuadCurve(to: CGPoint(x: w * fx(0.46), y: h * 0.405), control: CGPoint(x: w * fx(0.4), y: h * 0.37))
                for x in [0.35, 0.39, 0.43, 0.46] {
                    lashes.move(to: CGPoint(x: w * fx(x), y: h * 0.395))
                    lashes.addLine(to: CGPoint(x: w * fx(x - 0.01), y: h * 0.37))
                }
                ctx.stroke(lashes, with: .color(.black), lineWidth: w * 0.018)
            }
            // Arched brows.
            var brows = Path()
            brows.move(to: CGPoint(x: w * 0.33, y: h * 0.36))
            brows.addQuadCurve(to: CGPoint(x: w * 0.47, y: h * 0.355), control: CGPoint(x: w * 0.41, y: h * 0.32))
            brows.move(to: CGPoint(x: w * 0.53, y: h * 0.37))
            brows.addQuadCurve(to: CGPoint(x: w * 0.67, y: h * 0.365), control: CGPoint(x: w * 0.6, y: h * 0.335))
            ctx.stroke(brows, with: .color(goldDark), lineWidth: w * 0.02)

            // Rosy cheeks, beauty mark, and full red lips.
            ctx.fill(Path(ellipseIn: r(0.31, 0.47, 0.1, 0.05)), with: .color(.pink.opacity(0.45)))
            ctx.fill(Path(ellipseIn: r(0.59, 0.47, 0.1, 0.05)), with: .color(.pink.opacity(0.45)))
            ctx.fill(Path(ellipseIn: r(0.6, 0.53, 0.025, 0.018)), with: .color(Color(red: 0.25, green: 0.12, blue: 0.08)))
            var lips = Path()
            lips.move(to: CGPoint(x: w * 0.42, y: h * 0.57))
            lips.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.555), control: CGPoint(x: w * 0.46, y: h * 0.535))
            lips.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.57), control: CGPoint(x: w * 0.54, y: h * 0.535))
            lips.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.57), control: CGPoint(x: w * 0.5, y: h * 0.62))
            ctx.fill(lips, with: .color(lipRed))
            ctx.fill(Path(ellipseIn: r(0.47, 0.575, 0.04, 0.012)), with: .color(.white.opacity(0.5)))
        }
    }
}
