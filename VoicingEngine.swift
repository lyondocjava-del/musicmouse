import Foundation

/// Pure port of the voicing logic from MusicMouse.java.
/// All settings the Java version read from Swing widgets live in `VoicingSettings`.
struct VoicingSettings {
    var mode = 0          // 0 Diatonic, 1 Pentatonic, 2 Chromatic, 3 Quartal, 4 Octatonic, 5 Middle Eastern
    var diatonic = 0      // 0 Major, 1 Minor (harmonic minor)
    var treatment = 0     // 0 Chord, 1 Arpeggio, 2 Line, 3 Improv
    var motion = 0        // 0 Parallel, 1 Contrary
    var patternMotion = 0 // 0 Parallel, 1 Contrary
    var axisAssign = 0    // 0: bass on Y, 1: bass on X
    var pairing = 0       // 0 Chord/melody, 1 Voice pairs
    var articulation = 0  // 0 Staccato, 1 Half legato, 2 Legato
    var interval = 4
    var transposition = 0
    var patternIndex = 0
    var patternEnabled = true
    var showPatternMovement = true
    var grouping = false
    var root = 60         // C4
}

struct VoicingEngine {
    static let axisKeyCount = 14

    static let modeSteps: [[Int]] = [
        [0, 2, 4, 5, 7, 9, 11],
        [0, 2, 4, 7, 9],
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        [0, 2, 5, 7, 10],
        [0, 2, 3, 5, 6, 8, 9, 11],
        [0, 1, 4, 5, 7, 8, 11]
    ]
    static let harmonicMinor = [0, 2, 3, 5, 7, 8, 11]
    static let patterns: [[Int]] = [
        [0, 4, 5, 0, 4, 3, 4, 5, 0, 4],
        [0, 2, 4, 7, 4, 2],
        [0, 1, 2, 3, 4, 3, 2, 1],
        [0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1],
        [0, 4, 7, 11, 7, 4, 7, 4],
        [0, 1, 0, 1, 2, 1, 2, 3, 2, 3, 4, 3, 2, 1, 2, 1],
        [0, 2, 3, 4, 5, 6, 5, 4, 3, 2],
        [0, 7, 1, 6, 2, 5, 3, 4, 5, 2, 4, 5, 2, 6, 1, 7],
        [0, 1, 4, 1, 0, 4, 0, 4],
        [0, 7, 0, 0, 2, 1, 2, 4, 3, 2, 1, 2, 0, 0]
    ]

    func currentScale(_ s: VoicingSettings) -> [Int] {
        if s.mode == 0 && s.diatonic == 1 { return VoicingEngine.harmonicMinor }
        return VoicingEngine.modeSteps[s.mode]
    }

    func transposedRoot(_ s: VoicingSettings) -> Int { s.root + s.transposition }

    func scaleDegreeToMidi(base: Int, degree: Int, intervals: [Int]) -> Int {
        let size = intervals.count
        let octave = Int(floor(Double(degree) / Double(size)))
        var step = degree % size
        if step < 0 { step += size }
        return base + octave * 12 + intervals[step]
    }

    func nearestScalePitch(_ target: Int, _ scaleRoot: Int, _ intervals: [Int]) -> Int {
        var best = target
        var bestDistance = Int.max
        var note = max(28, target - 12)
        let top = min(100, target + 12)
        while note <= top {
            let pitchClass = ((note - scaleRoot) % 12 + 12) % 12
            if intervals.contains(pitchClass) {
                let d = abs(note - target)
                if d < bestDistance { best = note; bestDistance = d }
            }
            note += 1
        }
        return best
    }

    func shiftScaleDegrees(_ note: Int, _ degreeOffset: Int, _ tonic: Int, _ scale: [Int]) -> Int {
        var closestDegree = 0
        var closestDistance = Int.max
        var degree = -48
        while degree <= 48 {
            let scalePitch = scaleDegreeToMidi(base: tonic, degree: degree, intervals: scale)
            let d = abs(note - scalePitch)
            if d < closestDistance { closestDistance = d; closestDegree = degree }
            degree += 1
        }
        let shifted = scaleDegreeToMidi(base: tonic, degree: closestDegree + degreeOffset, intervals: scale)
        return nearestScalePitch(shifted, tonic, scale)
    }

