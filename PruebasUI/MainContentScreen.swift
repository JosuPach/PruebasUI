import SwiftUI
import CoreBluetooth

// MARK: - MAIN CONTENT SCREEN
struct MainContentScreen: View {
    @StateObject var communicator = BLECommunicator()
    @Binding var shotsMap: [Int : ShotConfig]
    
    // Callbacks de navegación
    var onBackClick: () -> Void
    var onDrillsClick: () -> Void
    var onSwapClick: () -> Void
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void
    
    // Estados de UI
    @State private var showDeviceSelectionDialog: Bool = false
    @State private var showConfigDialog: Bool = false
    @State private var currentConfigMode: DragonBotMode = .NONE
    @State private var gridPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 1. FONDO HOMOLOGADO (Estrellas + Rejilla)
            Color.dragonBotBackground.ignoresSafeArea()
            
            StarFieldView()
            
            InfinitePerspectiveGrid(phase: gridPhase)
                .stroke(
                    LinearGradient(
                        colors: [Color.dragonBotSecondary.opacity(0.3), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: 1.0
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        gridPhase = 1.0
                    }
                }
            
            NavigationView {
                ZStack {
                    // Fondo del NavigationView transparente para ver el ZStack base
                    Color.clear.ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 25) {
                            
                            // Cabecera HUD
                            VStack(spacing: 4) {
                                Text("DEVICE_CONTROL_PANEL")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.dragonBotSecondary)
                                    .opacity(0.8)
                                
                                Text("DRAGONBOT")
                                    .font(.system(size: 28, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .tracking(4)
                            }
                            .padding(.top, 20)
                            
                            // --- COMPONENTE: ConnectionWarning ---
                            ConnectionWarningView(
                                communicator: communicator,
                                onConnectClick: { showDeviceSelectionDialog = true }
                            )
                            
                            // --- SECCIÓN: MODOS DE OPERACIÓN DIRECTA ---
                            ControlSection(title: "MODOS DE OPERACIÓN") {
                                HStack(spacing: 12) {
                                    ConfigButton(label: "MANUAL", icon: "hand.tap.fill") {
                                        communicator.sendCommand("[L000]")
                                    }
                                    ConfigButton(label: "I.A. MODE", icon: "cpu") {
                                        communicator.sendCommand("[F000]")
                                    }
                                }
                            }
                            
                            // --- SECCIÓN: PROGRAMAS (DRILLS y SWAP como navegación) ---
                            ControlSection(title: "PROGRAMAS Y RUTINAS") {
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        // Botón Navegación DRILL
                                        NavigationLink(destination: DrillScreen(
                                            communicator: communicator,
                                            shots: $shotsMap,
                                            onBackClick: onBackClick,
                                            onConfigShot: onConfigShot,
                                            onAddShot: onAddShot,
                                            onDeleteShot: onDeleteShot
                                        )) {
                                            NavButtonContent(label: "CONFIG DRILL", icon: "target", color: .dragonBotSecondary)
                                        }
                                        
                                        // Botón Navegación SWAP
                                        NavigationLink(destination: SwapConfigScreen(
                                            communicator: communicator,
                                            onClose: onBackClick
                                        )) {
                                            NavButtonContent(label: "MODO SWAP", icon: "arrow.2.squarepath", color: .dragonBotSecondary)
                                        }
                                    }
                                }
                            }
                            
                            // --- SECCIÓN: SINGLE SHOT (Sliders) ---
                            ControlSection(title: "CONTROL INDIVIDUAL") {
                                HStack(spacing: 12) {
                                    ConfigButton(label: "SLIDERS", icon: "slider.horizontal.3") {
                                        currentConfigMode = .MANUAL
                                        showConfigDialog = true
                                    }
                                    ConfigButton(label: "AUTO SHOT", icon: "scope") {
                                        currentConfigMode = .AUTO
                                        showConfigDialog = true
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onBackClick) {
                            Image(systemName: "chevron.left.square")
                                .foregroundColor(.dragonBotPrimary)
                                .font(.title3)
                        }
                    }
                }
            }
            .accentColor(.dragonBotPrimary)
            .onAppear {
                UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
                UINavigationBar.appearance().shadowImage = UIImage()
            }
        }
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
        .sheet(isPresented: $showConfigDialog) {
            ModeConfigurationDialog(
                mode: currentConfigMode,
                onDismiss: {
                    showConfigDialog = false
                    currentConfigMode = .NONE
                },
                onSave: { command in
                    communicator.sendCommand(command)
                }
            )
        }
    }
}

