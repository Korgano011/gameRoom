import SwiftUI

/// Craps at the salon's dice table, banked by the Princess. Before each come-out roll everyone bets the pass line
/// (7 or 11 wins, 2, 3 or 12 loses, anything else is the point — make it again before a 7) or don't pass (the
/// opposite, with 12 a push). Once a point is on, pass bettors can take odds behind the line (up to twice the
/// line bet, paid at true odds), and anyone can drop a one-roll field bet (3, 4, 9, 10, 11 even money; 2 pays
/// double, 12 triple). The dice pass to the next shooter on a seven-out.
/// You can choose to be the house instead: you bank the table, and the Princess plays a seat.
@Observable final class CrapsTable {
    struct Player: Identifiable {
        let id: Int
        var name: String
        /// Who she was before the salon's adjustment.
        var wasName: String
        var skin: Color
        var look: GirlLook
        var isHuman = false
        var isPrincess = false
        var isKid = false
        var stack = HoldemTable.buyIn
        var pass = 0
        var dontPass = 0
        var odds = 0
        var field = 0
        var seated = true
        var note = ""
        var aggression = 0.5
        var hasBets: Bool { pass + dontPass + odds + field > 0 }
        /// What she has on the layout, for her seat tag.
        var betsText: String {
            var parts: [String] = []
            if pass > 0 { parts.append("Pass $\(pass)") }
            if dontPass > 0 { parts.append("Don't $\(dontPass)") }
            if odds > 0 { parts.append("Odds $\(odds)") }
            if field > 0 { parts.append("Field $\(field)") }
            return parts.joined(separator: " · ")
        }
    }

    /// Pass-line decisions before the Princess closes the table.
    static let lastCallHand = 25
    static let fieldBet = 5

    /// 0 is you; the newcomers follow; the Princess (the house) is last.
    var players: [Player]
    var handNumber = 0
    var shooter = 0
    var dice = (1, 1)
    var rolling = false
    var point: Int?
    var message = "Will Lavender play, or be the house?"
    var banner: String?
    var departures: [HoldemTable.Departure] = []
    var winners: Set<Int> = []
    var finished = false
    /// Your line bet for the next come-out (kept from hand to hand).
    var humanBet = 5
    /// You drop a field bet on every roll while this is on.
    var fieldOn = false

    private var betCont: CheckedContinuation<Bool, Never>?
    private var rollCont: CheckedContinuation<Void, Never>?
    private var roleCont: CheckedContinuation<Bool, Never>?
    let sound: Sound
    let pace: Double
    var onFinished: (() -> Void)?

    init(players: [Player], sound: Sound, pace: Double) {
        self.players = players
        self.sound = sound
        self.pace = pace
    }

    var human: Player { players[0] }
    /// You chose to be the house: you bank the table; the Princess plays a seat.
    private(set) var youAreHouse = false
    var choosingRole: Bool { roleCont != nil }
    var princessIndex: Int { players.firstIndex(where: \.isPrincess) ?? players.count - 1 }
    var house: Int { youAreHouse ? 0 : princessIndex }
    /// The seat at the bottom of the table: you, or the Princess when you're the house.
    var bottom: Int { youAreHouse ? princessIndex : 0 }
    var dealerName: String { youAreHouse ? "Lavender" : "The Princess" }
    var humanToBet: Bool { betCont != nil }
    var humanToRoll: Bool { rollCont != nil }
    var humanIsShooter: Bool { shooter == 0 && !youAreHouse }
    var watching: Bool { !youAreHouse && human.stack <= 0 && !human.hasBets && !choosingRole }
    private var newcomers: [Int] { players.indices.filter { !players[$0].isHuman && !players[$0].isPrincess && players[$0].seated } }
    /// Everyone who bets against the house and takes a turn with the dice.
    private var bettors: [Int] { players.indices.filter { $0 != house && players[$0].seated } }

    /// The most odds you can take behind your pass-line bet right now.
    var humanOddsAvailable: Int {
        guard point != nil, human.pass > 0, human.odds == 0 else { return 0 }
        return min(human.pass * 2, human.stack)
    }

