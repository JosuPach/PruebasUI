import SwiftUI

struct AppContainerView: View {
    @StateObject private var storage = ShotStorage()
    @ObservedObject var communicator: BLECommunicator
    
    // MARK: - Estado de Navegación
    @State private var currentScreen: Screen = .INICIO
    @State private var previousScreen: Screen = .CONTENIDO_PRINCIPAL // Para recordar el origen
    
    // MARK: - Estado de Datos
    @State private var shots: [Int: ShotConfig] = [:]
    @State private var currentShotNumber: Int = -1

    // MARK: - Lógica de Tiros
    private func getNextShotNumber() -> Int {
        return (shots.keys.max() ?? 0) + 1
    }
    
    func onAddShot() {
        let next = getNextShotNumber()
        shots[next] = ShotConfig(shotNumber: next)
    }
    
    func onDeleteShot(shotNumber: Int) {
        shots.removeValue(forKey: shotNumber)
    }

    // MARK: - Navegación Principal
    var body: some View {
        ZStack {
            switch currentScreen {
                
            case .INICIO:
                InicioScreen(
                    onStartClick: {
                        withAnimation { currentScreen = .CONTENIDO_PRINCIPAL }
                    }
                )
                
            case .CONTENIDO_PRINCIPAL:
                MainContentScreen(
                    communicator: communicator,
                    shotsMap: $shots,
                    onBackClick: {
                        communicator.disconnect()
                        withAnimation { currentScreen = .INICIO }
                    },
                    onDrillsClick: {
                        withAnimation { currentScreen = .drillScreen }
                    },
                    onSwapClick: {
                        withAnimation { currentScreen = .swapScreen }
                    },
                    onConfigShot: { shotNumber in
                        navigateToConfig(from: .CONTENIDO_PRINCIPAL, shotNumber: shotNumber)
                    },
                    onAddShot: { onAddShot() },
                    onDeleteShot: { shotNumber in onDeleteShot(shotNumber: shotNumber) }
                )
                
            case .drillScreen:
                DrillScreen(
                    communicator: communicator,
                    shots: $shots,
                    onBackClick: {
                        withAnimation { currentScreen = .CONTENIDO_PRINCIPAL }
                    },
                    onConfigShot: { shotNumber in
                        navigateToConfig(from: .drillScreen, shotNumber: shotNumber)
                    },
                    onAddShot: { onAddShot() },
                    onDeleteShot: { shotNumber in onDeleteShot(shotNumber: shotNumber) }
                )
                
            case .swapScreen:
                // Integración de la pantalla de calibración técnica (Cancha)
                SwapConfigScreen(
                    communicator: communicator,
                    onClose: {
                        withAnimation { currentScreen = .CONTENIDO_PRINCIPAL }
                    }
                )
                
            case .shotConfigScreen:
                if let config = shots[currentShotNumber] {
                    ShotConfigScreen(
                        shotConfig: config,
                        communicator: communicator,
                        onSaveConfig: { updated in
                            shots[updated.shotNumber] = updated
                            
                            // FORZAMOS el regreso a Drills
                            withAnimation(.spring()) {
                                currentScreen = .drillScreen
                            }
                        },
                        onCancel: {
                            // Al cancelar, quizás sí prefieras volver a la anterior
                            // o también forzarlo a Drills:
                            withAnimation(.spring()) {
                                currentScreen = .drillScreen
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers de Navegación
    private func navigateToConfig(from screen: Screen, shotNumber: Int) {
        currentShotNumber = shotNumber
        previousScreen = screen // Guardamos de dónde venimos
        withAnimation { currentScreen = .shotConfigScreen }
    }

    private var errorFallbackView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50)).foregroundColor(.orange)
            Text("ERROR: CONFIGURACIÓN NO ENCONTRADA")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
            Button("VOLVER") {
                withAnimation { currentScreen = .CONTENIDO_PRINCIPAL }
            }
            .padding().background(Color.white.opacity(0.1)).cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}