// MARK: - COMPONENTES DE APOYO

struct ControlSection<Content: View>: View {
    let title: String
    let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.dragonBotPrimary)
                .padding(.leading, 4)
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NavButtonContent: View {
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.title2)
            Text(label).font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .frame(maxWidth: .infinity, minHeight: 85)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.5), lineWidth: 1))
    }
}

struct ConfigButton: View {
    let label: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.title2)
                Text(label).font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .frame(maxWidth: .infinity, minHeight: 85)
            .background(Color.dragonBotPrimary)
            .foregroundColor(.black)
            .cornerRadius(8)
        }
    }
}

struct ConnectionWarningView: View {
    @ObservedObject var communicator: BLECommunicator
    var onConnectClick: () -> Void
    
    var body: some View {
        HStack {
            let isConnected = communicator.isConnected
            Circle()
                .fill(isConnected ? Color.dragonBotPrimary : Color.dragonBotError)
                .frame(width: 8, height: 8)
                .shadow(color: isConnected ? Color.dragonBotPrimary : Color.dragonBotError, radius: 4)
            
            Text(isConnected ? "SISTEMA VINCULADO" : "ESPERANDO CONEXIÓN")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            if !isConnected {
                Button(action: onConnectClick) {
                    Text("BUSCAR")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.dragonBotSecondary)
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - DIALOGO CON SLIDERS
struct ModeConfigurationDialog: View {
    let mode: DragonBotMode
    let onDismiss: () -> Void
    let onSave: (String) -> Void
    
    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("CONFIG_\(String(describing: mode))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotPrimary)
                    Spacer()
                    Button("CERRAR") { onDismiss() }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotError)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                if mode == .MANUAL {
                    ManualSlidersList(onSave: onSave)
                } else {
                    Text("MODO AUTO SELECCIONADO")
                        .foregroundColor(.white)
                        .padding()
                }
                Spacer()
            }
        }
    }
}

struct ManualSlidersList: View {
    let onSave: (String) -> Void
    @State private var vA: Float = 127
    @State private var vB: Float = 127
    @State private var vC: Float = 127
    @State private var vD: Float = 127
    @State private var vE: Float = 127
    
    func send(prefix: String, val: Float) {
        let cmd = "[\(prefix)\(String(format: "%03d", Int(val)))]"
        onSave(cmd)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                HStack(spacing: 15) {
                    Button("OFF") { onSave("[O000]") }.buttonStyle(TerminalButtonStyle(color: .dragonBotError))
                    Button("REMOTE") { onSave("[R000]") }.buttonStyle(TerminalButtonStyle(color: .dragonBotSecondary))
                }
                
                SliderItem(label: "SERVO_UP (A)", value: $vA) { send(prefix: "A", val: vA) }
                SliderItem(label: "SERVO_DOWN (B)", value: $vB) { send(prefix: "B", val: vB) }
                SliderItem(label: "ELEVACIÓN (C)", value: $vC) { send(prefix: "C", val: vC) }
                SliderItem(label: "ROTACIÓN (D)", value: $vD) { send(prefix: "D", val: vD) }
                SliderItem(label: "FEEDER (E)", value: $vE) { send(prefix: "E", val: vE) }
            }
            .padding()
        }
    }
}

struct SliderItem: View {
    let label: String
    @Binding var value: Float
    let onAction: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(Int(value))").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.dragonBotPrimary)
            }
            Slider(value: $value, in: 0...255, step: 1) { editing in
                if !editing { onAction() }
            }
            .accentColor(.dragonBotPrimary)
        }
    }
}

struct TerminalButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1))
    }
}
