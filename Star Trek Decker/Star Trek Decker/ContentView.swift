import SwiftUI

@Observable
final class AppModel {
    enum Screen: Equatable { case title, prologue, missions, mission(Int) }

    var screen: Screen = .title
    var unlocked: Int { didSet { UserDefaults.standard.set(unlocked, forKey: "unlocked") } }
    var completed: Set<Int> { didSet { UserDefaults.standard.set(Array(completed), forKey: "completed") } }
    var sawPrologue: Bool { didSet { UserDefaults.standard.set(sawPrologue, forKey: "sawPrologue") } }
    var soundOn: Bool { didSet { UserDefaults.standard.set(!soundOn, forKey: "muted"); Sound.shared.muted = !soundOn } }
    var voiceOn: Bool { didSet { UserDefaults.standard.set(!voiceOn, forKey: "voiceOff"); Sound.shared.voiceOn = voiceOn } }
    var level: Int { didSet { UserDefaults.standard.set(level, forKey: "level") } }
    /// Set when all three missions were just completed and reset at a harder level; the menu shows a banner.
    var leveledUp = false

    init() {
        let d = UserDefaults.standard
        unlocked = max(1, d.integer(forKey: "unlocked"))
        completed = Set(d.array(forKey: "completed") as? [Int] ?? [])
        sawPrologue = d.bool(forKey: "sawPrologue")
        soundOn = !d.bool(forKey: "muted")
        voiceOn = !d.bool(forKey: "voiceOff")
        level = max(1, d.integer(forKey: "level"))
        Sound.shared.muted = !soundOn
        Sound.shared.voiceOn = voiceOn
    }

    func finished(_ mission: Int, won: Bool) {
        if won {
            completed.insert(mission)
            unlocked = max(unlocked, min(3, mission + 1))
            // All three done: reset the missions one level harder.
            if completed.isSuperset(of: [1, 2, 3]) {
                level += 1
                completed = []
                unlocked = 1
                leveledUp = true
            }
        }
        screen = .missions
    }
}

/// Difficulty level: 1 the first time through; each time all three missions are completed they reset one level harder.
enum Difficulty {
    static var level: Int { max(1, UserDefaults.standard.integer(forKey: "level")) }
    /// Enemy damage / toughness multiplier: +20% per level.
    static var power: Double { 1 + 0.2 * Double(level - 1) }
    /// " · Level N" for mission titles once past the first time through.
    static var tag: String { level > 1 ? " · Level \(level)" : "" }
}

/// Screenshot hook (debug builds only): skip mission intro cutscenes.
var skipIntros: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("-noIntro")
    #else
    false
    #endif
}

struct ContentView: View {
    @State private var app: AppModel = {
        let a = AppModel()
        #if DEBUG
        // Screenshot hook: -screen 1|2|3|missions
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count {
            if let n = Int(args[i + 1]) { a.screen = .mission(n) } else if args[i + 1] == "missions" { a.screen = .missions } else if args[i + 1] == "prologue" { a.screen = .prologue }
        }
        #endif
        return a
    }()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch app.screen {
            case .title:
                TitleView(app: app)
            case .prologue:
                CutsceneView(shots: Story.prologue) {
                    app.sawPrologue = true
                    app.screen = .mission(1)
                }
            case .missions:
                MissionMenu(app: app)
            case .mission(1):
                Mission1View { won in app.finished(1, won: won) }
            case .mission(2):
                Mission2View { won in app.finished(2, won: won) }
            case .mission(3):
                Mission3View { won in app.finished(3, won: won) }
            case .mission:
                MissionMenu(app: app)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: app.screen)
    }
}

// MARK: - Title

