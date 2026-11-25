import SwiftUI

struct ContentView: View {
    @State private var show = Show()
    @State private var showRules = false
    @State private var confirmQuit = false
    @AppStorage(Sound.enabledKey) private var soundOn = true

    var body: some View {
        VStack(spacing: 0) {
            if show.screen != .title { topBar }
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            LinearGradient(colors: [navy, Color(red: 0.05, green: 0.12, blue: 0.20)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .environment(show)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRules) { RulesView() }
        .task { _ = Sound.shared }
        #if DEBUG
        .overlay { if UserDefaults.standard.bool(forKey: "debugKiss") { QueenKissView(demo: true) } }
        .onAppear { if UserDefaults.standard.bool(forKey: "debugCards") { show.debugCards() }; if UserDefaults.standard.bool(forKey: "debugBonus") { show.debugBonus() } }
        #endif        // synthesize the sound effects before they're needed
        .confirmationDialog("Quit this show and start over?", isPresented: $confirmQuit) {
            Button("New game", role: .destructive, action: newGame)
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 720)
        #endif
    }

    @ViewBuilder private var screen: some View {
        switch show.screen {
        case .title: TitleView()
        case .intro: IntroView()
        case .hunt: if let h = show.hunt { HuntView(hunt: h) }
        case .huntResults: HuntResultsView()
        case .cards: if let m = show.cards { MoneyCardsView(m: m) }
        case .pick: PickView()
        case .summary: SummaryView()
        case .eliminated: EliminatedView(newGame: newGame)
        case .finalIntro: FinalIntroView()
        case .bonus: if let b = show.bonus { BonusView(b: b) }
        case .finale: FinaleView(newGame: newGame)
        }
    }

    private var topBar: some View {
        HStack {
            Text("CARD SHARKS ISLAND").font(.headline.weight(.black)).foregroundStyle(gold)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("ON THE ISLAND").font(.caption2.bold()).foregroundStyle(.secondary)
                Text("\(show.alive.count) of 6").font(.headline.monospacedDigit()).foregroundStyle(gold)
            }
            Menu {
                Button("How to Play", systemImage: "questionmark.circle") { showRules = true }
                Toggle(isOn: $soundOn) { Label("Sound", systemImage: soundOn ? "speaker.wave.2" : "speaker.slash") }
                Button("New Game", systemImage: "arrow.counterclockwise") { confirmQuit = true }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title2)
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.black.opacity(0.3))
    }

    private func newGame() {
        show.quit()
        show = Show()
    }
}

#Preview {
    ContentView()
}
