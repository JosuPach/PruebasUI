import SwiftUI

struct SwapConfigScreen: View {

    @ObservedObject var communicator: BLECommunicator
    var onClose: () -> Void   // Para cerrar la pantalla

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {

                Text("Configuración Swap")
                    .font(.largeTitle)
                    .foregroundColor(DragonBotTheme.primary)

                // ------------------------
                // BOTÓN SW  →  [WA]
                // ------------------------
                Button(action: sendSW) {
                    Text("Modo Swap  [WA]")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal)

                // ------------------------
                // BOTÓN GOSW → [PL]
                // ------------------------
                Button(action: sendGoSW) {
                    Text("Iniciar Swap  [PL]")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal)

                // ------------------------
                // ENV SWAP 1 → [Y070992727990000]
                // ------------------------
                Button(action: sendSwap1) {
                    Text("Enviar Swap 1")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal)

                // ------------------------
                // ENV SWAP 2 → [Y105992727000000]
                // ------------------------
                Button(action: sendSwap2) {
                    Text("Enviar Swap 2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .padding(.horizontal)

                Spacer()

                // ------------------------
                // BOTÓN DE REGRESO
                // ------------------------
                Button("CERRAR / ATRÁS") {
                    onClose()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom, 20)

            }
            .padding(.top, 20)
            .navigationBarTitle("Swap", displayMode: .inline)
        }
    }

    // ------------------------------------------------------------
    // MARK: - Funciones que envían exactamente los comandos Python
    // ------------------------------------------------------------

    private func sendSW() {
        let cmd = "[WA]"
        communicator.sendCommand(cmd)
        print("Modo Swap enviado: \(cmd)")
    }

    private func sendGoSW() {
        let cmd = "[PL]"
        communicator.sendCommand(cmd)
        print("Iniciar Swap enviado: \(cmd)")
    }

    private func sendSwap1() {
        let cmd = "[Y070992727990000]"
        communicator.sendCommand(cmd)
        print("Shot Swap 1 enviado: \(cmd)")
    }

    private func sendSwap2() {
        let cmd = "[Y105992727000000]"
        communicator.sendCommand(cmd)
        print("Shot Swap 2 enviado: \(cmd)")
    }
}
