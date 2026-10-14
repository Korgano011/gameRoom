import SwiftUI

struct NightResult {
    let night: Int
    let departures: [HoldemTable.Departure]
    let profit: Int
    let yourWinnings: Int
    let princessWinnings: Int
    let yourStack: Int
    let errandNext: Bool
    /// A hearts, nines, pedro or pişti night: played just for fun, so no money changes hands.
    var isForFun = false
    /// "hearts", "nines", "pedro" or "pişti" on a for-fun night.
    var funGame = ""
}

@Observable final class Director {
    enum Mode { case title, story, poker, holdem, blackjack, paigow, craps, banked, hearts, nines, pedro, pisti, big2, ninetyNine, ohHell, californiaJack, tricks, summary }

    var mode = Mode.title
    var place = Place.targetLot
    var caption = ""
    var people: [Person] = []
    var you: Person
    let princess: Person
    var camera = Camera()
    var puffs: [Puff] = []
    var perfume: PerfumeBlast?
    /// Perfume arms lowered from the salon ceiling, one per new girl.
    var sprays: [PerfumeBlast] = []
    var retractMirror = RetractMirror()
    var casinoEmpty = false
    var pushingCarts = 0
    var corralCarts = 0
    var beam: Beam?
    var ship = SalonShip()
    var shipShown = false
    var shipScale = 0.9
    var shipSays: String?
    var shipSaysUntil = Date.distantPast
    var machineOnUntil = Date.distantPast
    var buttonPressT0 = Date.distantPast
    var poker: VideoPokerSession?
    var table: HoldemTable?
    var blackjack: BlackjackTable?
    var paigow: PaiGowTable?
    var craps: CrapsTable?
    /// Three card poker, let it ride or red dog.
    var banked: BankedTable?
    /// Credits left on the Princess of Poker's machine when you reached game 10; they go to the house as dollars.
    private var leftoverCredits = 0
    var hearts: HeartsTable?
    var nines: NinesTable?
    var ohHell: OhHellTable?
    var californiaJack: CaliforniaJackTable?
    var pedro: PedroTable?
    var pisti: PistiTable?
    var big2: Big2Table?
    var ninetyNine: NinetyNineTable?
    /// Pepper, spades or domino hearts.
    var tricks: TrickTable?
    /// The game you've picked for the next night (from night 3 on).
    var chosenGame: HoldemTable.Game?
    /// Tonight's game at the salon's table.
    private(set) var tonightGame = HoldemTable.Game.texas

    /// Each day has a morning game and an afternoon game (day 1, the co-workers', has just one); then you rest.
    enum Session {
        case morning, afternoon
        var name: String { self == .morning ? "morning" : "afternoon" }
    }
    private(set) var session = Session.morning
    /// The morning game is over and the afternoon game is next, at the same stop.
    private(set) var afternoonPending = false
    private var morningGame = HoldemTable.Game.texas
    /// "Day 3 · Morning", for the table headers.
    var dayLabel: String { save.night == 1 ? "Day 1" : "Day \(save.night) · \(session.name.capitalized)" }
    /// The game the picker suggests for the next session.
    var nextGameDefault: HoldemTable.Game {
        afternoonPending ? morningGame.afternoon(day: save.night) : .forNight(save.night + 1)
    }
    /// Groceries and the bank come after the last game of every second day.
    private var errandAfter: Bool { save.night % 2 == 0 && session == .afternoon }
    var nightResult: NightResult?
    var save = SaveData.load()
    var muted = false { didSet { sound.muted = muted } }
    /// The intro shift can be skipped straight to the machine.
    var skippable = false
    /// Tonight's stop on the flying salon's tour.
    var venue = Venue.mainStreet
    /// Where you've chosen to fly the salon next (from night 3 on).
    var chosenVenue: Venue?
    /// Day 1 is the co-workers' day and day 2 Main Street; after that you pick the stop for each new day.
    var nextNightPicksVenue: Bool { !afternoonPending && save.night + 1 >= 3 }
    /// The co-workers see your picture next to the Princess's on the machine.
    var casinoSecondGirl = false
    var lightsOut = 0.0
    /// The kid's five-minute change back can be fast-forwarded.
    var canFastForward = false
    private var fastForwardAsked = false
    /// Tonight's newcomers, kept so the kids can be followed home.
    private var tonight: [Person] = []
    /// The two co-workers at the time clock when Larry punches out; they come looking for him that evening.
    private var workCrew: [Person] = []
    /// The clock on the wall at a kid's home: minutes after midnight, running at `clockRate` per second.
    private var clockBase = 21.0 * 60
    private var clockT0: Date?
    private var clockRate = 0.0

    func clockMinutes(at now: Date) -> Double {
        clockBase + (clockT0.map { now.timeIntervalSince($0) } ?? 0) * clockRate
    }

    func fastForward() { fastForwardAsked = true }

    private var scrollBase = 0.0
    private var scrollT0: Date?
    private var scrollSpeed = 0.0
    private var task: Task<Void, Never>?
    private var tableTask: Task<Void, Never>?
    let sound = Sound()

    init() {
        you = Director.makeYou(girl: false)
        princess = Person("Princess", height: 206, skin: .princessSkin,
                          guy: GuyLook(hair: .brown, shirt: .gray, pants: .gray), girl: .princess, isGirl: true, x: 860)
    }

    // MARK: Cast

    static func makeYou(girl: Bool) -> Person {
        let p = Person(girl ? "Lavender" : "Larry", height: 200, skin: Color(red: 0.96, green: 0.8, blue: 0.66),
                       guy: GuyLook(hair: Color(red: 0.35, green: 0.22, blue: 0.12), shirt: Color(red: 0.8, green: 0.05, blue: 0.1),
                                    pants: Color(red: 0.76, green: 0.66, blue: 0.48), nameTag: true),
                       girl: .lavender,   // thick lavender curls, lavender lipstick and a matching lavender dress
                       isGirl: girl, x: 500)
        p.wasName = "Larry"
        p.girlName = "Lavender"
        p.hairName = "lavender"
        return p
    }

    private static let skins: [Color] = [Color(red: 0.98, green: 0.85, blue: 0.75), Color(red: 0.92, green: 0.74, blue: 0.6),
                                         Color(red: 0.78, green: 0.58, blue: 0.42), Color(red: 0.55, green: 0.38, blue: 0.26),
                                         Color(red: 0.4, green: 0.27, blue: 0.18)]
    private static let manNames: [(String, String)] = [("Mike", "Michelle"), ("Dan", "Danielle"), ("Joe", "Josephine"), ("Tony", "Toni"),
                                                       ("Chris", "Christina"), ("Bobby", "Roberta"), ("Frank", "Frances"), ("Pat", "Patricia"),
                                                       ("Steve", "Stephanie"), ("Paul", "Paula"), ("Eric", "Erica"), ("Carl", "Carla"),
                                                       ("Ken", "Kendra"), ("Ron", "Veronica"), ("Gary", "Gabby"), ("Nick", "Nicole")]
    private static let boyNames: [(String, String)] = [("Tommy", "Tammy"), ("Billy", "Billie"), ("Danny", "Dani"), ("Joey", "Jo"),
                                                       ("Andy", "Andrea"), ("Sam", "Samantha"), ("Alex", "Alexa"), ("Charlie", "Charlotte")]
    private static let shirts: [Color] = [.blue, .green, .orange, .teal, .indigo, .brown, Color(red: 0.5, green: 0.5, blue: 0.55), .cyan, .mint]
    private static let pants: [Color] = [Color(red: 0.2, green: 0.25, blue: 0.45), Color(red: 0.25, green: 0.25, blue: 0.25),
                                         Color(red: 0.76, green: 0.66, blue: 0.48), Color(red: 0.35, green: 0.3, blue: 0.25)]
    private static let naturalHair: [Color] = [Color(red: 0.15, green: 0.1, blue: 0.05), Color(red: 0.4, green: 0.25, blue: 0.1),
                                               Color(red: 0.75, green: 0.6, blue: 0.3), Color(red: 0.55, green: 0.55, blue: 0.55), Color(red: 0.6, green: 0.2, blue: 0.05)]

    private func makePasserby(kid: Bool, taken: Set<String>) -> Person {
        let pool = (kid ? Self.boyNames : Self.manNames).filter { !taken.contains($0.0) }
        let names = pool.randomElement() ?? (kid ? Self.boyNames : Self.manNames).randomElement()!
        let hair = GirlLook.hairColors.randomElement()!
        // Most passersby are light-skinned: 3 in 4 get one of the two lightest tones.
        let skin = Double.random(in: 0..<1) < 0.75 ? Self.skins[Int.random(in: 0...1)] : Self.skins[Int.random(in: 2...4)]
        let p = Person(names.0, height: kid ? 135 : Double.random(in: 188...210), kid: kid, skin: skin,
                       guy: GuyLook(hair: Self.naturalHair.randomElement()!, shirt: Self.shirts.randomElement()!, pants: Self.pants.randomElement()!),
                       girl: .changed(hair: hair.1, lips: GirlLook.lipColors.randomElement()!), isGirl: false, x: -100)
        p.wasName = names.0
        p.hairName = hair.0
        p.girlName = names.1
        return p
    }

    // MARK: Running scenes

