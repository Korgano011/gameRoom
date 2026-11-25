import SwiftUI

let gold = Color(red: 0.98, green: 0.80, blue: 0.25)
let navy = Color(red: 0.06, green: 0.22, blue: 0.30)
let lagoon = Color(red: 0.10, green: 0.55, blue: 0.58)

// MARK: - Shared pieces

struct Avatar: View {
    let p: Contestant
    var size: CGFloat = 40

    var body: some View {
        Text(p.initial)
            .font(.system(size: size * 0.45, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(p.color.gradient))
            .overlay(Circle().stroke(p.human ? gold : .white.opacity(0.5), lineWidth: p.human ? 3 : 1))
            .opacity(p.out ? 0.4 : 1)
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.35)))
    }
}

struct HostBubble: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mic.fill").foregroundStyle(gold).padding(.top, 2)
            Text(text).font(.body.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: text)
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ContinueButton: View {
    @Environment(Show.self) private var show
    var title = "Continue"
    var body: some View {
        Button { show.respond() } label: {
            Text(title).font(.headline).frame(maxWidth: 320).padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(gold)
        .foregroundStyle(.black)
        .disabled(show.awaiting != .proceed)
    }
}

struct FastForward: View {
    @Environment(Show.self) private var show
    var body: some View {
        @Bindable var show = show
        if !show.watchingAfterOut {
            Toggle(isOn: $show.fast) { Label("Fast-forward", systemImage: "forward.fill") }
                .toggleStyle(.button)
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    var dark = false
    var body: some View {
        Text(text).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
            .background(color, in: Capsule()).foregroundStyle(dark ? .black : .white)
    }
}


let feltGreen = Color(red: 0.07, green: 0.38, blue: 0.25)

func chestColor(_ p: Contestant) -> Color {
    (p.chest ?? 0) > 0 ? p.chestTier?.color ?? .gray : .gray
}

/// A playing card, face up or face down.
struct CardFace: View {
    let card: PCard?
    var up = true
    var w: CGFloat = 60
    var glow: Color? = nil

    var body: some View {
        let h = w * 1.4
        ZStack {
            if let card, up, card == BonusRound.queen {
                QueenPortrait().clipShape(RoundedRectangle(cornerRadius: w * 0.12))
                VStack(spacing: -w * 0.05) {
                    Text("Q").font(.system(size: w * 0.2, weight: .bold, design: .serif))
                    Text("♠").font(.system(size: w * 0.16))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, w * 0.03).padding(.vertical, w * 0.01)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: w * 0.05))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(w * 0.06)
            } else if let card, up {
                RoundedRectangle(cornerRadius: w * 0.12).fill(.white)
                let ink = card.isRed ? Color(red: 0.85, green: 0.1, blue: 0.2) : .black
                VStack(alignment: .leading, spacing: -2) {
                    Text(card.rankText).font(.system(size: w * 0.3, weight: .bold, design: .rounded))
                    Text(card.suitSymbol).font(.system(size: w * 0.22))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(w * 0.08)
                .foregroundStyle(ink)
                Text(card.suitSymbol).font(.system(size: w * 0.5)).foregroundStyle(ink).offset(x: w * 0.1, y: h * 0.12)
            } else {
                RoundedRectangle(cornerRadius: w * 0.12)
                    .fill(LinearGradient(colors: [Color(red: 0.75, green: 0.12, blue: 0.2), Color(red: 0.45, green: 0.05, blue: 0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: w * 0.08).stroke(gold.opacity(0.8), lineWidth: 1.5).padding(w * 0.08)
                Text("$").font(.system(size: w * 0.45, weight: .black, design: .serif)).foregroundStyle(gold)
            }
            RoundedRectangle(cornerRadius: w * 0.12)
                .stroke(glow ?? .black.opacity(0.3), lineWidth: glow == nil ? 1 : 3)
        }
        .frame(width: w, height: h)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

// MARK: - Title

struct TitleView: View {
    @Environment(Show.self) private var show
    @State private var pick: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    HStack(spacing: -14) {
                        ForEach(Array([PCard(rank: 14, suit: 3), PCard(rank: 13, suit: 2), PCard(rank: 7, suit: 1)].enumerated()), id: \.offset) { i, c in
                            CardFace(card: c, w: 52).rotationEffect(.degrees(Double(i - 1) * 10))
                        }
                        CardFace(card: nil, w: 52).rotationEffect(.degrees(20))
                    }
                    .padding(.bottom, 6)
                    Text("CARD SHARKS ISLAND")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [gold, .orange], startPoint: .top, endPoint: .bottom))
                        .multilineTextAlignment(.center)
                    Text("Six players. Five excursions. Treasure chests numbered 1 to 9. Bring back the lowest number and you play the Money Cards — win the Big Bet or go home. The last one standing plays the bonus round for up to \(money(BonusRound.topPrize)) — if the Queen of Spades doesn't get you first.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
                .padding(.top)

                Text("Choose your contestant").font(.title3.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(show.players) { p in
                        Button { pick = p.id } label: {
                            VStack(spacing: 6) {
                                Avatar(p: p, size: 50)
                                Text(p.name).font(.headline)
                                Text(p.hometown).font(.caption).foregroundStyle(.secondary)
                                Text(p.trait).font(.caption2.bold()).foregroundStyle(gold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(pick == p.id ? gold.opacity(0.25) : .white.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(pick == p.id ? gold : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { show.start(as: pick) } label: {
                    Text(pick.map { "Play as \(show.players[$0].name)" } ?? "Pick a contestant")
                        .font(.headline).frame(maxWidth: 320).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black)
                .disabled(pick == nil)

                Button("Just watch a computer-only show") { show.start(as: nil) }
                    .font(.footnote)
            }
            .padding()
        }
    }
}

// MARK: - Excursion intro and results

struct IntroView: View {
    @Environment(Show.self) private var show

    var body: some View {
        let kind = show.kind
        ScrollView {
            VStack(spacing: 18) {
                Text("EXCURSION \(show.excursion + 1) OF \(HuntKind.allCases.count)").font(.caption.bold()).foregroundStyle(gold)
                Image(systemName: kind.symbol).font(.system(size: 60)).foregroundStyle(gold)
                Text(kind.title).font(.largeTitle.bold())
                Text(kind.blurb).multilineTextAlignment(.center)
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(show.alive.count) \(show.alive.count == 1 ? "player" : "players"), \(kind.tiers.count) chests: bronze 1–3, silver 4–6, gold 7–9", systemImage: "shippingbox.fill")
                        Label("The lowest number brought back faces elimination on the Money Cards — empty-handed counts as 0", systemImage: "suit.spade.fill")
                        if kind == .pyramid {
                            Label("Hidden trap doors drop you back to the bottom — once sprung, you can see them", systemImage: "arrow.down.to.line")
                        }
                        if kind == .bufadora {
                            Label("Four blowholes! Stay out of a ring when it rumbles", systemImage: "water.waves")
                        }
                        if kind == .belmar {
                            Label("Get hit by a wave and you're washed back to the beach without your chest", systemImage: "water.waves")
                        }
                        Label("\(Int(kind.seconds)) seconds on the clock", systemImage: "timer")
                        if show.humanIn {
                            Label("Move with the arrow keys, WASD, the pad, or by swiping", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                ContinueButton(title: show.humanIn ? "Start the excursion" : "Watch the excursion")
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }
}

struct HuntResultsView: View {
    @Environment(Show.self) private var show

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Treasure Count").font(.largeTitle.bold())
                Panel {
                    VStack(spacing: 8) {
                        ForEach(Array(show.ranking.enumerated()), id: \.element) { i, id in
                            let p = show.players[id]
                            HStack {
                                Text("\(i + 1)").font(.headline.monospacedDigit()).frame(width: 24)
                                Avatar(p: p, size: 32)
                                Text(p.name + (p.human ? " (you)" : "")).font(.headline)
                                Spacer()
                                if show.seat == id {
                                    Badge(text: "MONEY CARDS", color: .red)
                                } else {
                                    Badge(text: "SAFE", color: .green.opacity(0.7))
                                }
                                Text(p.emptyHanded ? "Empty · 0" : "\(p.chest ?? 0)")
                                    .font(.title3.bold().monospacedDigit())
                                    .foregroundStyle(chestColor(p))
                                    .frame(minWidth: 70, alignment: .trailing)
                            }
                        }
                    }
                }
                if let seat = show.seat {
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Facing elimination").font(.headline)
                            if show.tied.count > 1 {
                                Text("\(show.tied.map { show.name($0) }.sorted().joined(separator: " and ")) tied for the lowest number — a coin toss sends \(show.name(seat)) to the Money Cards.")
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(show.name(seat)) brought back the lowest number and plays the Money Cards with \(money(MoneyCards.stake)).")
                            Text("Bust and you're off the island. Lose the Big Bet and you keep your money but go home. Win the Big Bet and you stay — and choose who goes home instead.")
                                .foregroundStyle(gold).bold()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ContinueButton(title: show.seat == show.humanID ? "Play the Money Cards" : "Watch the Money Cards")
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - The Money Cards

struct MoneyCardsView: View {
    @Environment(Show.self) private var show
    let m: MoneyCards

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                board
                HostBubble(text: m.host)
                controls
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: m.bank)
        .animation(.easeInOut(duration: 0.3), value: m.level)
    }

    private var header: some View {
        let p = show.players[m.player]
        return HStack(spacing: 12) {
            Avatar(p: p, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("MONEY CARDS — FACING ELIMINATION").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(p.name + (p.human ? " (you)" : "")).font(.title3.bold())
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("BANK").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(money(m.bank)).font(.title2.bold().monospacedDigit())
                    .foregroundStyle(m.flash == .wrong ? .red : m.flash == .right ? .green : gold)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 110, alignment: .trailing)
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    /// The Big Bet on top, the second row in the middle, the first row at the bottom.
    private var board: some View {
        VStack(spacing: 10) {
            row(2, title: "BIG BET")
            row(1, title: "ROW 2")
            row(0, title: "ROW 1")
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(feltGreen.gradient, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(gold.opacity(0.6), lineWidth: 2))
    }

    private func row(_ r: Int, title: String) -> some View {
        let active = m.level == r && m.outcome == nil
        return VStack(spacing: 4) {
            Text(title).font(.caption2.weight(.black)).foregroundStyle(active ? gold : .white.opacity(0.6))
            HStack(spacing: 8) {
                ForEach(0..<m.rows[r].count, id: \.self) { i in
                    slot(m.rows[r][i], current: active && m.pos == i)
                }
            }
        }
    }

    @ViewBuilder private func slot(_ s: Slot, current: Bool) -> some View {
        VStack(spacing: 3) {
            if s.card == nil {
                RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .frame(width: 58, height: 58 * 1.4)
            } else {
                CardFace(card: s.card, up: s.up, w: 58,
                         glow: current ? gold : s.result == .right ? .green : s.result == .wrong ? .red : s.moved ? .cyan : nil)
                    .opacity(s.unused ? 0.3 : 1)
            }
            Group {
                if let h = s.higher {
                    Text("\(h ? "▲" : "▼") \(money(s.wager))")
                        .foregroundStyle(s.result == .right ? .green : s.result == .wrong ? .red : .white)
                } else if s.moved {
                    Text("moved up").foregroundStyle(.cyan)
                } else {
                    Text(" ")
                }
            }
            .font(.caption2.bold().monospacedDigit())
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(width: 66)
        }
    }

    @ViewBuilder private var controls: some View {
        switch show.awaiting {
        case .wager:
            wagerPanel
        case .proceed:
            ContinueButton(title: m.isFinal ? "See the final results" : "Continue")
        default:
            FastForward()
        }
    }

    private var wagerPanel: some View {
        @Bindable var m = m
        let o = m.odds
        return VStack(spacing: 10) {
            Text("Unseen cards: \(o.higher) higher · \(o.lower) lower · \(o.same) the same")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button { m.wager = max(m.minWager, m.wager - MoneyCards.step) } label: { Image(systemName: "minus.circle.fill").font(.title) }
                    .disabled(m.wager <= m.minWager)
                VStack(spacing: 0) {
                    Text("WAGER").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(money(m.wager)).font(.title.bold().monospacedDigit()).foregroundStyle(gold)
                        .contentTransition(.numericText())
                }
                .frame(minWidth: 130)
                Button { m.wager = min(m.bank, m.wager + MoneyCards.step) } label: { Image(systemName: "plus.circle.fill").font(.title) }
                    .disabled(m.wager >= m.bank)
            }
            .buttonStyle(.plain).foregroundStyle(gold)
            HStack(spacing: 8) {
                Button("Min \(money(m.minWager))") { m.wager = m.minWager }
                Button("Half") { m.wager = max(m.minWager, (m.bank / 2 / MoneyCards.step) * MoneyCards.step) }
                Button("All in") { m.wager = m.bank }
            }
            .buttonStyle(.bordered).font(.caption.bold())
            if m.canChange {
                Button { show.changeBase() } label: {
                    Label("Change the \(m.base.name)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered).tint(.cyan)
                Text("Don't like the base card? Change it once per row.").font(.caption2).foregroundStyle(.secondary)
            }
            if m.isBigBet {
                Text("Big Bet: at least half your bank (\(money(m.minWager))).").font(.caption.bold()).foregroundStyle(.orange)
            }
            HStack(spacing: 12) {
                Button {
                    m.higher = true
                    show.respond()
                } label: {
                    Label("HIGHER", systemImage: "arrow.up").font(.title3.weight(.black)).frame(maxWidth: 160, minHeight: 44)
                }
                .buttonStyle(.borderedProminent).tint(.green)
                Button {
                    m.higher = false
                    show.respond()
                } label: {
                    Label("LOWER", systemImage: "arrow.down").font(.title3.weight(.black)).frame(maxWidth: 160, minHeight: 44)
                }
                .buttonStyle(.borderedProminent).tint(.red)
            }
        }
    }
}

// MARK: - Choosing who leaves

struct PickView: View {
    @Environment(Show.self) private var show
    @State private var choice: Int?

    var body: some View {
        let picker = show.picker ?? 0
        let mine = show.isHuman(picker)
        ScrollView {
            VStack(spacing: 16) {
                Avatar(p: show.players[picker], size: 64)
                Text(mine ? "You won the Big Bet!" : "\(show.name(picker)) won the Big Bet!")
                    .font(.title2.bold()).multilineTextAlignment(.center)
                Text(mine ? "Choose a player to send home." : "\(show.name(picker)) must send someone home...")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                    ForEach(show.pickable, id: \.self) { id in
                        let p = show.players[id]
                        let on = (mine ? choice : show.picked) == id
                        Button {
                            if mine && show.awaiting == .eliminate { choice = id }
                        } label: {
                            VStack(spacing: 4) {
                                Avatar(p: p, size: 40)
                                Text(p.name + (p.human ? " (you)" : "")).font(.caption.bold())
                                Text(p.emptyHanded ? "Empty-handed" : "Brought back a \(p.chest ?? 0)").font(.caption2).foregroundStyle(gold)
                            }
                            .frame(maxWidth: .infinity).padding(8)
                            .background(on ? Color.red.opacity(0.5) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if mine {
                    Button {
                        show.picked = choice
                        show.respond()
                    } label: {
                        Text(choice.map { "Send \(show.name($0)) home" } ?? "Pick a player").frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                    .disabled(choice == nil || show.awaiting != .eliminate)
                } else if let p = show.picked {
                    Text("\(show.name(p)), you're off the island.").font(.headline).foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Between excursions

struct SummaryView: View {
    @Environment(Show.self) private var show

    var body: some View {
        let last = show.alive.count == 1
        ScrollView {
            VStack(spacing: 16) {
                Text("Excursion \(show.excursion + 1) Wrap-up").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(show.summary, id: \.self) { Text($0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(last ? "One player left — on to the bonus round!" : "Still on the island").font(.headline).multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    ForEach(show.alive, id: \.self) { id in
                        VStack { Avatar(p: show.players[id]); Text(show.players[id].name).font(.caption) }
                    }
                }
                ContinueButton(title: last ? "On to the bonus round" : "Next excursion")
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

struct EliminatedView: View {
    @Environment(Show.self) private var show
    let newGame: () -> Void

    var body: some View {
        let me = show.players[show.humanID ?? 0]
        VStack(spacing: 18) {
            Image(systemName: "figure.walk.departure").font(.system(size: 60)).foregroundStyle(.red)
            Text("You're off the island").font(.largeTitle.bold())
            Text(me.fate).font(.title3)
            Text(me.bank > 0 ? "You leave with \(money(me.bank))" : "You leave empty-handed")
                .font(.title2.bold()).foregroundStyle(gold)
            HStack {
                Button("Watch the rest of the show") { show.respond(true) }
                    .buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black)
                Button("New game", action: newGame).buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: - Bonus round

struct FinalIntroView: View {
    @Environment(Show.self) private var show

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("THE BONUS ROUND").font(.caption.bold()).foregroundStyle(gold)
                if let seat = show.seat {
                    let p = show.players[seat]
                    Avatar(p: p, size: 64)
                    Text("\(p.name) is the last one on the island!").font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ten cards are face down: Ace through 9 — and the Queen of Spades.")
                            Text("The first card picked goes in the ones place, the second in the tens, then hundreds, and so on. Pick up to six cards, and stop any time to take the cash.")
                                .foregroundStyle(.secondary)
                            Text("Turn over the Queen of Spades and the cash is lost!").foregroundStyle(.red).bold()
                            Text("Top prize: \(money(BonusRound.topPrize))").foregroundStyle(gold).bold()
                            if p.bank > 0 {
                                Text("Already won on the island: \(money(p.bank))").foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ContinueButton(title: "Play the bonus round")
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

struct FinaleView: View {
    @Environment(Show.self) private var show
    let newGame: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let b = show.bonus {
                    let p = show.players[b.player]
                    if b.hitQueen {
                        CardFace(card: BonusRound.queen, w: 90)
                    } else {
                        Image(systemName: "trophy.fill").font(.system(size: 60)).foregroundStyle(gold)
                    }
                    Text("\(p.name) is the champion!").font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text(b.hitQueen ? "The Queen of Spades took the bonus cash." : "Bonus round: \(money(b.cash))")
                        .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Total: \(money(p.bank))").font(.title.bold()).foregroundStyle(gold)
                }
                Panel {
                    VStack(spacing: 8) {
                        Text("Who took home what").font(.headline)
                        ForEach(show.players.sorted { $0.bank > $1.bank }) { p in
                            HStack {
                                Avatar(p: p, size: 28)
                                VStack(alignment: .leading) {
                                    Text(p.name + (p.human ? " (you)" : "")).bold()
                                    Text(p.fate).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(money(p.bank)).monospacedDigit().foregroundStyle(p.bank > 0 ? gold : .secondary)
                            }
                        }
                    }
                }
                Button("Play again", action: newGame)
                    .buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black)
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Rules

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("The show") {
                    Text("Six players, one of them you, go on treasure excursions. After each excursion the player who brought back the lowest number faces elimination on the Money Cards. Each round sends one player home, until one is left — the champion, who plays the Money Cards as the bonus round.")
                }
                Section("Excursions") {
                    Text("1. The Hedge Maze · 2. Boat Hunt · 3. The Pyramid · 4. La Bufadora · 5. Belmar Beach")
                    Text("Find a treasure chest with a number inside: bronze 1–3, silver 4–6, gold 7–9. Coming back empty-handed counts as 0. Ties for the lowest are settled by a coin toss. The Pyramid hides trap doors. At La Bufadora and Belmar you must carry your chest back — blowholes and waves knock it out of your hands.")
                }
                Section("The Money Cards") {
                    Text("Eight cards are dealt on three levels. You start with $200. Before each card, wager at least $50 and call it higher or lower than the card before it. Right: the wager is added to your bank. Wrong: it's taken away. A pair is no gain, no loss. Aces are high.")
                    Text("After the first three calls, the last card moves up to start the second row and you get another $200 for three more cards. Then the last card moves up to the top row for the Big Bet: you must wager at least half your bank. (On the Big Bet a tie is burned and a new card dealt.)")
                    Text("Don't like the base card at the start of a row? Change it once per row for a fresh card from the deck, before your first call on that row.")
                    Text("Bust on the first row and the last card moves up with another $200 for the last four cards. Bust after that and the game is over.")
                    Text("Bet everything and call every card right: $28,800.")
                }
                Section("Facing elimination") {
                    Text("Bust: you're off the island. Lose the Big Bet: you keep whatever money is left, but you're off the island. Win the Big Bet: you keep the money, stay on the island, and choose another player to send home.")
                }
                Section("The bonus round") {
                    Text("The last player standing faces ten face-down cards: Ace (1) through 9, and the Queen of Spades.")
                    Text("The first card picked is the ones digit, the second the tens, then hundreds, thousands, ten-thousands and hundred-thousands. Pick up to six cards and stop any time to keep the cash.")
                    Text("Turn over the Queen of Spades and the bonus cash is lost. Top prize: $987,654.")
                }
            }
            .navigationTitle("How to Play")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Bonus round

struct BonusView: View {
    @Environment(Show.self) private var show
    let b: BonusRound

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                number
                board
                HostBubble(text: b.host)
                controls
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .overlay { if b.kiss { QueenKissView().transition(.opacity) } }
        .animation(.easeInOut(duration: 0.3), value: b.kiss)
        .animation(.easeInOut(duration: 0.3), value: b.turned)
    }

    private var header: some View {
        let p = show.players[b.player]
        return HStack(spacing: 12) {
            Avatar(p: p, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("THE BONUS ROUND").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(p.name + (p.human ? " (you)" : "")).font(.title3.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("CARDS").font(.caption2.bold()).foregroundStyle(.secondary)
                Text("\(b.turned.count) of \(BonusRound.maxPicks)").font(.title3.bold().monospacedDigit()).foregroundStyle(gold)
            }
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Six digit boxes, hundred-thousands on the left down to ones on the right.
    private var number: some View {
        let d = b.digits
        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("$").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(gold)
                ForEach((0..<BonusRound.maxPicks).reversed(), id: \.self) { i in
                    let filled = i < d.count
                    Text(filled ? "\(d[i])" : "–")
                        .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(b.hitQueen ? .red.opacity(0.6) : filled ? .black : .white.opacity(0.3))
                        .strikethrough(b.hitQueen && filled)
                        .frame(width: 40, height: 52)
                        .background(filled ? gold : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(i == d.count && !b.over ? gold : .clear, lineWidth: 2))
                    if i == 3 { Text(",").font(.title.bold()).foregroundStyle(.secondary) }
                }
            }
            Text(b.hitQueen ? "LOST TO THE QUEEN" : "BONUS CASH: \(money(b.cash))")
                .font(.headline.monospacedDigit()).foregroundStyle(b.hitQueen ? .red : gold)
        }
    }

    private var board: some View {
        let canTap = show.isHuman(b.player) && show.awaiting == .bonusPick
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
            ForEach(b.cards.indices, id: \.self) { i in
                let up = b.turned.contains(i)
                let order = b.turned.firstIndex(of: i)
                Button {
                    if canTap && !up {
                        b.tapped = i
                        show.respond()
                    }
                } label: {
                    VStack(spacing: 3) {
                        CardFace(card: b.cards[i], up: up, w: 58,
                                 glow: up && b.cards[i] == BonusRound.queen ? .red : canTap && !up ? .white.opacity(0.7) : nil)
                        Text(order.map { b.cards[i] == BonusRound.queen ? "Queen!" : BonusRound.places[$0] } ?? " ")
                            .font(.caption2.bold()).foregroundStyle(order != nil && b.cards[i] == BonusRound.queen ? .red : gold)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(feltGreen.gradient, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(gold.opacity(0.6), lineWidth: 2))
    }

    @ViewBuilder private var controls: some View {
        switch show.awaiting {
        case .bonusPick:
            VStack(spacing: 8) {
                Text(b.turned.isEmpty ? "Tap a card. 1 in 10 is the Queen."
                     : "Tap a card for the \(BonusRound.places[b.turned.count]) place — 1 in \(b.faceDown.count) is the Queen.")
                    .font(.headline).foregroundStyle(gold).multilineTextAlignment(.center)
                if !b.turned.isEmpty {
                    Button {
                        b.stopTapped = true
                        show.respond()
                    } label: {
                        Text("STOP — take \(money(b.cash))").font(.title3.weight(.black)).frame(maxWidth: 300, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                }
            }
        case .proceed:
            ContinueButton(title: "See the final results")
        default:
            EmptyView()
        }
    }
}

#Preview("Queen of Spades") {
    CardFace(card: BonusRound.queen, w: 200).padding().background(feltGreen)
}
