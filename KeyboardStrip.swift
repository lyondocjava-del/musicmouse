import SwiftUI

/// Piano strip mirroring the KeyboardPanel/VKeyboardPanel edge displays:
/// lights the note its voice is currently on.
struct KeyboardStrip: View {
    let litNote: Int
    let color: Color
    var vertical = false

    private let lo = 36
    private let hi = 96

    var body: some View {
        if vertical {
            VStack(spacing: 0) { keys(reversed: true) }
        } else {
            HStack(spacing: 0) { keys(reversed: false) }
        }
    }

    @ViewBuilder
    func keys(reversed: Bool) -> some View {
        let range = reversed ? Array((lo...hi).reversed()) : Array(lo...hi)
        ForEach(range, id: \.self) { note in
            Rectangle()
                .fill(note == litNote ? color
                        : isBlack(note) ? Color(white: 0.12) : Color(white: 0.85))
                .overlay(Rectangle().stroke(Color(white: 0.3), lineWidth: 0.5))
        }
    }

    func isBlack(_ n: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(n % 12)
    }
}
