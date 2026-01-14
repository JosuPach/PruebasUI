import SwiftUI
import CoreBluetooth

// MARK: - MAIN CONTENT SCREEN
struct MainContentScreen: View {
    @ObservedObject var communicator: BLECommunicator
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
    @State private var showJoystickDialog: Bool = false // NUEVO ESTADO
    @State private var currentConfigMode: DragonBotMode = .NONE
    @State private var gridPhase: CGFloat = 0
    
    init(communicator: BLECommunicator,
         shotsMap: Binding<[Int : ShotConfig]>,
         onBackClick: @escaping () -> Void,
         onDrillsClick: @escaping () -> Void,
         onSwapClick: @escaping () -> Void,
         onConfigShot: @escaping (Int) -> Void,
         onAddShot: @escaping () -> Void,
         onDeleteShot: @escaping (Int) -> Void) {
        
        self.communicator = communicator
        self._shotsMap = shotsMap
        self.onBackClick = onBackClick
        self.onDrillsClick = onDrillsClick
        self.onSwapClick = onSwapClick
        self.onConfigShot = onConfigShot
        self.onAddShot = onAddShot
        self.onDeleteShot = onDeleteShot
        
        // --- CORRECCIÓN DE FONDO BLANCO ---
        UITableView.appearance().backgroundColor = .clear
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            // Capa 1: Fondo Tron
            Color.dragonBotBackground.ignoresSafeArea()
            StarFieldView()
            InfinitePerspectiveGrid(phase: gridPhase)
                .stroke(LinearGradient(colors: [Color.dragonBotSecondary.opacity(0.3), .clear], startPoint: .bottom, endPoint: .top), lineWidth: 1.0)
                .onAppear {
                    withAnimation(Animation.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                        gridPhase = 1.0
                    }
                }
            
            // Capa 2: Contenido
            NavigationView {
                ZStack {
                    Color.clear.ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 35) {
                            // Cabecera HUD
                            VStack(spacing: 8) {
                                Text("// SYSTEM_CORE_READY")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.dragonBotSecondary)
                                
                                Text("DRAGONBOT")
                                    .font(.system(size: 36, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .tracking(8)
                                    .shadow(color: Color.dragonBotPrimary.opacity(0.4), radius: 10)
                            }
                            .padding(.top, 40)
                            
                            ConnectionWarningView(communicator: communicator, onConnectClick: { showDeviceSelectionDialog = true })
                            
                            // SECCIÓN: MODOS RÁPIDOS
                            ControlSection(title: "QUICK_OPERATIONS") {
                                HStack(spacing: 15) {
                                    ConfigButton(label: "MANUAL", icon: "hand.tap.fill", color: .dragonBotPrimary) {
                                        communicator.sendCommand("[L000]")
                                    }
                                    ConfigButton(label: "I.A. MODE", icon: "bolt.shield.fill", color: .dragonBotSecondary) {
                                        communicator.sendCommand("[F000]")
                                    }
                                }
                            }

                            // --- NUEVA SECCIÓN: JOYSTICK REMOTE ---
                            ControlSection(title: "REMOTE_PILOT_INTERFACE") {
                                Button(action: { showJoystickDialog = true }) {
                                    NavButtonContent(label: "REAL_TIME_CONTROL", icon: "gamecontroller.fill", color: .dragonBotSecondary)
                                }
                            }
                            
                            // SECCIÓN: PROGRAMAS TÁCTICOS
                            ControlSection(title: "TACTICAL_PROGRAMS") {
                                VStack(spacing: 15) {
                                    NavigationLink(destination: DrillScreen(communicator: communicator, shots: $shotsMap, onBackClick: onBackClick, onConfigShot: onConfigShot, onAddShot: onAddShot, onDeleteShot: onDeleteShot)) {
                                        NavButtonContent(label: "DRILL_EDITOR", icon: "scope", color: .dragonBotPrimary)
                                    }
                                    NavigationLink(destination: SwapConfigScreen(communicator: communicator, onClose: onBackClick)) {
                                        NavButtonContent(label: "SWAP_PROTOCOL", icon: "arrow.triangle.2.circlepath", color: .dragonBotSecondary)
                                    }
                                }
                            }
                            
                            // SECCIÓN: AJUSTES MANUALES
                            ControlSection(title: "CRITICAL_OVERRIDE") {
                                HStack(spacing: 15) {
                                    ConfigButton(label: "SLIDERS", icon: "slider.horizontal.3", color: .dragonBotPrimary) {
                                        currentConfigMode = .MANUAL
                                        showConfigDialog = true
                                    }
                                    ConfigButton(label: "AUTO SHOT", icon: "target", color: .white) {
                                        currentConfigMode = .AUTO
                                        showConfigDialog = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 60)
                    }
                    .scrollContentBackground(.hidden)
                }
                .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        // DIÁLOGOS (SHEETS)
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
        // --- POPUP DE JOYSTICKS ---
        .fullScreenCover(isPresented: $showJoystickDialog) {
            JoystickRemoteDialog(communicator: communicator) {
                showJoystickDialog = false
            }
        }
    }
}

// MARK: - COMPONENTE DE JOYSTICKS REMOTOS
struct JoystickRemoteDialog: View {
    @ObservedObject var communicator: BLECommunicator
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("REMOTE_PILOT_LINK")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.dragonBotSecondary)
                        Text("REAL_TIME_DATA_STREAM")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.square.fill")
                            .font(.title)
                            .foregroundColor(.dragonBotError)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.4))
                