    private func run(_ body: @escaping () async throws -> Void) {
        task?.cancel()
        task = Task { [weak self] in
            do { try await body() } catch {}
            if Task.isCancelled { self?.sound.stopAll() }
        }
    }

    private func wait(_ s: Double) async throws {
        try await Task.sleep(for: .seconds(s))
    }

    @discardableResult
    private func say(_ p: Person, _ text: String, _ voice: Voice) -> Double {
        let d = max(2.2, Double(text.count) * 0.09 + 1.0)
        p.say(text, for: d)
        sound.speak(text, as: voice)
        return d
    }

    private func talk(_ p: Person, _ text: String, _ voice: Voice) async throws {
        try await wait(say(p, text, voice))
    }

    private func voice(for p: Person) -> Voice {
        if p === princess { return .princess }
        if p.isGirl { return p.isKid ? .kidGirl : .girl }
        return p.isKid ? .boy : .guy
    }

    private func shipSay(_ text: String) async throws {
        let d = max(2.4, Double(text.count) * 0.09 + 1.0)
        shipSays = text
        shipSaysUntil = .now + d
        sound.speak(text, as: .princess)
        try await wait(d)
    }

    private func shoot(_ c: CGPoint, zoom: Double, over s: Double) {
        let now = Date.now
        camera.from = camera.shot(at: now)
        camera.to = (c, zoom)
        camera.t0 = now
        camera.dur = s
    }

    private func resetCamera() {
        camera = Camera()
    }

    func streetOffset(at now: Date) -> Double {
        scrollBase + (scrollT0.map { now.timeIntervalSince($0) } ?? 0) * scrollSpeed
    }

    private func startScroll(speed: Double) {
        scrollBase = streetOffset(at: .now)
        scrollT0 = .now
        scrollSpeed = speed
    }

    private func stopScroll() {
        scrollBase = streetOffset(at: .now)
        scrollT0 = nil
    }


    private func pressButton() async throws {
        princess.reachTo = CGPoint(x: SalonSpot.button.x, y: SalonSpot.button.y - 14)
        try await wait(0.5)
        buttonPressT0 = .now
        sound.beep()
        try await wait(0.6)
        princess.reachTo = nil
    }

    private func clearScene() {
        people = []
        you.seated = false
        you.reachTo = nil
        you.lean(to: 0, over: 0)
        puffs = []
        perfume = nil
        sprays = []
        retractMirror = RetractMirror()
        beam = nil
        shipShown = false
        shipSays = nil
        casinoEmpty = false
        casinoSecondGirl = false
        lightsOut = 0
        canFastForward = false
        pushingCarts = 0
        corralCarts = 0
        machineOnUntil = .distantPast
        scrollT0 = nil
        resetCamera()
        sound.stopAll()
    }

    private var beamFactor: Double { save.has(.turboBeam) ? 0.5 : 1 }

    // MARK: Title

    func goToTitle() {
        task?.cancel()
        tableTask?.cancel()
        table?.abandon()
        table = nil
        blackjack?.abandon()
        blackjack = nil
        paigow?.abandon()
        paigow = nil
        craps?.abandon()
        craps = nil
        banked?.abandon()
        banked = nil
        tricks?.abandon()
        tricks = nil
        hearts?.abandon()
        hearts = nil
        nines?.abandon()
        nines = nil
        ohHell?.abandon()
        ohHell = nil
        californiaJack?.abandon()
        californiaJack = nil
        pedro?.abandon()
        pedro = nil
        pisti?.abandon()
        pisti = nil
        big2?.abandon()
        big2 = nil
        ninetyNine?.abandon()
        ninetyNine = nil
        poker = nil
        clearScene()
        mode = .title
    }

    func resetSalon() {
        SaveData.erase()
        save = SaveData()
        afternoonPending = false
    }

    // MARK: The shift and the casino

    func startShift() {
        sound.prepare()
        run { [weak self] in try await self?.shift() }
    }

    private func shift() async throws {
        clearScene()
        mode = .story
        skippable = true
        place = .targetLot
        you = Self.makeYou(girl: false)
        people = [you]
        you.place(x: 900)
        pushingCarts = 5
        corralCarts = 3
        caption = "You're Larry, a cart attendant at Target. One last row of carts before the end of your shift…"
        you.walk(to: 430, speed: 70)
        try await wait(6.9)
        pushingCarts = 0
        corralCarts = 8
        sound.clunk()
        caption = "The carts are in the corral."
        try await wait(1)
        try await talk(you, "End of my shift! Time to punch out.", .guy)
        // Over to the time clock by the store doors, where two co-workers are clocking out too.
        workCrew = []
        for _ in 0..<2 { workCrew.append(makeCoworker(taken: Set(workCrew.map(\.wasName)))) }
        for (i, p) in workCrew.enumerated() {
            p.place(x: 1080 + Double(i) * 90)
            p.walk(to: 760 + Double(i) * 90, speed: 110)
        }
        people = workCrew + [you]
        caption = "Larry heads to the time clock to punch out."
        you.walk(to: TargetSpot.clock.x - 42, speed: 110)
        try await wait(max(3.2, you.moveDur + 0.2))
        you.reachTo = TargetSpot.clock
        try await wait(0.5)
        sound.beep()
        caption = "Clunk! Larry punches out."
        try await wait(0.8)
        you.reachTo = nil
        try await wait(0.4)
        try await talk(you, "I'm going to sneak in a few games with the princess.", .guy)
        try await talk(workCrew[0], "Save your money. I don't think game 10 even exists.", .guy)
        try await talk(you, "Yes it does. One guy in Atlantic City got to it twice.", .guy)
        try await talk(workCrew[1], "Suit yourself, Larry.", .guy)
        you.walk(to: 1100, speed: 150)
        try await wait(3.4)

        place = .casinoOutside
        people = [you]
        you.place(x: -60)
        you.walk(to: 500, speed: 150)
        caption = "After every shift, Larry sneaks over to the Princess Palace Casino."
        try await wait(4)
        you.visible = false
        try await wait(0.6)

        place = .casino
        let extras = (0..<4).map { i in
            let p = makePasserby(kid: false, taken: [])
            p.height = 175
            p.place(x: [110.0, 270, 730, 890][i])
            return p
        }
        people = extras + [you]
        you.visible = true
        you.place(x: -60)
        you.walk(to: 500, speed: 150)
        caption = "You sit down at the Princess of Poker's machine."
        try await wait(4.4)
        startPoker()
    }

    func skipIntro() {
        guard skippable else { return }
        task?.cancel()
        clearScene()
        startPoker()
    }

    func startPoker() {
        sound.prepare()
        skippable = false
        let s = VideoPokerSession(sound: sound)
        s.onEnd = { [weak self] ending in
            if ending == .qualified {
                self?.leftoverCredits = self?.poker?.credits ?? 0
                self?.run { [weak self] in try await self?.gameTen() }
            } else if ending == .cashedOut || ending == .notMaxBet {
                let credits = self?.poker?.credits ?? 0
                self?.run { [weak self] in try await self?.cashedOut(credits: credits, auto: ending == .notMaxBet) }
            }
        }
        poker = s
        mode = .poker
        s.begin()
    }

    /// Larry cashes out early (or the machine cashes him out when he doesn't qualify for game 10) and heads home.
    private func cashedOut(credits: Int, auto: Bool) async throws {
        try await wait(auto ? 7.5 : 3.5)
        poker = nil
        clearScene()
        mode = .story
        place = .casino
        let extras = (0..<4).map { i in
            let p = makePasserby(kid: false, taken: [])
            p.height = 175
            p.place(x: [110.0, 270, 730, 890][i])
            return p
        }
        you = Self.makeYou(girl: false)
        you.place(x: 500)
        people = extras + [you]
        caption = auto ? "The machine cashes Larry out automatically: \(credits) credits."
                       : "Larry cashes out early with \(credits) credits."
        for _ in 0..<4 {
            sound.coin()
            try await wait(0.35)
        }
        try await wait(1)
        try await talk(you, "So long Princess. Tomorrow's another day.", .guy)
        you.walk(to: 1120, speed: 140)
        caption = "Larry heads home for the night."
        try await wait(4.6)
        goToTitle()
    }

    // MARK: Game 10

