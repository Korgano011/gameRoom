import SwiftUI

struct HoldemView: View {
    @Bindable var table: HoldemTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color
    let goldChips: Bool

    @State private var raiseTo = 4.0

    /// Where the newcomers sit around the oval (fractions of the table area).
    private let spots: [CGPoint] = [CGPoint(x: 0.14, y: 0.3), CGPoint(x: 0.86, y: 0.3), CGPoint(x: 0.14, y: 0.68), CGPoint(x: 0.86, y: 0.68)]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · \(table.gameName) · Hand \(table.handNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text("\(table.caribbean ? "Bets" : "Pot") $\(table.pot)")
                    .font(.system(.headline, design: .rounded, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.yellow)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Ellipse()
                        .fill(RadialGradient(colors: [felt.opacity(0.95), felt.opacity(0.7)], center: .center, startRadius: 10, endRadius: size.width * 0.6))
                        .overlay(Ellipse().strokeBorder(Color(red: 0.45, green: 0.25, blue: 0.1), lineWidth: 14))
                        .overlay(Ellipse().strokeBorder(Color.yellow.opacity(0.5), lineWidth: 2).padding(7))
                        .padding(.horizontal, size.width * 0.12)
                        .padding(.vertical, size.height * 0.12)


                    VStack(spacing: 6) {
                        if table.draw {
                            Text("Five Card Draw")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.yellow)
                        } else {
                        if table.caribbean {
                            Text(table.youAreHouse ? "Lavender's hand · House" : "The Princess's hand")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                // Caribbean Stud: only the Princess's first card is face up until the reveal.
                                CardView(card: table.board[safe: i], faceUp: !table.caribbean || i == 0 || table.dealerShown,
                                         width: min(48, size.width * 0.1))
                            }
                        }
                        }
                        Text(table.message)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .frame(maxWidth: size.width * 0.55)
                    }
                    .position(x: size.width * 0.5, y: size.height * 0.47)

                    ForEach(Array(table.seats.enumerated()), id: \.offset) { i, seat in
                        // You at the bottom, the Princess (also dealing) at the top, newcomers around the sides.
                        // When you're the Caribbean Stud house you take the top spot and the Princess plays from the bottom.
                        let top = CGPoint(x: 0.5, y: 0.15), low = CGPoint(x: 0.5, y: 0.86)
                        let p = i == 0 ? (table.youAreHouse ? top : low) : (seat.isPrincess ? (table.youAreHouse ? low : top) : spots[(i - 1) % spots.count])
                        SeatView(seat: seat, label: label(i, seat), isTurn: table.turn == i, isDealer: table.dealer == i,
                                 winner: table.winners.contains(i), goldChips: goldChips)
                            .position(x: size.width * p.x, y: size.height * p.y)
                    }