                Spacer()
                
                // Área de Joysticks
                HStack {
                    // Joystick Izquierdo (Movimiento/Orientación)
                    VStack {
                        Text("OSC_PRIMARY").font(.system(size: 10, design: .monospaced)).foregroundColor(.dragonBotPrimary)
                        JoystickView(label: "L") { x, y in
                            let cmd = "[LX\(Int(x * 127 + 127))Y\(Int(y * 127 + 127))]"
                            communicator.sendCommand(cmd)
                        }
                    }
                    
                    Spacer()
                    
                    // Joystick Derecho (Cámara/Puntería)
                    VStack {
                        Text("OSC_SECONDARY").font(.system(size: 10, design: .monospaced)).foregroundColor(.dragonBotSecondary)
                        JoystickView(label: "R") { x, y in
                            let cmd = "[RX\(Int(x * 127 + 127))Y\(Int(y * 127 + 127))]"
                            communicator.sendCommand(cmd)
                        }
                    }
                }
                .padding(40)
                
                // Botones Rápidos HUD
                HStack(spacing: 20) {
                    Button("STOP") { communicator.sendCommand("[O000]") }
                        .buttonStyle(TerminalButtonStyle(color: .dragonBotError))
                    Button("CENTER") { communicator.sendCommand("[C127]") }
                        .buttonStyle(TerminalButtonStyle(color: .white))
                    Button("FIRE") { communicator.sendCommand("[E255]") }
                        .buttonStyle(TerminalButtonStyle(color: .dragonBotPrimary))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - UI COMPONENT: JOYSTICK
struct JoystickView: View {
    let label: String
    let onMove: (Double, Double) -> Void // Retorna valores de -1.0 a 1.0
    
    @State private var offset: CGSize = .zero
    let radius: CGFloat = 70
    
    var body: some View {
        ZStack {
            // Base del joystick
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: radius * 2, height: radius * 2)
                .background(Circle().fill(Color.black.opacity(0.3)))
                .overlay(
                    Text(label)
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.05))
                )
            
            // Cursor (Stick)
            Circle()
                .fill(
                    RadialGradient(colors: [.white, .dragonBotPrimary], center: .center, startRadius: 0, endRadius: 30)
                )
                .frame(width: 50, height: 50)
                .shadow(color: .dragonBotPrimary.opacity(0.5), radius: 10)
                .offset(offset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                            let angle = atan2(value.translation.height, value.translation.width)
                            
                            let limitedDistance = min(distance, radius)
                            let newX = cos(angle) * limitedDistance
                            let newY = sin(angle) * limitedDistance
                            
                            offset = CGSize(width: newX, height: newY)
                            onMove(newX / radius, -(newY / radius)) // Invertimos Y para que arriba sea positivo
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                offset = .zero
                                onMove(0, 0)
                            }
                        }
                )
        }
    }
}

