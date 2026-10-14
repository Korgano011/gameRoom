import AVFoundation

/// Realtime-synthesised sounds (no audio files): the salon's engine hum, the beam, the
/// transformation machine's warble, powder-puff pats, a perfume atomizer's hiss, a button beep, strap clunks, a chime,
/// a card flick, a coin payout, a tinkle in the toilet and a flush.
nonisolated final class Synth: @unchecked Sendable {
    var humT: Float = 0
    var beamT: Float = 0
    var zapT: Float = 0
    var muted = false
    var chimeTrig = false
    var beepTrig = false
    var clunkTrig = false
    var puffTrig = false
    var cardTrig = false
    var coinTrig = false
    var peeT: Float = 0
    var perfumeT: Float = 0
    var flushTrig = false
    var razzTrig = false
    var sampleRate: Float = 44100

    private var hum: Float = 0, beam: Float = 0, zap: Float = 0
    private var humPh: Float = 0, beamPh: Float = 0, beamLfo: Float = 0, zapPh: Float = 0, zapLfo: Float = 0
    private var lp: Float = 0
    private var chimeT: Float = 3, beepT: Float = 1, beepPh: Float = 0, clunkT: Float = 1
    private var puffT: Float = 1, cardT: Float = 1, coinT: Float = 2
    private var pee: Float = 0, peeLp: Float = 0, peeLp2: Float = 0, peeWob: Float = 0, peeWobT: Float = 0, tinklePh: Float = 0, tinkleF: Float = 1200
    private var perfume: Float = 0, perfumeLp: Float = 0, perfumeHp: Float = 0
    private var flushT: Float = 5, flushLp: Float = 0, flushPh: Float = 0
    private var razzT: Float = 2, razzPh: Float = 0, razzLp: Float = 0
    private var seed: UInt32 = 2463534242

    private func rand() -> Float {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    func render(_ frames: Int, _ out: UnsafeMutablePointer<Float>) {
        let sr = sampleRate
        let twoPi = 2 * Float.pi
        if chimeTrig { chimeT = 0; chimeTrig = false }
        if beepTrig { beepT = 0; beepTrig = false }
        if clunkTrig { clunkT = 0; clunkTrig = false }
        if puffTrig { puffT = 0; puffTrig = false }
        if cardTrig { cardT = 0; cardTrig = false }
        if coinTrig { coinT = 0; coinTrig = false }
        if flushTrig { flushT = 0; flushTrig = false }
        if razzTrig { razzT = 0; razzTrig = false }
        for i in 0..<frames {
            hum += (humT - hum) * 0.0008
            beam += (beamT - beam) * 0.002
            zap += (zapT - zap) * 0.002
            let n = rand()
            var s: Float = 0
            if hum > 0.001 {
                humPh += twoPi * 62 / sr
                s += (sin(humPh) * 0.5 + sin(humPh * 2.01) * 0.25) * 0.18 * hum
            }
            if beam > 0.001 {
                beamLfo += twoPi * 3 / sr
                beamPh += twoPi * (520 + 80 * sin(beamLfo)) / sr
                lp += (n - lp) * 0.05
                s += (sin(beamPh) * 0.07 + lp * 0.12) * beam
            }
            if zap > 0.001 {
                zapLfo += twoPi * 7 / sr
                zapPh += twoPi * (880 + 300 * sin(zapLfo)) / sr
                s += (sin(zapPh) * 0.06 + sin(zapPh * 1.5) * 0.04) * zap
            }
            if chimeT < 2.5 {
                chimeT += 1 / sr
                for (k, f) in [1046.5, 1318.5, 1568.0, 2093.0].enumerated() {
                    let at = Float(k) * 0.12
                    if chimeT > at {
                        let u = chimeT - at
                        s += sin(twoPi * Float(f) * u) * 0.1 * exp(-u * 3)
                    }
                }
            }
            if beepT < 0.3 {
                beepT += 1 / sr
                beepPh += twoPi * (700 + 500 * beepT) / sr
                s += (sin(beepPh) > 0 ? 0.09 : -0.09) * (1 - beepT / 0.3)
            }
            if clunkT < 0.25 {
                clunkT += 1 / sr
                s += (sin(twoPi * 95 * clunkT) * 0.4 + n * 0.15) * exp(-clunkT * 25)
            }
            if puffT < 0.25 {
                puffT += 1 / sr
                lp += (n - lp) * 0.08
                s += lp * 0.9 * exp(-puffT * 18)
            }
            if cardT < 0.06 {
                cardT += 1 / sr
                s += n * 0.3 * (1 - cardT / 0.06)
            }
            if coinT < 1.0 {
                coinT += 1 / sr
                for (at, f): (Float, Float) in [(0, 2637), (0.08, 3136), (0.16, 3951), (0.3, 3520)] where coinT > at {
                    let u = coinT - at
                    s += sin(twoPi * f * u) * 0.1 * exp(-u * 9)
                }
            }
            if pee > 0.001 || peeT > 0 {
                pee += (peeT - pee) * 0.0006
                // A thin stream into water: band-limited hiss that wobbles, plus little tinkling tones.
                peeWobT -= 1 / sr
                if peeWobT <= 0 {
                    peeWobT = 0.04 + abs(rand()) * 0.08
                    peeWob = 0.7 + abs(rand()) * 0.3
                    tinkleF = 1100 + abs(rand()) * 900
                }
                peeLp += (n - peeLp) * 0.35
                peeLp2 += (peeLp - peeLp2) * 0.06
                let hiss = (peeLp - peeLp2) * 0.55
                tinklePh += twoPi * tinkleF / sr
                s += (hiss + sin(tinklePh) * 0.025) * peeWob * pee
            }
            if perfume > 0.001 || perfumeT > 0 {
                perfume += (perfumeT - perfume) * 0.004
                // An atomizer's steady hiss: bright, high-passed noise with a little flutter.
                perfumeLp += (n - perfumeLp) * 0.6
                perfumeHp += (perfumeLp - perfumeHp) * 0.15
                s += (perfumeLp - perfumeHp) * 0.45 * (0.9 + 0.1 * sin(Float(i) * 0.002)) * perfume
            }
            if flushT < 4.5 {
                flushT += 1 / sr
                // The rush of a flush: swells, then swirls away with a low gurgle.
                let env = min(1, flushT / 0.25) * exp(-max(0, flushT - 0.6) * 0.9)
                flushLp += (n - flushLp) * (0.04 + 0.12 * exp(-flushT))
                flushPh += twoPi * (70 + 25 * sin(flushT * 9)) / sr
                s += (flushLp * 1.1 + sin(flushPh) * 0.12 * min(1, flushT)) * env
            }
            if razzT < 1.1 {
                razzT += 1 / sr
                // A raspberry: a buzzy low saw with lips flapping ~28 times a second, sagging in pitch.
                let env = min(1, razzT / 0.04) * (razzT > 0.85 ? max(0, 1 - (razzT - 0.85) / 0.25) : 1)
                razzPh += (150 - 45 * razzT) / sr
                let saw = (razzPh - floorf(razzPh)) * 2 - 1
                let flap = 0.55 + 0.45 * sin(twoPi * 28 * razzT)
                razzLp += (saw + n * 0.35 - razzLp) * 0.25
                s += razzLp * 0.55 * flap * env
            }
            out[i] = muted ? 0 : tanhf(s) * 0.6
        }
    }

    static func makeNode(_ synth: Synth, _ format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frames, abl in
            let list = UnsafeMutableAudioBufferListPointer(abl)
            guard let first = list.first, let data = first.mData else { return noErr }
            let p = data.bindMemory(to: Float.self, capacity: Int(frames))
            synth.render(Int(frames), p)
            for b in list.dropFirst() {
                if let d = b.mData { memcpy(d, data, Int(frames) * MemoryLayout<Float>.size) }
            }
            return noErr
        }
    }
}

