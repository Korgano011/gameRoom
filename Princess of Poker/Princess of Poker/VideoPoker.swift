import SwiftUI

let numberWords = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

/// One sitting at the Princess of Poker's machine: 200 credits, nine games of 25 hands each.
@Observable final class VideoPokerSession {
    enum Phase { case intro, ready, doubling, picking, result, over }
    enum Ending { case cashedOut, broke, notMaxBet, qualified }

    static let startCredits = 200
    static let handsPerGame = 25

    var credits = startCredits
    var game = VPGame.jacks
    var handsPlayed = 0
    var bet = 5
    /// Double Down Stud: the bet was doubled before the fifth card.
    var doubled = false
    var maxBetThroughout = true
    var phase = Phase.intro
    var hand: [Card] = []
    var piles: [[Card]] = []
    var pickedPile: Int?
    var result = VPHand.nothing
    var won = 0
    var princessBonus = false
    var ending: Ending?
    var line = ""
    var talkingUntil = Date.distantPast

    private var deck: [Card] = []
    private var introTask: Task<Void, Never>?
    let sound: Sound
    /// Called when the session ends; the Director takes over (game 10 or an ending screen).
    var onEnd: ((Ending) -> Void)?

    init(sound: Sound) {
        self.sound = sound
    }

    var talking: Bool { Date.now < talkingUntil }
    /// Everything riding on this hand.
    var totalBet: Int { bet * (doubled ? 2 : 1) }

    func say(_ text: String) {
        line = text
        talkingUntil = .now + Double(text.count) * 0.065 + 0.5
        sound.speak(text, as: .princess)
    }

    func begin() {
        announce(first: true)
    }

    private func announce(first: Bool = false) {
        phase = .intro
        hand = []
        piles = []
        pickedPile = nil
        doubled = false
        let n = numberWords[game.number]
        // Games 2–4 are named as Double Down Stud before their type; game 1 is plain Double Down Stud.
        let name = game.doubleDown && game != .jacks ? "Double Down Stud \(game.title)" : game.title
        let text = first
            ? "Welcome honey. I am the Princess of Poker. Welcome to game \(n): \(name). Let's begin."
            : "Game \(n) is \(name). Let's begin."
        say(text)
        let pause = (first ? 6.5 : 3.5) + (game.doubleDown ? 1 : 0)
        introTask?.cancel()
        introTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(pause))
            guard let self, !Task.isCancelled, self.phase == .intro else { return }
            self.phase = .ready
        }
    }

    var canDeal: Bool { (phase == .ready || phase == .result || phase == .intro) && credits > 0 }
    var betweenHands: Bool { phase == .ready || phase == .result || phase == .intro }
    var canDouble: Bool { phase == .doubling && credits >= bet }

    func betOne() {
        guard betweenHands else { return }
        bet = bet >= min(5, credits) ? 1 : bet + 1
        sound.card()
    }

    func betMax() {
        guard betweenHands else { return }
        bet = min(5, credits)
        deal()
    }

    func deal() {
        guard canDeal else { return }
        introTask?.cancel()
        bet = min(bet, credits)
        credits -= bet
        if bet < 5 { maxBetThroughout = false }
        deck = Deck.shuffled(joker: game.usesJoker)
        if game.sneakyQueens {
            for i in deck.indices where deck[i].rank == 12 && Int.random(in: 0..<3) == 0 {
                deck[i].princess = true
            }
        }
        won = 0
        result = .nothing
        princessBonus = false
        pickedPile = nil
        doubled = false
        sound.card()
        if game.pickEm {
            hand = Array(deck.prefix(2))
            piles = [Array(deck[2..<5]), Array(deck[5..<8])]
            deck.removeFirst(8)
            phase = .picking
        } else {
            // Four cards face up; the fifth waits face down until you double down or stand.
            hand = Array(deck.prefix(5))
            deck.removeFirst(5)
            phase = .doubling
        }
    }

    /// Double Down Stud: match your bet, then see the fifth card.
    func doubleDown() {
        guard canDouble else { return }
        credits -= bet
        doubled = true
        sound.coin()
        settle()
    }

    /// Double Down Stud: keep your bet as it is and turn over the fifth card.
    func stand() {
        guard phase == .doubling else { return }
        sound.card()
        settle()
    }

    func pick(_ pile: Int) {
        guard phase == .picking else { return }
        pickedPile = pile
        hand += piles[pile]
        sound.card()
        settle()
    }

    private func settle() {
        result = game.evaluate(hand)
        won = game.row(for: result)?.payout(bet: totalBet) ?? 0
        if won > 0 && game.sneakyQueens && hand.contains(where: \.princess) {
            won *= 2
            princessBonus = true
        }
        credits += won
        handsPlayed += 1
        phase = .result
        if won > 0 { sound.coin() }
        if princessBonus {
            say("A sneaky queen! That's me, honey. Two times pay!")
        } else if result >= .fullHouse, won > 0 {
            say(["Ooh, nice hand, gorgeous!", "Look at you go, honey!", "Now that's how a Princess plays!"].randomElement()!)
        }

        if credits <= 0 {
            end(.broke)
        } else if handsPlayed >= Self.handsPerGame {
            if game == .pickSneaky {
                end(maxBetThroughout ? .qualified : .notMaxBet)
            } else {
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1.6))
                    guard let self, self.phase == .result, self.ending == nil else { return }
                    self.game = VPGame(rawValue: self.game.rawValue + 1)!
                    self.handsPlayed = 0
                    self.announce()
                }
            }
        }
    }

    func cashOut() {
        guard betweenHands, ending == nil else { return }
        end(.cashedOut)
    }

    private func end(_ e: Ending) {
        introTask?.cancel()
        ending = e
        phase = .over
        let tail = "I am the Princess of Poker. Play longer to see the endless game. Insert credits."
        switch e {
        case .cashedOut: say("Sorry to see you go so early, honey.")
        case .broke: say("You are good honey, but not good enough. " + tail)
        case .notMaxBet: say("You did not play the max bet of 5 throughout the game, so you do not qualify for game 10. Cashing you out, honey.")
        case .qualified: say("You are very very good gorgeous. You have made it to game 10. Let's begin.")
        }
        onEnd?(e)
    }

    var resultText: String {
        guard phase == .result || (phase == .over && !hand.isEmpty && ending != .cashedOut) else { return "" }
        guard won > 0, let row = game.row(for: result) else { return "No win" }
        return "\(row.name)! Win \(won)" + (doubled ? " (doubled down)" : "") + (princessBonus ? " (Sneaky Queen 2×)" : "")
    }
}

