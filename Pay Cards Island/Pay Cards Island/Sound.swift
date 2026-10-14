import AVFoundation

/// Game sounds: a bell for a right guess, a razz for a wrong one, a snap when a card is turned,
/// a blip when a card is taken, a creak-and-sparkle when a chest opens, La Bufadora's rumble and
/// roar, a fanfare for the jackpot, and the Queen of Spades' blown kiss and laugh.
/// Everything is synthesized in the background at launch — there are no audio files.
final class Sound {
    enum Effect { case bell, razz, chest(ChestTier), jackpot, select, flip, rumble, geyser, kiss, laugh }

    static let shared = Sound()
    static let enabledKey = "soundOn"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let blipPlayer = AVAudioPlayerNode()     // selection blips never cut off other sounds
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.rate, channels: 1)!
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    var enabled: Bool { UserDefaults.standard.object(forKey: Sound.enabledKey) as? Bool ?? true }

    private init() {
        #if os(iOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        #endif
        for node in [player, blipPlayer] {
            engine.attach(node)
            try? engine.connectNode(node, to: engine.mainMixerNode, format: format)
        }
        Task.detached(priority: .userInitiated) {
            let waves = Synth.all()
            await self.load(waves)
        }
    }

    private func load(_ waves: [String: [Float]]) {
        for (name, samples) in waves {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
            buffers[name] = buffer
        }
    }

    func play(_ effect: Effect) {
        let name = switch effect {
        case .bell: "bell"
        case .razz: "razz"
        case .chest(let tier): "chest\(tier.rawValue)"
        case .jackpot: "fanfare"
        case .select: "select"
        case .flip: "flip"
        case .rumble: "rumble"
        case .geyser: "geyser"
        case .kiss: "kiss"
        case .laugh: "laugh"
        }
        guard enabled, let buffer = buffers[name] else { return }
        if !engine.isRunning { try? engine.start() }
        let node = switch effect {
        case .select, .flip: blipPlayer
        default: player
        }
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        try? node.playAudio()
    }
}