                    // Your hole cards, big enough to read, just to the left of your seat.
                    if !table.human.hole.isEmpty {
                        let hole = table.human.hole
                        let w = hole.count > 2 ? 50.0 : 60.0
                        let step = min(w + 4, (size.width * 0.5 - 56) / Double(hole.count) - 2)
                        HStack(spacing: step - w) {
                            ForEach(hole) { card in
                                CardView(card: card, dim: table.human.folded, width: w)
                            }
                        }
                        .frame(width: w + step * Double(hole.count - 1))
                        .position(x: size.width * 0.5 - 52 - (w + step * Double(hole.count - 1)) / 2, y: size.height * 0.91)
                    }
                }
            }
            .frame(minHeight: 460)

            if let mine = table.humanHandText {
                Text("Lavender has: \(mine)")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(Color.yellow, in: Capsule())
                    .padding(.horizontal)
                    .animation(.default, value: mine)
            }

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

            actionBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), Color(red: 0.08, green: 0.0, blue: 0.1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.default, value: table.banner)
        .onChange(of: table.humanToAct) { _, mine in
            if mine { raiseTo = Double(minRaiseTo) }
        }
    }

    private func label(_ i: Int, _ seat: HoldemTable.Seat) -> String {
        if i == 0 { return table.youAreHouse ? "Lavender · House" : "Lavender" }
        if seat.isPrincess { return table.youAreHouse ? "Princess" : (table.caribbean ? "Princess · House" : "Princess · Dealer") }
        return seat.name
    }

    private var me: HoldemTable.Seat { table.human }
    private var toCall: Int { max(0, table.currentBet - me.bet) }
    private var maxTo: Int { me.bet + me.stack }
    private var minRaiseTo: Int { min(maxTo, max(table.currentBet + table.lastRaise, HoldemTable.bigBlind)) }

    @ViewBuilder private var actionBar: some View {
        if table.choosingRole {
            RoleChoice(detail: "Should Lavender play a seat against the Princess's hand, or be the house and bank the table? Then the Princess plays instead.") { table.chooseRole(house: $0) }
        } else if table.finished {
            Text("The table is closed for the night.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.youAreHouse && !table.humanToAct {
            HStack {
                Text("Lavender is the house — she holds the dealer's hand and pays the winners.")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
            .frame(minHeight: 44)
        } else if table.watching {
            HStack {
                Text("Lavender is out of chips — watching the rest of the game.")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
        } else if table.humanToDraw {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(me.hole) { card in
                        let out = table.discards.contains(card.id)
                        Button { table.toggleDiscard(card) } label: {
                            CardView(card: card, width: 58)
                                .opacity(out ? 0.45 : 1)
                                .overlay(alignment: .top) {
                                    if out {
                                        Text("DISCARD")
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .background(Capsule().fill(Color.pink))
                                            .offset(y: -8)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .offset(y: out ? -8 : 0)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: table.discards)
                actionButton(table.discards.isEmpty ? "Stand pat" : "Draw \(table.discards.count)", .pink) { table.confirmDraw() }
            }
        } else if table.humanToAct && table.caribbean {
            HStack(spacing: 8) {
                actionButton("Fold", .gray) { table.act(.fold) }
                actionButton(table.humanRaise > 0 ? "Raise $\(table.humanRaise)" : "Play", .pink) { table.act(.call) }
            }
        } else if table.humanToAct {
            VStack(spacing: 8) {
                if maxTo > table.currentBet {
                    HStack {
                        Text("\(table.currentBet == 0 ? "Bet" : "Raise to") $\(Int(raiseTo))")
                            .font(.system(.subheadline, design: .rounded, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 110, alignment: .leading)
                        if minRaiseTo < maxTo {
                            Slider(value: $raiseTo, in: Double(minRaiseTo)...Double(maxTo), step: 1)
                                .tint(.pink)
                        } else {
                            Spacer()
                        }
                    }
                    HStack(spacing: 6) {
                        quick("Min") { raiseTo = Double(minRaiseTo) }
                        quick("½ Pot") { raiseTo = Double(clamp(table.currentBet + table.pot / 2)) }
                        quick("Pot") { raiseTo = Double(clamp(table.currentBet + table.pot + toCall)) }
                        quick("All in") { raiseTo = Double(maxTo) }
                    }
                }
                HStack(spacing: 8) {
                    actionButton("Fold", .gray) { table.act(.fold) }
                    if toCall == 0 {
                        actionButton("Check", .blue) { table.act(.check) }
                    } else {
                        actionButton(toCall >= me.stack ? "Call all in" : "Call $\(toCall)", .blue) { table.act(.call) }
                    }
                    if maxTo > table.currentBet {
                        actionButton(Int(raiseTo) >= maxTo ? "All in!" : (table.currentBet == 0 ? "Bet" : "Raise"), .pink) {
                            table.act(.raise(to: Int(raiseTo)))
                        }
                    }
                }
            }
        } else {
            HStack {
                Text(table.turn.map { "\(table.seats[$0].name) is thinking…" } ?? " ")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 44)
        }
    }

    private func clamp(_ v: Int) -> Int { min(maxTo, max(minRaiseTo, v)) }

    private func quick(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .buttonStyle(.bordered)
            .tint(.white)
            .frame(maxWidth: .infinity)
    }

    private func actionButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct SeatView: View {
    let seat: HoldemTable.Seat
    let label: String
    let isTurn: Bool
    let isDealer: Bool
    let winner: Bool
    let goldChips: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if seat.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: seat.skin, look: seat.look) }
                }
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(Color.white.opacity(0.15)))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(isTurn ? Color.yellow : (winner ? Color.green : Color.white.opacity(0.4)), lineWidth: isTurn || winner ? 3 : 1))
                    .opacity(seat.seated ? (seat.folded && seat.stack > 0 ? 0.6 : 1) : 0.25)
                if isDealer && seat.seated {
                    Text("D")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.white))
                        .offset(x: 6, y: -4)
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if seat.seated || seat.isHuman {
                HStack(spacing: 3) {
                    Circle().fill(goldChips ? Color.yellow : Color.red).frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])))
                    Text(seat.stack < 0 ? "-$\(-seat.stack)" : "$\(seat.stack)")
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.yellow)
                }
                if !seat.hole.isEmpty && !seat.isHuman {
                    HStack(spacing: 2) {
                        ForEach(seat.hole) { card in
                            CardView(card: card, faceUp: seat.isHuman || seat.showCards, dim: seat.folded, width: seat.hole.count > 4 ? 16 : (seat.hole.count > 2 ? 22 : 30))
                        }
                    }
                }
                if !seat.note.isEmpty {
                    Text(seat.note)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.9)))
                        .lineLimit(1)
                }
            } else {
                Text("beamed down")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 96)
    }
}
