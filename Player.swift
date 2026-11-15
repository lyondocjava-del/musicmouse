import Foundation
import Combine

/// The runtime role the Java MusicMouse JFrame played: holds the musical state,
/// drives the tick clock, and routes notes to the MIDI synth.
final class Player: ObservableObject {
    @Published var settings = VoicingSettings()
    @Published var cursorX = 0
    @Published var cursorY = 0
    @Published var haveCursor = false
    @Published var running = false
    @Published var gridW = 1
    @Published var gridH = 1
    @Published var voiceEnabled = [true, true, true, true]
    @Published var voiceChannelIndices = [0, 1, 2, 3]
    @Published var axisNotes: [Int] = [-1, -1, -1, -1]
    @Published var activeNotes: [Int] = [-1, -1, -1, -1]
    @Published var tempo1 = 95
    @Published var tempo2 = 200
    @Published var fastTempo = 600
    @Published var alternateTempo = false
    @Published var instrumentProgram = 0
    @Published var status = "Move the cursor on the grid. Tap Play or touch to start sound."
    @Published var tick = 0

    let engine = VoicingEngine()
    let synth = MidiSynth()

    private var clock: Timer?
    private var lastMovementNanos: UInt64 = 0
    private var smoothedMouseSpeed = 0.0
    private var userHasToggledPlayback = false
    private var noteGeneration = [0, 0, 0, 0]
    private var improvVoiceOrder = [0, 1, 2, 3]

    init() { applyInstrument(0) }

    var activeTempo: Int { alternateTempo ? tempo2 : tempo1 }

    var currentVoicing: [Int] {
        engine.calculateVoicing(settings, x: cursorX, y: cursorY, w: gridW, h: gridH,
                                running: running, tick: tick)
    }

    func applyInstrument(_ program: Int) {
        instrumentProgram = program
        for ch in 0..<16 { synth.programChange(ch, program) }
    }

    func testSound() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let code = self.synth.testScale()
            DispatchQueue.main.async {
                self.status = "\(self.synth.status) · test event rc=\(code)"
            }
        }
    }

    func toggleRunning() {
        userHasToggledPlayback = true
        running.toggle()
        if running {
            if !haveCursor {
                cursorX = gridW / 2
                cursorY = gridH / 2
                haveCursor = true
            }
            tick = 0
            scheduleClock()
            playTick()
            status = "Playing - move your finger to shape the voicing."
        } else {
            clock?.invalidate()
            silence()
            status = "Stopped - move to set a new position."
        }
    }

    func silence() {
        for v in 0..<4 { stopVoice(v) }
        synth.allNotesOff()
    }

    func stopVoice(_ voice: Int) {
        noteGeneration[voice] += 1
        if activeNotes[voice] >= 0 { synth.noteOff(voiceChannelIndices[voice], activeNotes[voice]) }
        activeNotes[voice] = -1
    }

    func updateAxisKeys() {
        let notes = engine.calculateVoicingAt(settings, x: cursorX, y: cursorY, w: gridW, h: gridH)
        axisNotes = notes
    }

    func harmonyChanged() {
        if !running || tick == 0 { return }
        for v in 0..<4 { stopVoice(v) }
        tick -= 1
        playTick()
    }

    private func updateClockDelay(_ speed: Double) {
        let baseTempo = Double(activeTempo)
        let fast = max(baseTempo, Double(fastTempo))
        let movement = min(max(0.0, speed) / 8000.0, 1.0)
        let effective = baseTempo + (fast - baseTempo) * movement
        scheduleClock(interval: max(0.025, 60.0 / effective))
    }

    private func scheduleClock(interval: Double? = nil) {
        clock?.invalidate()
        let delay = interval ?? max(0.025, 60.0 / Double(activeTempo))
        clock = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { [weak self] _ in
            self?.playTick()
        }
    }

    func playTick() {
        guard running else { return }
        let notes = engine.calculateVoicing(settings, x: cursorX, y: cursorY, w: gridW, h: gridH,
                                            running: running, tick: tick)
        var arpeggioVoice = -1
        if settings.treatment == 1 {
            let order = [0, 1, 2, 3].sorted { notes[$0] < notes[$1] }
            arpeggioVoice = order[tick % order.count]
        } else if settings.treatment == 3 {
            if tick % improvVoiceOrder.count == 0 {
                for i in stride(from: improvVoiceOrder.count - 1, through: 1, by: -1) {
                    let j = Int.random(in: 0...i)
                    improvVoiceOrder.swapAt(i, j)
                }
            }
        }
        for voice in 0..<4 {
            let due: Bool
            switch settings.treatment {
            case 0: due = true
            case 1: due = voice == arpeggioVoice
            case 2: due = voice == tick % 4
            default: due = voice == improvVoiceOrder[tick % improvVoiceOrder.count]
            }
            if !voiceEnabled[voice] || !due {
                if settings.articulation != 2 { stopVoice(voice) }
                continue
            }
            let note = notes[voice]
            if settings.grouping && activeNotes[voice] == note { continue }
            if settings.articulation == 2 && activeNotes[voice] == note { continue }
            stopVoice(voice)
            synth.noteOn(voiceChannelIndices[voice], note, voice == 0 ? 104 : 88)
            activeNotes[voice] = note
        }
        if settings.articulation < 2 {
            let fraction = settings.articulation == 0 ? 0.25 : 0.95
            let duration = max(0.04, 60.0 / Double(activeTempo) * fraction)
            let generation = noteGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self = self else { return }
                for v in 0..<4 where generation[v] == self.noteGeneration[v] { self.stopVoice(v) }
            }
        }
        tick += 1
    }

    func cursorMoved(x: Double, y: Double) {
        let now = DispatchTime.now().uptimeNanoseconds
        let snappedX = VoicingEngine.keyCenter(Int(x), max(1, gridW))
        let snappedY = VoicingEngine.keyCenter(Int(y), max(1, gridH))
        let moved = snappedX != cursorX || snappedY != cursorY
        let dx = snappedX - cursorX
        let dy = snappedY - cursorY
        cursorX = snappedX
        cursorY = snappedY
        haveCursor = true
        if moved {
            let elapsed = now &- lastMovementNanos
            if elapsed > 0 {
                let instantSpeed = Double(dx * dx + dy * dy).squareRoot() / (Double(elapsed) / 1e9)
                smoothedMouseSpeed = smoothedMouseSpeed == 0
                    ? instantSpeed
                    : smoothedMouseSpeed * 0.7 + instantSpeed * 0.3
            }
            lastMovementNanos = now
        }
        if moved { updateAxisKeys() }
        if running && moved {
            for v in 0..<4 { stopVoice(v) }
            updateClockDelay(smoothedMouseSpeed)
            playTick()
        }
        if !running {
            if !userHasToggledPlayback {
                toggleRunning()
                return
            }
            status = "Preview - voices: \(currentVoicing) - tap Play"
        }
    }
}