enum Voice {
    case princess, guy, girl, boy, kidGirl
}

final class Sound {
    private let synth = Synth()
    private var engine: AVAudioEngine?
    private let speech = AVSpeechSynthesizer()

    var muted = false {
        didSet {
            synth.muted = muted
            if muted { speech.stopSpeaking(at: .immediate) }
        }
    }
    var voiceOn = true

    func prepare() {
        guard engine == nil else { return }
        #if os(iOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let e = AVAudioEngine()
        let sr = e.outputNode.outputFormat(forBus: 0).sampleRate
        synth.sampleRate = Float(sr > 0 ? sr : 44100)
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: Double(synth.sampleRate), channels: 1) else { return }
        let node = Synth.makeNode(synth, fmt)
        e.attach(node)
        try? e.connectNode(node, to: e.mainMixerNode, format: fmt)
        do { try e.start(); engine = e } catch { engine = nil }
    }

    /// The best-quality installed US English male voice, if there is one.
    private static let maleVoice: AVSpeechSynthesisVoice? = {
        let males = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" && $0.gender == .male }
        return males.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-US.Aaron")
    }()

    func speak(_ text: String, as voice: Voice) {
        guard !muted, voiceOn else { return }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        switch voice {
        case .princess: u.pitchMultiplier = 1.25; u.rate = 0.38
        case .guy:
            // A real male voice (you, before the salon; the men passing by).
            if let male = Self.maleVoice { u.voice = male; u.pitchMultiplier = 0.95 } else { u.pitchMultiplier = 0.8 }
            u.rate = 0.41
        case .girl: u.pitchMultiplier = 1.45; u.rate = 0.41
        case .boy: u.pitchMultiplier = 1.3; u.rate = 0.43
        case .kidGirl: u.pitchMultiplier = 1.75; u.rate = 0.43
        }
        speech.speak(u)
    }

    func hum(_ on: Bool) { synth.humT = on ? 1 : 0 }
    func beam(_ on: Bool) { synth.beamT = on ? 1 : 0 }
    func zap(_ on: Bool) { synth.zapT = on ? 1 : 0 }
    func stopAll() {
        hum(false); beam(false); zap(false); pee(false); perfume(false)
        speech.stopSpeaking(at: .immediate)
    }
    func chime() { synth.chimeTrig = true }
    func beep() { synth.beepTrig = true }
    func clunk() { synth.clunkTrig = true }
    func puff() { synth.puffTrig = true }
    func card() { synth.cardTrig = true }
    func coin() { synth.coinTrig = true }
    func pee(_ on: Bool) { synth.peeT = on ? 1 : 0 }
    func flush() { synth.flushTrig = true }
    func razz() { synth.razzTrig = true }
    func perfume(_ on: Bool) { synth.perfumeT = on ? 1 : 0 }
}