// MARK: - View

struct VideoPokerView: View {
    @Bindable var session: VideoPokerSession
    var onInsertCredits: () -> Void
    var onLeave: () -> Void

    var body: some View {
        GeometryReader { geo in
            let cardW = min(96, (geo.size.width - 48) / 5.4)
            ScrollView {
                VStack(spacing: 10) {
                    princessScreen
                    header
                    paytable
                    cards(cardW)
                    Text(session.resultText)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(session.won > 0 ? Color.yellow : .white.opacity(0.7))
                        .frame(minHeight: 28)
                    meters
                    controls
                }
                .padding(14)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.02, blue: 0.2), Color(red: 0.03, green: 0.0, blue: 0.08)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .overlay {
            // Cashing out (yourself, or automatically when you don't qualify) cuts back to the casino instead.
            if session.phase == .over, session.ending == .broke {
                endingOverlay
            }
        }
    }

    private var princessScreen: some View {
        HStack(alignment: .center, spacing: 12) {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                PrincessFace(talking: session.talking)
            }
            .frame(width: 104, height: 104)
            .background(Circle().fill(RadialGradient(colors: [.pink.opacity(0.6), .purple.opacity(0.3)], center: .center, startRadius: 5, endRadius: 60)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 3))
            VStack(alignment: .leading, spacing: 4) {
                Text("THE PRINCESS OF POKER")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(session.line.isEmpty ? "…" : session.line)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .animation(.default, value: session.line)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("GAME \(session.game.number) OF 10")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.pink)
            Text(session.game.title.uppercased())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            Text("Hand \(min(session.handsPlayed + (session.phase == .doubling || session.phase == .picking ? 1 : 0), 25)) / 25")
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var paytable: some View {
        let rows = session.game.paytable
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let shownBet = max(1, session.phase == .result ? session.totalBet : session.bet)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(rows) { row in
                let hit = session.phase == .result && session.result == row.hand && session.won > 0
                HStack {
                    Text(row.name).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    Text("\(row.payout(bet: shownBet))").monospacedDigit()
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(hit ? .black : .yellow)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(hit ? Color.yellow : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(8)
        .background(Color(red: 0.05, green: 0.05, blue: 0.4), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .bottomTrailing) {
            if session.game.doubleDown {
                Text("Double down before the 5th card" + (session.game.sneakyQueens ? " · Princess on a queen = 2× pay" : ""))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.pink, in: Capsule())
                    .offset(y: 10)
            }
        }
    }

    @ViewBuilder private func cards(_ w: CGFloat) -> some View {
        if session.game.pickEm {
            pickEmCards(w)
        } else {
            HStack(spacing: w * 0.12) {
                ForEach(0..<5, id: \.self) { i in
                    let card = i < session.hand.count ? session.hand[i] : nil
                    // The fifth card stays face down until you double down or stand.
                    let up = card != nil && !(i == 4 && session.phase == .doubling)
                    CardView(card: card ?? Card(rank: 14, suit: .spades), faceUp: up,
                             wild: up && (card.map(session.game.isWild) ?? false), width: w)
                }
            }
            .padding(.top, 10)
            .frame(minHeight: w * 1.42 + 16)
        }
    }

    private func pickEmCards(_ w: CGFloat) -> some View {
        let small = w * 0.9
        return HStack(alignment: .top, spacing: small * 0.3) {
            VStack(spacing: 4) {
                Text("YOUR CARDS").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { i in
                        let card = i < session.hand.count ? session.hand[i] : nil
                        CardView(card: card ?? .joker, faceUp: card != nil, wild: card.map(session.game.isWild) ?? false, width: small)
                    }
                }
            }
            // Once a pile is picked, only that pile stays on screen.
            ForEach((0..<2).filter { session.pickedPile == nil || session.pickedPile == $0 }, id: \.self) { p in
                let pile = p < session.piles.count ? session.piles[p] : []
                let revealed = session.phase == .result || session.phase == .over
                let chosen = session.pickedPile == p
                Button {
                    session.pick(p)
                } label: {
                    VStack(spacing: 4) {
                        Text(session.phase == .picking ? "PICK \(p == 0 ? "A" : "B")" : (chosen ? "PICKED" : "PILE \(p == 0 ? "A" : "B")"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(chosen ? .yellow : .white.opacity(0.7))
                        if pile.isEmpty {
                            CardView(card: nil, width: small)
                        } else {
                            if revealed {
                                // The picked pile spreads out side by side, every card fully showing.
                                HStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { k in
                                        CardView(card: pile[k], wild: session.game.isWild(pile[k]), width: small)
                                    }
                                }
                            } else {
                                // Two cards face down behind the face-up top card.
                                ZStack(alignment: .top) {
                                    ForEach((0..<3).reversed(), id: \.self) { k in
                                        CardView(card: pile[k], faceUp: k == 0, wild: k == 0 && session.game.isWild(pile[k]), width: small)
                                            .offset(y: Double(2 - k) * small * 0.16)
                                    }
                                }
                                .padding(.bottom, small * 0.32)
                            }
                        }
                    }
                    .padding(4)
                    .background(chosen ? Color.yellow.opacity(0.2) : (session.phase == .picking ? Color.white.opacity(0.08) : .clear),
                                in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                // No .disabled here: it would fade the picked pile. pick(_:) ignores taps outside .picking.
            }
        }
    }

    private var meters: some View {
        HStack {
            meter("CREDITS", "\(session.credits)")
            meter("BET", "\(session.bet)")
            meter("WIN", "\(session.won)")
            VStack(spacing: 2) {
                Image(systemName: session.maxBetThroughout ? "crown.fill" : "xmark.circle.fill")
                    .foregroundStyle(session.maxBetThroughout ? .yellow : .gray)
                Text(session.maxBetThroughout ? "Max bet streak" : "Game 10 lost")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func meter(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(.red)
            Text(value).font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(.yellow)
                .contentTransition(.numericText())
                .animation(.default, value: value)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            machineButton("CASH OUT", .orange, enabled: session.betweenHands && session.ending == nil) { session.cashOut() }
            switch session.phase {
            case .doubling:
                machineButton("DOUBLE DOWN", .red, enabled: session.canDouble) { session.doubleDown() }
                machineButton("5TH CARD", .green, enabled: true) { session.stand() }
            case .picking:
                machineButton("BET ONE", .blue, enabled: false) {}
                machineButton("BET MAX", .red, enabled: false) {}
                machineButton("PICK A PILE", .green, enabled: false) {}
            default:
                machineButton("BET ONE", .blue, enabled: session.betweenHands) { session.betOne() }
                machineButton("BET MAX", .red, enabled: session.betweenHands && session.credits > 0) { session.betMax() }
                machineButton("DEAL", .green, enabled: session.canDeal) { session.deal() }
            }
        }
    }

    private func machineButton(_ title: String, _ color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 10))
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var endingOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    PrincessFace(talking: session.talking, mood: session.ending == .broke ? .worried : .happy)
                }
                .frame(width: 180, height: 180)
                .background(Circle().fill(Color.pink.opacity(0.3)))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 4))
                Text(session.line)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("Credits left: \(session.credits)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.yellow)
                HStack(spacing: 12) {
                    Button("Insert Credits", action: onInsertCredits)
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    Button("Leave the Casino", action: onLeave)
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
                .font(.system(.headline, design: .rounded))
            }
            .padding(24)
            .frame(maxWidth: 520)
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
