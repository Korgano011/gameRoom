import SwiftUI

let gold = Color(red: 0.98, green: 0.80, blue: 0.25)
let navy = Color(red: 0.08, green: 0.12, blue: 0.30)
let booth = Color(red: 0.55, green: 0.35, blue: 0.85)

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

// MARK: - Title

struct TitleView: View {
    @Environment(Show.self) private var show
    @State private var pick: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        ForEach(1...4, id: \.self) { n in
                            Text("\(n)").font(.system(size: 24, weight: .black, design: .rounded))
                                .frame(width: 42, height: 42)
                                .background(navy, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(gold, lineWidth: 2))
                        }
                    }
                    Text("SPOILERS ISLAND")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [gold, .orange], startPoint: .top, endPoint: .bottom))
                        .multilineTextAlignment(.center)
                    Text("Eight players. Four treasure excursions. Get 4 clues past the Spoilers — or go home. The final jackpot starts at \(money(50_000)).")
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
                        Label("\(show.alive.count) players, \(kind.tiers.count) chests: bronze, silver and gold", systemImage: "shippingbox.fill")
                        if kind == .belmar {
                            Label("The highest money card takes the final hot seat — the other three are the Spoilers", systemImage: "star.fill")
                            Label("That card is at stake: beat the Spoilers and it's added to the jackpot", systemImage: "dollarsign.circle.fill")
                            Label("Get hit by a wave and you're washed back to the beach without your chest", systemImage: "water.waves")
                            Label("\(Int(kind.seconds)) seconds on the clock", systemImage: "timer")
                        } else {
                            Label("The biggest money card is at stake — it can go into the final jackpot", systemImage: "star.fill")
                            Label("The four smallest face elimination: the smallest takes the hot seat, the other three are the Spoilers", systemImage: "exclamationmark.triangle.fill")
                        }
                        if kind.payScale > 1 {
                            Label("Money cards are worth \(kind.payScale)× the Hedge Maze's", systemImage: "dollarsign.circle.fill")
                        }
                        if kind == .pyramid {
                            Label("Hidden trap doors drop you back to the bottom — once sprung, you can see them", systemImage: "arrow.down.to.line")
                        }
                        if kind == .bufadora {
                            Label("Four blowholes! Stay out of a ring when it rumbles", systemImage: "water.waves")
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
                                if i == 0 { Badge(text: "AT STAKE", color: gold, dark: true) }
                                if show.hotSeat == id {
                                    Badge(text: "HOT SEAT", color: .red)
                                } else if show.spoilerTeam.contains(id) {
                                    Badge(text: "SPOILER", color: booth)
                                } else {
                                    Badge(text: "SAFE", color: .green.opacity(0.7))
                                }
                                Text(p.chest == 0 ? "Empty-handed" : money(p.chest ?? 0))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(cardColor(p))
                                    .frame(minWidth: 100, alignment: .trailing)
                            }
                        }
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("On the line").font(.headline)
                        if let seat = show.hotSeat {
                            Text("\(show.name(seat)) takes the hot seat against \(show.spoilerTeam.map(show.name).formatted(.list(type: .and))). Each miss pays \(show.name(seat)) \(money(SpoilerRound.reward)); each Spoiler who names the subject wins \(money(SpoilerRound.reward)).")
                            Text("Get 4 clues past them and \(money(show.stake)) goes into the jackpot — and \(show.name(seat)) sends home a Spoiler still in the booth. If all three name it, \(show.name(seat)) goes home.")
                                .foregroundStyle(gold).bold()
                        }
                        Text("Final jackpot: \(money(show.jackpot)) and growing").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                ContinueButton(title: show.hotSeat == show.humanID ? "Take the hot seat"
                               : show.spoilerTeam.contains(show.humanID ?? -1) ? "Into the Spoilers' booth" : "Watch the Spoilers round")
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - The Spoilers round

struct SpoilersView: View {
    @Environment(Show.self) private var show
    let r: SpoilerRound