struct TitleView: View {
    let app: AppModel

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    drawStarfield(ctx, size: size, t: t, speed: 0.6)
                    let s = min(size.width / 400, 1.6)
                    drawConstellation(ctx, at: CGPoint(x: size.width * 0.55, y: size.height * 0.42), scale: s * 1.1, t: t)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer().frame(height: 40)
                Text("STAR TREK")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(LCARS.peach)
                Text("DECKER")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(colors: [LCARS.gold, LCARS.orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: LCARS.orange.opacity(0.6), radius: 12)
                Text("U.S.S. CONSTELLATION · NCC-1017-A")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(LCARS.lilac)
                Spacer()
                VStack(spacing: 10) {
                    lcarsButton(app.sawPrologue ? "CONTINUE" : "BEGIN", LCARS.orange) {
                        app.screen = app.sawPrologue ? .missions : .prologue
                    }
                    if app.sawPrologue {
                        lcarsButton("REPLAY PROLOGUE", LCARS.lilac) { app.screen = .prologue }
                    }
                    HStack(spacing: 10) {
                        settingToggle("SOUND", on: app.soundOn) { app.soundOn.toggle() }
                        settingToggle("VOICES", on: app.voiceOn) { app.voiceOn.toggle() }
                    }
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

func lcarsButton(_ title: String, _ c: Color, action: @escaping () -> Void) -> some View {
    Button {
        Sound.shared.play(.beep)
        action()
    } label: {
        Text(title)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(c))
            .foregroundStyle(.black)
    }
}

private func settingToggle(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
            Text(title)
        }
        .font(.system(size: 13, weight: .heavy, design: .rounded))
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(Capsule().fill(on ? LCARS.blue : Color.white.opacity(0.15)))
        .foregroundStyle(on ? .black : .white)
    }
}

// MARK: - Mission menu

struct MissionMenu: View {
    let app: AppModel
    @State private var stardate = "32\(Int.random(in: 100...999)).\(Int.random(in: 0...9))"

    private let missions: [(n: Int, title: String, blurb: String, icon: String)] = [
        (1, "The Klingon Incursion", "A facelifted Star Trek Senior. Hunt every Klingon warship across an 8×8 galaxy — scans, warp vectors, phasers, torpedoes, shields, damage control and life support.", "scope"),
        (2, "The Doomsday Machine", "A planet killer with a neutronium hull. Take heavy damage, limp to a starbase, separate the saucer, find the disruptor ray — and stop the machine before it eats the Arcadia Colony.", "circle.hexagongrid.fill"),
        (3, "Resistance", "The Borg have assimilated the all-woman crew of the U.S.S. Halcyon. Chase the cube, outwit its adaptations, rescue the six women and destroy it.", "cube.fill"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Button { app.screen = .title } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .black))
                            .frame(width: 44, height: 32)
                            .background(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16).fill(LCARS.orange))
                    }
                    .foregroundStyle(.black)
                    Text("MISSION SELECT")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).frame(height: 32)
                        .background(UnevenRoundedRectangle(bottomTrailingRadius: 16, topTrailingRadius: 16).fill(LCARS.lilac))
                        .foregroundStyle(.black)
                }
                .padding(.top, 8)

                HStack {
                    Text("Captain Matt Decker · Stardate \(stardate)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(LCARS.peach)
                    Spacer()
                    Text("LEVEL \(app.level)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(app.level > 1 ? LCARS.red : LCARS.blue))
                        .foregroundStyle(.black)
                }

                if app.leveledUp {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALL MISSIONS COMPLETE")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LCARS.green)
                        Text("Starfleet Command has new orders, Captain. The missions begin again at Level \(app.level): more Klingons and less time, a tougher planet killer, and a faster, deadlier Borg cube.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        lcarsButton("ACKNOWLEDGED", LCARS.green) { app.leveledUp = false }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(LCARS.panel))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(LCARS.green, lineWidth: 1.5))
                }

                ForEach(missions, id: \.n) { m in
                    let open = m.n <= app.unlocked
                    Button {
                        guard open else { return }
                        Sound.shared.play(.chirp)
                        app.screen = .mission(m.n)
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle().fill(open ? missionColor(m.n) : Color.white.opacity(0.12))
                                Image(systemName: open ? m.icon : "lock.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(open ? .black : .white.opacity(0.5))
                            }
                            .frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("MISSION \(m.n)")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundStyle(missionColor(m.n))
                                    if app.completed.contains(m.n) {
                                        Text("COMPLETE")
                                            .font(.system(size: 9, weight: .black, design: .rounded))
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Capsule().fill(LCARS.green))
                                            .foregroundStyle(.black)
                                    }
                                }
                                Text(m.title)
                                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(open ? m.blurb : "Complete Mission \(m.n - 1) to unlock.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18).fill(LCARS.panel))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(missionColor(m.n).opacity(open ? 0.8 : 0.25), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                lcarsButton("REPLAY PROLOGUE", LCARS.tan) { app.screen = .prologue }
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func missionColor(_ n: Int) -> Color {
        [LCARS.orange, LCARS.lilac, LCARS.green][max(0, min(2, n - 1))]
    }
}
