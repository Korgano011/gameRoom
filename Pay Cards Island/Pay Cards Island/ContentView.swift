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
            LinearGradient(colors: [navy, Color(red: 0.02, green: 0.30, blue: 0.38)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .environment(show)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRules) { RulesView() }
        .task { _ = Sound.shared }        // synthesize the sound effects before they're needed
        .confirmationDialog("Quit this show and start over?", isPresented: $confirmQuit) {
            Button("New game", role: .destructive, action: newGame)
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 700)
        #endif
    }

    @ViewBuilder private var screen: some View {
        switch show.screen {
        case .title: TitleView()
        case .intro: IntroView()
        case .hunt: if let h = show.hunt { HuntView(hunt: h) }
        case .huntResults: HuntResultsView()
        case .payCards: if let pc = show.payCards { PayCardsView(pc: pc) }
        case .bonus: if let b = show.bonus { BonusView(b: b) }
        case .pick: PickView()
        case .summary: SummaryView()
        case .eliminated: EliminatedView(newGame: newGame)
        case .final: if let f = show.final { FinalView(f: f) }
        case .finale: FinaleView(newGame: newGame)
        }
    }

    private var topBar: some View {
        HStack {
            Text("PAY CARDS ISLAND").font(.headline.weight(.black)).foregroundStyle(gold)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("FINAL JACKPOT").font(.caption2.bold()).foregroundStyle(.secondary)
                Text(money(show.jackpot)).font(.headline.monospacedDigit()).foregroundStyle(gold)
                    .contentTransition(.numericText())
                    .animation(.default, value: show.jackpot)
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
