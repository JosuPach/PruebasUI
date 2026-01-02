import SwiftUI

struct LoopCounter: View {
    var loopCount: Int
    var isInfinite: Bool
    var onIncrement: () -> Void
    var onDecrement: () -> Void
    var onSetInfinite: () -> Void
    var onSetFinite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("-") { onDecrement() }
                .frame(width: 44, height: 44).buttonStyle(.bordered)

            Text(isInfinite ? "∞" : String(format: "%02d", loopCount))
                .font(.title2)
                .frame(minWidth: 80)

            Button("+") { onIncrement() }
                .frame(width: 44, height: 44).buttonStyle(.bordered)

            Spacer()

            Toggle(isOn: Binding(get: { isInfinite }, set: { new in
                if new { onSetInfinite() } else { onSetFinite() }
            })) {
                Text("Infinito")
            }
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: DragonBotTheme.primary))
        }
        .padding()
        .background(DragonBotTheme.surface.opacity(0.06))
        .cornerRadius(8)
    }
}