    func currentPatternOffset(_ s: VoicingSettings, running: Bool, tick: Int) -> Int {
        if !running || !s.patternEnabled { return 0 }
        let pattern = VoicingEngine.patterns[s.patternIndex]
        return pattern[tick % pattern.count]
    }

    /// The four-voice voicing for a cursor position (pre-pattern, like Java calculateVoicingAt).
    func calculateVoicingAt(_ s: VoicingSettings, x: Int, y: Int, w: Int, h: Int) -> [Int] {
        let scale = currentScale(s)
        let tonic = transposedRoot(s)
        let cx = max(0, min(w - 1, x))
        let cy = max(0, min(h - 1, y))
        let bw = max(1, w)
        let bh = max(1, h)

        let bassDegree = s.axisAssign == 0 ? (bh - 1 - cy) * 14 / bh : cx * 14 / bw
        let leadDegree = s.axisAssign == 0 ? cx * 14 / bw : (bh - 1 - cy) * 14 / bh
        let spread = cx * 5 / bw + 1
        let inversion = cx * 3 / bw
        var notes = [Int](repeating: 0, count: 4)
        notes[0] = scaleDegreeToMidi(base: tonic - 24, degree: bassDegree, intervals: scale)
        notes[1] = scaleDegreeToMidi(base: tonic + 12, degree: leadDegree, intervals: scale)

        let companionA: Int
        let companionB: Int
        if s.pairing == 1 {
            if s.motion == 0 {
                companionA = notes[0] + s.interval + spread
                companionB = notes[1] + s.interval + spread
            } else {
                companionA = tonic + 24 - (notes[0] - (tonic - 24)) + s.interval + spread
                companionB = tonic + 24 - (notes[1] - (tonic + 12)) - s.interval - spread
            }
        } else {
            if s.motion == 1 {
                let contraryAnchor = tonic + 12 - (notes[0] - (tonic - 24))
                companionA = contraryAnchor + s.interval + inversion
                companionB = contraryAnchor + s.interval * 2 + spread
            } else {
                companionA = notes[0] + s.interval + inversion
                companionB = notes[0] + s.interval * 2 + spread
            }
        }
        notes[2] = nearestScalePitch(companionA, tonic, scale)
        notes[3] = nearestScalePitch(companionB, tonic, scale)
        for i in 0..<notes.count { notes[i] = max(28, min(100, notes[i])) }
        return notes
    }

    /// Voicing with the autonomous pattern offset applied (Java calculateVoicing).
    func calculateVoicing(_ s: VoicingSettings, x: Int, y: Int, w: Int, h: Int, running: Bool, tick: Int) -> [Int] {
        var notes = calculateVoicingAt(s, x: x, y: y, w: w, h: h)
        if !running || !s.patternEnabled { return notes }
        var patternOffset = currentPatternOffset(s, running: running, tick: tick)
        if s.patternMotion == 1 { patternOffset = -patternOffset }
        let scale = currentScale(s)
        let tonic = transposedRoot(s)
        for i in 0..<notes.count {
            notes[i] = shiftScaleDegrees(notes[i], patternOffset, tonic, scale)
        }
        return notes
    }

    /// Ghost-cursor position when the autonomous pattern is driving (Java patternCursorPosition).
    func patternCursorPosition(_ s: VoicingSettings, x: Int, y: Int, w: Int, h: Int, running: Bool, tick: Int) -> (Int, Int) {
        var px = x, py = y
        if s.patternEnabled {
            let offset = currentPatternOffset(s, running: running, tick: tick)
            px += offset * max(1, w) / 14
            let dir = s.patternMotion == 0 ? 1 : -1
            py += dir * offset * max(1, h) / 14
        }
        return (max(0, min(w - 1, px)), max(0, min(h - 1, py)))
    }

    static func keyCenter(_ coordinate: Int, _ dimension: Int) -> Int {
        let index = max(0, min(axisKeyCount - 1, coordinate * axisKeyCount / max(1, dimension)))
        return keyCenterForIndex(index, dimension)
    }

    static func keyCenterForIndex(_ index: Int, _ dimension: Int) -> Int {
        (2 * index + 1) * dimension / (2 * axisKeyCount)
    }
}
