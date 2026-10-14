import SwiftUI

struct HeartsView: View {
    @Bindable var table: HeartsTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color

    /// Where each seat sits around the table (fractions of the table area), clockwise from you.
    private let spots: [CGPoint] = [CGPoint(x: 0.5, y: 0.87), CGPoint(x: 0.13, y: 0.47), CGPoint(x: 0.5, y: 0.13), CGPoint(x: 0.87, y: 0.47)]
    /// Where each seat's card lands in the trick, toward that seat.
    private let trickSpots: [CGPoint] = [CGPoint(x: 0.5, y: 0.6), CGPoint(x: 0.36, y: 0.47), CGPoint(x: 0.5, y: 0.33), CGPoint(x: 0.64, y: 0.47)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Hearts · Hand \(table.handNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text("Just for fun · to \(HeartsTable.gameOver)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.pink)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Ellipse()
                        .fill(RadialGradient(colors: [felt.opacity(0.95), felt.opacity(0.7)], center: .center, startRadius: 10, endRadius: size.width * 0.6))
                        .overlay(Ellipse().strokeBorder(Color(red: 0.45, green: 0.25, blue: 0.1), lineWidth: 14))
                        .overlay(Ellipse().strokeBorder(Color.pink.opacity(0.5), lineWidth: 2).padding(7))
                        .padding(.horizontal, size.width * 0.12)
                        .padding(.vertical, size.height * 0.12)

                    ForEach(table.trick, id: \.card.id) { play in
                        let p = trickSpots[play.seat]
                        CardView(card: play.card, pinup: HeartsTable.isQueen(play.card), width: min(52, size.width * 0.12))
                            .overlay {
                                if table.trickWinner == play.seat {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(Color.yellow, lineWidth: 3)
                                }
                            }
                            .position(x: size.width * p.x, y: size.height * p.y)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Text(table.message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: size.width * 0.5)
                        .position(x: size.width * 0.5, y: size.height * 0.73)

                    ForEach(Array(table.players.enumerated()), id: \.offset) { i, player in
                        HeartsSeat(player: player, isTurn: table.turn == i, leading: table.finished && table.leaders.contains(i))
                            .position(x: size.width * spots[i].x, y: size.height * spots[i].y)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: table.trick.count)
            }
            .frame(minHeight: 380)

            if let banner = table.banner {
                Text(banner)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.pink.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .transition(.opacity)
                    .id(banner)
            }

            yourHand
                .padding(.horizontal, 8)

            actionBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), Color(red: 0.08, green: 0.0, blue: 0.1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.default, value: table.banner)
    }

    /// Your thirteen cards in a fan: tap to pass or play. Cards you can't play are dimmed.
    private var yourHand: some View {
        GeometryReader { geo in
            let hand = table.human.hand
            let w = 50.0
            let step = hand.count > 1 ? min(w + 2, (geo.size.width - w) / Double(hand.count - 1)) : 0
            let legal = table.legalForHuman
            HStack(spacing: step - w) {
                ForEach(hand) { card in
                    let picked = table.selected.contains(card.id)
                    Button { table.tap(card) } label: {
                        CardView(card: card, dim: table.humanToPlay && !legal.contains(card.id), pinup: HeartsTable.isQueen(card), width: w)
                            .overlay {
                                if table.received.contains(card.id) {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(Color.pink, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .offset(y: picked || (table.humanToPlay && legal.contains(card.id)) ? -12 : 0)
                    .animation(.easeOut(duration: 0.15), value: picked)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 86)
    }

    @ViewBuilder private var actionBar: some View {
        if table.finished {
            Text("The hearts game is over for the night.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.passing {
            Button {
                table.confirmPass()
            } label: {
                Text(table.selected.count == 3 ? "Pass to \(table.passTarget ?? "")" : "Pick \(3 - table.selected.count) more card\(table.selected.count == 2 ? "" : "s") to pass")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background((table.selected.count == 3 ? Color.pink : Color.gray).gradient, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(table.selected.count != 3)
        } else {
            HStack {
                Text(table.humanToPlay ? "Lavender's turn — tap a raised card to play it."
                     : (table.turn.map { "\(table.players[$0].name) is thinking…" } ?? " "))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                if table.heartsBroken {
                    Text("♥ broken").font(.system(.footnote, design: .rounded, weight: .bold)).foregroundStyle(.red)
                }
            }
            .frame(minHeight: 46)
        }
    }
}

private struct HeartsSeat: View {
    let player: HeartsTable.Player
    let isTurn: Bool
    let leading: Bool

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if player.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: player.skin, look: player.look) }
            }
            .frame(width: 58, height: 58)
            .background(Circle().fill(Color.white.opacity(0.15)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(isTurn ? Color.yellow : (leading ? Color.green : Color.white.opacity(0.4)), lineWidth: isTurn || leading ? 3 : 1))
            Text(player.isPrincess ? "Princess" : player.isHuman ? "Lavender" : player.name)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(player.score) pts" + (player.handPoints > 0 ? " · +\(player.handPoints)♥" : ""))
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.yellow)
            if !player.isHuman && !player.hand.isEmpty {
                HStack(spacing: -11) {
                    ForEach(0..<player.hand.count, id: \.self) { _ in
                        CardView(card: Card(rank: 2, suit: .clubs), faceUp: false, width: 14)
                    }
                }
            }
        }
        .frame(width: 96)
    }
}