/// Pure waveform math, safe to run off the main thread.
nonisolated enum Synth {
    static let rate = 44_100.0

    static func all() -> [String: [Float]] {
        var w: [String: [Float]] = [:]

        // Bell: an E6 strike with the inharmonic overtones of a real bell, ringing out.
        w["bell"] = render(seconds: 1.6) { t in
            let f = 1318.5
            let strike = min(1, t / 0.002)
            let tone = sin(2 * .pi * f * t) * exp(-2.8 * t)
                + 0.5 * sin(2 * .pi * f * 2.76 * t) * exp(-5 * t)
                + 0.25 * sin(2 * .pi * f * 5.4 * t) * exp(-9 * t)
            return 0.3 * strike * tone
        }

        // Razz: two detuned, sagging sawtooth buzzes with a raspberry flutter.
        w["razz"] = render(seconds: 0.85) { t in
            let sag = 1 - 0.12 * t
            let buzz = saw(92 * sag * t) + saw(97 * sag * t)
            let flutter = 0.65 + 0.35 * sin(2 * .pi * 28 * t)
            let env = min(1, t / 0.01) * min(1, (0.85 - t) / 0.12)
            return 0.14 * buzz * flutter * env
        }

        // Select: a quick upward "blip" with a soft click at the front.
        w["select"] = render(seconds: 0.11) { t in
            let phase = 2 * .pi * (900 * t + 2600 * t * t)      // 900 Hz sweeping up
            let click = t < 0.004 ? (1 - t / 0.004) * 0.5 : 0
            return 0.22 * (sin(phase) * exp(-32 * t) * min(1, t / 0.002) + click)
        }

        // Chest: a creaking hinge, then a rising sparkle — 2, 3 or 5 notes for bronze, silver, gold.
        let notes = [1046.5, 1318.5, 1568.0, 2093.0, 2637.0]      // C6 E6 G6 C7 E7
        for (tier, count) in [2, 3, 5].enumerated() {
            w["chest\(tier)"] = render(seconds: 0.45 + Double(count) * 0.09 + 0.8) { t in
                var out = 0.0
                if t < 0.4 {
                    // Wobbling low sawtooth (integrated phase) with ratcheting clicks.
                    let cycles = 70 * t - 40 / (2 * .pi * 3) * cos(2 * .pi * 3 * t)
                        - 15 / (2 * .pi * 17) * cos(2 * .pi * 17 * t)
                    let ratchet = pow(abs(sin(2 * .pi * 22 * t)), 6)
                    out += 0.2 * saw(cycles) * ratchet * min(1, t / 0.02) * min(1, (0.4 - t) / 0.05)
                }
                for n in 0..<count {
                    let s = t - 0.45 - Double(n) * 0.09
                    guard s > 0 else { continue }
                    let f = notes[n]
                    out += 0.13 * min(1, s / 0.003) * exp(-4.5 * s)
                        * (sin(2 * .pi * f * s) + 0.3 * sin(2 * .pi * f * 3.01 * s))
                }
                return out
            }
        }

        // Flip: a short snap of filtered noise with a soft card-on-felt thump.
        var noise = Noise(seed: 7)
        w["flip"] = render(seconds: 0.12) { t in
            let snap = noise.next() * exp(-60 * t)
            return 0.35 * snap + 0.2 * sin(2 * .pi * 140 * t) * exp(-40 * t)
        }

        // Rumble: a low, swelling growl from under the rocks.
        var low = 0.0
        w["rumble"] = render(seconds: 1.9) { t in
            low += (noise.next() - low) * 0.02
            let growl = sin(2 * .pi * 48 * t) + 0.6 * sin(2 * .pi * 71 * t + sin(2 * .pi * 3 * t))
            let env = min(1, t / 1.2) * min(1, (1.9 - t) / 0.2)
            return env * (0.18 * growl * (0.7 + 0.3 * sin(2 * .pi * 7 * t)) + 1.6 * low)
        }

        // Geyser: a whoomp, then a roaring hiss of spray that slowly settles.
        var body = 0.0
        w["geyser"] = render(seconds: 2.4) { t in
            let n = noise.next()
            body += (n - body) * 0.12
            let whoomp = sin(2 * .pi * (70 - 30 * t) * t) * exp(-6 * t)
            let env = min(1, t / 0.05) * exp(-1.1 * t)
            return 0.35 * whoomp + env * (0.5 * body + 0.12 * n)
        }

        // Jackpot: "ta-ta-ta-TAAA" (C5 E5 G5 C6), swelling into a held C-major chord under a chime shower.
        let calls: [(start: Double, length: Double, freq: Double)] = [
            (0.00, 0.14, 523.25), (0.16, 0.14, 659.25), (0.32, 0.14, 783.99), (0.48, 2.10, 1046.5),
            (0.48, 2.10, 523.25), (0.48, 2.10, 659.25), (0.48, 2.10, 783.99),
        ]
        let chimes = [2093.0, 2637.0, 3136.0, 2349.3, 3520.0, 2793.8, 4186.0, 3951.1]
        w["fanfare"] = render(seconds: 3.2) { t in
            var out = 0.0
            for c in calls {
                let s = t - c.start
                guard s > 0, s < c.length else { continue }
                let env = min(1, s / 0.02) * min(1, (c.length - s) / 0.25) * (c.length > 1 ? exp(-0.35 * s) : 1)
                out += 0.055 * env * brass(c.freq, s)
            }
            for n in 0..<28 {
                let s = t - 0.55 - Double(n) * 0.075
                guard s > 0, s < 0.6 else { continue }
                out += 0.045 * exp(-7 * s) * min(1, s / 0.003) * sin(2 * .pi * chimes[(n * 5) % chimes.count] * s)
            }
            return out
        }

        // Kiss: a lip smack, then a breathy, sliding "mwah".
        var breath = 0.0
        w["kiss"] = render(seconds: 0.75) { t in
            let n = noise.next()
            breath += (n - breath) * 0.25
            let smack = (0.5 * n + sin(2 * .pi * 1_900 * t)) * exp(-90 * t)
            let s = t - 0.07
            guard s > 0 else { return 0.4 * smack }
            let f = 330 - 110 * min(1, s / 0.5)
            let open = min(1, s / 0.18)                        // "m" opening into "ah"
            var voice = 0.0
            for k in 1...6 { voice += sin(2 * .pi * Double(k) * f * s) * pow(open, Double(k - 1) * 0.5) / Double(k) }
            let env = min(1, s / 0.04) * min(1, (0.68 - s) / 0.25)
            return 0.4 * smack * exp(-40 * s) + max(0, env) * (0.16 * voice + 0.12 * breath)
        }

        // Laugh: a run of breathy, falling "ha"s on the Queen's beat, ending in a long "haaa".
        var air = 0.0
        let beat = 0.22, has = 10
        w["laugh"] = render(seconds: beat * Double(has) + 0.75) { t in
            let n = noise.next()
            air += (n - air) * 0.3
            let i = min(has, Int(t / beat))
            let s = t - Double(i) * beat
            let len = i == has ? 0.7 : beat * 0.75
            guard s < len else { return 0 }
            let f = (560 - 16 * Double(i)) * (1 - 0.12 * s / len)
            let env = min(1, s / 0.015) * min(1, (len - s) / 0.06) * (1 - 0.04 * Double(i))
            var voice = 0.0
            for k in 1...7 {   // a bright "ah" vowel
                let fk = Double(k) * f
                voice += sin(2 * .pi * fk * t) * (fk > 700 && fk < 1_400 ? 1.0 : 0.35) / Double(k)
            }
            let h = exp(-30 * s)   // the "h" of each "ha"
            return env * (0.17 * voice * (1 - 0.6 * h) + (0.08 + 0.25 * h) * air)
        }
        return w
    }

    /// Deterministic white noise, so the effects sound the same every launch.
    struct Noise {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53) * 2 - 1
        }
    }

    private static func saw(_ x: Double) -> Double { 2 * (x - (x + 0.5).rounded(.down)) }

    /// Brass-like tone: six harmonics with a gentle vibrato that comes in after the attack.
    private static func brass(_ f: Double, _ t: Double) -> Double {
        let vib = 1 + 0.004 * sin(2 * .pi * 5.5 * t) * min(1, max(0, t - 0.2) / 0.3)
        var v = 0.0
        for k in 1...6 { v += sin(2 * .pi * Double(k) * f * vib * t) / pow(Double(k), 1.2) }
        return v
    }

    private static func render(seconds: Double, _ wave: (Double) -> Double) -> [Float] {
        (0..<Int(seconds * rate)).map { Float(wave(Double($0) / rate)) }
    }
}
