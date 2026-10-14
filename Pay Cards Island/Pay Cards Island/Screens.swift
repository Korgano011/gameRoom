import SwiftUI

let gold = Color(red: 0.98, green: 0.80, blue: 0.25)
let navy = Color(red: 0.08, green: 0.12, blue: 0.30)
let felt = Color(red: 0.05, green: 0.33, blue: 0.20)

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

func cardColor(_ amount: Int) -> Color {
    amount >= 3_500 ? ChestTier.gold.color : amount >= 1_250 ? ChestTier.silver.color
        : amount > 0 ? ChestTier.bronze.color : .gray
}

/// A playing card: face up, face down (optionally numbered), or an empty spot.
struct CardView: View {
    var card: PlayingCard?
    var number: Int? = nil
    var ring: Color? = nil
    var empty = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let shape = RoundedRectangle(cornerRadius: w * 0.1)
            ZStack {
                if empty {
                    shape.strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                } else if let card {
                    shape.fill(.white)
                    face(card, w)
                } else {
                    shape.fill(LinearGradient(colors: [Color(red: 0.7, green: 0.1, blue: 0.15), Color(red: 0.45, green: 0.04, blue: 0.1)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                    shape.inset(by: w * 0.07).stroke(gold.opacity(0.7), lineWidth: max(1, w * 0.025))
                    if let number {
                        Text("\(number)").font(.system(size: w * 0.36, weight: .heavy, design: .rounded)).foregroundStyle(gold)
                    } else {
                        Image(systemName: "suit.diamond.fill").font(.system(size: w * 0.3)).foregroundStyle(gold.opacity(0.6))
                    }
                }
                if let ring { shape.stroke(ring, lineWidth: max(2, w * 0.06)) }
            }
            .shadow(color: .black.opacity(empty ? 0 : 0.35), radius: 2, y: 1)
        }
        .aspectRatio(0.7, contentMode: .fit)
    }

    @ViewBuilder private func face(_ c: PlayingCard, _ w: CGFloat) -> some View {
        if c == FinalRound.queen {
            ZStack {
                QueenPortrait().clipShape(RoundedRectangle(cornerRadius: w * 0.1))
                RoundedRectangle(cornerRadius: w * 0.08).inset(by: w * 0.04).stroke(gold.opacity(0.8), lineWidth: max(1, w * 0.02))
                ForEach([false, true], id: \.self) { flipped in
                    VStack(spacing: -w * 0.05) {
                        Text("Q").font(.system(size: w * 0.15, weight: .bold, design: .serif))
                        Text("♠").font(.system(size: w * 0.12))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, w * 0.025).padding(.vertical, w * 0.01)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: w * 0.04))
                    .rotationEffect(.degrees(flipped ? 180 : 0))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: flipped ? .bottomTrailing : .topLeading)
                    .padding(w * 0.06)
                }
            }
        } else if c.isJoker {
            VStack(spacing: 0) {
                Text("★").font(.system(size: w * 0.5)).foregroundStyle(.purple)
                Text("JOKER").font(.system(size: w * 0.16, weight: .black)).foregroundStyle(.purple)
            }
        } else {
            let color: Color = c.isRed ? Color(red: 0.8, green: 0.05, blue: 0.1) : .black
            ZStack {
                VStack(spacing: -w * 0.04) {
                    Text(c.rankText).font(.system(size: w * 0.24, weight: .bold, design: .rounded))
                    Text(c.suitText).font(.system(size: w * 0.2))
                }
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(w * 0.07)
                Text(c.suitText).font(.system(size: w * 0.46)).foregroundStyle(color).offset(x: w * 0.08, y: w * 0.12)
            }
        }
    }
}

// MARK: - Title