    private func gameTen() async throws {
        try await wait(7.5)
        poker = nil
        clearScene()
        mode = .story
        place = .casino
        casinoEmpty = false
        you = Self.makeYou(girl: false)
        people = [you]
        you.place(x: 500)
        you.mood = .happy
        caption = "Game 10! Larry made it!"
        try await wait(1.2)
        try await talk(you, "I beat you. Ha ha ha. I beat you.", .guy)
        casinoEmpty = true
        you.mood = .worried
        caption = "Suddenly the lights drop by half…"
        try await wait(3.2)

        caption = "…then powder puffs come flying out!"
        let face = you.face(at: .now)
        shoot(face, zoom: 2.1, over: 1.5)
        try await wait(1.6)
        you.mood = .shocked
        let pastel: [Color] = [Color(red: 1, green: 0.75, blue: 0.85), Color(red: 1, green: 0.9, blue: 0.95), Color(red: 0.95, green: 0.8, blue: 1)]
        for k in 1...5 {
            let side = k % 2 == 0 ? -1.0 : 1.0
            let from = CGPoint(x: face.x + side * 330, y: face.y + Double.random(in: -180...120))
            let target = CGPoint(x: face.x + side * 20, y: face.y + Double.random(in: -12...14))
            puffs.append(Puff(from: from, target: target, away: CGPoint(x: face.x + side * 360, y: face.y - 220),
                              t0: .now, color: pastel.randomElement()!))
            try await wait(0.7)
            sound.puff()
            you.powder = Double(k) / 5
            caption = "Pat! Puff number \(k)…"
            try await wait(0.55)
        }
        caption = "Five puffs! He's covered in powder."
        try await wait(1.4)
        puffs.removeAll()

        caption = "A perfume nozzle swings out of the machine…"
        let nozzle = CGPoint(x: face.x + 130, y: face.y - 10)
        perfume = PerfumeBlast(cabinet: CGPoint(x: 560, y: face.y + 60), nozzle: nozzle, target: face,
                               t0: Date.now.addingTimeInterval(1.2), dur: 10)
        try await wait(1.2)
        sound.perfume(true)
        caption = "Pssssht! A blast of perfume!"
        try await wait(3.5)
        caption = "It keeps on spraying… he's drenched in it!"
        try await wait(3.5)
        caption = "He smells like a flower shop!"
        try await wait(3)
        sound.perfume(false)
        caption = "Ten seconds of perfume!"
        try await wait(1.4)
        perfume = nil
        shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 0.8)
        try await wait(0.8)
        you.mood = .scared
        you.running = true
        you.walk(to: 1120, speed: 320)
        caption = "He runs out of the casino!"
        try await wait(2)

        place = .casinoOutside
        casinoEmpty = false
        you.place(x: 500)
        you.walk(to: 650, speed: 300)
        try await wait(0.6)
        you.running = false
        you.handsToFace = true
        you.powderOffT0 = .now
        you.powderOffDur = 3
        caption = "He brushes off the powder…"
        try await wait(3.3)
        you.handsToFace = false
        you.powder = 0
        you.powderOffT0 = .distantFuture
        you.mood = .scared
        caption = "…then starts running home, scared."
        you.running = true
        you.walk(to: 1120, speed: 300)
        try await wait(1.7)

        place = .street
        you.place(x: 330)
        you.jogging = true
        startScroll(speed: 260)
        try await wait(3.5)
        ship = SalonShip(x: 720, y0: -320, y1: -320)
        shipScale = 0.85
        shipShown = true
        ship.move(to: Stage.ground, over: 3.5)
        sound.hum(true)
        caption = "Suddenly, a flying beauty salon lands in front of him!"
        try await wait(1.6)
        stopScroll()
        you.jogging = false
        you.running = false
        you.mood = .shocked
        try await wait(1.9)
        ship.flying = false
        sound.hum(false)
        sound.clunk()
        try await wait(1)
        ship.doorOpen = true
        try await wait(0.5)
        caption = "…and pulls him inside!"
        say(you, "Whoa!", .guy)
        sound.beam(true)
        you.walk(to: ship.x, speed: 170)
        try await wait(2.3)
        you.visible = false
        ship.doorOpen = false
        sound.beam(false)
        sound.clunk()
        try await wait(1.2)

