import SwiftUI
import Combine

struct FiringView: View {
    @EnvironmentObject var store: AlarmStore
    @State private var currentTime = Date()
    @State private var pulse = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 48) {
                Text(currentTime, style: .time)
                    .font(.system(size: 72, weight: .thin, design: .default))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Button {
                    store.stopAlarm()
                } label: {
                    Text("Stop")
                        .font(.title.bold())
                        .foregroundStyle(.black)
                        .frame(width: 160, height: 160)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .scaleEffect(pulse ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            }
        }
        .onReceive(clock) { currentTime = $0 }
    }
}
