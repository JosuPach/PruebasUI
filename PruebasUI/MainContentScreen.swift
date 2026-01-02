import SwiftUI
import CoreBluetooth

// Requerido para el mock de DeviceSelectionDialog
extension CBPeripheral: Identifiable {
    public var id: UUID { return UUID() }
}

// MARK: - MAIN CONTENT SCREEN (CÓDIGO CORREGIDO)

struct MainContentScreen: View {
    // IMPORTANTE: Asegúrate de que BLECommunicator exista como ObservableObject
    @StateObject var communicator = BLECommunicator()
    @Binding var shotsMap: [Int : ShotConfig]
    // Callbacks para navegación
    var onBackClick: () -> Void
    var onDrillsClick: () -> Void
    var onSwapClick: () -> Void
    
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void
    
    // Estados de la UI
    @State private var showDeviceSelectionDialog: Bool = false
    @State private var showConfigDialog: Bool = false
    @State private var currentConfigMode: DragonBotMode = .NONE
    
    // NOTA: 'showDrillScreen' ya no es necesario para la navegación simple (eliminado)
    
    // 2. Estado para mostrar la pantalla de Configuración de Tiro (dentro de Drills)
    @State private var showShotConfigScreen: Bool = false
    
    // 3. Almacenamiento de todos los tiros.
    
    // 4. El número de tiro que se está configurando actualmente (si aplica)
    @State private var currentShotConfigNumber: Int? = nil
    
    // 5. El próximo número de tiro disponible
    @State private var nextShotNumber: Int = 1
    
    // Lógica para añadir un nuevo tiro
    func addShot() {
        let newConfig = ShotConfig(shotNumber: nextShotNumber)
        shotsMap[nextShotNumber] = newConfig
        nextShotNumber += 1
    }
    
    // Lógica para borrar un tiro
    func deleteShot(number: Int) {
        shotsMap.removeValue(forKey: number)
    }
    
    // Lógica para ir a la configuración de un tiroo
    func configShot(number: Int) {
        currentShotConfigNumber = number
        showShotConfigScreen = true
    }
    
    // Lógica de guardar la configuración de tiro
    func saveShotConfig() {
        showShotConfigScreen = false
    }
    
    // Lógica para cancelar/volver de la configuración de tiro
    func cancelShotConfig() {
        showShotConfigScreen = false
    }
    
    var body: some View {
        // Envolvemos todo el contenido en un ZStack para el color de fondo
        ZStack {
            Color.dragonBotBackground.edgesIgnoringSafeArea(.all)
            
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {

                        // Texto de Bienvenida
                        Text("¡Controla todas las funciones de la DRAGONBOT desde aquí!")
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                        
                        // --- COMPONENTE: ConnectionWarning ---
                        ConnectionWarning(
                            communicator: communicator,
                            onConnectClick: {
                                showDeviceSelectionDialog = true
                            }
                        )
                        
                        // --- SECCIÓN: MODOS DE OPERACIÓN DIRECTA ---
                        ControlSection(title: "MODOS DE OPERACIÓN DIRECTA") {
                            HStack(spacing: 8) {
                                ConfigButton(label: "MANUAL") { communicator.sendCommand("[L000]") }
                                ConfigButton(label: "I.A.") { communicator.sendCommand("[F000]") }
                            }
                        }
                        
                        // --- SECCIÓN: PROGRAMAS Y RUTINAS (DRILLS y SWAP) ---
                        ControlSection(title: "PROGRAMAS Y RUTINAS") {
                            VStack(spacing: 8) {

                                HStack(spacing: 8) {

                                    // ---- DRILL ----
                                    NavigationLink(
                                        destination: DrillScreen(
                                            communicator: communicator,
                                            shots: $shotsMap,
                                            onBackClick: { onBackClick() },
                                            onConfigShot: { shotNumber in
                                                onConfigShot(shotNumber)
                                            },
                                            onAddShot: { onAddShot() },
                                            onDeleteShot: { shotNumber in
                                                onDeleteShot(shotNumber)
                                            }
                                        )
                                    ) {
                                        Text("Configurar Drill")
                                    }

                                    // ---- SWAP ----
                                    NavigationLink(
                                        destination: SwapConfigScreen(
                                            communicator: communicator,
                                            onClose: { onBackClick() }
                                        )
                                    ) {
                                        Text("SWAP")
                                    }
                                }

                                Text("CONFIGÚRALA CON EL MODO QUE MÁS TE DIVIERTA")
                                    .font(.caption)
                                    .foregroundColor(.dragonBotSecondary)
                            }
                        }

                        
                        // --- SECCIÓN: SINGLE SHOT ---
                        ControlSection(title: "SINGLE SHOT") {
                            HStack(spacing: 8) {

                                ConfigButton(label: "Manual Sliders") {
                                    currentConfigMode = .MANUAL
                                    showConfigDialog = true
                                }
                                
                                ConfigButton(label: "Modo Auto") {
                                    currentConfigMode = .AUTO
                                    showConfigDialog = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30) // Espacio al final del scroll
                    }
                    .frame(maxWidth: .infinity)
                }
                .navigationBarItems(
                    leading: Button(action: onBackClick) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.dragonBotPrimary)
                    }
                )
                .navigationTitle("Control de la DRAGONBOT")
                .navigationBarTitleDisplayMode(.inline)
            }

