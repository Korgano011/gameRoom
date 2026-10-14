import SwiftUI

enum Stage {
    static let W = 1000.0
    static let H = 600.0
    static let ground = 540.0
}

struct GuyLook {
    var hair: Color
    var shirt: Color
    var pants: Color
    /// A red work shirt with a name tag.
    var nameTag = false
}

struct GirlLook {
    var hair: Color
    var lips: Color
    var dress: Color
    var dressHi: Color
    var tiara = false

    /// The Princess of Poker's own sparkling dress; everyone she changes gets the same one.
    static let princessDress = Color(red: 0.62, green: 0.2, blue: 0.78)
    static let princessDressHi = Color(red: 0.95, green: 0.6, blue: 1.0)

    static let princess = GirlLook(hair: Color(red: 0.55, green: 0.18, blue: 0.1),
                                   lips: Color(red: 0.1, green: 0.7, blue: 0.25),
                                   dress: princessDress, dressHi: princessDressHi, tiara: true)

    /// Sparkling dresses come in pink, green, yellow, red, blue, the Princess's own purple, gold and silver (colour, highlight).
    static let dressColors: [(String, Color, Color)] = [
        ("pink", Color(red: 1, green: 0.35, blue: 0.65), Color(red: 1, green: 0.75, blue: 0.88)),
        ("green", Color(red: 0.1, green: 0.62, blue: 0.3), Color(red: 0.6, green: 0.95, blue: 0.65)),
        ("yellow", Color(red: 0.95, green: 0.78, blue: 0.1), Color(red: 1, green: 0.97, blue: 0.65)),
        ("red", Color(red: 0.85, green: 0.08, blue: 0.15), Color(red: 1, green: 0.55, blue: 0.55)),
        ("blue", Color(red: 0.15, green: 0.4, blue: 0.95), Color(red: 0.6, green: 0.8, blue: 1)),
        ("purple", princessDress, princessDressHi),
        ("gold", Color(red: 0.85, green: 0.64, blue: 0.12), Color(red: 1, green: 0.92, blue: 0.55)),
        ("silver", Color(red: 0.7, green: 0.72, blue: 0.77), Color(red: 0.96, green: 0.97, blue: 1))]

    /// A newcomer's look after the adjustment: a sparkling dress in a random colour.
    static func changed(hair: Color, lips: Color) -> GirlLook {
        let d = dressColors.randomElement()!
        return GirlLook(hair: hair, lips: lips, dress: d.1, dressHi: d.2)
    }

    /// Lavender's own look: lavender curls, lavender lipstick and a lavender dress to match.
    static let lavender = GirlLook(hair: lavenderHair, lips: lavenderLips, dress: lavenderDress, dressHi: lavenderDressHi)
    static let lavenderHair = Color(red: 0.8, green: 0.68, blue: 0.96)
    static let lavenderLips = Color(red: 0.69, green: 0.47, blue: 0.88)
    static let lavenderDress = Color(red: 0.71, green: 0.58, blue: 0.93)
    static let lavenderDressHi = Color(red: 0.92, green: 0.86, blue: 1)

    static let hairColors: [(String, Color)] = [
        ("pink", Color(red: 1, green: 0.45, blue: 0.7)), ("blue", Color(red: 0.25, green: 0.5, blue: 1)),
        ("red", Color(red: 0.85, green: 0.12, blue: 0.1)), ("blonde", Color(red: 0.98, green: 0.84, blue: 0.4)),
        ("jet black", Color(red: 0.08, green: 0.07, blue: 0.1)), ("purple", Color(red: 0.55, green: 0.25, blue: 0.85)),
        ("green", Color(red: 0.2, green: 0.75, blue: 0.35)), ("orange", Color(red: 1, green: 0.55, blue: 0.1)),
        ("silver", Color(red: 0.82, green: 0.84, blue: 0.9)), ("teal", Color(red: 0.1, green: 0.7, blue: 0.7))]
    static let lipColors: [Color] = [
        Color(red: 0.9, green: 0.05, blue: 0.2), Color(red: 1, green: 0.4, blue: 0.7), Color(red: 0.95, green: 0.45, blue: 0.1),
        Color(red: 0.15, green: 0.35, blue: 0.95), Color(red: 0.7, green: 0.0, blue: 0.4), Color(red: 0.95, green: 0.75, blue: 0.1),
        Color(red: 0.1, green: 0.1, blue: 0.12), Color(red: 0.0, green: 0.7, blue: 0.7),
        goldLips, silverLips]
    static let goldLips = Color(red: 0.86, green: 0.66, blue: 0.16)
    static let silverLips = Color(red: 0.76, green: 0.78, blue: 0.84)
    static let pinkLips = Color(red: 1, green: 0.35, blue: 0.65)
}

enum Mood { case happy, shocked, worried, scared }

final class Person: Identifiable {
    let id = UUID()
    var name: String
    /// Who he was before the salon's adjustment.
    var wasName = ""
    /// The colour name of her new curls, e.g. "pink".
    var hairName = ""
    /// Her name after the adjustment.
    var girlName = ""
    var height: Double
    let isKid: Bool
    let skin: Color
    var guy: GuyLook
    var girl: GirlLook
    /// Seeds the sparkle pattern on the dress.
    let seed = Int.random(in: 0..<10_000)

