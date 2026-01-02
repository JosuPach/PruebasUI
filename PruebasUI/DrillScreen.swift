import SwiftUI

struct DrillScreen: View {
    @ObservedObject var communicator: BLECommunicator
    
    @Binding var shots: [Int : ShotConfig]   // ← ESTE ES EL TIPO CORRECTO
    
    var onBackClick: () -> Void
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void    // ← CORREGIDO

    // Estado UI
    @State private var loopCount: Int = 1
    @State private var isInfinite: Bool = false
    @State private var isRunning: Bool = false

    // MARK: - Helpers (formateo/envío)
    private func sendLoopCommand(_ count: Int) {
        let formatted = String(format: "%02d", min(max(count, 0), 99))
        communicator.sendCommand("[N\(formatted)]")
        print("Sent loop command: [N\(formatted)]")
    }

    private func buildConsolidatedShotsCommand() -> String {
        let ordered = shots.values.sorted { $0.shotNumber < $1.shotNumber }
        let joined = ordered.map { cfg in
            String(format: "A%03d:B%03d:C%03d:D%03d:E%03d",
                   cfg.speedAB, cfg.speedAB, cfg.targetC, cfg.targetD, cfg.delayE)
        }.joined(separator: ":")
        return joined
    }

    private func startDrill() {
        guard communicator.isConnected else {
            print("No conectado")
            return
        }

        communicator.sendCommand("[MD]")

        let loopValue = isInfinite ? 255 : min(max(loopCount, 1), 255)
        let loopP = String(format: "%03d", loopValue)
        let shotsCmd = buildConsolidatedShotsCommand()

        let final = "[MD]P\(loopP):\(shotsCmd)[GO]"
        communicator.sendCommand(final)

        print("Drill start: \(final)")
        isRunning = true
    }

    private func stopDrill() {
        communicator.sendCommand("[Z]")
        isRunning = false
        print("Drill stopped")
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // Title
                    Text("Configuración de DRILLS")
                        .font(.title)
                        .foregroundColor(DragonBotTheme.primary)
                        .padding(.top)

                    Text("Estado: \(communicator.isConnected ? "Conectado" : "Desconectado")")
                        .foregroundColor(communicator.isConnected ? DragonBotTheme.primary : .red)

                    // Loop Counter
                    LoopCounter(
                        loopCount: loopCount,
                        isInfinite: isInfinite,
                        onIncrement: {
                            loopCount += 1
                            isInfinite = false
                            sendLoopCommand(loopCount)
                        },
                        onDecrement: {
                            if loopCount > 1 {
                                loopCount -= 1
                                isInfinite = false
                                sendLoopCommand(loopCount)
                            }
                        },
                        onSetInfinite: {
                            isInfinite = true
                            communicator.sendCommand("[I]")
                        },
                        onSetFinite: {
                            isInfinite = false
                            sendLoopCommand(loopCount)
                        }
                    )
                    .padding(.horizontal)

                    Button(action: { communicator.sendCommand("[MD]") }) {
                        Text("ACTIVAR MODO DRILL")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DragonBotTheme.tertiary)

                    Button(action: onAddShot) {
                        Text("AGREGAR TIRO")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(DragonBotTheme.secondary)

                    // Shots list
                    if shots.isEmpty {
                        Text("Presiona 'AGREGAR TIRO' para empezar a configurar tu rutina.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tiros en la rutina:")
                                .foregroundColor(DragonBotTheme.primary)
                                .padding(.bottom, 8)

                            ForEach(shots.keys.sorted(), id: \.self) { key in
                                if let cfg = shots[key] {
                                    HStack(spacing: 8) {

                                        // ← BOTÓN CORREGIDO PARA EDITAR
                                        Button(action: {
                                            onConfigShot(cfg.shotNumber)
                                        }) {
                                            Text("EDITAR TIRO #\(cfg.shotNumber)")
                                                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                                                .padding(.horizontal)
                                                .background(Color(UIColor.systemGray6))
                                                .cornerRadius(8)
                                        }

                                        // ← BORRAR TIRO
                                        Button(action: {
                                            onDeleteShot(cfg.shotNumber)
                                        }) {
                                            Text("BORRAR")
                                                .frame(width: 90, height: 70)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: 16) {
                        Button(action: startDrill) {
                            Text("INICIAR DRILL")
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .disabled(shots.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .tint(DragonBotTheme.primary)

                        Button(action: stopDrill) {
                            Text("DETENER DRILL")
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(.horizontal)

                    Button(action: { communicator.sendCommand("[X]") }) {
                        Text("BORRAR RUTINA COMPLETA")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .disabled(shots.isEmpty)
                    .buttonStyle(.bordered)
                    .tint(.red.opacity(0.8))

                    Spacer()
                }
                .padding(.bottom, 30)
            }
            .navigationBarTitle("DRILLS", displayMode: .inline)
            .navigationBarItems(leading: Button("Atrás") { onBackClick() })
        }
    }
}