struct TitleView: View {
    @Environment(Show.self) private var show
    @State private var pick: Int?
    @State private var queenDemo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach([PlayingCard(rank: 14, suit: 0), PlayingCard(rank: 13, suit: 1), PlayingCard(rank: 0, suit: 0),
                                 PlayingCard(rank: 12, suit: 2), PlayingCard(rank: 11, suit: 3)]) { c in
                            CardView(card: c).frame(width: 40)
                        }
                    }
                    Text("PAY CARDS ISLAND")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [gold, .orange], startPoint: .top, endPoint: .bottom))
                        .multilineTextAlignment(.center)
                    Text("Nine players. Four treasure excursions. Pay Cards duels, a memory bonus round, and a final jackpot that starts at \(money(50_000)).")
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
                Button { queenDemo = true } label: { Label("Meet the Queen of Spades", systemImage: "suit.spade.fill") }
                    .font(.footnote)
            }
            .padding()
        }
        .overlay {
            if queenDemo {
                QueenKissView(demo: true) { queenDemo = false }.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: queenDemo)
    }
}

// MARK: - Excursion intro and results

struct IntroView: View {
    @Environment(Show.self) private var show

    var body: some View {
        let kind = show.kind
        ScrollView {
            VStack(spacing: 18) {
                Text("EXCURSION \(show.excursion + 1) OF 4").font(.caption.bold()).foregroundStyle(gold)
                Image(systemName: kind.symbol).font(.system(size: 60)).foregroundStyle(gold)
                Text(kind.title).font(.largeTitle.bold())
                Text(kind.blurb).multilineTextAlignment(.center)
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(show.alive.count) players, \(kind.tiers.count) chests: bronze, silver and gold", systemImage: "shippingbox.fill")
                        Label("The biggest money card becomes the bonus round's top prize", systemImage: "star.fill")
                        Label("The two smallest face off at Pay Cards", systemImage: "exclamationmark.triangle.fill")
                        if kind == .bufadora {
                            Label("Stay out of the geyser's ring when it rumbles!", systemImage: "water.waves")
                        }
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
                                if i == 0 {
                                    Text("BONUS PRIZE").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(gold, in: Capsule()).foregroundStyle(.black)
                                }
                                if show.facing.contains(id) {
                                    Text("PAY CARDS").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.red, in: Capsule())
                                }
                                Text(p.chest == 0 ? "Empty-handed" : money(p.chest ?? 0))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(cardColor(p.chest ?? 0))
                                    .frame(minWidth: 100, alignment: .trailing)
                            }
                        }
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("On the line").font(.headline)
                        Text("\(show.facing.map(show.name).joined(separator: " vs. ")) play three hands of Pay Cards. The loser keeps their Pay Cards money but leaves the island.")
                        Text("The winner plays the bonus round for $50, $500 and \(money(show.bonusTop)).")
                            .foregroundStyle(gold).bold()
                        Text("Final jackpot: \(money(show.jackpot)) and growing").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                ContinueButton(title: show.facing.contains(show.humanID ?? -1) ? "Play Pay Cards" : "Watch Pay Cards")
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Pay Cards

struct PayCardsView: View {
    @Environment(Show.self) private var show
    let pc: PayCards

    private var humanPlays: Bool { pc.ids.contains { show.isHuman($0) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("PAY CARDS · HAND \(pc.kind.rawValue + 1) OF 3 · \(pc.kind.title.uppercased())")
                    .font(.caption.bold()).foregroundStyle(gold).multilineTextAlignment(.center)
                HStack(alignment: .top, spacing: 10) {
                    ForEach(pc.ids, id: \.self) { podium($0) }
                }
                HostBubble(text: pc.host)
                board
                controls
                payTable
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private func podium(_ id: Int) -> some View {
        let p = show.players[id]
        let up = pc.turn == id
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Avatar(p: p, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(p.name + (p.human ? " (you)" : "")).font(.subheadline.bold()).lineLimit(1)
                    Text(money(pc.money[id] ?? 0)).font(.title3.bold().monospacedDigit()).foregroundStyle(gold)
                        .contentTransition(.numericText())
                        .animation(.default, value: pc.money[id])
                }
                Spacer(minLength: 0)
                if let c = pc.drawOff[id] { CardView(card: c).frame(width: 30) }
            }
            HStack(spacing: 3) {
                let hand = pc.hands[id] ?? []
                ForEach(0..<5, id: \.self) { i in
                    if i < hand.count { CardView(card: hand[i]) } else { CardView(card: nil, empty: true) }
                }
            }
            Text(pc.results[id] ?? (up ? (p.human ? "Your turn" : "Their turn") : " "))
                .font(.caption2.bold())
                .foregroundStyle(pc.best.contains(id) ? gold : .secondary)
                .lineLimit(2).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .top)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(up ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(up ? gold : pc.winner == id ? .green : .clear, lineWidth: 2))
    }