        // Inside the salon
        shipShown = false
        place = .salon
        people = [you]
        you.visible = true
        you.place(x: SalonSpot.chairX[1])
        you.mood = .shocked
        sound.clunk()
        you.strapped = true
        caption = "He is strapped to a chair."
        try await wait(1.3)
        try await talk(you, "Oh my gosh!", .guy)
        princess.place(x: 1060)
        princess.visible = true
        princess.mood = .happy
        princess.reachTo = nil
        people.append(princess)
        princess.walk(to: 690, speed: 120)
        caption = "Then she comes in…"
        try await wait(3.2)
        try await talk(princess, "Welcome, Larry. I am the Princess of Poker. Here comes the final game.", .princess)
        // Whatever credits were left on her machine go to the house, a dollar a credit.
        let left = leftoverCredits
        leftoverCredits = 0
        if left > 0 {
            save.cash += left
            save.store()
            sound.coin()
            caption = "Your \(left) leftover credits go to the house: $\(left) in the salon's cash box."
            try await talk(princess, "And the \(left) credits you had left on my machine? They go to the house. That's \(left) dollars, honey.", .princess)
        }
        caption = "She slowly walks to press the yellow button…"
        princess.walk(to: 822, speed: 30)
        try await talk(you, "Let me out of here. Let me out of here.", .guy)
        try await wait(max(0.3, princess.moveDur - 3.6))
        try await pressButton()
        machineOnUntil = .now + 19.6
        sound.zap(true)
        you.changeToGirl(body: 8.9, face: 10)
        caption = "The machine starts turning him into a girl, starting with the feet…"
        try await wait(4)
        caption = "…up through a sparkling lavender dress…"
        try await wait(4.4)
        // Close-up as the line reaches his face: the guy's face morphs into a girl's.
        shoot(you.face(at: .now), zoom: 3.6, over: 0.8)
        caption = "…to thick lavender curls and lavender lipstick to match."
        try await talkOver(10.9, [
            (you, "My face! What's happening to my face?!", .guy),
            (princess, "Hold still, honey. Here come your lavender curls.", .princess),
            (you, "Is that… lavender lipstick?!", .girl)])
        sound.zap(false)
        sound.chime()
        try await wait(1)
        shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 1)
        try await wait(1)
        caption = "The transformation is complete."
        try await talk(princess, "All done, honey! Go look in the mirror.", .princess)
        you.strapped = false
        sound.clunk()
        caption = "She gets up and walks over to the mirror on the wall…"
        you.walk(to: SalonSpot.mirrorStand, speed: 90)
        try await wait(max(1.2, you.moveDur + 0.4))
        try await mirrorCloseUp()
        caption = ""
        try await talk(you, "You turned me into a girl!", .girl)
        shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 1)
        you.mood = .happy
        try await talk(princess, "Larry is gone, honey. From now on, your name is Lavender.", .princess)
        you.name = "Lavender"
        caption = "Larry is now Lavender."
        try await talk(you, "Lavender… I love it!", .girl)
        caption = ""
        try await talk(princess, "Our games are girls card games, played on a table in a separate room.", .princess)
        try await talk(princess, "Each day we will ask men as they come by if they want to play a girls poker game with us.", .princess)
        try await talk(princess, "If they accept, we beam them up and tell them this is a girls poker game. Then I surprise them by turning them into girls.", .princess)
        you.strapped = false
        save.reachedSalon = true
        save.store()
        try await wait(1.5)
        afternoonPending = false
        try await nextSession()
    }

    // MARK: Nights at the salon

    func continueSalon() {
        sound.prepare()
        you = Self.makeYou(girl: true)
        run { [weak self] in try await self?.nextSession() }
    }

    func nextNight() {
        let errand = nightResult?.errandNext ?? false
        nightResult = nil
        run { [weak self] in
            guard let self else { return }
            if errand { try await self.errand() }
            try await self.nextSession()
        }
    }

    /// The afternoon game if the morning's is done, otherwise a new day's morning game.
    private func nextSession() async throws {
        if afternoonPending {
            afternoonPending = false
            session = .afternoon
            try await night(afternoon: true)
        } else {
            session = .morning
            try await night(afternoon: false)
        }
    }

    private func night(afternoon: Bool) async throws {
        if afternoon {
            tonightGame = chosenGame ?? morningGame.afternoon(day: save.night)
        } else {
            save.night += 1
            save.store()
            tonightGame = save.night == 1 ? .ninetyNine : (chosenGame ?? .forNight(save.night))
            morningGame = tonightGame
        }
        chosenGame = nil
        if save.night == 1 {
            try await coworkersNight()
            return
        }
        if !afternoon {
            venue = chosenVenue ?? Venue.forNight(save.night)
            chosenVenue = nil
        }
        let when = "Day \(save.night), \(session.name)."
        clearScene()
        mode = .story
        place = venue == .mainStreet ? .sidewalk : .venue
        shipScale = 0.8
        shipShown = true
        // You or the Princess stands outside the salon door to invite the passersby.
        let host = Bool.random() ? you : princess
        host.mood = .happy
        host.reachTo = nil
        host.place(height: 0)
        if save.night == 2 || afternoon {
            // The salon is parked as the last store down Main Street (or still parked from the morning).
            ship = SalonShip(x: 840, y0: Stage.ground, y1: Stage.ground, flying: false)
            host.visible = true
            host.place(x: 735)
            people = [host]
        } else {
            // The flying salon travels to tonight's venue and lands in the last spot.
            ship = SalonShip(x: 840, y0: -320, y1: -320)
            ship.move(to: Stage.ground, over: 3.5)
            sound.hum(true)
            caption = "\(when) The flying salon travels to \(venue.name)…"
            try await wait(3.7)
            ship.flying = false
            sound.hum(false)
            sound.clunk()
            try await wait(0.6)
            ship.doorOpen = true
            host.visible = true
            host.place(x: ship.x)
            people = [host]
            host.walk(to: 735, speed: 120)
            try await wait(1.0)
            ship.doorOpen = false
        }
        caption = "\(when) The Princess's salon is open \(venue.whereAt). "
            + (host === you ? "Lavender stands outside to invite players…" : "The Princess stands outside to invite players…")
        try await wait(3.2)

        var newcomers: [Person] = []
        let passers = 6 + (save.has(.champagne) ? 2 : 0)
        let acceptance = 0.55 + (save.has(.neonSign) ? 0.15 : 0)
        // Hearts, pedro and pişti need exactly two newcomers to make four with you and the Princess; nines needs just one.
        let fun = tonightGame.isForFun
        let seats = tonightGame.newcomerSeats, need = fun ? seats : 1
        for n in 0..<passers where newcomers.count < seats {
            people.removeAll { !$0.visible || ($0.x1 > 1050 && !$0.isWalking(at: .now)) }
            // Every passerby comes along on his own: a man, or a boy.
            let kid = Double.random(in: 0..<1) < 0.35
            let p = makePasserby(kid: kid, taken: Set(newcomers.map(\.wasName)))
            p.place(x: -80)
            people.append(p)
            p.walk(to: 620, speed: 130)
            caption = kid ? "Here comes a boy named \(p.name)." : "Here comes \(p.name)."
            try await wait(5.4)
            try await talk(host, kid ? "Hi there, sweetie! Want to play \(tonightGame.pitch) with us?"
                                     : "Hey there, handsome! Want to play \(tonightGame.pitch) with us?", voice(for: host))
            let last = passers - n <= need - newcomers.count
            if last || Double.random(in: 0..<1) < acceptance {
                let game = tonightGame.name
                let yes = fun
                    ? (kid ? ["Cool! I love \(game.lowercased())!", "\(game)? Awesome!", "Sure, I'll play!"]
                           : ["Sure, why not!", "\(game)? Count me in!", "I haven't played \(game.lowercased()) in years!", "Deal me in!"])
                    : (kid ? ["Cool! Can I really play?", "\(tonightGame == .blackjack || tonightGame == .craps || tonightGame == .redDog ? tonightGame.name : "Poker")? Awesome!", "Sure, I'll play!"]
                           : ["Sure, why not!", "\(tonightGame == .blackjack || tonightGame == .craps || tonightGame == .redDog ? tonightGame.name : "A poker game")? Count me in!", "I'm feeling lucky today!", "Deal me in!"])
                try await talk(p, yes.randomElement()!, voice(for: p))
                ship.doorOpen = true
                sound.clunk()
                caption = "\(p.name) accepts — and steps into the salon!"
                p.walk(to: ship.x, speed: 130)
                try await wait(2.0)
                p.visible = false
                ship.doorOpen = false
                sound.clunk()
                newcomers.append(p)
                try await wait(0.8)
            } else {
                try await talk(p, (kid ? ["No thanks! I have to get home to my mom.", "Uh… no thanks!", fun ? "My mom's waiting for me!" : "My mom says no poker!"]
                                       : ["No thanks!", "Not today, lady.", "Uh… I'm good.", "I've got to get home."]).randomElement()!, voice(for: p))
                p.walk(to: 1120 + Double.random(in: 0...60), speed: 150)
                caption = "\(p.name) walks on by."
                try await wait(2.4)
            }
        }
        // The host heads inside for the adjustment.
        ship.doorOpen = true
        host.walk(to: ship.x, speed: 130)
        try await wait(1.0)
        host.visible = false
        ship.doorOpen = false
        sound.clunk()
        try await wait(0.6)
        tonight = newcomers
        try await adjustment(newcomers)
    }

    /// Day 1: right after the change, two of Larry's co-workers come looking for him at the casino, find two
    /// girls on the Princess's machine, then spot the salon and get lured into a game of 99.
    private func coworkersNight() async throws {
        venue = .mainStreet
        clearScene()
        mode = .story
        place = .casino
        casinoSecondGirl = true
        // The same two co-workers who saw him punch out (new ones if the shift was skipped).
        var crew = workCrew
        while crew.count < 2 { crew.append(makeCoworker(taken: Set(crew.map(\.wasName)))) }
        for p in crew {
            p.mood = .happy
            p.visible = true
            p.place(height: 0)
        }
        for (i, p) in crew.enumerated() {
            p.place(x: -80 - Double(i) * 90)
            p.walk(to: 320 + Double(i) * 120, speed: 140)
        }
        people = crew
        caption = "Day 1. That evening, two of Larry's co-workers from Target go looking for him at the casino…"
        try await wait(5.4)
        try await talk(crew[0], "Larry always sneaks over here after his shift. Where is he?", .guy)
        shoot(CGPoint(x: 500, y: 277), zoom: 3.4, over: 1.2)
        caption = "On the Princess of Poker's machine, there are two girl pictures instead of one!"
        try await wait(1.8)
        try await talk(crew[1], "Hey, look! There are two girls on the machine now!", .guy)
        try await talk(crew[0], "Wait… the one with the lavender hair looks just like Larry!", .guy)
        try await talk(crew[1], "Larry. She's got you.", .guy)
        try await talk(crew[0], "We have to find him!", .guy)
        shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 1)
        try await wait(1.2)
        for p in crew { p.walk(to: 1120, speed: 150) }
        caption = "They head outside to keep looking…"
        try await wait(4.4)

        casinoSecondGirl = false
        place = .sidewalk
        ship = SalonShip(x: 840, y0: Stage.ground, y1: Stage.ground, flying: false)
        shipScale = 0.8
        shipShown = true
        you.visible = true
        you.mood = .happy
        you.place(height: 0)
        you.place(x: 735)
        for (i, p) in crew.enumerated() {
            p.place(x: -80 - Double(i) * 90)
            p.walk(to: 620 - Double(i) * 75, speed: 130)
        }
        people = crew + [you]
        caption = "…and spot the Princess's flying salon parked at the end of Main Street."
        try await wait(5.6)
        try await talk(you, "Hi guys! Looking for me? Come play a girls game of 99 with us!", .girl)
        try await talk(crew[0], "Larry? Is that… you?!", .guy)
        try await talk(you, "It's Lavender now!", .girl)
        try await talk(crew[1], "99? Count us in!", .guy)
        ship.doorOpen = true
        sound.clunk()
        caption = "Your co-workers are lured into the salon!"
        for (i, p) in crew.enumerated() { p.walk(to: ship.x - Double(i) * 20, speed: 130) }
        try await wait(2.6)
        for p in crew { p.visible = false }
        you.walk(to: ship.x, speed: 130)
        try await wait(1.0)
        you.visible = false
        ship.doorOpen = false
        sound.clunk()
        try await wait(0.6)
        tonight = crew
        try await adjustment(crew)
    }

    /// After the co-workers' game, they step outside still girls and change back over 30 seconds.
    /// Then they want Lavender to come with them. She doesn't.
    private func coworkersFarewell() async throws {
        clearScene()
        mode = .story
        place = .sidewalk
        ship = SalonShip(x: 840, y0: Stage.ground, y1: Stage.ground, flying: false)
        shipScale = 0.8
        shipShown = true
        let crew = tonight
        ship.doorOpen = true
        sound.clunk()
        for (i, p) in crew.enumerated() {
            p.visible = true
            p.opacity = 1
            p.strapped = false
            p.mood = .happy
            p.place(height: 0)
            p.place(x: ship.x - Double(i) * 20)
            p.walk(to: 380 + Double(i) * 110, speed: 120)
        }
        you.visible = true
        you.strapped = false
        you.mood = .happy
        you.place(height: 0)
        you.place(x: ship.x)
        you.walk(to: 700, speed: 120)
        people = crew + [you]
        caption = "The game is over. Your co-workers step out of the salon — still girls…"
        try await wait(3.4)
        ship.doorOpen = false
        sound.clunk()
        try await changeBack(crew)
        caption = "Your co-workers are men again — and they want you to come with them."
        try await wait(2.4)
        guard crew.count >= 2 else { return }
        try await talk(crew[0], "Come on, Larry. Let's get you back to Target.", .guy)
        try await talk(crew[1], "She can turn you back too, right?", .guy)
        try await talk(you, "I don't want to come back. I am happy this way.", .girl)
        try await talk(crew[crew.count - 1], "Well… you do look happy.", .guy)
        try await talk(you, "I have a going away present for you.", .girl)
        try await talk(crew[0], "I think she's going to give us a kiss.", .guy)
        caption = "You give each of your co-workers a kiss goodbye."
        for p in crew.reversed() {
            // Stand just to his right, then lean in until her lips touch his cheek.
            let stance = you.kissStance(for: p.cheek(at: .now))
            you.walk(to: stance.x, speed: 120)
            try await wait(max(0.4, you.moveDur))
            shoot(p.face(at: .now), zoom: 2.6, over: 0.6)
            try await wait(0.7)
            you.lean(to: stance.angle, over: 0.7)
            you.float(to: stance.rise, over: 0.7)
            try await wait(0.8)
            p.kissMark = you.girl.lips
            p.mood = .shocked
            sound.chime()
            try await wait(1.1)
            you.lean(to: 0, over: 0.6)
            you.float(to: 0, over: 0.6)
            try await wait(0.9)
            p.mood = .happy
        }
        shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 0.8)
        you.walk(to: 700, speed: 120)
        caption = "Each of them heads off with a lavender kiss mark on his cheek."
        try await talk(crew[1], "Wow… thanks!", .guy)
        try await wait(max(0.3, you.moveDur - 1.5))
        for (i, p) in crew.enumerated() { p.walk(to: -120 - Double(i) * 60, speed: 120) }
        caption = "Your co-workers head home without you."
        try await wait(3.6)
        ship.doorOpen = true
        you.walk(to: ship.x, speed: 120)
        try await wait(1.3)
        you.visible = false
        ship.doorOpen = false
        sound.clunk()
        try await wait(0.8)
    }

    /// Close-up on the girl under the wall mirror: her face and her reflection side by side.
    private func mirrorCloseUp(_ mirror: CGPoint = CGPoint(x: SalonSpot.mirrorX + 90, y: SalonSpot.mirrorY)) async throws {
        shoot(CGPoint(x: mirror.x, y: mirror.y + 50), zoom: 2.1, over: 0.8)
        try await wait(1.0)
    }

    /// Grown-ups change back from girls to men over 30 seconds (it can be fast-forwarded), head first, feet last.
    private func changeBack(_ group: [Person]) async throws {
        guard !group.isEmpty else { return }
        caption = "…then the transformation starts to wear off!"
        sound.chime()
        for p in group {
            p.mood = .shocked
            p.change(toGirl: false, over: 30)
        }
        let faces = group.map { $0.face(at: .now) }
        let minX = faces.map(\.x).min()!, maxX = faces.map(\.x).max()!
        shoot(CGPoint(x: (minX + maxX) / 2, y: faces.map(\.y).reduce(0, +) / Double(faces.count)),
              zoom: min(3.2, Stage.W / (maxX - minX + 260)), over: 1.2)
        canFastForward = true
        fastForwardAsked = false
        let start = Date.now
        let a = group[0], b = group.count > 1 ? group[1] : group[0]
        var lines: [(Double, Person, String)] = [
            (1, a, "Whoa — something's happening to me!"), (6, b, "My curls are disappearing!"),
            (11, a, "My lipstick is fading away!"), (17, b, "The dress is turning back into my clothes!"),
            (23, a, "My feet are tingling!")]
        var zoomedOut = false
        while group.contains(where: { $0.girlness(at: .now) > 0 }) {
            let elapsed = Date.now.timeIntervalSince(start)
            if fastForwardAsked {
                fastForwardAsked = false
                canFastForward = false
                lines.removeAll()
                for p in group { p.change(toGirl: false, over: 4) }
            }
            if !zoomedOut && (elapsed > 12 || !canFastForward) {
                zoomedOut = true
                for p in group { p.mood = .worried }
                shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 1.5)
            }
            if let l = lines.first, elapsed >= l.0 {
                lines.removeFirst()
                say(l.1, l.2, voice(for: l.1))
            }
            let left = Int((group.map { $0.girlness(at: .now) }.max()! * 30).rounded(.up))
            caption = "The transformation is wearing off… 0:" + String(format: "%02d", left) + " to go."
            try await wait(0.25)
        }
        canFastForward = false
        for p in group {
            p.name = p.wasName
            p.mood = .happy
        }
        sound.chime()
        caption = group.count == 1 ? "\(a.wasName) is a man again!" : group.map(\.wasName).joined(separator: " and ") + " are men again!"
        try await wait(1.6)
    }

    /// After a game the grown-ups step out of the salon still girls, change back over 30 seconds, then head home.
    private func grownUpsHeadOut(_ adults: [Person]) async throws {
        clearScene()
        mode = .story
        place = venue == .mainStreet ? .sidewalk : .venue
        ship = SalonShip(x: 840, y0: Stage.ground, y1: Stage.ground, flying: false)
        shipScale = 0.8
        shipShown = true
        ship.doorOpen = true
        sound.clunk()
        for (i, p) in adults.enumerated() {
            p.visible = true
            p.opacity = 1
            p.strapped = false
            p.mood = .happy
            p.place(height: 0)
            p.place(x: ship.x - Double(i) * 20)
            p.walk(to: 600 - Double(i) * 130, speed: 120)
        }
        people = adults
        caption = "The game is over. " + adults.map(\.name).joined(separator: ", ") + (adults.count == 1 ? " steps" : " step")
            + " out of the salon — still " + (adults.count == 1 ? "a girl…" : "girls…")
        try await wait(3.6)
        ship.doorOpen = false
        sound.clunk()
        try await changeBack(adults)
        let done = ["I'm me again!", "Wait till I tell the guys about this.", "That was the strangest card game of my life.", "Same time tomorrow?"]
        for (p, line) in zip(adults, done.shuffled()) { try await talk(p, line, .guy) }
        for (i, p) in adults.enumerated() { p.walk(to: -120 - Double(i) * 60, speed: 130) }
        caption = adults.count == 1 ? "He heads home." : "They head home."
        try await wait(3.4)
    }

    /// Runs lines of dialogue during a fixed stretch of time (the face morph), then waits out the rest.
    private func talkOver(_ total: Double, _ lines: [(Person, String, Voice)]) async throws {
        let start = Date.now
        try await wait(0.6)
        for (p, text, v) in lines {
            let left = total - Date.now.timeIntervalSince(start)
            if left < 2.2 { break }
            try await wait(min(say(p, text, v), left))
        }
        let left = total - Date.now.timeIntervalSince(start)
        if left > 0 { try await wait(left) }
    }

    private func makeCoworker(taken: Set<String>) -> Person {
        let p = makePasserby(kid: false, taken: taken)
        p.guy = GuyLook(hair: p.guy.hair, shirt: Color(red: 0.8, green: 0.05, blue: 0.1), pants: Color(red: 0.76, green: 0.66, blue: 0.48), nameTag: true)
        return p
    }

    /// A boy goes home to his mother still a girl. An hour later the change wears off over 30 seconds.
    private func kidGoesHome(_ kid: Person) async throws {
        clearScene()
        mode = .story
        place = .home
        clockBase = 21 * 60
        clockT0 = nil
        let mom = Person("Mom", height: 194, skin: kid.skin, guy: GuyLook(hair: .brown, shirt: .gray, pants: .gray),
                         girl: GirlLook(hair: Self.naturalHair.randomElement()!, lips: Color(red: 0.8, green: 0.1, blue: 0.2),
                                        dress: Color(red: 0.2, green: 0.45, blue: 0.75), dressHi: Color(red: 0.6, green: 0.8, blue: 1)),
                         isGirl: true, x: 700)
        kid.visible = true
        kid.opacity = 1
        kid.strapped = false
        kid.mood = .happy
        kid.place(height: 0)
        kid.place(x: 80)
        people = [mom, kid]
        caption = "\(kid.name) heads home to Mom — still a girl."
        kid.walk(to: 420, speed: 120)
        try await wait(3.2)
        mom.mood = .shocked
        mom.handsToFace = true
        try await talk(mom, "Aaah! Who are you?! Where is my son?", .girl)
        try await talk(kid, "Mom, it's me, \(kid.wasName)! The Princess of Poker turned me into a girl!", .kidGirl)
        try await talk(mom, "You smell of perfume.", .girl)
        try await talk(mom, "Oh no! My baby! What did they do to you?", .girl)
        mom.handsToFace = false
        mom.mood = .worried
        caption = "One hour later…"
        try await wait(2.4)
        clockBase = 22 * 60
        caption = "…the transformation starts to disappear!"
        sound.chime()
        kid.mood = .shocked
        kid.change(toGirl: false, over: 30)
        clockT0 = .now
        clockRate = 5.0 / 30
        shoot(kid.face(at: .now), zoom: 3.2, over: 1.2)
        canFastForward = true
        fastForwardAsked = false
        let start = Date.now
        var lines: [(Double, Person, String, Voice)] = [
            (1, mom, "Something's happening to you!", .girl), (5, kid, "My face feels funny!", .kidGirl),
            (10, mom, "Your hair… it's going back!", .girl), (15, kid, "Is it working, Mom?", .boy),
            (20, mom, "Almost there, sweetheart. Hold still!", .girl), (25, kid, "My feet are tingling!", .boy)]
        var zoomedOut = false
        while kid.girlness(at: .now) > 0 {
            let elapsed = Date.now.timeIntervalSince(start)
            if fastForwardAsked {
                fastForwardAsked = false
                canFastForward = false
                lines.removeAll()
                kid.change(toGirl: false, over: 4)
                clockBase = clockMinutes(at: .now)
                clockT0 = .now
                clockRate = max(0, 22 * 60 + 5 - clockBase) / 4
            }
            if !zoomedOut && (elapsed > 12 || !canFastForward) {
                zoomedOut = true
                kid.mood = .worried
                shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 1.5)
            }
            if let l = lines.first, elapsed >= l.0 {
                lines.removeFirst()
                say(l.1, l.2, l.3)
            }
            let left = Int((kid.girlness(at: .now) * 30).rounded(.up))
            caption = "The transformation is wearing off… \(left / 60):" + String(format: "%02d", left % 60) + " to go."
            try await wait(0.25)
        }
        canFastForward = false
        clockBase = 22 * 60 + 5
        clockT0 = nil
        kid.name = kid.wasName
        kid.mood = .happy
        mom.mood = .happy
        sound.chime()
        caption = "The reversal is complete — \(kid.wasName) is a boy again!"
        try await talk(mom, "Oh, thank goodness! My little boy is back!", .girl)
        try await talk(kid, "I'm me again!", .boy)
        try await talk(mom, "Now go take a shower and wash that perfume off.", .girl)
        try await wait(1)
    }

    private func adjustment(_ newcomers: [Person]) async throws {
        clearScene()
        place = .salon
        you.place(x: 60)
        you.visible = true
        you.mood = .happy
        princess.place(x: 822)
        princess.visible = true
        princess.reachTo = nil
        for (i, p) in newcomers.enumerated() {
            p.visible = true
            p.place(height: 0)
            p.place(x: SalonSpot.chairX[i])
            p.mood = .worried
            p.strapped = true
        }
        people = newcomers + [you, princess]
        sound.clunk()
        caption = "The new players are strapped into the salon chairs."
        try await wait(1.6)
        // The change is a surprise: she doesn't tell them what the machine does.
        try await talk(princess, "Welcome, " + (newcomers.count == 1 ? "honey" : "everybody") + "! This is \(tonightGame.pitch). "
                       + "Sit back and relax. I have a little surprise for " + (newcomers.count == 1 ? "you" : "all of you") + " before we play.", .princess)
        // Each of them answers — no two alike.
        var menSay = ["A surprise? What kind of surprise?", "Uh… what are the straps for?", "Is this part of the game?",
                      "Okay… I guess?", "I just wanted to play cards!", "What's that button do?"]
        var boysSay = ["A surprise? Cool!", "Why do I have to be strapped in?", "Is it a prize?", "Can't I just play cards?"]
        for p in newcomers {
            var pool = p.isKid ? boysSay : menSay
            let line = pool.remove(at: Int.random(in: 0..<pool.count))
            if p.isKid { boysSay = pool } else { menSay = pool }
            try await talk(p, line, voice(for: p))
        }
        try await pressButton()
        machineOnUntil = .now + 18.2
        sound.zap(true)
        for p in newcomers { p.changeToGirl(body: 7.4, face: 10) }
        caption = "Starting with the feet, the machine turns " + (newcomers.count == 1 ? "him into a girl…" : "them into girls…")
        for p in newcomers { p.mood = .shocked }
        let zapStart = Date.now
        try await talk(princess, "Surprise!", .princess)
        try await wait(max(0.5, 5 - Date.now.timeIntervalSince(zapStart)))
        caption = "…sparkling dresses, then thick curly hair and lipstick…"
        try await wait(2)
        // Close-up on the faces as they morph from guy to girl.
        let faces = newcomers.map { $0.face(at: .now) }
        let midX = (faces.map(\.x).min()! + faces.map(\.x).max()!) / 2
        let midY = faces.map(\.y).reduce(0, +) / Double(faces.count)
        let spread = faces.map(\.x).max()! - faces.map(\.x).min()!
        shoot(CGPoint(x: midX, y: midY), zoom: min(3.6, Stage.W / (spread + 260)), over: 0.8)
        let first = newcomers[0], second = newcomers.count > 1 ? newcomers[1] : newcomers[0]
        try await talkOver(10.9, [
            (first, first.isKid ? "My face feels all tingly!" : "Hey! What's happening to my face?!", first.isKid ? .boy : .guy),
            (princess, "Don't fight it, girls. Every girl at my table needs a pretty face.", .princess),
            (second, second.isKid ? "I'm growing curls!" : "My hair… it's all curly!", voice(for: second)),
            (first, "Is that… lipstick?!", voice(for: first))])
        sound.zap(false)
        sound.chime()
        try await wait(0.6)
        shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 1)
        try await wait(1)
        for p in newcomers { p.name = p.girlName }
        caption = newcomers.map { "\($0.wasName) is now \($0.name), with \($0.hairName) curls" }.joined(separator: " · ")
        try await wait(2.2)
        // The retractable mirror comes down from the ceiling and the new girls line up under it to look all at once.
        try await talk(princess, newcomers.count == 1 ? "All done, honey! Come stand under the mirror." : "All done, girls! Line up under the mirror.", .princess)
        let spots = newcomers.count == 1 ? [SalonSpot.lineUp[1]] : newcomers.count == 2 ? [SalonSpot.lineUp[0] + 50, SalonSpot.lineUp[2] - 50] : SalonSpot.lineUp
        for (p, x) in zip(newcomers, spots) {
            p.strapped = false
            p.walk(to: x, speed: 110)
        }
        sound.clunk()
        caption = "The straps pop open and the new girls line up side by side…"
        try await wait(max(1.0, (newcomers.map(\.moveDur).max() ?? 0) + 0.3))
        retractMirror = RetractMirror(from: 0, to: 1, t0: .now, dur: 2.4)
        sound.hum(true)
        caption = "…as a wide mirror lowers from the ceiling!"
        try await wait(2.5)
        sound.hum(false)
        sound.chime()
        let glass = SalonSpot.retractRect
        shoot(CGPoint(x: 500, y: glass.midY + 95), zoom: 1.55, over: 0.8)
        try await wait(1.0)
        caption = "They all look in the mirror at once…"
        var manSees = ["I'm a girl!", "Look at all this hair!", "Is that lipstick?", "What happened to my clothes?", "Look at us!"]
        var kidSees = ["I'm a girl now!", "Look at my curly hair!", "Wait till Mom sees this!"]
        for p in newcomers {
            var pool = p.isKid ? kidSees : manSees
            var line = pool.remove(at: Int.random(in: 0..<pool.count))
            if line == "Look at all this hair!" { line = "Look at all this \(p.hairName) hair!" }
            if p.isKid { kidSees = pool } else { manSees = pool }
            try await talk(p, line, voice(for: p))
            p.mood = .happy
        }
        try await wait(0.6)
        shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 0.8)
        retractMirror = RetractMirror(from: 1, to: 0, t0: .now, dur: 2.0)
        sound.hum(true)
        caption = "The mirror rises back into the ceiling…"
        try await wait(2.1)
        sound.hum(false)
        // Then gold arms come down from the ceiling and give each of them a spray of perfume.
        caption = "…and gold arms come down from the ceiling, each holding a perfume bottle!"
        let start = Date.now.addingTimeInterval(1.4)
        sprays = newcomers.map { p in
            let face = p.face(at: .now)
            let nozzle = CGPoint(x: face.x + 85, y: face.y - 28)
            return PerfumeBlast(cabinet: CGPoint(x: nozzle.x + 18, y: 30), nozzle: nozzle, target: face, t0: start, dur: 5)
        }
        for p in newcomers { p.mood = .shocked }
        try await wait(1.4)
        sound.perfume(true)
        caption = "Pssssht! A spray of perfume for every new girl!"
        try await wait(2.6)
        caption = "They smell like a flower garden!"
        try await wait(2.4)
        sound.perfume(false)
        try await wait(0.4)
        sprays = []
        for p in newcomers { p.mood = .happy }
        let sniffer = newcomers.randomElement()!
        try await talk(sniffer, "Mmm, I smell so pretty!", voice(for: sniffer))
        caption = ""
        try await talk(princess, tonightGame.isForFun
                       ? "Now, to the card room, girls! \(save.night == 1 ? "Tonight" : "This \(session.name)")'s game is \(tonightGame.name.lowercased()) — just for fun, no money on the table."
                       : "Now, to the \(tonightGame == .blackjack || tonightGame == .redDog ? "card" : tonightGame == .craps ? "dice" : "poker") room, girls! This \(session.name)'s game is \(tonightGame.name). Every buy-in is fifty dollars.", .princess)
        try await wait(0.8)
        startTable(newcomers)
    }

    private func startTable(_ newcomers: [Person]) {
        if tonightGame == .hearts {
            startHearts(newcomers)
            return
        }
        if tonightGame == .nines {
            startNines(newcomers)
            return
        }
        if tonightGame == .ohHell {
            startOhHell(newcomers)
            return
        }
        if tonightGame == .californiaJack {
            startCaliforniaJack(newcomers)
            return
        }
        if tonightGame == .pedro {
            startPedro(newcomers)
            return
        }
        if tonightGame == .pisti {
            startPisti(newcomers)
            return
        }
        if tonightGame == .big2 {
            startBig2(newcomers)
            return
        }
        if tonightGame == .ninetyNine {
            startNinetyNine(newcomers)
            return
        }
        if tonightGame == .blackjack {
            startBlackjack(newcomers)
            return
        }
        if tonightGame == .paigow {
            startPaiGow(newcomers)
            return
        }
        if tonightGame == .craps {
            startCraps(newcomers)
            return
        }
        if [.threeCard, .letItRide, .redDog].contains(tonightGame) {
            startBanked(newcomers)
            return
        }
        if [.pepper, .spades, .dominoHearts, .callItRight].contains(tonightGame) {
            startTricks(newcomers)
            return
        }
        var seats = [HoldemTable.Seat(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true, stack: HoldemTable.buyIn)]
        for (i, p) in newcomers.enumerated() {
            seats.append(HoldemTable.Seat(id: i + 1, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isHuman: false,
                                          stack: HoldemTable.buyIn, isKid: p.isKid, aggression: Double.random(in: 0.2...0.85)))
        }
        seats.append(HoldemTable.Seat(id: seats.count, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl,
                                      isHuman: false, stack: HoldemTable.buyIn, isPrincess: true, aggression: 0.55))
        let t = HoldemTable(seats: seats, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1, looseness: save.has(.snackBar) ? 1 : 0,
                            game: tonightGame)
        t.onFinished = { [weak self] in self?.finishNight() }
        table = t
        clearScene()
        mode = .holdem
        tableTask = Task { await t.run() }
    }

    /// Hearts: you across from the Princess, a newcomer on each side. Nobody bets.
    private func startHearts(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            HeartsTable.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        var players = [HeartsTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        players.append(seat(1, newcomers[0]))
        players.append(HeartsTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true))
        players.append(seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]))
        let h = HeartsTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        h.onFinished = { [weak self] in self?.finishHearts() }
        hearts = h
        clearScene()
        mode = .hearts
        tableTask = Task { await h.run() }
    }

    private func finishHearts() {
        guard let h = hearts else { return }
        let departures = h.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: "finished the hearts game with \(p.score) points", isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: h.human.score, errandNext: errandAfter, isForFun: true, funGame: "hearts")
        hearts = nil
        afterTable(departures)
    }

    /// Nines: you, the Princess and one newcomer, with the spare hand in the middle. Nobody bets.
    private func startNines(_ newcomers: [Person]) {
        let p = newcomers[0]
        let players = [
            NinesTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true),
            NinesTable.Player(id: 1, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid),
            NinesTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true),
        ]
        let n = NinesTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        n.onFinished = { [weak self] in self?.finishNines() }
        nines = n
        clearScene()
        mode = .nines
        tableTask = Task { await n.run() }
    }

    private func finishNines() {
        guard let n = nines else { return }
        let departures = n.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: "finished the nines game with \(p.score) point\(p.score == 1 ? "" : "s") left", isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: n.human.score, errandNext: errandAfter, isForFun: true, funGame: "nines")
        nines = nil
        afterTable(departures)
    }

    /// Oh hell: you across from the Princess, a newcomer on each side, thirteen hands from one card up to thirteen. Nobody bets.
    private func startOhHell(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            OhHellTable.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        var players = [OhHellTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        players.append(seat(1, newcomers[0]))
        players.append(OhHellTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true))
        players.append(seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]))
        let t = OhHellTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in self?.finishOhHell() }
        ohHell = t
        clearScene()
        mode = .ohHell
        tableTask = Task { await t.run() }
    }

    private func finishOhHell() {
        guard let t = ohHell else { return }
        let departures = t.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: "finished the oh hell game with \(p.score) points", isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: t.human.score, errandNext: errandAfter, isForFun: true, funGame: "oh hell")
        ohHell = nil
        afterTable(departures)
    }

    /// California jack: you across from the Princess, a newcomer on each side, everyone for herself. Nobody bets.
    private func startCaliforniaJack(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            CaliforniaJackTable.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        var players = [CaliforniaJackTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        players.append(seat(1, newcomers[0]))
        players.append(CaliforniaJackTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true))
        players.append(seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]))
        let t = CaliforniaJackTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in self?.finishCaliforniaJack() }
        californiaJack = t
        clearScene()
        mode = .californiaJack
        tableTask = Task { await t.run() }
    }

    private func finishCaliforniaJack() {
        guard let t = californiaJack else { return }
        let departures = t.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: "finished the california jack game with \(p.score) point\(p.score == 1 ? "" : "s")", isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: t.human.score, errandNext: errandAfter, isForFun: true, funGame: "California Jack")
        californiaJack = nil
        afterTable(departures)
    }

    /// Pedro: you and the Princess as partners across the table, a newcomer on each side. Nobody bets.
    private func startPedro(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            PedroTable.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        let players = [
            PedroTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true),
            seat(1, newcomers[0]),
            PedroTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true),
            seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]),
        ]
        let t = PedroTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in self?.finishPedro() }
        pedro = t
        clearScene()
        mode = .pedro
        tableTask = Task { await t.run() }
    }

    private func finishPedro() {
        guard let t = pedro else { return }
        let won = t.winningTeam == 1
        let departures = t.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: "\(won ? "won" : "lost") the pedro game \(t.scores[1]) to \(t.scores[0])", isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: t.scores[0], errandNext: errandAfter, isForFun: true, funGame: "pedro")
        pedro = nil
        afterTable(departures)
    }

    /// Pişti: you, the Princess and a newcomer on each side, everyone for herself. Nobody bets.
    private func startPisti(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            PistiTable.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        let players = [
            PistiTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true),
            seat(1, newcomers[0]),
            PistiTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true),
            seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]),
        ]
        let t = PistiTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in self?.finishPisti() }
        pisti = t
        clearScene()
        mode = .pisti
        tableTask = Task { await t.run() }
    }

    private func finishPisti() {
        guard let t = pisti else { return }
        let departures = t.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: "finished the pişti game with \(p.score) points", isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: t.human.score, errandNext: errandAfter, isForFun: true, funGame: "pişti")
        pisti = nil
        afterTable(departures)
    }

    /// Big Two: you, the Princess and a newcomer on each side, everyone for herself. Nobody bets.
    private func startBig2(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            Big2Table.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        let players = [
            Big2Table.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true),
            seat(1, newcomers[0]),
            Big2Table.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true),
            seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]),
        ]
        let t = Big2Table(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in self?.finishBig2() }
        big2 = t
        clearScene()
        mode = .big2
        tableTask = Task { await t.run() }
    }

    private func finishBig2() {
        guard let t = big2 else { return }
        let departures = t.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: "finished the Big Two game with \(p.score) penalty points", isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: t.human.score, errandNext: errandAfter, isForFun: true, funGame: "Big Two")
        big2 = nil
        afterTable(departures)
    }

    /// 99: you, the Princess and a newcomer on each side, two tokens apiece. Nobody bets.
    private func startNinetyNine(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            NinetyNineTable.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        let players = [
            NinetyNineTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true),
            seat(1, newcomers[0]),
            NinetyNineTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true),
            seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]),
        ]
        let t = NinetyNineTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in self?.finishNinetyNine() }
        ninetyNine = t
        clearScene()
        mode = .ninetyNine
        tableTask = Task { await t.run() }
    }

    private func finishNinetyNine() {
        guard let t = ninetyNine else { return }
        let departures = t.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: t.winner == p.id ? "won the 99 game" : "finished the 99 game with \(p.tokens) token\(p.tokens == 1 ? "" : "s")",
                                  isKid: p.isKid)
        }
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: t.human.tokens, errandNext: errandAfter, isForFun: true, funGame: "99")
        ninetyNine = nil
        afterTable(departures)
    }

    /// Blackjack: you choose to play a seat or be the house; whoever isn't the house plays against her hand.
    private func startBlackjack(_ newcomers: [Person]) {
        var players = [BlackjackTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        for (i, p) in newcomers.enumerated() {
            players.append(BlackjackTable.Player(id: i + 1, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid,
                                                 aggression: Double.random(in: 0.2...0.85)))
        }
        players.append(BlackjackTable.Player(id: players.count, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl,
                                             isPrincess: true, aggression: 0.55))
        let t = BlackjackTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in
            guard let self, let t = self.blackjack else { return }
            self.blackjack = nil
            self.finishMoneyGame(departures: t.departures, yourWinnings: t.yourWinnings, princessWinnings: t.princessWinnings, yourStack: t.human.stack)
        }
        blackjack = t
        clearScene()
        mode = .blackjack
        tableTask = Task { await t.run() }
    }

    /// Pai gow poker: the Princess banks; you and the newcomers set seven cards against hers.
    private func startPaiGow(_ newcomers: [Person]) {
        var players = [PaiGowTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        for (i, p) in newcomers.enumerated() {
            players.append(PaiGowTable.Player(id: i + 1, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid,
                                              aggression: Double.random(in: 0.2...0.85)))
        }
        players.append(PaiGowTable.Player(id: players.count, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl,
                                          isPrincess: true))
        let t = PaiGowTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in
            guard let self, let t = self.paigow else { return }
            self.paigow = nil
            self.finishMoneyGame(departures: t.departures, yourWinnings: t.yourWinnings, princessWinnings: t.princessWinnings, yourStack: t.human.stack)
        }
        paigow = t
        clearScene()
        mode = .paigow
        tableTask = Task { await t.run() }
    }

    /// Craps: the Princess banks; you and the newcomers bet the pass line and take turns with the dice.
    private func startCraps(_ newcomers: [Person]) {
        var players = [CrapsTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        for (i, p) in newcomers.enumerated() {
            players.append(CrapsTable.Player(id: i + 1, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid,
                                             aggression: Double.random(in: 0.2...0.85)))
        }
        players.append(CrapsTable.Player(id: players.count, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl,
                                         isPrincess: true, aggression: 0.55))
        let t = CrapsTable(players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in
            guard let self, let t = self.craps else { return }
            self.craps = nil
            self.finishMoneyGame(departures: t.departures, yourWinnings: t.yourWinnings, princessWinnings: t.princessWinnings, yourStack: t.human.stack)
        }
        craps = t
        clearScene()
        mode = .craps
        tableTask = Task { await t.run() }
    }

    /// Three card poker, let it ride or red dog: the Princess banks; you and the newcomers bet against the house.
    private func startBanked(_ newcomers: [Person]) {
        var players = [BankedTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        for (i, p) in newcomers.enumerated() {
            players.append(BankedTable.Player(id: i + 1, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid,
                                              aggression: Double.random(in: 0.2...0.85)))
        }
        players.append(BankedTable.Player(id: players.count, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl,
                                          isPrincess: true))
        let t = BankedTable(game: tonightGame, players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in
            guard let self, let t = self.banked else { return }
            self.banked = nil
            self.finishMoneyGame(departures: t.departures, yourWinnings: t.yourWinnings, princessWinnings: t.princessWinnings, yourStack: t.human.stack)
        }
        banked = t
        clearScene()
        mode = .banked
        tableTask = Task { await t.run() }
    }

    /// Pepper, spades or domino hearts: you across from the Princess, a newcomer on each side. Nobody bets.
    private func startTricks(_ newcomers: [Person]) {
        let seat = { (i: Int, p: Person) in
            TrickTable.Player(id: i, name: p.name, wasName: p.wasName, skin: p.skin, look: p.girl, isKid: p.isKid)
        }
        var players = [TrickTable.Player(id: 0, name: "Lavender", wasName: "Larry", skin: you.skin, look: you.girl, isHuman: true)]
        players.append(seat(1, newcomers[0]))
        players.append(TrickTable.Player(id: 2, name: "Princess", wasName: "Princess", skin: princess.skin, look: princess.girl, isPrincess: true))
        players.append(seat(3, newcomers.count > 1 ? newcomers[1] : newcomers[0]))
        let t = TrickTable(game: tonightGame, players: players, sound: sound, pace: save.has(.shuffler) ? 1.6 : 1)
        t.onFinished = { [weak self] in self?.finishTricks() }
        tricks = t
        clearScene()
        mode = .tricks
        tableTask = Task { await t.run() }
    }

    private func finishTricks() {
        guard let t = tricks else { return }
        let name = t.game.name.lowercased()
        let departures = t.players.filter { !$0.isHuman && !$0.isPrincess }.map { p in
            HoldemTable.Departure(name: p.name, wasName: p.wasName, takeaway: 0,
                                  reason: t.partnerships ? "finished the \(name) game" : "finished the \(name) game with \(p.score) points", isKid: p.isKid)
        }
        let yours = t.partnerships ? t.teamScore[0] : t.human.score
        nightResult = NightResult(night: save.night, departures: departures, profit: 0, yourWinnings: 0, princessWinnings: 0,
                                  yourStack: yours, errandNext: errandAfter, isForFun: true, funGame: name)
        tricks = nil
        afterTable(departures)
    }

    /// A banked money game is over: what you and the Princess won goes in the cash box.
    private func finishMoneyGame(departures: [HoldemTable.Departure], yourWinnings: Int, princessWinnings: Int, yourStack: Int) {
        let profit = yourWinnings + princessWinnings
        save.cash += profit
        save.totalProfit += profit
        save.store()
        nightResult = NightResult(night: save.night, departures: departures, profit: profit,
                                  yourWinnings: yourWinnings, princessWinnings: princessWinnings,
                                  yourStack: yourStack, errandNext: errandAfter)
        afterTable(departures)
    }

    private func finishNight() {
        guard let t = table else { return }
        let profit = t.revenue
        save.cash += profit
        save.totalProfit += profit
        save.store()
        nightResult = NightResult(night: save.night, departures: t.departures, profit: profit,
                                  yourWinnings: t.yourWinnings, princessWinnings: t.princessWinnings,
                                  yourStack: t.human.stack, errandNext: errandAfter)
        table = nil
        afterTable(t.departures)
    }

    private func afterTable(_ departures: [HoldemTable.Departure]) {
        // Boys go home to their moms, still girls, before the night's summary.
        let kids = departures.filter(\.isKid).compactMap { d in tonight.first { $0.wasName == d.wasName } }
        // Grown-ups step outside and change back over 30 seconds.
        let adults = departures.filter { !$0.isKid }.compactMap { d in tonight.first { $0.wasName == d.wasName } }
        let coworkers = save.night == 1
        // Once the day's last game is done, it's time to rest.
        let dayDone = coworkers || session == .afternoon
        afternoonPending = !dayDone
        if kids.isEmpty && adults.isEmpty && !coworkers && !dayDone {
            mode = .summary
        } else {
            let first = save.night == 1
            run { [weak self] in
                if coworkers { try await self?.coworkersFarewell() } else if !adults.isEmpty { try await self?.grownUpsHeadOut(adults) }
                for k in kids { try await self?.kidGoesHome(k) }
                if dayDone { try await self?.bedtime(first: first) }
                self?.mode = .summary
            }
        }
    }

    /// After the day's games the Princess shows you to your room so you can both get some rest.
    /// The first time, Lavender has a good look at herself in the bedroom mirror.
    private func bedtime(first: Bool) async throws {
        clearScene()
        mode = .story
        place = .bedroom
        for p in [you, princess] {
            p.visible = true
            p.opacity = 1
            p.strapped = false
            p.reachTo = nil
            p.mood = .happy
            p.place(height: 0)
        }
        you.place(x: 40)
        princess.place(x: -30)
        people = [you, princess]
        caption = first ? "After the first day's game, the Princess shows Lavender to her room."
                        : "Day \(save.night) is done — both games are over. Time to rest."
        sound.clunk()
        you.walk(to: 470, speed: 120)
        princess.walk(to: 230, speed: 120)
        try await wait(3.8)
        if first {
            try await talk(princess, "Here's your room, honey. We both need some rest after a day like this.", .princess)
            try await talk(you, "It's beautiful! Thank you, Princess.", .girl)
        } else {
            try await talk(princess, "Two games in one day! You were wonderful, honey. Let's get some rest.", .princess)
            try await talk(you, "I'm so tired. Goodnight, Princess.", .girl)
        }
        try await talk(princess, "Sweet dreams. See you in the morning!", .princess)
        princess.walk(to: -60, speed: 120)
        try await wait(2.4)
        princess.visible = false
        sound.clunk()
        caption = ""
        try await wait(0.6)
        if first {
            try await talk(you, "What a day this has been.", .girl)
            caption = "Lavender walks over to the mirror in her bedroom…"
            you.walk(to: BedroomSpot.mirrorStand, speed: 100)
            try await wait(max(0.4, you.moveDur + 0.3))
            try await mirrorCloseUp(CGPoint(x: BedroomSpot.mirrorX - 100, y: BedroomSpot.mirrorY))
            caption = ""
            try await talk(you, "This really beats pushing carts.", .girl)
            try await talk(you, "Ooh I really love my new look.", .girl)
            try await wait(0.6)
            shoot(CGPoint(x: Stage.W / 2, y: Stage.H / 2), zoom: 1, over: 1)
            try await wait(1)
        }
        you.walk(to: 520, speed: 110)
        try await wait(3.3)
        caption = "Time for some rest. Goodnight!"
        for k in 1...20 {
            lightsOut = Double(k) / 20
            try await wait(0.08)
        }
        try await wait(2.2)
    }

    func buy(_ u: Upgrade) {
        guard !save.has(u), save.cash + save.bank >= u.price else { return }
        let fromCash = min(max(save.cash, 0), u.price)
        save.cash -= fromCash
        save.bank -= u.price - fromCash
        save.owned.insert(u)
        save.store()
        sound.coin()
    }

    // MARK: Groceries and the bank

    private func errand() async throws {
        clearScene()
        mode = .story
        place = .town
        ship = SalonShip(x: 500, y0: 250, y1: 250)
        shipScale = 0.72
        shipShown = true
        sound.hum(true)
        you.visible = true
        you.mood = .happy
        princess.visible = true
        princess.reachTo = nil
        you.place(x: 470)
        princess.place(x: 535)
        for p in [you, princess] {
            p.place(height: Stage.ground - 250)
            p.float(to: 0, over: 2.4 * beamFactor)
        }
        people = [you, princess]
        beam = Beam(x: 500, top: 250, bottom: Stage.ground + 10)
        sound.beam(true)
        caption = "Every two nights, you and the Princess beam down to buy groceries and make a bank deposit."
        try await wait(2.6 * beamFactor)
        beam = nil
        sound.beam(false)
        sound.hum(false)

        you.walk(to: 285, speed: 120)
        princess.walk(to: 325, speed: 120)
        try await wait(2.0)
        caption = "Groceries at the Fresh Market…"
        you.visible = false
        princess.visible = false
        try await wait(2.2)
        let groceries = 40
        let fromCash = min(max(save.cash, 0), groceries)
        save.cash -= fromCash
        save.bank -= groceries - fromCash
        you.visible = true
        princess.visible = true
        caption = "Groceries: $\(groceries)."
        try await wait(1.2)
        you.walk(to: 790, speed: 130)
        princess.walk(to: 830, speed: 130)
        try await wait(4.2)
        you.visible = false
        princess.visible = false
        caption = "…and a deposit at First National Bank."
        try await wait(2)
        let deposit = max(0, save.cash - 50)
        save.cash -= deposit
        save.bank += deposit
        save.store()
        sound.coin()
        you.visible = true
        princess.visible = true
        caption = deposit > 0 ? "Deposited $\(deposit). Bank balance: $\(save.bank)." : "Nothing extra to deposit tonight. Bank balance: $\(save.bank)."
        try await talk(princess, deposit > 0 ? "A lovely deposit, honey!" : "We'll need more players to lose, honey.", .princess)
        you.walk(to: 470, speed: 130)
        princess.walk(to: 535, speed: 130)
        try await wait(2.6)
        beam = Beam(x: 500, top: 250, bottom: Stage.ground + 10)
        sound.beam(true)
        sound.hum(true)
        for p in [you, princess] { p.float(to: Stage.ground - 250, over: 2.4 * beamFactor) }
        try await wait(2.5 * beamFactor)
        beam = nil
        sound.beam(false)
        sound.hum(false)
        you.place(height: 0)
        princess.place(height: 0)
    }
}