    /// Everyone sees the secret subject except a Spoiler who's still trying to name it.
    private var canSee: Bool {
        guard let me = show.humanID, r.active.contains(me) else { return true }
        return r.won != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                scoreboard
                subjectCard
                people
                board
                HostBubble(text: r.host)
                controls
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: r.tiles)
        .animation(.easeInOut(duration: 0.3), value: r.shown)
    }

    private var scoreboard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.isFinal ? "JACKPOT + BELMAR CARD" : "AT STAKE").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(money(r.stake)).font(.title2.bold().monospacedDigit()).foregroundStyle(gold)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("CLUES GIVEN").font(.caption2.bold()).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<SpoilerRound.goal, id: \.self) { i in
                        Circle().fill(i < r.given ? Color.green : .white.opacity(0.15)).frame(width: 14, height: 14)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PASSES LEFT").font(.caption2.bold()).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<r.passLimit, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3).fill(i < r.passesLeft ? Color.orange : .white.opacity(0.15))
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private var subjectCard: some View {
        VStack(spacing: 4) {
            Text("SECRET SUBJECT · \(r.subject.kind.rawValue.uppercased())").font(.caption.bold()).foregroundStyle(gold)
            if canSee {
                Text(r.subject.name).font(.system(size: 28, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
            } else {
                Text("? ? ?").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(.secondary)
                Text("You're in the booth — you can't see the subject or the board.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(navy, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold, lineWidth: 2))
    }

    private var people: some View {
        HStack(alignment: .top, spacing: 10) {
            let seat = show.players[r.hotSeat]
            VStack(spacing: 4) {
                Badge(text: "HOT SEAT", color: .red)
                Avatar(p: seat, size: 48)
                Text(seat.name + (seat.human ? " (you)" : "")).font(.caption.bold())
                Text("+\(money(r.earned[seat.id] ?? 0))").font(.caption.monospacedDigit()).foregroundStyle(gold)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            ForEach(r.spoilers, id: \.self) { id in
                boothView(id)
            }
        }
    }

    private func boothView(_ id: Int) -> some View {
        let p = show.players[id]
        let out = r.retired.contains(id)
        let guess = r.shown.contains(id) ? r.guesses[id] : nil
        let right = guess == r.subject.name
        return VStack(spacing: 4) {
            Badge(text: out ? "NAMED IT" : "IN THE BOOTH", color: out ? .gray : booth)
            Avatar(p: p, size: 40)
                .padding(6)
                .background(LinearGradient(colors: [.white.opacity(0.18), .cyan.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(out ? 0.15 : 0.5)))
            Text(p.name + (p.human ? " (you)" : "")).font(.caption.bold())
            if let guess, canSee || r.won != nil || p.human {
                Text(guess).font(.caption2.bold()).multilineTextAlignment(.center)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background((right ? Color.green : .red).opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
            } else if let guess {
                // A Spoiler in the booth hears whether the others were right, but not what they said.
                Text(guess == r.subject.name ? "Right!" : "Wrong").font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background((right ? Color.green : .red).opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
            }
            Text("+\(money(r.earned[id] ?? 0))").font(.caption.monospacedDigit()).foregroundStyle(gold)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(booth.opacity(out ? 0.06 : 0.18), in: RoundedRectangle(cornerRadius: 12))
        .opacity(out ? 0.7 : 1)
    }

    private var board: some View {
        let mine = show.isHuman(r.hotSeat)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
            ForEach(0..<8, id: \.self) { slot in
                Button {
                    if mine && show.awaiting == .pickClue && r.tiles[slot] == .hidden {
                        r.tapped = slot
                        show.respond()
                    }
                } label: {
                    tile(slot)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func tile(_ slot: Int) -> some View {
        let state = r.tiles[slot]
        let clue = r.clue(slot)
        let pickable = show.isHuman(r.hotSeat) && show.awaiting == .pickClue && state == .hidden
        VStack(spacing: 4) {
            switch state {
            case .hidden:
                Text("\(slot + 1)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(gold)
            case .reading:
                Text("CLUE \(slot + 1) · READING").font(.caption2.bold()).foregroundStyle(gold)
                if canSee { Text(clue.text).font(.callout.weight(.semibold)) } else { Text("…").font(.title.bold()) }
            case .given:
                Text("CLUE \(slot + 1) · GIVEN").font(.caption2.bold()).foregroundStyle(.green)
                Text(clue.text).font(.callout.weight(.semibold))
            case .passed:
                Text("CLUE \(slot + 1) · PASSED").font(.caption2.bold()).foregroundStyle(.orange)
                if canSee { Text(clue.text).font(.callout).foregroundStyle(.secondary) }
            case .unused:
                Text("CLUE \(slot + 1) · NOT USED").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(clue.text).font(.callout).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(8)
        .background(background(state), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border(state), lineWidth: state == .reading || pickable ? 3 : 1))
    }

    private func background(_ s: Tile) -> Color {
        switch s {
        case .hidden: navy
        case .reading: Color(red: 0.25, green: 0.20, blue: 0.05)
        case .given: Color.green.opacity(0.18)
        case .passed, .unused: Color.black.opacity(0.35)
        }
    }

    private func border(_ s: Tile) -> Color {
        switch s {
        case .hidden: gold.opacity(0.6)
        case .reading: gold
        case .given: .green
        case .passed: .orange.opacity(0.5)
        case .unused: .white.opacity(0.2)
        }
    }

    @ViewBuilder private var controls: some View {
        switch show.awaiting {
        case .pickClue:
            Text("Tap a number on the board.").font(.headline).foregroundStyle(gold)
        case .giveOrPass:
            HStack(spacing: 12) {
                Button {
                    r.giveIt = true
                    show.respond()
                } label: {
                    Label("Give it", systemImage: "hand.point.right.fill").frame(maxWidth: 160)
                }
                .buttonStyle(.borderedProminent).tint(.green)
                Button {
                    r.giveIt = false
                    show.respond()
                } label: {
                    Label("Pass (\(r.passesLeft) left)", systemImage: "arrow.uturn.backward").frame(maxWidth: 160)
                }
                .buttonStyle(.borderedProminent).tint(.orange)
                .disabled(r.passesLeft == 0)
            }
            .font(.headline)
        case .guess:
            VStack(spacing: 8) {
                Text("What's the secret \(r.subject.kind.noun)?").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
                    ForEach(r.choices, id: \.self) { c in
                        Button {
                            r.humanGuess = c
                            show.respond()
                        } label: {
                            Text(c).font(.callout.bold()).frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.bordered).tint(booth)
                    }
                }
            }
        case .proceed:
            ContinueButton(title: r.isFinal ? "See the final results" : "Continue")
        default:
            FastForward()
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
                Text(mine ? "You got 4 clues past the Spoilers!" : "\(show.name(picker)) got 4 clues past the Spoilers!")
                    .font(.title2.bold()).multilineTextAlignment(.center)
                Text(mine ? "Choose a Spoiler still in the booth to send home." : "\(show.name(picker)) must send home a Spoiler still in the booth...")
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
                                Text("Treasure \(money(p.treasure))").font(.caption2).foregroundStyle(gold)
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
                        Text(choice.map { "Send \(show.name($0)) home" } ?? "Pick a Spoiler").frame(maxWidth: 280)
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
                Text(show.alive.count == 4 ? "The final four — off to Belmar" : "Still on the island").font(.headline)
                HStack(spacing: 12) {
                    ForEach(show.alive, id: \.self) { id in
                        VStack { Avatar(p: show.players[id]); Text(show.players[id].name).font(.caption) }
                    }
                }
                ContinueButton(title: show.alive.count == 4 ? "On to Belmar Beach" : "Next excursion")
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
        let order = show.ranking
        ScrollView {
            VStack(spacing: 16) {
                Text("THE FINAL ROUND").font(.caption.bold()).foregroundStyle(gold)
                Text("Playing for \(money(show.jackpot + show.stake))").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Panel {
                    VStack(spacing: 8) {
                        Text("Belmar Beach money cards").font(.headline)
                        ForEach(order, id: \.self) { id in
                            let p = show.players[id]
                            HStack {
                                Avatar(p: p, size: 32)
                                Text(p.name + (p.human ? " (you)" : "")).font(.headline)
                                Spacer()
                                if show.hotSeat == id {
                                    Badge(text: "AT STAKE", color: gold, dark: true)
                                    Badge(text: "HOT SEAT", color: .red)
                                } else {
                                    Badge(text: "SPOILER", color: booth)
                                }
                                Text(p.chest == 0 ? "Empty-handed" : money(p.chest ?? 0)).font(.headline.monospacedDigit()).foregroundStyle(cardColor(p))
                                    .frame(minWidth: 100, alignment: .trailing)
                            }
                        }
                    }
                }
                if let seat = show.hotSeat {
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(show.name(seat)) brought back the highest money card from Belmar and takes the hot seat for the jackpot.")
                            Text("That \(money(show.stake)) card is at stake. Same game, tougher rules: only \(Show.finalPasses) passes. Get 4 clues past the other three and win the \(money(show.jackpot)) jackpot plus the card: \(money(show.jackpot + show.stake)). Get spoiled and both are lost.")
                                .foregroundStyle(gold).bold()
                            Text("Misses still pay \(money(SpoilerRound.reward)) to the hot seat, and every Spoiler who names the subject wins \(money(SpoilerRound.reward)).")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ContinueButton(title: "Play the final")
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
                if let r = show.round, r.isFinal {
                    let p = show.players[r.hotSeat]
                    Image(systemName: r.won == true ? "trophy.fill" : "cloud.rain.fill")
                        .font(.system(size: 60)).foregroundStyle(r.won == true ? gold : .gray)
                    Text(r.won == true ? "\(p.name) wins \(money(r.stake))!" : "The Spoilers stop \(p.name)!")
                        .font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text("The secret subject was \(r.subject.name).").foregroundStyle(.secondary)
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
                    Text("Eight players, one of them you, go on five treasure excursions. Each of the first four sends one player home. The final four go to Belmar Beach to decide who takes the final hot seat. The final jackpot starts at $50,000.")
                }
                Section("Excursions") {
                    Text("1. The Hedge Maze · 2. Boat Hunt · 3. The Pyramid · 4. La Bufadora · 5. Belmar Beach")
                    Text("Find a treasure chest with a money card inside. Cards are worth 2× on the Boat Hunt, 3× in the Pyramid, 4× at La Bufadora and 5× at Belmar. The Pyramid hides trap doors that drop you back to the bottom. At La Bufadora you must carry your chest back to base camp — and if one of the four blowholes erupts while you're inside its ring, it knocks the chest out of your hands. At Belmar the chests are out in the water: carry one back to the sand in 35 seconds, and if a wave hits you, you're washed back to the beach without your chest and have to try again.")
                    Text("On the first four excursions, the biggest money card is at stake (at least $1,000). The four smallest face elimination: the very smallest takes the hot seat, and the other three become the Spoilers.")
                }
                Section("The Spoilers round") {
                    Text("The player in the hot seat sees a secret subject — a famous person, place or thing — and a board of 8 numbered clues. The Spoilers can't see either.")
                    Text("Pick a number and read the clue privately. Give it to the Spoilers if you think it won't give the subject away, or pass on it. You have 4 passes; once they're gone, every clue you pick goes to the Spoilers.")
                    Text("After each clue you give, every Spoiler still in the booth guesses. A wrong guess pays the hot seat $250. A right guess wins that Spoiler $250, and they're out of the round.")
                    Text("Give 4 clues with at least one Spoiler still stumped and you win: the amount at stake goes into the final jackpot and you send home one of the Spoilers still in the booth. If all three Spoilers name the subject, you keep the money you've won but you're off the island, and nothing goes into the jackpot.")
                }
                Section("Final round") {
                    Text("The player with the highest money card at Belmar Beach takes the hot seat; the other three are the Spoilers, and that card is at stake. Same game, but only 2 passes. Get 4 clues past them to win the jackpot plus the Belmar card.")
                }
                Section("Knocked out?") {
                    Text("Everyone keeps the $250s they earned. If you're eliminated, you can keep watching the rest of the show.")
                }
            }
            .navigationTitle("How to Play")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