// MARK: - DIALOGO CON SLIDERS RESTAURADO Y ESTILIZADO
struct ModeConfigurationDialog: View {
    let mode: DragonBotMode
    let onDismiss: () -> Void
    let onSave: (String) -> Void
    
    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header del Dialog
                HStack {
                    Text("SYSTEM_CONFIG // \(String(describing: mode))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotPrimary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.dragonBotError)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                if mode == .MANUAL {
                    ManualSlidersList(onSave: onSave)
                } else {
                    VStack {
                        Spacer()
                        Text("AUTO_MODE_READY")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("SYSTEM_WAITING_FOR_TRIGGER")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                }
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
                // Botones de Comando Directo
                HStack(spacing: 15) {
                    Button("SHUTDOWN") { onSave("[O000]") }.buttonStyle(TerminalButtonStyle(color: .dragonBotError))
                    Button("REMOTE") { onSave("[R000]") }.buttonStyle(TerminalButtonStyle(color: .dragonBotSecondary))
                }
                .padding(.top)
                
                // Lista de Sliders
                VStack(spacing: 30) {
                    SliderItem(label: "SERVO_UP (A)", value: $vA) { send(prefix: "A", val: vA) }
                    SliderItem(label: "SERVO_DOWN (B)", value: $vB) { send(prefix: "B", val: vB) }
                    SliderItem(label: "ELEVACIÓN (C)", value: $vC) { send(prefix: "C", val: vC) }
                    SliderItem(label: "ROTACIÓN (D)", value: $vD) { send(prefix: "D", val: vD) }
                    SliderItem(label: "FEEDER (E)", value: $vE) { send(prefix: "E", val: vE) }
                }
                .padding(.top, 10)
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
                Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(Int(value))").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.dragonBotPrimary)
            }
            Slider(value: $value, in: 0...255, step: 1) { editing in
                if !editing { onAction() }
            }
            .accentColor(.dragonBotPrimary)
        }
    }
}

// MARK: - ESTILOS ADICIONALES
struct TerminalButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.4 : 0.1))
            .foregroundColor(color)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.5), lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - COMPONENTES VISUALES (GLASSY)
struct GlassyContainer<Content: View>: View {
    let color: Color
    let content: Content
    init(color: Color, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LinearGradient(colors: [color.opacity(0.6), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
            content
        }
    }
}

struct NavButtonContent: View {
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        GlassyContainer(color: color) {
            HStack(spacing: 20) {
                Image(systemName: icon).font(.system(size: 24)).foregroundColor(color).frame(width: 50)
                Text(label).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(color.opacity(0.5)).padding(.trailing)
            }
            .padding(.vertical, 20)
        }
    }
}

struct ConfigButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            GlassyContainer(color: color) {
                VStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 24)).foregroundColor(color)
                    Text(label).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
    }
}

struct ControlSection<Content: View>: View {
    let title: String
    let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text(title).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                Rectangle().fill(LinearGradient(colors: [.dragonBotPrimary.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            }
            content()
        }
    }
}

struct ConnectionWarningView: View {
    @ObservedObject var communicator: BLECommunicator
    var onConnectClick: () -> Void
    var body: some View {
        let isConnected = communicator.isConnected
        let activeColor = isConnected ? Color.dragonBotPrimary : Color.dragonBotError
        HStack {
            Circle().fill(activeColor).frame(width: 8, height: 8).shadow(color: activeColor, radius: 4)
            Text(isConnected ? "LINK_ESTABLISHED" : "LINK_OFFLINE").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(activeColor)
            Spacer()
            if !isConnected {
                Button("INIT_SCAN", action: onConnectClick)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8).background(activeColor.opacity(0.2)).foregroundColor(activeColor).cornerRadius(4)
            }
        }.padding().background(Color.black.opacity(0.3)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

