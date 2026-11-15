import SwiftUI

@main
struct MusicMouseApp: App {
    @StateObject private var player = Player()

    var body: some Scene {
        WindowGroup {
            ContentView(player: player)
        }
    }
}