    // MARK: Dice

    /// True odds on a point: 4/10 pay 2 to 1, 5/9 pay 3 to 2, 6/8 pay 6 to 5.
    static func oddsPayout(_ bet: Int, point: Int) -> Int {
        switch point {
        case 4, 10: bet * 2
        case 5, 9: bet * 3 / 2
        default: bet * 6 / 5
        }
    }

    /// The field: 2 pays double, 12 triple, 3, 4, 9, 10, 11 even money; 5, 6, 7, 8 lose.
    static func fieldPays(_ total: Int) -> Int {
        switch total {
        case 2: 2
        case 12: 3
        case 3, 4, 9, 10, 11: 1
        default: 0
        }
    }

    static func callName(_ total: Int, _ d: (Int, Int)) -> String {
        switch total {
        case 2: "Snake eyes"
        case 3: "Ace-deuce"
        case 11: "Yo-leven"
        case 12: "Boxcars"
        default: d.0 == d.1 && [4, 6, 8, 10].contains(total) ? "Hard \(total)" : "\(total)"
        }
    }

    // MARK: Your choices

    func chooseRole(house: Bool) {
        guard let c = roleCont else { return }
        roleCont = nil
        c.resume(returning: house)
    }

    /// Bet the pass line (or don't pass) for the next come-out.
    func placeBet(dontPass: Bool) {
        guard let c = betCont else { return }
        betCont = nil
        c.resume(returning: dontPass)
    }

    func takeOdds() {
        let amount = humanOddsAvailable
        guard amount > 0 else { return }
        players[0].stack -= amount
        players[0].odds = amount
        players[0].note = players[0].betsText
        sound.coin()
    }

    /// Turn your field bet on or off; while you're waiting to roll it goes straight onto the layout (or comes back).
    func toggleField() {
        fieldOn.toggle()
        if humanToRoll { setHumanField(fieldOn) }
    }

    private func setHumanField(_ on: Bool) {
        if on, human.field == 0, human.stack >= Self.fieldBet {
            players[0].stack -= Self.fieldBet
            players[0].field = Self.fieldBet
            sound.coin()
        } else if !on, human.field > 0 {
            players[0].stack += human.field
            players[0].field = 0
        }
        if human.field == 0 && human.stack < Self.fieldBet { fieldOn = false }
        players[0].note = players[0].betsText
    }

    func roll() {
        guard let c = rollCont else { return }
        rollCont = nil
        c.resume()
    }

    func abandon() {
        if let c = roleCont { roleCont = nil; c.resume(returning: false) }
        if let c = betCont { betCont = nil; c.resume(returning: false) }
        if let c = rollCont { rollCont = nil; c.resume() }
    }

    // MARK: Flow