    private var board: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(pc.slots) { slot in
                let tappable = (show.awaiting == .call && slot.state == .down) || (show.awaiting == .take && slot.state == .up)
                Button {
                    guard tappable else { return }
                    pc.tapped = slot.id
                    show.respond()
                } label: {
                    switch slot.state {
                    case .down: CardView(card: nil, number: slot.id + 1, ring: tappable ? gold.opacity(0.6) : nil)
                    case .up: CardView(card: slot.card, ring: show.awaiting == .take ? gold : pc.fresh.contains(slot.id) ? .cyan : nil)
                    case .taken: CardView(card: nil, empty: true)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: 360)
        .background(felt, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.45, green: 0.3, blue: 0.1), lineWidth: 4))
        .animation(.easeInOut(duration: 0.25), value: pc.slots.map(\.state))
    }

    @ViewBuilder private var controls: some View {
        switch show.awaiting {
        case .call:
            Text("Tap a face-down card to call it").font(.headline).foregroundStyle(gold)
        case .take:
            Text("Tap a face-up card to take it").font(.headline).foregroundStyle(gold)
        case .keepOrPass:
            HStack {
                Button { show.respond(true) } label: { Text(pc.fresh.count > 1 ? "Keep all three" : "Keep it").frame(maxWidth: 200) }
                    .buttonStyle(.borderedProminent).tint(.green)
                Button { show.respond(false) } label: { Text("Turn back & pass").frame(maxWidth: 200) }
                    .buttonStyle(.borderedProminent).tint(.orange)
            }
        case .proceed:
            ContinueButton(title: pc.winner == nil ? "Next" : "Continue")
        default:
            if !humanPlays { FastForward() }
        }
    }

