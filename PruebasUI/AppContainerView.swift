import SwiftUI

struct AppContainerView: View {
    @StateObject private var storage = ShotStorage()   // ✅ correcto
    @ObservedObject var communicator: BLECommunicator
    @State private var currentScreen: Screen = .INICIO

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
    
    func onSaveShotConfig(_ config: ShotConfig) {
        shots[config.shotNumber] = config
    }

    // MARK: - Navegación

    var body: some View {
        switch currentScreen {
            
        case .INICIO:
            InicioScreen(
                onStartClick: { currentScreen = .CONTENIDO_PRINCIPAL }
            )
            
        case .CONTENIDO_PRINCIPAL:
            MainContentScreen(
                communicator: communicator,
                shotsMap: $shots,
                
                onBackClick: {
                    communicator.disconnect()
                    currentScreen = .INICIO
                },
                
                onDrillsClick: {
                    currentScreen = .drillScreen
                },
                
                onSwapClick: {
                    currentScreen = .swapScreen
                },
                
                onConfigShot: { shotNumber in
                    currentShotNumber = shotNumber
                    currentScreen = .shotConfigScreen
                },
                
                onAddShot: {
                    onAddShot()
                },
                
                onDeleteShot: { shotNumber in
                    onDeleteShot(shotNumber: shotNumber)
                }
            )
            
        case .drillScreen:
            DrillScreen(
                communicator: communicator,
                shots: $shots,
                
                onBackClick: {
                    currentScreen = .CONTENIDO_PRINCIPAL
                },
                
                // DrillScreen pasa el número del tiro (Int), úsalo directamente:
                onConfigShot: { shotNumber in
                    currentShotNumber = shotNumber
                    currentScreen = .shotConfigScreen
                },
                
                onAddShot: {
                    onAddShot()
                },
                
                // onDeleteShot también recibe Int
                onDeleteShot: { shotNumber in
                    onDeleteShot(shotNumber: shotNumber)
                }
            )
            
        case .swapScreen:
            VStack {
                Text("Pantalla de SwapScreen")
                    .font(.largeTitle)
                    .foregroundColor(DragonBotTheme.primary)
                
                Button("Regresar") {
                    currentScreen = .CONTENIDO_PRINCIPAL
                }
            }
            
        case .shotConfigScreen:
            if let config = shots[currentShotNumber] {
                ShotConfigScreen(
                    shotConfig: config,
                    communicator: communicator,

                    onSaveConfig: { updated in
                        shots[updated.shotNumber] = updated   // <-- GUARDAR AQUÍ
                        currentScreen = .CONTENIDO_PRINCIPAL
                    },

                    onCancel: {
                        currentScreen = .CONTENIDO_PRINCIPAL
                    }
                )
            } else {
                VStack {
                    Text("Error: Tiro no encontrado")
                        .foregroundColor(.red)
                    Button("Volver") {
                        currentScreen = .CONTENIDO_PRINCIPAL
                    }
                }
            }
        }
    }
}
