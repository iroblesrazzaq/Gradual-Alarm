import AVFoundation
import SwiftUI

struct SoundPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSound: String
    private let sounds = ["birds", "chimes", "breeze", "dawn", "piano"]
    @State private var player: AVAudioPlayer?
    private let frequencies: [String: Double] = [
        "birds": 440,
        "chimes": 523.25,
        "breeze": 392,
        "dawn": 330,
        "piano": 262
    ]

    var body: some View {
        NavigationView {
            List(sounds, id: \.self) { sound in
                HStack {
                    Text(sound.capitalized)
                    Spacer()
                    if selectedSound == sound {
                        Image(systemName: "checkmark")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSound = sound
                    playPreview(sound)
                }
            }
            .navigationTitle("Sounds")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func playPreview(_ sound: String) {
        let frequency = frequencies[sound] ?? 440
        guard let url = ToneGenerator.shared.toneURL(for: "preview_\(sound)", frequency: frequency) else {
            return
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