    var visible = true
    var opacity = 1.0
    var baseY = Stage.ground
    var x0: Double
    var x1: Double
    var moveT0 = Date.distantPast
    var moveDur = 0.0
    var running = false
    /// Legs keep going while standing still (running home on a scrolling street).
    var jogging = false

    private var y0 = 0.0, y1 = 0.0
    private var riseT0 = Date.distantPast
    private var riseDur = 0.0

    /// 0 = still a guy, 1 = a girl from toes to curls.
    private var changeFrom: Double
    private var changeTo: Double
    var changeT0 = Date.distantPast
    var changeDur = 0.0

    var powder = 0.0
    var powderOffT0 = Date.distantFuture
    var powderOffDur = 3.0
    /// Hands up at the cheeks — brushing off powder, or in shock.
    var handsToFace = false
    /// Where the right hand is reaching (the yellow button).
    var reachTo: CGPoint?
    var strapped = false
    var mood = Mood.happy
    var says: String?
    var saysUntil = Date.distantPast
    var talkingUntil = Date.distantPast
    /// A lipstick kiss mark on the cheek, in the kisser's lipstick colour.
    var kissMark: Color?
    /// Sitting down (on the toilet), seen from the front.
    var seated = false
    /// Leaning in for a kiss: radians around the feet, negative leans left.
    private var leanFrom = 0.0, leanTo = 0.0
    private var leanT0 = Date.distantPast
    private var leanDur = 0.0

    init(_ name: String, height: Double, kid: Bool = false, skin: Color, guy: GuyLook, girl: GirlLook, isGirl: Bool, x: Double) {
        self.name = name
        self.height = height
        isKid = kid
        self.skin = skin
        self.guy = guy
        self.girl = girl
        changeFrom = isGirl ? 1 : 0
        changeTo = changeFrom
        x0 = x
        x1 = x
    }

    func x(at now: Date) -> Double {
        let t = now.timeIntervalSince(moveT0)
        if t >= moveDur { return x1 }
        if t <= 0 { return x0 }
        return x0 + (x1 - x0) * t / moveDur
    }

    func isWalking(at now: Date) -> Bool {
        if jogging { return true }
        let t = now.timeIntervalSince(moveT0)
        return t > 0 && t < moveDur
    }

    func walk(to x: Double, speed: Double = 120) {
        let now = Date.now
        x0 = self.x(at: now)
        x1 = x
        moveT0 = now
        moveDur = abs(x1 - x0) / speed
    }

    func place(x: Double) {
        (x0, x1, moveDur) = (x, x, 0)
    }

    func rise(at now: Date) -> Double {
        let t = now.timeIntervalSince(riseT0)
        if t >= riseDur { return y1 }
        if t <= 0 { return y0 }
        let u = t / riseDur
        return y0 + (y1 - y0) * u * u * (3 - 2 * u)
    }

    func float(to height: Double, over seconds: Double) {
        let now = Date.now
        y0 = rise(at: now)
        y1 = height
        riseT0 = now
        riseDur = seconds
    }

    func place(height: Double) {
        (y0, y1, riseDur) = (height, height, 0)
    }

    /// For a two-speed change: the girlness where the line reaches the chin, and how long the body took.
    private var changePivot: Double?
    private var changeBodyDur = 0.0

    /// Girlness at which the change line reaches the chin and the face starts to morph.
    var morphStart: Double {
        let r = height * (isKid ? 0.12 : 0.095)
        return (height - 2 * r) / (height + r)
    }

    func girlness(at now: Date) -> Double {
        let t = now.timeIntervalSince(changeT0)
        if t >= changeDur { return changeTo }
        if t <= 0 { return changeFrom }
        if let pivot = changePivot {
            if t < changeBodyDur { return changeFrom + (pivot - changeFrom) * t / changeBodyDur }
            return pivot + (changeTo - pivot) * (t - changeBodyDur) / (changeDur - changeBodyDur)
        }
        return changeFrom + (changeTo - changeFrom) * t / changeDur
    }

    func change(toGirl: Bool, over seconds: Double) {
        let now = Date.now
        changeFrom = girlness(at: now)
        changeTo = toGirl ? 1 : 0
        changeT0 = now
        changeDur = seconds
        changePivot = nil
    }

    /// Feet up to the chin over `body` seconds, then the face morphs slowly over `face` seconds.
    func changeToGirl(body: Double, face: Double) {
        let now = Date.now
        changeFrom = girlness(at: now)
        changeTo = 1
        changeT0 = now
        changePivot = max(changeFrom, morphStart)
        changeBodyDur = body
        changeDur = body + face
    }

    var isGirl: Bool { changeTo == 1 }

    func powderLevel(at now: Date) -> Double {
        let t = now.timeIntervalSince(powderOffT0)
        if t <= 0 { return powder }
        return powder * max(0, 1 - t / powderOffDur)
    }

