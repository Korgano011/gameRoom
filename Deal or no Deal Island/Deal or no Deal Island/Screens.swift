import SwiftUI

let gold = Color(red: 0.98, green: 0.80, blue: 0.25)
let navy = Color(red: 0.06, green: 0.22, blue: 0.30)
let lagoon = Color(red: 0.10, green: 0.55, blue: 0.58)
let caseSteel = Color(red: 0.78, green: 0.80, blue: 0.84)
let finalRed = Color(red: 0.82, green: 0.18, blue: 0.24)

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

func cardColor(_ p: Contestant) -> Color {
    (p.chest ?? 0) > 0 ? p.chestTier?.color ?? .gray : .gray
}

/// A small closed briefcase.
struct CaseShape: View {
    let number: Int
    var size: CGFloat = 54
    var tint: Color = caseSteel

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(tint.opacity(0.9), lineWidth: 3)
                .frame(width: size * 0.34, height: size * 0.14)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                Rectangle().fill(.black.opacity(0.2)).frame(height: 2).offset(y: -size * 0.12)
                Text("\(number)").font(.system(size: size * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(navy)
            }
            .frame(width: size, height: size * 0.66)
        }
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
                    HStack(spacing: 8) {
                        ForEach([1, 7, 13, 20], id: \.self) { CaseShape(number: $0, size: 46) }
                    }
                    Text("BANKER'S ISLAND")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [gold, .orange], startPoint: .top, endPoint: .bottom))
                        .multilineTextAlignment(.center)
                    Text("Six players. Five excursions. Twenty cases. Bring back the lowest amount and you face the banker — beat the banker or go home. The final case starts at \(money(Board.finalCaseStart)).")
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
                        Label("\(show.alive.count) \(show.alive.count == 1 ? "player" : "players"), \(kind.tiers.count) chests: bronze, silver and gold", systemImage: "shippingbox.fill")
                        Label("Every amount brought back goes on the right side of the banker's board", systemImage: "list.number")
                        Label("The lowest amount faces the banker — empty-handed puts \(money(ChestTier.minimum)) on the board and faces the banker first", systemImage: "phone.fill")
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
                                    Badge(text: "FACES THE BANKER", color: .red)
                                } else {
                                    Badge(text: "SAFE", color: .green.opacity(0.7))
                                }
                                Text(p.emptyHanded ? "Empty-handed · \(money(ChestTier.minimum))" : money(p.chest ?? 0))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(cardColor(p))
                                    .frame(minWidth: 100, alignment: .trailing)
                            }
                        }
                    }
                }
                if let seat = show.seat {
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("On the line").font(.headline)
                            Text("\(show.name(seat)) brought back the lowest amount and faces the banker. Every amount brought back is on the board.")
                            Text("Make a GOOD deal — more than what's in your own case — and you stay, send someone home, and the deal goes into the final case. Make a BAD deal and you keep the money but leave the island.")
                                .foregroundStyle(gold).bold()
                            Text("Final case: \(money(show.finalCase)) and growing").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ContinueButton(title: show.seat == show.humanID ? "Face the banker" : "Watch the banker round")
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Facing the banker

struct BankerView: View {
    @Environment(Show.self) private var show
    let r: BankerRound

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                // Wide screens: amounts either side of the cases. Narrow: amounts on top, cases below.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        column(0..<10)
                        cases(4).frame(minWidth: 250)
                        column(10..<20)
                    }
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            column(0..<10)
                            column(10..<20)
                        }
                        cases(5)
                    }
                }
                HostBubble(text: r.host)
                controls
                if !r.offers.isEmpty { offerHistory }
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: r.opened)
        .animation(.easeInOut(duration: 0.3), value: r.offer)
    }

    private var header: some View {
        let p = show.players[r.player]
        return HStack(spacing: 12) {
            Avatar(p: p, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.isFinal ? "THE FINAL" : "FACING THE BANKER").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(p.name + (p.human ? " (you)" : "")).font(.title3.bold())
                if r.isFinal {
                    Text(r.finalCaseInPlay ? "Final case in play" : "Final case gone")
                        .font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background((r.finalCaseInPlay ? finalRed : Color.gray).opacity(0.8), in: Capsule())
                }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            if let m = r.mine {
                VStack(spacing: 2) {
                    CaseShape(number: m + 1, size: 44, tint: gold)
                    Text(r.outcome != nil ? money(r.value(ofCase: m)) : "YOUR CASE").font(.caption2.bold()).foregroundStyle(gold)
                }
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("OFFER").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(r.offer.map { money($0) } ?? r.dealt.map { money($0) } ?? "—").font(.title2.bold().monospacedDigit()).foregroundStyle(gold)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 110, alignment: .trailing)
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private func column(_ range: Range<Int>) -> some View {
        VStack(spacing: 4) {
            ForEach(range, id: \.self) { e in
                let entry = r.entries[e]
                let gone = r.isOpened(entry: e)
                if e == r.finalEntry {
                    finalRow(entry, gone: gone)
                } else {
                HStack(spacing: 4) {
                    if let who = entry.who {
                        Circle().fill(show.players[who].color).frame(width: 8, height: 8)
                    }
                    Text(money(entry.value)).font(.callout.bold().monospacedDigit())
                        .strikethrough(gone)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, minHeight: 26)
                .padding(.horizontal, 4)
                .background(gone ? Color.black.opacity(0.35) : (range.lowerBound == 0 ? lagoon : gold),
                            in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(gone ? Color.secondary : (range.lowerBound == 0 ? Color.white : Color.black))
                .opacity(gone ? 0.5 : 1)
                }
            }
        }
        .frame(width: 104)
    }

    /// The final case's slot on the board: labelled and in red so it can't be missed.
    private func finalRow(_ entry: BoardEntry, gone: Bool) -> some View {
        VStack(spacing: 0) {
            Label("FINAL CASE", systemImage: "star.fill").font(.system(size: 9, weight: .black))
            Text(money(entry.value)).font(.callout.weight(.heavy).monospacedDigit())
                .strikethrough(gone)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 4)
        .background(gone ? Color.black.opacity(0.35) : finalRed, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(gone ? .clear : gold, lineWidth: 2))
        .foregroundStyle(gone ? Color.secondary : Color.white)
        .opacity(gone ? 0.5 : 1)
    }

    private func cases(_ perRow: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: perRow), spacing: 8) {
            ForEach(0..<Board.caseCount, id: \.self) { c in
                let opened = r.opened.contains(c)
                let isMine = r.mine == c
                let canTap = show.isHuman(r.player) && !opened && !isMine
                    && (show.awaiting == .pickCase || show.awaiting == .openCase)
                Button {
                    if canTap {
                        r.tapped = c
                        show.respond()
                    }
                } label: {
                    ZStack {
                        if opened && !isMine && r.isFinalCase(c) {
                            VStack(spacing: 0) {
                                Text("FINAL CASE").font(.system(size: 8, weight: .black))
                                Text(money(r.value(ofCase: c))).font(.caption.bold().monospacedDigit())
                                    .lineLimit(1).minimumScaleFactor(0.5)
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(finalRed.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(.white)
                        } else if opened && !isMine {
                            Text(money(r.value(ofCase: c))).font(.caption.bold().monospacedDigit())
                                .lineLimit(1).minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(r.lastOpened == c ? gold : .secondary)
                        } else {
                            CaseShape(number: c + 1, size: 50, tint: isMine ? gold : caseSteel)
                                .opacity(isMine && r.outcome == nil ? 0.35 : 1)
                                .overlay {
                                    if canTap { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.7), lineWidth: 1.5).padding(-2) }
                                }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var controls: some View {
        switch show.awaiting {
        case .pickCase:
            Text("Tap a case to keep for yourself.").font(.headline).foregroundStyle(gold)
        case .openCase:
            Text("Tap a case to open — \(r.toOpen) to go this round.").font(.headline).foregroundStyle(gold)
        case .dealOrNot:
            VStack(spacing: 8) {
                Text(r.isFinal ? "Whatever you take is yours."
                     : "Good deal = more than your case holds. Odds the deal beats your case: \(Int((oddsGood * 100).rounded()))%")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button {
                        r.takeIt = true
                        show.respond()
                    } label: {
                        Text("DEAL").font(.title2.weight(.black)).frame(maxWidth: 160, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                    Button {
                        r.takeIt = false
                        show.respond()
                    } label: {
                        Text("NO DEAL").font(.title2.weight(.black)).frame(maxWidth: 160, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                }
            }
        case .proceed:
            ContinueButton(title: r.isFinal ? "See the final results" : "Continue")
        default:
            FastForward()
        }
    }

    private var oddsGood: Double {
        guard let o = r.offer else { return 0 }
        return Double(r.remaining.filter { $0 < o }.count) / Double(max(1, r.remaining.count))
    }

    private var offerHistory: some View {
        HStack(spacing: 6) {
            Text("Offers:").font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(Array(r.offers.enumerated()), id: \.offset) { i, o in
                Text(money(o)).font(.caption.monospacedDigit())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((r.dealt == o && i == r.offers.count - 1 ? Color.green : .white).opacity(0.15), in: Capsule())
            }
            Spacer()
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
                Text(mine ? "You beat the banker!" : "\(show.name(picker)) beat the banker!")
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
                                Text(p.emptyHanded ? "Empty-handed" : "Brought back \(money(p.chest ?? 0))").font(.caption2).foregroundStyle(gold)
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
                Text("Final case: \(money(show.finalCase))").font(.title2.bold()).foregroundStyle(gold)
                Text(last ? "One player left — on to the final" : "Still on the island").font(.headline)
                HStack(spacing: 12) {
                    ForEach(show.alive, id: \.self) { id in
                        VStack { Avatar(p: show.players[id]); Text(show.players[id].name).font(.caption) }
                    }
                }
                ContinueButton(title: last ? "On to the final" : "Next excursion")
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

// MARK: - Final round

struct FinalIntroView: View {
    @Environment(Show.self) private var show

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("THE FINAL").font(.caption.bold()).foregroundStyle(gold)
                if let seat = show.seat {
                    let p = show.players[seat]
                    Avatar(p: p, size: 64)
                    Text("\(p.name) is the last one on the island").font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Brought back from Belmar: \(p.emptyHanded ? "nothing, so \(money(ChestTier.minimum))" : money(p.chest ?? 0)) — it stays on the board")
                            Text("The final case — \(money(show.finalCase)) — is one of the 20 cases on the board.")
                                .foregroundStyle(gold).bold()
                            Text("Face the banker one last time. There's no good or bad deal now: whatever \(p.human ? "you walk" : "\(p.name) walks") away with — a deal or the case — is won.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ContinueButton(title: "Face the banker")
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
                if let r = show.round, r.isFinal, let won = r.outcome {
                    let p = show.players[r.player]
                    Image(systemName: "trophy.fill").font(.system(size: 60)).foregroundStyle(gold)
                    Text("\(p.name) wins \(money(won))!").font(.largeTitle.bold()).multilineTextAlignment(.center)
                    if let m = r.mine {
                        Text("Case \(m + 1) held \(money(r.value(ofCase: m))). The final case was \(money(show.finalCase)).")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
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
                    Text("Six players, one of them you, go on treasure excursions. After each excursion the player who brought back the lowest amount faces the banker. Each round sends one player home, until one is left for the final. The final case starts at $150,000.")
                }
                Section("Excursions") {
                    Text("1. The Hedge Maze · 2. Boat Hunt · 3. The Pyramid · 4. La Bufadora · 5. Belmar Beach")
                    Text("Find a treasure chest with a money amount inside: bronze $1,250–$5,000, silver $5,250–$12,500, gold $12,750–$25,000. The Pyramid hides trap doors. At La Bufadora and Belmar you must carry your chest back — blowholes and waves knock it out of your hands.")
                }
                Section("The board") {
                    Text("20 cases. Left side, always the same: $0.01, $0.25, $0.50, $0.75, $1, $5, $10, $25, $50, $75.")
                    Text("Right side: $100, $250, $500, $1,000, plus the amounts brought back from that excursion. From the second round on, a new highest amount is added each round and carries over: $50,000, then $75,000, $100,000 and $150,000. There are always 20 cases.")
                }
                Section("Facing the banker") {
                    Text("Pick a case to keep, then open 5 cases, then 4, then 3, then 2 and 2, then 1 at a time. After each batch the banker calls with an offer: Deal, or No Deal?")
                    Text("A GOOD deal is one worth more than what's in your own case. If you say No Deal all the way, your case is a good deal if it beats the banker's last offer.")
                    Text("Good deal: you stay on the island, send another player home, and the deal amount goes into the final case. Bad deal: you keep the money, but you're off the island.")
                }
                Section("The final") {
                    Text("The last player standing faces the banker one last time — no excursion. Their Belmar amount stays on the board. The final case is one of the 20 cases on the board. Whatever the player walks away with — a deal or their own case — is won.")
                }
            }
            .navigationTitle("How to Play")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
