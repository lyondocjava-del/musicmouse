import SwiftUI

struct GridView: View {
    @ObservedObject var player: Player

    static let voiceColors: [Color] = [
        Color(red: 104/255, green: 224/255, blue: 170/255),
        Color(red: 247/255, green: 117/255, blue: 102/255),
        Color(red: 91/255, green: 175/255, blue: 255/255),
        Color(red: 206/255, green: 126/255, blue: 246/255)
    ]

    var body: some View {
        GeometryReader { geo in
            let w = Int(geo.size.width)
            let h = Int(geo.size.height)
            ZStack {
                Color(red: 20/255, green: 22/255, blue: 25/255)
                gridLines(w: w, h: h)
                if player.haveCursor { cursorOverlay(w: w, h: h) }
            }
            .border(Color(red: 92/255, green: 95/255, blue: 101/255), width: 1)
            .onAppear { player.gridW = max(1, w); player.gridH = max(1, h) }
            .onChange(of: geo.size) { size in
                player.gridW = max(1, Int(size.width))
                player.gridH = max(1, Int(size.height))
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                player.cursorMoved(x: Double(v.location.x), y: Double(v.location.y))
            })
        }
    }

    func gridLines(w: Int, h: Int) -> some View {
        ZStack {
            Path { p in
                for i in 1..<12 {
                    let x = CGFloat(i) * CGFloat(w) / 12
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: CGFloat(h)))
                    let y = CGFloat(i) * CGFloat(h) / 12
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: CGFloat(w), y: y))
                }
            }
            .stroke(Color(red: 39/255, green: 42/255, blue: 47/255), lineWidth: 1)
            Path { p in
                let scale = player.engine.currentScale(player.settings)
                for note in scale {
                    let x = CGFloat(note) * CGFloat(w) / 12
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: CGFloat(h)))
                }
            }
            .stroke(Color(red: 70/255, green: 74/255, blue: 81/255), lineWidth: 1.4)
        }
    }

    func cursorOverlay(w: Int, h: Int) -> some View {
        let s = player.settings
        let disp = s.showPatternMovement
            ? player.engine.patternCursorPosition(s, x: player.cursorX, y: player.cursorY,
                                                  w: w, h: h, running: player.running, tick: player.tick)
            : (player.cursorX, player.cursorY)
        let pitches = player.currentVoicing
        let cx = CGFloat(VoicingEngine.keyCenter(disp.0, w))
        let cy = CGFloat(VoicingEngine.keyCenter(disp.1, h))
        return ZStack {
            // voice crosshairs + dots
            ForEach(0..<4, id: \.self) { voice in
                if player.voiceEnabled[voice] {
                    let horizontal = voice == 0 || voice == 2
                    Group {
                        if horizontal {
                            Path { p in
                                p.move(to: CGPoint(x: 0, y: cy))
                                p.addLine(to: CGPoint(x: CGFloat(w), y: cy))
                            }
                            .stroke(GridView.voiceColors[voice],
                                    style: StrokeStyle(lineWidth: voice < 2 ? 2 : 1.4))
                        } else {
                            Path { p in
                                p.move(to: CGPoint(x: cx, y: 0))
                                p.addLine(to: CGPoint(x: cx, y: CGFloat(h)))
                            }
                            .stroke(GridView.voiceColors[voice],
                                    style: StrokeStyle(lineWidth: voice < 2 ? 2 : 1.4))
                        }
                    }
                    Circle()
                        .fill(GridView.voiceColors[voice])
                        .frame(width: 10, height: 10)
                        .position(x: cx, y: cy)
                    Text("V\(voice + 1)  \(pitches[voice])")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(GridView.voiceColors[voice])
                        .position(x: min(cx + 46, CGFloat(w) - 40), y: max(cy - 14, 8))
                }
            }
            // center crosshair
            Path { p in
                p.move(to: CGPoint(x: cx, y: 0)); p.addLine(to: CGPoint(x: cx, y: CGFloat(h)))
                p.move(to: CGPoint(x: 0, y: cy)); p.addLine(to: CGPoint(x: CGFloat(w), y: cy))
            }
            .stroke(Color.white.opacity(0.63), lineWidth: 1)
        }
    }
}
