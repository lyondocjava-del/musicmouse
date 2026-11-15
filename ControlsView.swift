import SwiftUI

struct ControlsView: View {
    @ObservedObject var player: Player

    static let modeNames = ["Diatonic", "Pentatonic", "Chromatic", "Quartal", "Octatonic", "Middle Eastern"]
    static let treatments = ["Chord", "Arpeggio", "Line", "Improv"]
    static let articulations = ["Staccato", "Half Legato", "Legato"]
    static let rootNames = ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                title("DOCJAVA MOUSE")
                harmonySection
                voicingSection
                rhythmSection
                tempoSection
                voicesSection
                soundSection
                Spacer(minLength: 10)
            }
            .padding(12)
            .font(.system(size: 12))
            .foregroundColor(Color(white: 0.78))
        }
        .background(Color(red: 35/255, green: 37/255, blue: 41/255))
        .frame(minWidth: 250, idealWidth: 270, maxWidth: 300)
    }

    var harmonySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            section("HARMONY")
            picker("Harmonic mode", selection: $player.settings.mode,
                   items: Self.modeNames) { player.harmonyChanged() }
            picker("Diatonic flavor", selection: $player.settings.diatonic,
                   items: ["Major", "Minor"]) { player.harmonyChanged() }
            picker("Root note", selection: Binding(
                get: { player.settings.root - 60 },
                set: { player.settings.root = 60 + $0 }),
                items: Self.rootNames) { }
            slider("Transposition \(player.settings.transposition) semitones",
                   value: Binding(get: { Double(player.settings.transposition) },
                                  set: { player.settings.transposition = Int($0) }),
                   range: -24...24, step: 1)
        }
    }

    var voicingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            section("VOICING")
            picker("Voice to axis", selection: $player.settings.axisAssign,
                   items: ["Bass on Y · lead on X", "Bass on X · lead on Y"]) { player.updateAxisKeys() }
            picker("Mouse movement", selection: $player.settings.motion,
                   items: ["Parallel", "Contrary"]) { }
            picker("Pattern movement", selection: $player.settings.patternMotion,
                   items: ["Parallel", "Contrary"]) { }
            picker("Voice relationship", selection: $player.settings.pairing,
                   items: ["Chord / melody", "Voice pairs"]) { }
            slider("Transposition interval \(player.settings.interval) semitones",
                   value: Binding(get: { Double(player.settings.interval) },
                                  set: { player.settings.interval = Int($0) }),
                   range: 1...12, step: 1)
        }
    }

    var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            section("RHYTHM")
            picker("Treatment", selection: $player.settings.treatment,
                   items: Self.treatments) { }
            picker("Pattern sequence", selection: $player.settings.patternIndex,
                   items: VoicingEngine.patterns.indices.map { String(format: "%02d  Pattern %d", $0 + 1, $0 + 1) }) { }
            Toggle("Pattern playback ON", isOn: $player.settings.patternEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            Toggle("Show pattern movement", isOn: $player.settings.showPatternMovement)
            Toggle("Group notes", isOn: $player.settings.grouping)
            picker("Articulation", selection: $player.settings.articulation,
                   items: Self.articulations) { }
        }
    }

    var tempoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider("Tempo 1  \(player.tempo1) BPM",
                   value: Binding(get: { Double(player.tempo1) },
                                  set: { player.tempo1 = Int($0) }),
                   range: 40...240, step: 1)
            slider("Tempo 2  \(player.tempo2) BPM",
                   value: Binding(get: { Double(player.tempo2) },
                                  set: { player.tempo2 = Int($0) }),
                   range: 40...240, step: 1)
            slider("Fast ceiling  \(player.fastTempo) BPM",
                   value: Binding(get: { Double(player.fastTempo) },
                                  set: { player.fastTempo = Int($0) }),
                   range: 240...1200, step: 10)
            Toggle("Alternate tempo (Tempo 2)", isOn: $player.alternateTempo)
        }
    }

    var voicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            section("VOICES")
            ForEach(0..<4, id: \.self) { v in
                HStack {
                    Toggle("Voice \(v + 1)\(v < 2 ? " (cursor)" : " (harmony)")",
                           isOn: Binding(
                            get: { player.voiceEnabled[v] },
                            set: {
                                player.voiceEnabled[v] = $0
                                if !$0 { player.stopVoice(v) }
                            }))
                        .toggleStyle(SwitchToggleStyle(tint: GridView.voiceColors[v]))
                    Spacer()
                    Picker("", selection: $player.voiceChannelIndices[v]) {
                        ForEach(1...16, id: \.self) { ch in
                            Text("\(ch)").tag(ch - 1)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 70)
                }
            }
        }
    }

    var soundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            section("SOUND")
            Picker("Instrument / MIDI patch", selection: $player.instrumentProgram) {
                ForEach(0..<MidiSynth.gmNames.count, id: \.self) { i in
                    Text(String(format: "%03d  %@", i + 1, MidiSynth.gmNames[i])).tag(i)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: player.instrumentProgram) { player.applyInstrument($0) }

            Button(action: { player.toggleRunning() }) {
                Text(player.running ? "■  Stop" : "▶  Play / Stop")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(red: 41/255, green: 119/255, blue: 157/255))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            Button(action: { player.testSound() }) {
                Text("Test sound")
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color(white: 0.25))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
        }
    }

    func title(_ t: String) -> some View {
        Text(t).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            .padding(.bottom, 4)
    }

    func section(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .bold))
            .foregroundColor(Color(red: 105/255, green: 180/255, blue: 216/255))
            .padding(.top, 8)
    }

    func picker(_ label: String, selection: Binding<Int>, items: [String],
                onChange: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11))
            Picker(label, selection: selection) {
                ForEach(items.indices, id: \.self) { i in
                    Text(items[i]).tag(i)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selection.wrappedValue) { _ in onChange() }
        }
    }

    func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11))
            Slider(value: value, in: range, step: step)
                .accentColor(Color(red: 72/255, green: 171/255, blue: 216/255))
        }
    }
}