    func run() async {
        youAreHouse = await withCheckedContinuation { roleCont = $0 }
        if Task.isCancelled { return }
        if youAreHouse {
            message = "Lavender is the house! She banks the table; the Princess plays a seat and takes her turn with the dice."
            sound.speak("You're the house, honey. I'll shoot!", as: .princess)
        } else {
            sound.speak("Craps, girls! Bet the pass line, and roll those dice!", as: .princess)
        }
        shooter = bettors.first ?? 0
        await wait(1.5)
        while !Task.isCancelled {
            if newcomers.isEmpty { break }
            if handNumber >= Self.lastCallHand {
                message = "Last call! The Princess closes the table."
                for i in newcomers { depart(i, reason: "cashes out at last call") }
                break
            }
            await playHand()
            await checkDepartures()
        }
        finished = true
        try? await Task.sleep(for: .seconds(1.5))
        onFinished?()
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s * (watching ? 0.6 : 1) / pace))
    }

    /// One pass-line decision: bets, the come-out roll, then rolls until the point is made or it's a seven-out.
    private func playHand() async {
        handNumber += 1
        point = nil
        winners = []
        if !bettors.contains(shooter) || (players[shooter].stack <= 0 && !players[shooter].hasBets) { passDice() }
        for i in players.indices { players[i].note = "" }

        // Line bets
        for i in bettors where players[i].stack > 0 {
            if players[i].isHuman {
                if Task.isCancelled { return }
                humanBet = min(humanBet, players[i].stack)
                message = "Come-out roll \(handNumber). Lavender bets the pass line — or don't pass."
                let dont = await withCheckedContinuation { betCont = $0 }
                let bet = max(1, min(humanBet, players[i].stack))
                players[i].stack -= bet
                if dont { players[i].dontPass = bet } else { players[i].pass = bet }
            } else {
                await wait(0.3)
                let bet = min(players[i].aggression > 0.6 && Double.random(in: 0..<1) < 0.5 ? 10 : 5, players[i].stack)
                players[i].stack -= bet
                if Double.random(in: 0..<1) < 0.2 { players[i].dontPass = bet } else { players[i].pass = bet }
            }
            players[i].note = players[i].betsText
            sound.coin()
        }
        guard bettors.contains(where: { players[$0].hasBets }) else { return }

        // Roll until the line is decided.
        while !Task.isCancelled {
            let decided = await rollOnce()
            if decided { break }
        }
        await wait(2.2)
    }

    /// One roll of the dice. Returns true when the pass line is decided.
    private func rollOnce() async -> Bool {
        // Field bets and odds go down before the dice fly.
        for i in bettors where !players[i].isHuman && players[i].stack >= Self.fieldBet {
            if Double.random(in: 0..<1) < players[i].aggression * 0.35 {
                players[i].stack -= Self.fieldBet
                players[i].field = Self.fieldBet
            }
            if point != nil, players[i].pass > 0, players[i].odds == 0, Double.random(in: 0..<1) < players[i].aggression {
                let amount = min(players[i].pass * (players[i].aggression > 0.6 ? 2 : 1), players[i].stack)
                players[i].stack -= amount
                players[i].odds = amount
            }
            players[i].note = players[i].betsText
        }
        let name = players[shooter].name
        if !youAreHouse && (human.hasBets || humanIsShooter) {
            if Task.isCancelled { return true }
            message = point.map { "The point is \($0). \(humanIsShooter ? "Lavender is the shooter — roll!" : "\(name) is shooting.")" }
                ?? (humanIsShooter ? "Come-out roll! Lavender is the shooter." : "Come-out roll! \(name) is shooting.")
            if fieldOn { setHumanField(true) }
            await withCheckedContinuation { rollCont = $0 }
        } else {
            message = point.map { "The point is \($0). \(name) is shooting." } ?? "Come-out roll! \(name) is shooting."
            await wait(1.0)
        }

        // The dice tumble down the table.
        rolling = true
        for k in 0..<8 {
            dice = (Int.random(in: 1...6), Int.random(in: 1...6))
            if k % 2 == 0 { sound.card() }
            try? await Task.sleep(for: .seconds(0.07 / pace))
        }
        let d = (Int.random(in: 1...6), Int.random(in: 1...6))
        dice = d
        rolling = false
        sound.clunk()
        let total = d.0 + d.1
        let call = Self.callName(total, d)

        settleField(total)

        var decided = false
        var line: String
        if let p = point {
            if total == p {
                line = "\(call)! The point is made — pass line wins!"
                settleLine(passWins: true, push: false, point: p)
                decided = true
            } else if total == 7 {
                line = "Seven out! Don't pass wins. The dice move on."
                settleLine(passWins: false, push: false, point: p)
                decided = true
            } else {
                line = "\(call)." + (Self.fieldPays(total) > 0 ? " Field wins!" : "")
            }
        } else {
            switch total {
            case 7, 11:
                line = "\(call)! Winner on the pass line!"
                settleLine(passWins: true, push: false, point: nil)
                decided = true
            case 2, 3:
                line = "\(call), craps! Don't pass wins."
                settleLine(passWins: false, push: false, point: nil)
                decided = true
            case 12:
                line = "Boxcars, craps! Don't pass pushes."
                settleLine(passWins: false, push: true, point: nil)
                decided = true
            default:
                point = total
                line = "\(call) — the point is \(total)!"
            }
        }
        message = line
        sound.speak(line.components(separatedBy: " The dice").first ?? line, as: .princess)
        for i in players.indices where i != house { players[i].note = players[i].betsText }
        if decided && total == 7 && point != nil { passDice() }
        await wait(1.6)
        return decided
    }

    private func settleField(_ total: Int) {
        let pays = Self.fieldPays(total)
        for i in players.indices where players[i].field > 0 {
            let bet = players[i].field
            players[i].field = 0
            if pays > 0 {
                players[i].stack += bet + bet * pays
                players[house].stack -= bet * pays
                winners.insert(i)
            } else {
                players[house].stack += bet
            }
        }
        if pays > 0 { sound.coin() }
    }

    private func settleLine(passWins: Bool, push: Bool, point: Int?) {
        var houseWon = false
        for i in players.indices where i != house {
            let pass = players[i].pass, dont = players[i].dontPass, odds = players[i].odds
            if pass > 0 {
                if passWins {
                    let won = pass + (point.map { Self.oddsPayout(odds, point: $0) } ?? 0)
                    players[i].stack += pass + odds + won
                    players[house].stack -= won
                    winners.insert(i)
                } else {
                    players[house].stack += pass + odds
                    houseWon = true
                }
            }
            if dont > 0 {
                if push {
                    players[i].stack += dont
                } else if !passWins {
                    players[i].stack += dont * 2
                    players[house].stack -= dont
                    winners.insert(i)
                } else {
                    players[house].stack += dont
                    houseWon = true
                }
            }
            players[i].pass = 0
            players[i].dontPass = 0
            players[i].odds = 0
        }
        if houseWon { winners.insert(house) }
        sound.coin()
    }

    /// The dice go to the next player at the table who can still bet.
    private func passDice() {
        let order = bettors
        guard !order.isEmpty else { return }
        let start = order.firstIndex(where: { $0 > shooter }) ?? 0
        for k in 0..<order.count {
            let i = order[(start + k) % order.count]
            if players[i].stack > 0 || players[i].hasBets { shooter = i; return }
        }
        shooter = order[start]
    }

    private func checkDepartures() async {
        for i in newcomers {
            if players[i].stack <= 0 {
                depart(i, reason: "is out of money")
            } else if players[i].stack >= HoldemTable.goal {
                depart(i, reason: "doubled her money")
            }
        }
        if !youAreHouse && human.stack <= 0 && !human.hasBets && banner == nil {
            fieldOn = false
            banner = "Lavender is out of chips — she sits back and watches the rest of the game."
            await wait(2.5)
        }
    }

    private func depart(_ i: Int, reason: String) {
        guard players[i].seated else { return }
        players[i].seated = false
        let d = HoldemTable.Departure(name: players[i].name, wasName: players[i].wasName, takeaway: max(0, players[i].stack),
                                      reason: reason, isKid: players[i].isKid)
        departures.append(d)
        banner = d.isKid
            ? "\(d.name) \(reason)! She heads home to her mom — still a girl" + (d.takeaway > 0 ? ", with $\(d.takeaway)." : ".")
            : "\(d.name) \(reason)! She's beamed back down and turned back into \(d.wasName)" + (d.takeaway > 0 ? " — taking $\(d.takeaway)." : ".")
        sound.beam(true)
        Task { [sound] in
            try? await Task.sleep(for: .seconds(1.5))
            sound.beam(false)
        }
    }

    var yourWinnings: Int { human.stack - HoldemTable.buyIn }
    var princessWinnings: Int { players[princessIndex].stack - HoldemTable.buyIn }
    var revenue: Int { yourWinnings + princessWinnings }
}