    func say(_ text: String, for seconds: Double) {
        says = text
        saysUntil = .now + seconds
        talkingUntil = .now + min(seconds, Double(text.count) * 0.06 + 0.4)
    }

    var footY: Double { baseY }

    /// The top of the head (or curls) in stage coordinates.
    func headTop(at now: Date) -> CGPoint {
        CGPoint(x: x(at: now), y: baseY - rise(at: now) - height - height * 0.05)
    }

    func lean(at now: Date) -> Double {
        let t = now.timeIntervalSince(leanT0)
        if t >= leanDur { return leanTo }
        if t <= 0 { return leanFrom }
        let u = t / leanDur
        return leanFrom + (leanTo - leanFrom) * u * u * (3 - 2 * u)
    }

    func lean(to angle: Double, over seconds: Double) {
        let now = Date.now
        leanFrom = lean(at: now)
        leanTo = angle
        leanT0 = now
        leanDur = seconds
    }

    /// The right cheek, where a kiss lands.
    func cheek(at now: Date) -> CGPoint {
        let r = height * (isKid ? 0.12 : 0.095)
        return CGPoint(x: x(at: now) + r * 0.7, y: baseY - rise(at: now) - height + r * 1.28)
    }

    /// Coming from the right: where to stand, how far to lean and how high to rise so the lips land on `cheek`.
    func kissStance(for cheek: CGPoint) -> (x: Double, angle: Double, rise: Double) {
        let r = height * (isKid ? 0.12 : 0.095)
        let mouth = height - r * 0.52
        let h = baseY - cheek.y
        let angle = max(0.21, acos(min(1, h / mouth)))
        return (cheek.x + mouth * sin(angle), -angle, max(0, h - mouth * cos(angle)))
    }

    /// The middle of the face, for close-ups and powder puffs.
    func face(at now: Date) -> CGPoint {
        let r = height * (isKid ? 0.12 : 0.095)
        return CGPoint(x: x(at: now), y: baseY - rise(at: now) - height + r)
    }
}

/// A powder puff flying in to pat a face, then flying away again.
struct Puff: Identifiable {
    let id = UUID()
    let from: CGPoint
    let target: CGPoint
    let away: CGPoint
    let t0: Date
    let inDur = 0.7
    let patDur = 0.35
    let outDur = 0.7
    let color: Color

    func position(at now: Date) -> CGPoint? {
        let t = now.timeIntervalSince(t0)
        if t < 0 || t > inDur + patDur + outDur { return nil }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ u: Double) -> CGPoint {
            let s = u * u * (3 - 2 * u)
            return CGPoint(x: a.x + (b.x - a.x) * s, y: a.y + (b.y - a.y) * s - sin(u * .pi) * 60)
        }
        if t < inDur { return lerp(from, target, t / inDur) }
        if t < inDur + patDur {
            let u = (t - inDur) / patDur
            return CGPoint(x: target.x, y: target.y - 8 * sin(u * .pi * 2))
        }
        return lerp(target, away, (t - inDur - patDur) / outDur)
    }
}

/// The video poker machine's perfume nozzle: an arm swings out from the cabinet
/// and sprays a mist at a face for `dur` seconds.
struct PerfumeBlast {
    let cabinet: CGPoint
    let nozzle: CGPoint
    let target: CGPoint
    let t0: Date
    let dur: Double

    /// 0 → 1 as the arm swings out, before spraying starts.
    func reach(at now: Date) -> Double {
        let u = min(1, max(0, 1 + now.timeIntervalSince(t0) / 1.0))
        return u * u * (3 - 2 * u)
    }

    /// Seconds into the spray, or nil when it isn't spraying.
    func spray(at now: Date) -> Double? {
        let t = now.timeIntervalSince(t0)
        return t >= 0 && t <= dur ? t : nil
    }
}

/// The salon's retractable mirror: a wide glass that lowers from the ceiling over the new girls (drop 0 = up, 1 = down).
struct RetractMirror {
    var from = 0.0
    var to = 0.0
    var t0 = Date.distantPast
    var dur = 2.0

    func drop(at now: Date) -> Double {
        let u = min(1, max(0, now.timeIntervalSince(t0) / dur))
        return from + (to - from) * u * u * (3 - 2 * u)
    }
}

/// A camera move for close-ups: centre and zoom, eased between two shots.
struct Camera {
    var from = (CGPoint(x: Stage.W / 2, y: Stage.H / 2), 1.0)
    var to = (CGPoint(x: Stage.W / 2, y: Stage.H / 2), 1.0)
    var t0 = Date.distantPast
    var dur = 0.0

    func shot(at now: Date) -> (CGPoint, Double) {
        let t = now.timeIntervalSince(t0)
        guard dur > 0, t < dur else { return to }
        if t <= 0 { return from }
        let u = t / dur
        let s = u * u * (3 - 2 * u)
        return (CGPoint(x: from.0.x + (to.0.x - from.0.x) * s, y: from.0.y + (to.0.y - from.0.y) * s),
                from.1 + (to.1 - from.1) * s)
    }
}
