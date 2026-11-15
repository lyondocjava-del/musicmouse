import SwiftUI

struct ContentView: View {
    @ObservedObject var player: Player

    var body: some View {
        HStack(spacing: 0) {
            ControlsView(player: player)
            VStack(spacing: 0) {
                Text("  XY PERFORMANCE GRID  ·  Move to shape four related voices")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 188/255, green: 194/255, blue: 205/255))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                KeyboardStrip(litNote: player.axisNotes[3], color: GridView.voiceColors[3])
                    .frame(height: 20)
                    .padding(.horizontal, 10)
                HStack(spacing: 0) {
                    KeyboardStrip(litNote: player.axisNotes[0], color: GridView.voiceColors[0], vertical: true)
                        .frame(width: 20)
                    GridView(player: player)
                    KeyboardStrip(litNote: player.axisNotes[2], color: GridView.voiceColors[2], vertical: true)
                        .frame(width: 20)
                }
                KeyboardStrip(litNote: player.axisNotes[1], color: GridView.voiceColors[1])
                    .frame(height: 20)
                    .padding(.horizontal, 10)
                Text(player.status)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 205/255, green: 210/255, blue: 218/255))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .background(Color(red: 21/255, green: 23/255, blue: 26/255))
        }
        .background(Color(red: 25/255, green: 27/255, blue: 30/255))
        .edgesIgnoringSafeArea(.all)
        .onDisappear { player.silence() }
    }
}
