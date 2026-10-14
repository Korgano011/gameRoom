import SwiftUI

struct ContentView: View {
    @State private var director = Director()
    @State private var showShop = false

    var body: some View {
        ZStack {
            switch director.mode {
            case .title:
                TitleView(director: director)
            case .story:
                StoryView(director: director)
            case .poker:
                if let session = director.poker {
                    VideoPokerView(session: session,
                                   onInsertCredits: { director.startPoker() },
                                   onLeave: { director.goToTitle() })
                }
            case .holdem:
                if let table = director.table {
                    HoldemView(table: table, day: director.dayLabel,
                               felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2),
                               goldChips: director.save.has(.clayChips))
                }
            case .blackjack:
                if let t = director.blackjack {
                    BlackjackView(table: t, day: director.dayLabel,
                                  felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2),
                                  goldChips: director.save.has(.clayChips))
                }
            case .paigow:
                if let t = director.paigow {
                    PaiGowView(table: t, day: director.dayLabel,
                               felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2),
                               goldChips: director.save.has(.clayChips))
                }
            case .craps:
                if let t = director.craps {
                    CrapsView(table: t, day: director.dayLabel,
                              felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2),
                              goldChips: director.save.has(.clayChips))
                }
            case .banked:
                if let t = director.banked {
                    BankedView(table: t, day: director.dayLabel,
                               felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2),
                               goldChips: director.save.has(.clayChips))
                }
            case .tricks:
                if let t = director.tricks {
                    TrickView(table: t, day: director.dayLabel,
                              felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .hearts:
                if let hearts = director.hearts {
                    HeartsView(table: hearts, day: director.dayLabel,
                               felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .nines:
                if let nines = director.nines {
                    NinesView(table: nines, day: director.dayLabel,
                              felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .ohHell:
                if let t = director.ohHell {
                    OhHellView(table: t, day: director.dayLabel,
                               felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .californiaJack:
                if let t = director.californiaJack {
                    CaliforniaJackView(table: t, day: director.dayLabel,
                                       felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .pedro:
                if let pedro = director.pedro {
                    PedroView(table: pedro, day: director.dayLabel,
                              felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .pisti:
                if let pisti = director.pisti {
                    PistiView(table: pisti, day: director.dayLabel,
                              felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .big2:
                if let big2 = director.big2 {
                    Big2View(table: big2, day: director.dayLabel,
                             felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .ninetyNine:
                if let t = director.ninetyNine {
                    NinetyNineView(table: t, day: director.dayLabel,
                                   felt: director.save.has(.velvetFelt) ? Color(red: 0.4, green: 0.1, blue: 0.5) : Color(red: 0.05, green: 0.45, blue: 0.2))
                }
            case .summary:
                SummaryView(director: director, showShop: $showShop)
            }
        }
        .overlay(alignment: .topTrailing) {
            if director.mode != .title {
                Button {
                    director.muted.toggle()
                } label: {
                    Image(systemName: director.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .padding(8)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
        .sheet(isPresented: $showShop) {
            ShopView(save: $director.save) { director.buy($0) }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TitleView: View {
    let director: Director
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PrincessFace(talking: false)
                    .frame(width: 200, height: 200)
                    .background(Circle().fill(RadialGradient(colors: [.pink, .purple], center: .center, startRadius: 10, endRadius: 120)))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 5))
                    .padding(.top, 30)

                Text("Princess of Poker")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .pink], startPoint: .top, endPoint: .bottom))
                    .multilineTextAlignment(.center)
                Text("Nine video poker games, 25 hands each, 200 credits. Play the max bet of 5 every hand to reach game 10 — the endless game.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    Button {
                        director.startShift()
                    } label: {
                        Label("Start Your Shift", systemImage: "cart.fill")
                            .frame(maxWidth: 320, minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    if director.save.reachedSalon {
                        if director.nextNightPicksVenue {
                            VenuePicker(director: director)
                        }
                        if director.nextNightPicksVenue || (director.afternoonPending && director.save.night != 1) {
                            GamePicker(director: director)
                        }
                        Button {
                            director.continueSalon()
                        } label: {
                            Label(director.afternoonPending ? "Return to the Salon — Day \(director.save.night) afternoon"
                                                            : "Return to the Salon — Day \(director.save.night + 1)", systemImage: "sparkles")
                                .frame(maxWidth: 320, minHeight: 34)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        Text("Cash box $\(director.save.cash) · Bank $\(director.save.bank) · Revenue so far $\(director.save.totalProfit)")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Button("Reset salon progress", role: .destructive) { confirmReset = true }
                            .font(.footnote)
                    }
                }
                .font(.system(.headline, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)
        }
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.03, blue: 0.3), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .confirmationDialog("Erase the salon, its cash, bank and enhancements?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { director.resetSalon() }
        }
    }
}

private struct StoryView: View {
    let director: Director

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    drawStage(ctx, size: size, director: director, now: tl.date)
                }
            }
            .aspectRatio(Stage.W / Stage.H, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)

            Text(director.caption)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 60)
                .padding(.horizontal)
                .animation(.default, value: director.caption)

            if director.canFastForward {
                Button("Fast-forward", systemImage: "forward.fill") { director.fastForward() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
            if director.skippable {
                Button("Skip to the machine") { director.skipIntro() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
            Spacer(minLength: 0)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private struct SummaryView: View {
    let director: Director
    @Binding var showShop: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let r = director.nightResult {
                    Text(director.afternoonPending ? "Day \(r.night) — the morning game is over"
                         : r.night == 1 ? "Day 1 is over" : "Day \(r.night) — both games are over")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                        .padding(.top, 30)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(r.departures) { d in
                            HStack(alignment: .top) {
                                Image(systemName: d.takeaway >= HoldemTable.buyIn ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundStyle(d.takeaway >= HoldemTable.buyIn ? .orange : .green)
                                VStack(alignment: .leading) {
                                    Text("\(d.name) \(d.reason)")
                                        .font(.system(.headline, design: .rounded))
                                    Text(r.isForFun
                                         ? (d.isKid ? "Went home to Mom still a girl — changed back into \(d.wasName) an hour later."
                                                    : "Stepped out of the salon and changed back into \(d.wasName) over 30 seconds.")
                                         : (d.isKid ? "Went home to Mom still a girl, with $\(d.takeaway) — changed back into \(d.wasName) an hour later."
                                                    : "Stepped out of the salon with $\(d.takeaway) and changed back into \(d.wasName) over 30 seconds."))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }
                        if r.departures.isEmpty {
                            Text("Nobody played this game.")
                        }
                        Divider().overlay(.white.opacity(0.3))
                        if r.isForFun {
                            row("You finished \(r.funGame) with", r.funGame == "99" ? "\(r.yourStack) token\(r.yourStack == 1 ? "" : "s")" : "\(r.yourStack) points")
                            row("Revenue this game", "$0 — just for fun", color: .pink)
                        } else {
                            row("You finished with", "$\(r.yourStack)")
                            row("You won", money(r.yourWinnings), color: r.yourWinnings >= 0 ? .green : .red)
                            row("The Princess won", money(r.princessWinnings), color: r.princessWinnings >= 0 ? .green : .red)
                            row("Revenue this game", money(r.profit), color: r.profit >= 0 ? .green : .red)
                        }
                        row("Cash box", "$\(director.save.cash)")
                        row("Bank", "$\(director.save.bank)")
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 520)

                    if director.nextNightPicksVenue {
                        VenuePicker(director: director)
                    }
                    if director.nextNightPicksVenue || (director.afternoonPending && r.night != 1) {
                        GamePicker(director: director)
                    }
                    VStack(spacing: 10) {
                        Button {
                            director.nextNight()
                        } label: {
                            Label(director.afternoonPending ? "Afternoon game" : r.errandNext ? "Beam down for groceries & the bank" : "Next day",
                                  systemImage: director.afternoonPending ? "sun.max.fill" : r.errandNext ? "cart.fill" : "sunrise.fill")
                                .frame(maxWidth: 320, minHeight: 34)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        Button {
                            showShop = true
                        } label: {
                            Label("Shop for salon & table enhancements", systemImage: "bag.fill")
                                .frame(maxWidth: 320, minHeight: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        Button("Back to title") { director.goToTitle() }
                            .font(.footnote)
                            .tint(.white.opacity(0.7))
                    }
                    .font(.system(.headline, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(LinearGradient(colors: [Color(red: 0.3, green: 0.05, blue: 0.3), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private func money(_ v: Int) -> String { (v < 0 ? "-$" : "$") + "\(abs(v))" }

    private func row(_ title: String, _ value: String, color: Color = .yellow) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(color).monospacedDigit()
        }
        .font(.system(.headline, design: .rounded))
    }
}

/// Choose where the flying salon travels for the next day.
private struct VenuePicker: View {
    @Bindable var director: Director

    var body: some View {
        let selected = director.chosenVenue ?? Venue.forNight(director.save.night + 1)
        VStack(spacing: 8) {
            Text("Where should the salon fly next?")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.yellow)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(Venue.allCases, id: \.self) { v in
                    Button {
                        director.chosenVenue = v
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: v.icon).font(.title3)
                            Text(v.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(v == selected ? .black : .white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(v == selected ? Color.yellow : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 520)
        .onAppear { if director.chosenVenue == nil { director.chosenVenue = selected } }
    }
}

/// Choose which game the salon's table plays next: the money makers in one box, the just-for-fun games in another.
private struct GamePicker: View {
    @Bindable var director: Director

    var body: some View {
        let selected = director.chosenGame ?? director.nextGameDefault
        VStack(spacing: 10) {
            Text("Which game should the table play?")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.yellow)
            box("Money makers", systemImage: "dollarsign.circle.fill",
                games: HoldemTable.Game.allCases.filter { !$0.isForFun }, selected: selected)
            box("Just for fun · no money", systemImage: "heart.circle.fill",
                games: HoldemTable.Game.allCases.filter(\.isForFun), selected: selected)
        }
        .frame(maxWidth: 520)
    }

    private func box(_ title: String, systemImage: String, games: [HoldemTable.Game], selected: HoldemTable.Game) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(games, id: \.self) { g in
                    Button {
                        director.chosenGame = g
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: g.icon).font(.title3)
                            Text(g.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(g == selected ? .black : .white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(g == selected ? Color.yellow : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}