// MARK: - View

/// One die with its pips.
struct DieView: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        let spots: [(CGFloat, CGFloat)] = switch value {
        case 1: [(0.5, 0.5)]
        case 2: [(0.27, 0.27), (0.73, 0.73)]
        case 3: [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)]
        case 4: [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)]
        case 5: [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)]
        default: [(0.27, 0.25), (0.73, 0.25), (0.27, 0.5), (0.73, 0.5), (0.27, 0.75), (0.73, 0.75)]
        }
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.15, blue: 0.3), Color(red: 0.7, green: 0.05, blue: 0.2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.4), radius: 3, x: 2, y: 3)
            ForEach(Array(spots.enumerated()), id: \.offset) { _, s in
                Circle().fill(.white)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .position(x: size * s.0, y: size * s.1)
            }
        }
        .frame(width: size, height: size)
    }
}

struct CrapsView: View {
    @Bindable var table: CrapsTable
    /// "Day 3 · Morning"
    let day: String
    let felt: Color
    let goldChips: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(day) · Craps · Come-out \(table.handNumber)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text(table.youAreHouse ? "Lavender is the house" : "Princess is the house")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.yellow)
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            houseSeat

            GeometryReader { geo in
                let size = geo.size
                let rail: CGFloat = 12
                // The bottom rail is deeper: each bettor's name is printed on it under her column of chips.
                let f = CGRect(x: rail, y: rail, width: size.width - rail * 2, height: size.height - rail - 22)
                ZStack(alignment: .topLeading) {
                    // The wooden rail and the felt.
                    RoundedRectangle(cornerRadius: 26)
                        .fill(LinearGradient(colors: [Color(red: 0.5, green: 0.28, blue: 0.12), Color(red: 0.3, green: 0.15, blue: 0.06)],
                                             startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 16)
                        .fill(felt)
                        .frame(width: f.width, height: f.height)
                        .offset(x: f.minX, y: f.minY)
                    CrapsLayout(point: table.point)
                        .frame(width: f.width, height: f.height)
                        .offset(x: f.minX, y: f.minY)

                    // The puck: ON the point box, or OFF in the don't-come corner.
                    puck
                        .position(puckSpot(in: f))
                        .animation(.spring(duration: 0.5), value: table.point)

                    // The dice land in the come area.
                    HStack(spacing: 10) {
                        DieView(value: table.dice.0, size: 34)
                            .rotationEffect(.degrees(table.rolling ? Double.random(in: -40...40) : -8))
                        DieView(value: table.dice.1, size: 34)
                            .rotationEffect(.degrees(table.rolling ? Double.random(in: -40...40) : 11))
                    }
                    .position(x: f.minX + f.width * 0.8, y: f.minY + f.height * 0.36)

                    // Everyone's chips on the layout, each bettor in her own column.
                    let cols = bettorSeats
                    ForEach(Array(cols.enumerated()), id: \.element) { k, i in
                        let p = table.players[i]
                        let x = f.minX + f.width * (0.27 + 0.72 * (CGFloat(k) + 0.5) / CGFloat(max(cols.count, 1)))
                        if p.pass > 0 {
                            CrapsChip(amount: p.pass, color: p.look.dress).position(x: x - 9, y: f.minY + f.height * 0.93)
                        }
                        if p.odds > 0 {
                            CrapsChip(amount: p.odds, color: p.look.dress).position(x: x + 15, y: f.minY + f.height * 0.93)
                        }
                        if p.dontPass > 0 {
                            CrapsChip(amount: p.dontPass, color: p.look.dress).position(x: x, y: f.minY + f.height * 0.81)
                        }
                        if p.field > 0 {
                            CrapsChip(amount: p.field, color: p.look.dress).position(x: x, y: f.minY + f.height * 0.615)
                        }
                        Text(p.isHuman ? "Lavender" : p.name)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 5)
                            .background(Capsule().fill(p.look.dress))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                            .frame(maxWidth: f.width * 0.72 / CGFloat(max(cols.count, 1)))
                            .opacity(p.seated ? 1 : 0.35)
                            .position(x: x, y: size.height - 11)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: table.players.map(\.betsText))
            }
            .frame(minHeight: 270, maxHeight: 440)
            .padding(.horizontal, 8)

            Text(table.message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 34)
                .padding(.horizontal)

            // The players along the rail.
            HStack(alignment: .top, spacing: 4) {
                ForEach(bettorSeats, id: \.self) { i in
                    railSeat(i)
                }
            }
            .padding(.horizontal, 8)

            if let banner = table.banner {
                CasinoBanner(text: banner)
            }

            actionBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), Color(red: 0.08, green: 0.0, blue: 0.1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.default, value: table.banner)
    }

    /// Everyone but the house, in seat order: you (or the Princess) and the newcomers.
    private var bettorSeats: [Int] {
        let others = table.players.indices.filter { $0 != table.house && $0 != table.bottom }
        return [table.bottom] + others
    }

    private func puckSpot(in f: CGRect) -> CGPoint {
        if let p = table.point, let k = CrapsLayout.points.firstIndex(of: p) {
            let x0 = f.minX + f.width * CrapsLayout.leftCol
            let w = f.width * (1 - CrapsLayout.leftCol) / 6
            return CGPoint(x: x0 + w * (CGFloat(k) + 0.5), y: f.minY + f.height * 0.06)
        }
        return CGPoint(x: f.minX + f.width * CrapsLayout.leftCol / 2, y: f.minY + f.height * 0.1)
    }

    /// The banker at the head of the table.
    private var houseSeat: some View {
        let h = table.players[table.house]
        return HStack(spacing: 8) {
            Group {
                if h.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: h.skin, look: h.look) }
            }
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.white.opacity(0.15)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(table.winners.contains(table.house) ? Color.green : Color.white.opacity(0.4),
                                           lineWidth: table.winners.contains(table.house) ? 3 : 1))
            VStack(alignment: .leading, spacing: 0) {
                Text(table.youAreHouse ? "Lavender · House" : "Princess · House")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                bankText(h.stack)
            }
        }
    }

    private func bankText(_ stack: Int) -> some View {
        HStack(spacing: 3) {
            Circle().fill(goldChips ? Color.yellow : Color.red).frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])))
            Text(stack < 0 ? "-$\(-stack)" : "$\(stack)")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.yellow)
        }
    }

    /// A player at the rail: her face ringed in her chip colour, her name, her bank, and the shooter tag.
    private func railSeat(_ i: Int) -> some View {
        let p = table.players[i]
        let shooting = table.shooter == i && p.seated
        let won = table.winners.contains(i)
        return VStack(spacing: 2) {
            Group {
                if p.isPrincess { PrincessFace(talking: false) } else { GirlPortrait(skin: p.skin, look: p.look) }
            }
            .frame(width: 46, height: 46)
            .background(Circle().fill(Color.white.opacity(0.15)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(p.look.dress, lineWidth: 3))
            .shadow(color: won ? .green : (shooting ? .yellow : .clear), radius: 6)
            .opacity(p.seated ? 1 : 0.25)
            Text(p.isHuman ? "Lavender" : p.name)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if p.seated {
                bankText(p.stack)
                if shooting { shooterTag }
                // Her bets on the layout right now, one per line.
                VStack(spacing: 0) {
                    ForEach(p.betsText.components(separatedBy: " · ").filter { !$0.isEmpty }, id: \.self) { bet in
                        Text(bet)
                            .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            } else {
                Text("beamed down")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The ON/OFF puck: white ON when a point is on, black OFF on the come-out.
    private var puck: some View {
        let on = table.point != nil
        return Text(on ? "ON" : "OFF")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(on ? .black : .white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(on ? Color.white : Color.black))
            .overlay(Circle().strokeBorder(on ? Color.black : Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
    }

    private var shooterTag: some View {
        Text("🎲 SHOOTER")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(Color.yellow))
    }

    @ViewBuilder private var actionBar: some View {
        if table.choosingRole {
            RoleChoice(detail: "Should Lavender play a seat against the Princess, or be the house and bank the table? Then the Princess plays instead.") { table.chooseRole(house: $0) }
        } else if table.finished {
            Text("The table is closed for the day.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
        } else if table.humanToBet {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(BlackjackTable.betChoices, id: \.self) { b in
                        let ok = b <= table.human.stack || b == BlackjackTable.betChoices[0]
                        let picked = table.humanBet == min(b, table.human.stack)
                        Button { table.humanBet = min(b, table.human.stack) } label: {
                            Text("$\(b)")
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(picked ? .black : .white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(picked ? Color.yellow : Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!ok)
                        .opacity(ok ? 1 : 0.35)
                    }
                }
                HStack(spacing: 8) {
                    CasinoButton(title: "Pass Line $\(table.humanBet)", color: .pink) { table.placeBet(dontPass: false) }
                    CasinoButton(title: "Don't Pass $\(table.humanBet)", color: .purple) { table.placeBet(dontPass: true) }
                }
            }
        } else if table.humanToRoll {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button { table.toggleField() } label: {
                        Text(table.fieldOn ? "Field $\(CrapsTable.fieldBet): ON" : "Field $\(CrapsTable.fieldBet): OFF")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(table.fieldOn ? .black : .white)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(table.fieldOn ? Color.yellow : Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(table.human.field == 0 && table.human.stack < CrapsTable.fieldBet)
                    .opacity(table.human.field == 0 && table.human.stack < CrapsTable.fieldBet ? 0.35 : 1)
                    if table.humanOddsAvailable > 0 {
                        Button { table.takeOdds() } label: {
                            Text("Take Odds $\(table.humanOddsAvailable)")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(Color.green.opacity(0.6), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                CasinoButton(title: table.humanIsShooter ? "🎲 Roll the Dice" : "Let \(table.players[table.shooter].name) Roll",
                             color: .pink) { table.roll() }
            }
        } else if table.youAreHouse {
            HStack {
                Text("Lavender is the house — she banks the table and pays the winners.")
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
        } else {
            HStack {
                Text("\(table.players[table.shooter].name) has the dice…")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .frame(minHeight: 44)
        }
    }
}

/// A chip on the layout in the bettor's own colour, with the amount on it.
struct CrapsChip: View {
    let amount: Int
    let color: Color

    var body: some View {
        Text("\(amount)")
            .font(.system(size: 9, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .shadow(color: .black, radius: 1)
            .frame(width: 24, height: 24)
            .background(Circle().fill(color))
            .overlay(Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 2.5, dash: [3, 3])).padding(1.5))
            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1.5)
            .transition(.scale.combined(with: .opacity))
    }
}

/// The printed craps layout: the point boxes across the top, the come area, the field, Big 6 and Big 8,
/// and the L-shaped don't pass bar and pass line wrapping around them.
struct CrapsLayout: View {
    let point: Int?

    static let points = [4, 5, 6, 8, 9, 10]
    /// Width of the left column (don't come bar on top, the pass lines' upright strips below), as a fraction.
    static let leftCol: CGFloat = 0.15

    var body: some View {
        Canvas { ctx, size in
            let W = size.width, H = size.height
            let line = Color.white.opacity(0.9)
            let gold = Color(red: 1, green: 0.85, blue: 0.3)
            let red = Color(red: 0.95, green: 0.2, blue: 0.2)
            func r(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
                CGRect(x: W * x0, y: H * y0, width: W * (x1 - x0), height: H * (y1 - y0))
            }
            func stroke(_ rect: CGRect) { ctx.stroke(Path(rect), with: .color(line), lineWidth: 1.5) }
            func label(_ s: String, _ p: CGPoint, size: CGFloat, color: Color = .white, rotate: Double = 0) {
                var c = ctx
                c.translateBy(x: p.x, y: p.y)
                c.rotate(by: .degrees(rotate))
                c.draw(Text(s).font(.system(size: size, weight: .heavy, design: .serif)).foregroundStyle(color), at: .zero)
            }
            let lc = Self.leftCol

            // Point boxes: 4 5 SIX 8 NINE 10.
            let bw = (1 - lc) / 6
            for (k, n) in Self.points.enumerated() {
                let box = r(lc + bw * CGFloat(k), 0, lc + bw * CGFloat(k + 1), 0.2)
                if n == point { ctx.fill(Path(box), with: .color(.white.opacity(0.12))) }
                stroke(box)
                label(n == 6 ? "SIX" : n == 9 ? "NINE" : "\(n)", CGPoint(x: box.midX, y: box.midY + H * 0.03),
                      size: min(20, H * 0.09, W * bw * (n == 9 ? 0.28 : 0.34)), color: n == 6 || n == 9 ? gold : .white)
            }

            // Don't come bar in the corner.
            let dc = r(0, 0, lc, 0.2)
            stroke(dc)
            label("DON'T", CGPoint(x: dc.midX, y: dc.minY + H * 0.04), size: 7)
            label("COME", CGPoint(x: dc.midX, y: dc.maxY - H * 0.035), size: 7)

            // Come.
            let come = r(lc, 0.2, 1, 0.5)
            stroke(come)
            label("COME", CGPoint(x: W * (lc + (1 - lc) * 0.4), y: come.midY), size: min(34, H * 0.14), color: red)

            // Big 6 / Big 8, split on the diagonal.
            let big = r(lc, 0.5, 0.27, 0.72)
            stroke(big)
            var diag = Path()
            diag.move(to: CGPoint(x: big.minX, y: big.maxY))
            diag.addLine(to: CGPoint(x: big.maxX, y: big.minY))
            ctx.stroke(diag, with: .color(line), lineWidth: 1.5)
            label("6", CGPoint(x: big.minX + big.width * 0.3, y: big.minY + big.height * 0.32), size: 15, color: red)
            label("8", CGPoint(x: big.minX + big.width * 0.7, y: big.minY + big.height * 0.7), size: 15, color: red)

            // The field.
            let field = r(0.27, 0.5, 1, 0.72)
            stroke(field)
            let nums: [(String, Bool)] = [("2", true), ("3", false), ("4", false), ("9", false), ("10", false), ("11", false), ("12", true)]
            for (k, n) in nums.enumerated() {
                let x = field.minX + field.width * (CGFloat(k) + 0.5) / CGFloat(nums.count)
                let y = field.minY + field.height * 0.2
                if n.1 {
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - 10, y: y - 10, width: 20, height: 20)), with: .color(gold), lineWidth: 1.5)
                }
                label(n.0, CGPoint(x: x, y: y), size: 13, color: n.1 ? gold : .white)
            }
            label("FIELD", CGPoint(x: field.midX, y: field.minY + field.height * 0.84), size: min(15, H * 0.06), color: gold)
            label("2× PAYS DOUBLE", CGPoint(x: field.minX + field.width * 0.12, y: field.minY + field.height * 0.84), size: 6, color: gold)
            label("12× PAYS TRIPLE", CGPoint(x: field.maxX - field.width * 0.12, y: field.minY + field.height * 0.84), size: 6, color: gold)

            // Don't pass bar (an L inside the pass line).
            let dpUp = r(0.075, 0.2, lc, 0.86), dpLow = r(lc, 0.72, 1, 0.86)
            stroke(dpUp)
            stroke(dpLow)
            label("DON'T PASS BAR", CGPoint(x: W * (lc + 0.02 + (1 - lc) * 0.06), y: dpLow.midY), size: 9)
            label("DON'T PASS", CGPoint(x: dpUp.midX, y: dpUp.midY), size: 8, rotate: -90)

            // Pass line around the outside.
            let pUp = r(0, 0.2, 0.075, 1), pLow = r(0.075, 0.86, 1, 1)
            stroke(pUp)
            stroke(pLow)
            label("PASS LINE", CGPoint(x: W * 0.17, y: pLow.midY), size: 10)
            label("PASS LINE", CGPoint(x: pUp.midX, y: pUp.midY), size: 8, rotate: -90)
        }
    }
}