            // --- DIALOGO DE SELECCIÓN DE DISPOSITIVOS ---
            .sheet(isPresented: $showDeviceSelectionDialog) {
                DeviceSelectionDialog(
                    communicator: communicator,
                    onDeviceSelected: { device in
                        communicator.connect(device: device)
                        showDeviceSelectionDialog = false
                    },
                    onDismiss: { showDeviceSelectionDialog = false }
                )
            }

            // --- DIALOGO DE CONFIGURACIÓN MANUAL / AUTO ---
            .sheet(isPresented: $showConfigDialog) {
                ModeConfigurationDialog(
                    mode: currentConfigMode,
                    onDismiss: {
                        showConfigDialog = false
                        currentConfigMode = .NONE
                    },
                    onSave: { command in
                        communicator.sendCommand(command)
                        if currentConfigMode != .MANUAL {
                            showConfigDialog = false
                            currentConfigMode = .NONE
                        }
                    }
                )
            }

            .accentColor(.dragonBotPrimary)
        }
    }

    
    // MARK: - Subestructuras (sin cambios, se mantienen como estaban)
    
    struct ConnectionWarning: View {
        @ObservedObject var communicator: BLECommunicator
        var onConnectClick: () -> Void
        
        // Simulación de un Central Manager de CoreBluetooth
        private func getStatusText() -> (text: String, color: Color) {
            switch (communicator.isConnected, communicator.isConnecting) {
            case (true, _):
                return (text: "DRAGONBOT CONECTADO", color: DragonBotTheme.primary)
            case (false, true):
                return (text: "CONECTANDO...", color: DragonBotTheme.tertiary)
            default:
                // Simulando estado de Bluetooth apagado
                if communicator.centralManagerWrapper?.state == .poweredOff {
                    return (text: "BLUETOOTH APAGADO", color: DragonBotTheme.error)
                }
                return (text: "DESCONECTADO", color: DragonBotTheme.error)
            }
        }
        
        var body: some View {
            let status = getStatusText()
            
            HStack {
                Image(systemName: status.text == "DRAGONBOT CONECTADO" ? "bolt.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(status.color)
                
                Text(status.text)
                    .font(.subheadline.bold())
                    .foregroundColor(status.color)
                
                Spacer()
                
                // Botón CONECTAR / Indicador de Carga
                if !communicator.isConnected && !communicator.isConnecting {
                    Button("CONECTAR") {
                        onConnectClick()
                    }
                    .padding(8)
                    .background(DragonBotTheme.secondary) // NOTA: Asumo que DragonBotTheme existe
                    .foregroundColor(DragonBotTheme.surface)
                    .cornerRadius(5)
                } else if communicator.isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DragonBotTheme.secondary))
                }
            }
            .padding()
            .background(Color.darkBlack.opacity(0.5)) // NOTA: Asumo que Color.darkBlack existe o está en DragonBotTheme
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Componentes de Botones
    struct ControlSection<Content: View>: View {
        let title: String
        let content: () -> Content
        
        var body: some View {
            VStack(spacing: 12) {
                Text(title.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.dragonBotPrimary)
                    .monospaced()
                
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16) // Añadido padding para asegurar el espaciado correcto
        }
    }
    
    struct ConfigButton: View {
        let label: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.black) // Contenido debe contrastar con el verde neón
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 5)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.dragonBotPrimary)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Pop-up de Configuración de Modos
    
    struct ModeConfigurationDialog: View {
        let mode: DragonBotMode
        let onDismiss: () -> Void
        let onSave: (String) -> Void
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack {
                        switch mode {
                        case .MANUAL:
                            ManualModeContent(onSave: onSave)
                        case .AUTO:
                            AutoModeContent(onSave: onSave)
                        case .NONE:
                            Text("Error: Navegación incorrecta.")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                }
                .background(Color.dragonBotBackground.edgesIgnoringSafeArea(.all))
                .navigationTitle("Configuración: \(mode.rawValue.replacingOccurrences(of: "_", with: " "))")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    trailing: Button("Cerrar") { onDismiss() }
                        .foregroundColor(.dragonBotSecondary)
                )
            }
        }
    }
    
    
    // MARK: - Contenido del Modo Manual (SLIDERS) - CLAVE
    
    struct ManualModeContent: View {
        let onSave: (String) -> Void
        
        // Estados para los 5 Sliders (corresponden a A, B, C, D, E)
        @State private var servoUpValue: Float = 0.0
        @State private var servoDownValue: Float = 0.0
        @State private var upDownValue: Float = 0.0
        @State private var leftRightValue: Float = 0.0
        @State private var feederValue: Float = 0.0
        
        private func sendAxisCommand(prefix: String, value: Float) {
            let intValue = Int(value.rounded())
            let formattedValue = String(format: "%03d", intValue) // Rellena con ceros (000 a 255)
            let command = "[\(prefix)\(formattedValue)]"
            onSave(command) // Llama al closure de envío de comando
        }
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Control Manual - Movimiento y Servos")
                    .font(.title2)
                    .foregroundColor(.dragonBotSecondary)
                
                HStack {
                    CommandButton(label: "SHUTDOWN RPI") { onSave("[O000]") }
                    CommandButton(label: "MODO REMOTO") { onSave("[R000]") }
                }
                .padding(.horizontal, 0)
                
                // SLIDER A: Servo Wheel Up
                SliderWithLabel(label: "Servo Wheel Up (A): \(Int(servoUpValue))", value: $servoUpValue) { newValue in
                    sendAxisCommand(prefix: "A", value: newValue)
                }
                
                // SLIDER B: Servo Wheel Down
                SliderWithLabel(label: "Servo Wheel Down (B): \(Int(servoDownValue))", value: $servoDownValue) { newValue in
                    sendAxisCommand(prefix: "B", value: newValue)
                }
                
                // SLIDER C: Up-Down
                SliderWithLabel(label: "Up-Down (C): \(Int(upDownValue))", value: $upDownValue) { newValue in
                    sendAxisCommand(prefix: "C", value: newValue)
                }
                
                // SLIDER D: Left-Right
                SliderWithLabel(label: "Left-Right (D): \(Int(leftRightValue))", value: $leftRightValue) { newValue in
                    sendAxisCommand(prefix: "D", value: newValue)
                }
                
                // SLIDER E: Feeder
                SliderWithLabel(label: "Feeder (E): \(Int(feederValue))", value: $feederValue) { newValue in
                    sendAxisCommand(prefix: "E", value: newValue)
                }
                
                Spacer().frame(height: 30)
            }
        }
    }
    
    // Subcomponente reutilizable para el Slider
    struct SliderWithLabel: View {
        let label: String
        @Binding var value: Float
        let onValueChange: (Float) -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Slider(value: $value, in: 0...255, step: 1) { isEditing in
                    if !isEditing {
                        onValueChange(value)
                    }
                }
                .accentColor(.dragonBotPrimary)
            }
            .padding(.horizontal, 10)
        }
    }
    
    // Subcomponente de botón de comando
    struct CommandButton: View {
        let label: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .monospaced()
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.dragonBotPrimary.opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.dragonBotPrimary, lineWidth: 1)
            )
        }
    }
    
    // Contenido del Modo Automático (Placeholder)
    struct AutoModeContent: View {
        let onSave: (String) -> Void // Se mantiene aunque no se use aún
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("Configuración de Puntos de Tiro (Modo Auto)")
                    .font(.title2)
                    .foregroundColor(.dragonBotSecondary)
                
                Text("La implementación de la cuadrícula de puntos de tiro (C/D) y las opciones automáticas se implementará aquí.")
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 5)
                
                // Aquí iría el componente TargetSelectionGrid
            }
            .padding()
        }
    }
}
