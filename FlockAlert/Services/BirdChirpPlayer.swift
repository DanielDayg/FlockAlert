import AVFoundation

// Synthesises a short two-note bird chirp entirely in memory — no audio file needed.
// Call chirp() from any thread; playback is dispatched internally.
final class BirdChirpPlayer {

    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let sampleRate = 44100.0

    init() {
        engine.attach(playerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func chirp() {
        // Mix with other audio — ambient category requires no background audio mode
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)

        // Restart engine if the system stopped it (e.g. after backgrounding)
        if !engine.isRunning {
            try? engine.start()
        }
        guard engine.isRunning else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let totalFrames = AVAudioFrameCount(sampleRate * 0.55)

        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return }
        buf.frameLength = totalFrames
        let ptr = buf.floatChannelData![0]

        // Two notes separated by a 60 ms gap — sounds like a canary tweet
        let noteDuration = 0.20   // seconds
        let noteFrames   = Int(sampleRate * noteDuration)
        let gapFrames    = Int(sampleRate * 0.060)

        for note in 0..<2 {
            let start = note * (noteFrames + gapFrames)
            // First note: 2800→3200→2800 Hz  |  Second note: 3100→3600→3100 Hz
            let baseFreq: Double = note == 0 ? 2800.0 : 3100.0
            let sweep:    Double = note == 0 ?  400.0 :  500.0

            for i in 0..<noteFrames {
                let frame = start + i
                guard frame < Int(totalFrames) else { break }
                let t        = Double(i) / sampleRate
                let progress = Double(i) / Double(noteFrames)

                // Frequency arc (up then down)
                let freq = baseFreq + sweep * sin(.pi * progress)

                // Amplitude: fast attack (first 4%), sustain, decay last 25%
                let attack = min(1.0, Double(i) / Double(max(1, noteFrames / 25)))
                let decay  = progress > 0.75 ? 1.0 - (progress - 0.75) / 0.25 : 1.0
                let amp    = attack * decay * 0.65

                ptr[frame] = Float(amp * sin(2.0 * .pi * freq * t))
            }
        }

        if !playerNode.isPlaying { playerNode.play() }
        playerNode.scheduleBuffer(buf, completionHandler: nil)
    }
}