    private var payTable: some View {
        let rows: [(String, String)] = [("Pair", "$20"), ("Two pair", "$40"), ("Three of a kind", "$50"),
                                        ("Full house", "$100"), ("Four of a kind", "$200"), ("Five of a kind", "$300"),
                                        ("Best hand", "+$50")]
        return Panel {
            VStack(spacing: 4) {
                Text("PAYOUTS").font(.caption.bold()).foregroundStyle(gold)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 4) {
                    ForEach(rows, id: \.0) { r in
                        HStack { Text(r.0); Spacer(); Text(r.1).bold().monospacedDigit() }.font(.caption)
                    }
                }
                Text("Deck: Jacks, Queens, Kings and Aces. Straights and flushes don't count.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Bonus round

struct Countdown: View {
    let end: Date
    let seconds: Double

    var body: some View {
        TimelineView(.animation) { tl in
            let left = max(0, end.timeIntervalSince(tl.date))
            VStack(spacing: 4) {
                Text("\(Int(left.rounded(.up)))").font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
                ProgressView(value: seconds > 0 ? left / seconds : 0).tint(gold).frame(maxWidth: 300)
            }
        }
    }
}

struct BonusView: View {
    @Environment(Show.self) private var show
    let b: Bonus

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("BONUS ROUND").font(.caption.bold()).foregroundStyle(gold)
                HStack(spacing: 10) {
                    Avatar(p: show.players[b.player], size: 44)
                    Text(show.name(b.player)).font(.title2.bold())
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("WON SO FAR").font(.caption2.bold()).foregroundStyle(.secondary)
                        Text(money(b.winnings)).font(.title3.bold().monospacedDigit()).foregroundStyle(gold)
                    }
                }
                ladder
                HostBubble(text: b.host)
                if let end = b.memorizeEnd {
                    Countdown(end: end, seconds: b.memorizeSeconds)
                }
                if let t = b.target {
                    HStack(spacing: 12) {
                        CardView(card: t).frame(width: 64)
                        Text(show.awaiting == .guess ? "Where is the \(t.name)?" : "The \(t.name)")
                            .font(.headline)
                    }
                }
                grid
                if show.awaiting == .proceed {
                    ContinueButton()
                } else if !show.isHuman(b.player) {
                    FastForward()
                }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private var ladder: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                let result = b.results[i]
                VStack(spacing: 2) {
                    Text("\([4, 8, 12][i]) CARDS").font(.caption2.bold())
                    Text(money(b.prizes[i])).font(.headline.monospacedDigit())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(result == true ? Color.green.opacity(0.6) : result == false ? .red.opacity(0.6)
                            : i == 2 && b.thirdForfeited ? .gray.opacity(0.25)
                            : i == b.phase ? gold.opacity(0.85) : .white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(i == b.phase && result == nil && !(i == 2 && b.thirdForfeited) ? .black : .primary)
                .overlay {
                    if i == 2 && b.thirdForfeited && result == nil {
                        Text("FORFEITED").font(.caption.bold()).foregroundStyle(.red).rotationEffect(.degrees(-8))
                    }
                }
            }
        }
    }

    private var grid: some View {
        let right = b.target.flatMap { b.cards.firstIndex(of: $0) }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(Array(b.cards.enumerated()), id: \.element) { i, c in
                let revealed = b.faceUp && b.guess != nil
                let ring: Color? = revealed ? (i == right ? .green : i == b.guess ? .red : nil)
                    : i == b.guess ? gold : nil
                Button {
                    guard show.awaiting == .guess else { return }
                    b.guess = i
                    Sound.shared.play(.select)
                    show.respond()
                } label: {
                    CardView(card: b.faceUp ? c : nil, number: b.faceUp ? nil : i + 1, ring: ring)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: b.cards.count <= 4 ? 360 : 440)
        .background(felt, in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.3), value: b.faceUp)
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
                Text(mine ? "You survived the bonus round!" : "\(show.name(picker)) survived the bonus round!")
                    .font(.title2.bold()).multilineTextAlignment(.center)
                Text(mine ? "Choose one player to send home." : "\(show.name(picker)) must choose one player to send home...")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                    ForEach(show.pickable, id: \.self) { id in
                        let p = show.players[id]
                        let on = (mine ? choice : show.picked) == id
                        Button {
                            if mine && show.awaiting == .eliminate { choice = id }
                        } label: {
                            VStack(spacing: 4) {
                                Avatar(p: p, size: 40)
                                Text(p.name + (p.human ? " (you)" : "")).font(.caption.bold())
                                Text(money(p.chest ?? 0)).font(.caption2).foregroundStyle(cardColor(p.chest ?? 0))
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
        ScrollView {
            VStack(spacing: 16) {
                Text("Excursion \(show.excursion + 1) Wrap-up").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(show.summary, id: \.self) { Text($0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Final jackpot: \(money(show.jackpot))").font(.title2.bold()).foregroundStyle(gold)
                Text(show.alive.count == 1 ? "The last player on the island" : "Still on the island").font(.headline)
                HStack(spacing: 12) {
                    ForEach(show.alive, id: \.self) { id in
                        VStack { Avatar(p: show.players[id]); Text(show.players[id].name).font(.caption) }
                    }
                }
                ContinueButton(title: show.alive.count == 1 ? "On to the final jackpot round" : "Next excursion")
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

// MARK: - Final jackpot round

struct FinalView: View {
    @Environment(Show.self) private var show
    let f: FinalRound

    private var myMove: Bool { show.awaiting == .finalMove }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("THE FINAL JACKPOT ROUND").font(.caption.bold()).foregroundStyle(gold)
                HStack(spacing: 10) {
                    Avatar(p: show.players[f.player], size: 48)
                    Text(show.name(f.player)).font(.title2.bold())
                    Spacer()
                    Text(money(show.jackpot)).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(gold)
                }
                HostBubble(text: f.host)
                handRow
                controls
                board
                payTable
                if !show.isHuman(f.player) && !f.revealed { FastForward() }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .overlay { if f.kiss { QueenKissView().transition(.opacity) } }
        .animation(.easeInOut(duration: 0.3), value: f.kiss)
    }

    /// The five spots of the hand. With a full hand, tap one to throw it out.
    private var handRow: some View {
        let canDiscard = myMove && f.full
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { k in
                    if k < f.hand.count {
                        let i = f.hand[k]
                        Button {
                            guard canDiscard else { return }
                            f.move = .discard(i)
                            show.respond()
                        } label: {
                            CardView(card: f.cards[i], ring: canDiscard ? .orange : nil)
                        }
                        .buttonStyle(.plain)
                    } else {
                        CardView(card: nil, empty: true)
                    }
                }
            }
            .frame(maxWidth: 360)
            Text(f.hand.isEmpty ? "Your hand" : f.payout > 0 ? "\(f.value.detail) · \(money(f.payout))" : "No pay yet")
                .font(.headline).foregroundStyle(f.payout > 0 ? gold : .secondary)
        }
    }

    @ViewBuilder private var controls: some View {
        if myMove {
            VStack(spacing: 8) {
                Text(f.full ? "Tap a card in your hand to throw it out" : "Tap a face-down card to turn it over")
                    .font(.headline).foregroundStyle(gold)
                if !f.hand.isEmpty && !f.needsReplacement {
                    Button {
                        f.move = .stop
                        show.respond()
                    } label: {
                        Text(f.payout > 0 ? "Stop and take \(money(f.payout))" : "Stop with nothing").frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                }
            }
        }
    }

    private var board: some View {
        let canFlip = myMove && !f.full
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(Array(f.cards.enumerated()), id: \.element) { i, c in
                let inHand = f.hand.contains(i)
                let out = f.discarded.contains(i)
                let shown = inHand || out || i == f.queenAt || f.revealed
                let ring: Color? = i == f.queenAt ? .red : inHand ? gold : nil
                Button {
                    guard canFlip, !shown else { return }
                    f.move = .flip(i)
                    show.respond()
                } label: {
                    CardView(card: shown ? c : nil, number: shown ? nil : i + 1, ring: ring)
                        .opacity(out ? 0.35 : f.revealed && !inHand && i != f.queenAt ? 0.6 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: 440)
        .background(felt, in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.3), value: f.hand)
    }

    private var payTable: some View {
        let rows: [(Int, String, String)] = [(1, "Pair", money(500)), (2, "Two pair", money(1_000)), (3, "Three of a kind", money(1_500)),
                                             (4, "Full house", money(2_500)), (5, "Four of a kind", "JACKPOT")]
        let current = f.hand.isEmpty ? -1 : f.value.category
        return Panel {
            VStack(spacing: 4) {
                Text("PAYOUTS").font(.caption.bold()).foregroundStyle(gold)
                ForEach(rows, id: \.0) { r in
                    HStack { Text(r.1); Spacer(); Text(r.2).bold().monospacedDigit() }
                        .font(.subheadline)
                        .foregroundStyle(r.0 == current ? gold : .primary)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(r.0 == current ? gold.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
                }
                Text("The board: one four of a kind, two threes of a kind, two pairs, one odd card — and the Queen of Spades. Turn her over and you leave with nothing.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 360)
        }
    }
}

struct FinaleView: View {
    @Environment(Show.self) private var show
    let newGame: () -> Void

    var body: some View {
        let f = show.final
        ScrollView {
            VStack(spacing: 16) {
                if let f {
                    let p = show.players[f.player]
                    Image(systemName: f.won == true ? "trophy.fill" : f.winnings > 0 ? "dollarsign.circle.fill" : "cloud.rain.fill")
                        .font(.system(size: 60)).foregroundStyle(f.winnings > 0 ? gold : .gray)
                    Text(f.won == true ? "\(p.name) wins \(money(show.jackpot))!"
                         : f.winnings > 0 ? "\(p.name) stops and takes \(money(f.winnings))" : "\(p.name) leaves with nothing")
                        .font(.largeTitle.bold()).multilineTextAlignment(.center)
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
                    Text("Nine players, one of them you, go on four treasure excursions. Each excursion sends two players home, until one is left to play for the final jackpot, which starts at $50,000.")
                }
                Section("Excursions") {
                    Text("1. The Hedge Maze · 2. Boat Hunt · 3. Queen's Staircase · 4. La Bufadora")
                    Text("Find a treasure chest with a money card inside. At La Bufadora you must carry it back to base camp — and if the geyser erupts while you're inside its ring, it rips the chest out of your hands.")
                    Text("The biggest money card becomes the top prize of the bonus round (at least $1,000). The two smallest play Pay Cards.")
                }
                Section("Pay Cards") {
                    Text("Three hands on a board of 16 cards (Jacks through Aces). Pair $20, two pair $40, three of a kind $50, full house $100, four of a kind $200, five of a kind $300, and $50 for the best hand. Straights and flushes don't count.")
                    Text("Five Card Draw: call three cards. A pair must be kept; otherwise keep them, or turn them back and pass. Then call the fourth and fifth cards one at a time — refuse one and control passes. Once the other player has five cards, you must keep whatever you turn over.")
                    Text("Strategy Round: the four corners start face up. Call two cards, then take two of the six showing; do that twice, then call one and take one.")
                    Text("Wild Card Round: like Five Card Draw, with two wild jokers hidden on the board.")
                    Text("After three hands the lower total keeps their money but leaves the island. A tie goes to a one-card draw-off, high card wins $50.")
                }
                Section("Bonus round") {
                    Text("Memorize 4 cards for 4 seconds, then find the one drawn from the deck: $50. Then 8 cards for 8 seconds: $500. Then 12 cards for 12 seconds: the biggest treasure brought back.")
                    Text("Miss level 1 or 2 and you lose your shot at level 3, but you get a second guess at that level's money. Miss level 3 and you keep $500.")
                    Text("Clear all three and you stay: you send another player home, and the top prize goes into the final jackpot. Otherwise you leave with your Pay Cards and bonus money.")
                }
                Section("Final jackpot") {
                    Text("16 face-down cards hide one four of a kind, two threes of a kind, two pairs, one odd card and the Queen of Spades. Turn cards over one at a time to build a hand: pair $500, two pair $1,000, three of a kind $1,500, full house $2,500, four of a kind wins the jackpot.")
                    Text("Once you hold five cards you can throw one out and turn over a replacement, as often as you dare. Stop any time and take the money — but turn over the Queen of Spades and you leave with nothing.")
                }
                Section("Knocked out?") {
                    Text("If you're eliminated, you can keep watching the rest of the show.")
                }
            }
            .navigationTitle("How to Play")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - The Queen of Spades

/// The Queen of Spades: a raven-haired pin-up queen with a tiara, smoky eyes and red lips.
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
    static let hair = Color(red: 0.13, green: 0.06, blue: 0.09)
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

        // Long wavy hair falling past her shoulders, behind everything else.
        var back = Path()
        back.move(to: CGPoint(x: 50, y: 22))
        back.addCurve(to: CGPoint(x: 23, y: 56), control1: CGPoint(x: 30, y: 22), control2: CGPoint(x: 21, y: 38))
        back.addCurve(to: CGPoint(x: 17, y: 96), control1: CGPoint(x: 25, y: 72), control2: CGPoint(x: 12, y: 82))
        back.addCurve(to: CGPoint(x: 28, y: 118), control1: CGPoint(x: 21, y: 106), control2: CGPoint(x: 18, y: 114))
        back.addCurve(to: CGPoint(x: 40, y: 100), control1: CGPoint(x: 38, y: 120), control2: CGPoint(x: 42, y: 108))
        back.addLine(to: CGPoint(x: 50, y: 100))
        var mirrored = back.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 100, ty: 0))
        mirrored.addPath(back)
        ctx.fill(mirrored, with: .color(hairColor))

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

        // Side-swept bangs and a glossy wave over one eye's brow.
        var bangs = Path()
        bangs.move(to: CGPoint(x: 33.5, y: 60))
        bangs.addCurve(to: CGPoint(x: 56, y: 36), control1: CGPoint(x: 31, y: 42), control2: CGPoint(x: 42, y: 34))
        bangs.addCurve(to: CGPoint(x: 67, y: 62), control1: CGPoint(x: 66, y: 38), control2: CGPoint(x: 69, y: 50))
        bangs.addCurve(to: CGPoint(x: 62, y: 46), control1: CGPoint(x: 65, y: 54), control2: CGPoint(x: 64, y: 49))
        bangs.addCurve(to: CGPoint(x: 38, y: 47), control1: CGPoint(x: 54, y: 41), control2: CGPoint(x: 44, y: 41))
        bangs.addCurve(to: CGPoint(x: 33.5, y: 60), control1: CGPoint(x: 35.5, y: 50), control2: CGPoint(x: 34.5, y: 55))
        ctx.fill(bangs, with: .color(hairColor))
        var sheen = Path()
        sheen.move(to: CGPoint(x: 38, y: 42))
        sheen.addQuadCurve(to: CGPoint(x: 56, y: 38), control: CGPoint(x: 46, y: 36))
        sheen.move(to: CGPoint(x: 21, y: 66))
        sheen.addQuadCurve(to: CGPoint(x: 18, y: 92), control: CGPoint(x: 23, y: 80))
        sheen.move(to: CGPoint(x: 79, y: 66))
        sheen.addQuadCurve(to: CGPoint(x: 82, y: 92), control: CGPoint(x: 77, y: 80))
        ctx.stroke(sheen, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

        // Pearl drop earrings.
        for x in [33.6, 66.4] {
            ctx.fill(Path(ellipseIn: CGRect(x: x - 0.8, y: 63, width: 1.6, height: 1.6)), with: .color(gold))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.4, y: 65, width: 2.8, height: 3.4)), with: .color(Color(white: 0.96)))
        }

        // Tiara.
        var tiara = Path()
        tiara.move(to: CGPoint(x: 38, y: 33))
        for (i, x) in stride(from: 41.0, through: 62.0, by: 3).enumerated() {
            tiara.addLine(to: CGPoint(x: x - 1.5, y: i == 3 ? 21 : i % 2 == 0 ? 27 : 25))
            tiara.addLine(to: CGPoint(x: x, y: 30))
        }
        tiara.addLine(to: CGPoint(x: 62, y: 33))
        tiara.addQuadCurve(to: CGPoint(x: 38, y: 33), control: CGPoint(x: 50, y: 30))
        ctx.fill(tiara, with: .color(gold))
        ctx.fill(Path(ellipseIn: CGRect(x: 47.6, y: 26, width: 3, height: 3)), with: .color(Self.lips))

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
            Sound.shared.play(.laugh)
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
