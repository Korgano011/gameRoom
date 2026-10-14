import AVFoundation

/// Synthesized sound effects plus spoken dialogue.
final class Sound {
    static let shared = Sound()

    enum Effect: CaseIterable {
        case beep, phaser, torpedo, explosion, alert, hit, transporter, warp, ray, chirp
    }

    enum Voice { case narrator, matt, boss, stranger, man, woman, borg, computer }

    var muted = false
    var voiceOn = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let rate = 44100.0
    private let format: AVAudioFormat
    private var cache: [Effect: AVAudioPCMBuffer] = [:]
    private let speech = AVSpeechSynthesizer()
    private var started = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
    }

    private func start() {
        guard !started else { return }
        started = true
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.6
        try? engine.start()
        player.play()
    }

    func play(_ e: Effect) {
        guard !muted else { return }
        start()
        guard engine.isRunning else { return }
        let buf = cache[e] ?? makeBuffer(e)
        cache[e] = buf
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
    }

    // MARK: synthesis

    private func makeBuffer(_ e: Effect) -> AVAudioPCMBuffer {
        let s = samples(e)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(s.count))!
        buf.frameLength = AVAudioFrameCount(s.count)
        let p = buf.floatChannelData![0]
        for i in 0..<s.count { p[i] = s[i] }
        return buf
    }

    private func samples(_ e: Effect) -> [Float] {
        func gen(_ dur: Double, _ f: (Double, Double) -> Double) -> [Float] {
            let n = Int(dur * rate)
            var out = [Float](repeating: 0, count: n)
            for i in 0..<n {
                let t = Double(i) / rate
                out[i] = Float(f(t, t / dur))
            }
            return out
        }
        var seed: UInt64 = 0x2355
        func noise() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(Int64(bitPattern: seed >> 11) % 2000) / 1000.0
        }
        switch e {
        case .beep:
            return gen(0.12) { t, u in sin(2 * .pi * 1320 * t) * 0.35 * (1 - u) }
        case .chirp:
            return gen(0.18) { t, u in sin(2 * .pi * (900 + 900 * u) * t) * 0.3 * (1 - u) }
        case .phaser:
            var ph = 0.0
            return gen(0.7) { t, u in
                ph += 2 * .pi * (1800 - 900 * u + 120 * sin(t * 90)) / 44100
                return (sin(ph) * 0.5 + sin(ph * 1.5) * 0.2) * 0.4 * min(1, (1 - u) * 4)
            }
        case .torpedo:
            var ph = 0.0
            return gen(0.55) { _, u in
                ph += 2 * .pi * (700 * pow(1 - u, 2) + 120) / 44100
                return sin(ph) * 0.5 * (1 - u)
            }
        case .explosion:
            var lp = 0.0
            return gen(1.2) { _, u in
                lp += (noise() - lp) * (0.06 * (1 - u) + 0.01)
                return lp * 1.6 * pow(1 - u, 1.6)
            }
        case .hit:
            var lp = 0.0
            return gen(0.45) { t, u in
                lp += (noise() - lp) * 0.2
                return (lp * 0.8 + sin(2 * .pi * 70 * t) * 0.5) * (1 - u)
            }
        case .alert:
            var ph = 0.0
            return gen(1.1) { t, _ in
                let cyc = t.truncatingRemainder(dividingBy: 0.55) / 0.55
                ph += 2 * .pi * (500 + 500 * cyc) / 44100
                return sin(ph) * 0.3 * (cyc < 0.9 ? 1 : 0)
            }
        case .transporter:
            return gen(1.4) { t, u in
                let shimmer = sin(2 * .pi * 2400 * t) * sin(2 * .pi * 7 * t) + sin(2 * .pi * 3100 * t) * 0.5
                return shimmer * 0.16 * sin(.pi * u)
            }
        case .warp:
            var ph = 0.0
            return gen(1.3) { _, u in
                ph += 2 * .pi * (60 + 500 * u * u) / 44100
                return (sin(ph) + noise() * 0.15) * 0.35 * sin(.pi * u)
            }
        case .ray:
            return gen(1.0) { t, u in
                (sin(2 * .pi * 220 * t + 4 * sin(2 * .pi * 11 * t)) * 0.4 + sin(2 * .pi * 440 * t) * 0.15) * sin(.pi * u)
            }
        }
    }

    // MARK: speech

    func say(_ text: String, as voice: Voice) {
        stopSpeaking()
        guard voiceOn, !muted, !text.isEmpty else { return }
        let u = AVSpeechUtterance(string: text)
        u.voice = pickVoice(voice)
        switch voice {
        case .borg: u.rate = 0.42; u.pitchMultiplier = 0.6
        case .computer: u.rate = 0.5; u.pitchMultiplier = 1.15
        case .boss: u.rate = 0.5; u.pitchMultiplier = 0.85
        case .stranger: u.rate = 0.46; u.pitchMultiplier = 1.1
        default: u.rate = 0.5
        }
        speech.speak(u)
    }

    func stopSpeaking() {
        if speech.isSpeaking { speech.stopSpeaking(at: .immediate) }
    }

    private lazy var voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }

    private func pickVoice(_ v: Voice) -> AVSpeechSynthesisVoice? {
        let males = voices.filter { $0.gender == .male }
        let females = voices.filter { $0.gender == .female }
        func pick(_ list: [AVSpeechSynthesisVoice], _ i: Int) -> AVSpeechSynthesisVoice? {
            let us = list.filter { $0.language == "en-US" }
            let pool = us.isEmpty ? list : us
            return pool.isEmpty ? AVSpeechSynthesisVoice(language: "en-US") : pool[i % pool.count]
        }
        switch v {
        case .matt, .narrator: return pick(males, 0)
        case .boss, .borg: return pick(males, 1)
        case .man: return pick(males, 2)
        case .stranger, .computer: return pick(females, 0)
        case .woman: return pick(females, 1)
        }
    }
}
