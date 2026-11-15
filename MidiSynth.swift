import AVFoundation
import AudioToolbox

/// AVAudioUnitSampler driven by the bundled TimGM6mb.sf2 (full General MIDI bank).
/// Mirrors the javax.sound.midi Synthesizer/MidiChannel calls used by the Java version.
final class MidiSynth {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    var status = "uninitialized"
    private var loadedPrograms = Set<Int>()

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            try engine.start()
            try loadProgram(0)
            status = "synth running=\(engine.isRunning)"
        } catch {
            status = "audio error: \(error.localizedDescription)"
        }
    }

    /// Loads a GM preset from the bundled sf2 (TimGM6mb keeps melodic presets at bank 0).
    private func loadProgram(_ program: Int) throws {
        if loadedPrograms.contains(program) { return }
        guard let url = Bundle.main.url(forResource: "TimGM6mb", withExtension: "sf2") else {
            status = "error: TimGM6mb.sf2 not in bundle"
            return
        }
        do {
            try sampler.loadSoundBankInstrument(at: url, program: UInt8(program),
                                                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                bankLSB: 0)
        } catch {
            // Some sf2 files number presets at bank 0 rather than the melodic-bank convention.
            try sampler.loadSoundBankInstrument(at: url, program: UInt8(program),
                                                bankMSB: 0, bankLSB: 0)
        }
        loadedPrograms.insert(program)
    }

    /// GM instrument names for the picker (programs 0-127).
    static let gmNames: [String] = [
        "Acoustic Grand Piano", "Bright Acoustic Piano", "Electric Grand Piano", "Honky-tonk Piano",
        "Electric Piano 1", "Electric Piano 2", "Harpsichord", "Clavinet",
        "Celesta", "Glockenspiel", "Music Box", "Vibraphone", "Marimba", "Xylophone", "Tubular Bells", "Dulcimer",
        "Drawbar Organ", "Percussive Organ", "Rock Organ", "Church Organ", "Reed Organ", "Accordion", "Harmonica", "Tango Accordion",
        "Acoustic Guitar (nylon)", "Acoustic Guitar (steel)", "Electric Guitar (jazz)", "Electric Guitar (clean)",
        "Electric Guitar (muted)", "Overdriven Guitar", "Distortion Guitar", "Guitar harmonics",
        "Acoustic Bass", "Electric Bass (finger)", "Electric Bass (pick)", "Fretless Bass",
        "Slap Bass 1", "Slap Bass 2", "Synth Bass 1", "Synth Bass 2",
        "Violin", "Viola", "Cello", "Contrabass", "Tremolo Strings", "Pizzicato Strings", "Orchestral Harp", "Timpani",
        "String Ensemble 1", "String Ensemble 2", "SynthStrings 1", "SynthStrings 2", "Choir Aahs", "Voice Oohs", "Synth Voice", "Orchestra Hit",
        "Trumpet", "Trombone", "Tuba", "Muted Trumpet", "French Horn", "Brass Section", "SynthBrass 1", "SynthBrass 2",
        "Soprano Sax", "Alto Sax", "Tenor Sax", "Baritone Sax", "Oboe", "English Horn", "Bassoon", "Clarinet",
        "Piccolo", "Flute", "Recorder", "Pan Flute", "Blown Bottle", "Shakuhachi", "Whistle", "Ocarina",
        "Lead 1 (square)", "Lead 2 (sawtooth)", "Lead 3 (calliope)", "Lead 4 (chiff)",
        "Lead 5 (charang)", "Lead 6 (voice)", "Lead 7 (fifths)", "Lead 8 (bass + lead)",
        "Pad 1 (new age)", "Pad 2 (warm)", "Pad 3 (polysynth)", "Pad 4 (choir)",
        "Pad 5 (bowed)", "Pad 6 (metallic)", "Pad 7 (halo)", "Pad 8 (sweep)",
        "FX 1 (rain)", "FX 2 (soundtrack)", "FX 3 (crystal)", "FX 4 (atmosphere)",
        "FX 5 (brightness)", "FX 6 (goblins)", "FX 7 (echoes)", "FX 8 (sci-fi)",
        "Sitar", "Banjo", "Shamisen", "Koto", "Kalimba", "Bag pipe", "Fiddle", "Shanai",
        "Tinkle Bell", "Agogo", "Steel Drums", "Woodblock", "Taiko Drum", "Melodic Tom", "Synth Drum", "Reverse Cymbal",
        "Guitar Fret Noise", "Breath Noise", "Seashore", "Bird Tweet", "Telephone Ring", "Helicopter", "Applause", "Gunshot"
    ]

    func noteOn(_ channel: Int, _ note: Int, _ velocity: Int) {
        sampler.startNote(UInt8(note & 0x7F), withVelocity: UInt8(velocity & 0x7F),
                          onChannel: UInt8(channel & 0xF))
    }

    func noteOff(_ channel: Int, _ note: Int) {
        sampler.stopNote(UInt8(note & 0x7F), onChannel: UInt8(channel & 0xF))
    }

    func programChange(_ channel: Int, _ program: Int, bank: Int = 0) {
        try? loadProgram(program)
        sampler.sendProgramChange(UInt8(program & 0x7F),
                                  bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                  bankLSB: 0,
                                  onChannel: UInt8(channel & 0xF))
    }

    func allNotesOff() {
        for ch in 0..<16 {
            sampler.sendController(123, withValue: 0, onChannel: UInt8(ch))
            sampler.sendController(120, withValue: 0, onChannel: UInt8(ch))
        }
    }

    /// Ascending four-note test so we can tell whether the synth renders at all.
    func testScale() -> OSStatus {
        let notes: [Int] = [60, 64, 67, 72]
        for (i, n) in notes.enumerated() {
            sampler.startNote(UInt8(n), withVelocity: 100, onChannel: 0)
            Thread.sleep(forTimeInterval: 0.25)
            sampler.stopNote(UInt8(n), onChannel: 0)
        }
        return noErr
    }
}
