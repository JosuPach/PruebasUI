import SwiftUI

struct ShotConfigScreen: View {

    @ObservedObject var shotConfig: ShotConfig
    @ObservedObject var communicator: BLECommunicator

    var onSaveConfig: (ShotConfig) -> Void
    var onCancel: () -> Void

    let dValues: [Int] = [255, 127, 0]
    let cValues: [Int] = [0, 64, 127, 191, 255]

    @State private var speedTemp: Double
    @State private var delayTemp: Double
    @State private var selectedRow: Int
    @State private var selectedCol: Int

    init(
        shotConfig: ShotConfig,
        communicator: BLECommunicator,
        onSaveConfig: @escaping (ShotConfig) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.shotConfig = shotConfig
        self.communicator = communicator
        self.onSaveConfig = onSaveConfig
        self.onCancel = onCancel

        _speedTemp = State(initialValue: Double(shotConfig.speedAB))
        _delayTemp = State(initialValue: Double(shotConfig.delayE))

        let row = dValues.firstIndex(of: shotConfig.targetD) ?? 1
        let col = cValues.firstIndex(of: shotConfig.targetC) ?? 2

        _selectedRow = State(initialValue: row)
        _selectedCol = State(initialValue: col)
    }

    // ------------------------------
    // 🔥 Generador de cadena SH local
    // ------------------------------
    private func buildSHCommand() -> String {
        let c = Int(Double(shotConfig.targetC) / 255.0 * 99.0)
        let d = Int(Double(shotConfig.targetD) / 255.0 * 99.0)
        let a = Int(Double(shotConfig.speedAB) / 255.0 * 99.0)
        let b = a
        let e = Int(Double(shotConfig.delayE) / 255.0 * 99.0)

        return String(format: "[SH%02d%02d%02d%02d%02d]", a, b, c, d, e)
    }

    private func sendSingleValue(prefix: String, value: Int) {
        let cmd = String(format: "[%@%03d]", prefix, value)
        communicator.sendCommand(cmd)
        print("send: \(cmd)")
    }

    private func saveConfigAndReturn() {
        shotConfig.speedAB = Int(speedTemp.rounded())
        shotConfig.delayE = Int(delayTemp.rounded())
        shotConfig.targetD = dValues[selectedRow]
        shotConfig.targetC = cValues[selectedCol]

        let sh = buildSHCommand()

        communicator.sendCommand(sh)
        print("Sent SH command on save: \(sh)")

        onSaveConfig(shotConfig)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    Text("TIRO #\(shotConfig.shotNumber)")
                        .font(.largeTitle)
                        .foregroundColor(DragonBotTheme.primary)

                    TargetSelectionGrid(
                        targetC: Binding(
                            get: { shotConfig.targetC },
                            set: { shotConfig.targetC = $0 }
                        ),
                        targetD: Binding(
                            get: { shotConfig.targetD },
                            set: { shotConfig.targetD = $0 }
                        ),
                        onTargetSelected: { cVal, dVal in
                            if let col = cValues.firstIndex(of: cVal),
                               let row = dValues.firstIndex(of: dVal) {
                                selectedCol = col
                                selectedRow = row
                            }
                            communicator.sendCommand(String(format: "[C%03d]", cVal))
                            communicator.sendCommand(String(format: "[D%03d]", dVal))
                        }
                    )
                    .padding(.horizontal)

                    SliderWithLabel(
                        label: "Velocidad (A/B): \(Int(speedTemp.rounded()))",
                        value: $speedTemp,
                        range: 0...255,
                        onEditingChangedFinished: {
                            let v = Int(speedTemp.rounded())
                            sendSingleValue(prefix: "A", value: v)
                            sendSingleValue(prefix: "B", value: v)
                        }
                    )
                    .padding(.horizontal)

                    SliderWithLabel(
                        label: "Retardo (E): \(Int(delayTemp.rounded()))",
                        value: $delayTemp,
                        range: 0...255,
                        onEditingChangedFinished: {
                            let v = Int(delayTemp.rounded())
                            sendSingleValue(prefix: "E", value: v)
                        }
                    )
                    .padding(.horizontal)

                    Spacer()

                    HStack(spacing: 16) {
                        Button("CANCELAR / ATRÁS") { onCancel() }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)

                        Button("GUARDAR CONFIG") { saveConfigAndReturn() }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent)
                            .tint(DragonBotTheme.primary)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitle(
                "Config. Tiro #\(shotConfig.shotNumber)",
                displayMode: .inline
            )
        }
    }
}
