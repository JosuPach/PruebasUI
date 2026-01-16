import SwiftUI
import CoreBluetooth

// MARK: - COMPONENTE: PATRÓN DE RED (GRID)
struct GridPatternView: View {
    var color: Color
    var spacing: CGFloat = 15
    
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 0.5)
            }
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - GLASSY CONTAINER
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
                .fill(Color.black.opacity(0.6))
            GridPatternView(color: color, spacing: 12)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [color.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 12)
                .stroke(LinearGradient(colors: [color.opacity(0.6), color.opacity(0.1), color.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            content
        }
    }
}

// MARK: - BOTONES DE NAVEGACIÓN Y CONFIG
struct NavButtonContent: View {
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        GlassyContainer(color: color) {
            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 45, height: 45)
                    Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundColor(color).shadow(color: color, radius: 5)
                }
                .padding(.leading, 15)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
                    Text("INICIAR SECUENCIA").font(.system(size: 8, design: .monospaced)).foregroundColor(color.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right.square.fill").font(.system(size: 18)).foregroundColor(color.opacity(0.5)).padding(.trailing, 15)
            }
            .padding(.vertical, 16)
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
                    HStack {
                        Rectangle().fill(color).frame(width: 10, height: 2)
                        Spacer()
                        Text("v1.0").font(.system(size: 6, design: .monospaced)).foregroundColor(color.opacity(0.5))
                    }
                    .padding(.horizontal, 8).padding(.top, 8)
                    Image(systemName: icon).font(.system(size: 28)).foregroundColor(color).shadow(color: color, radius: 8)
                    Text(label).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white).tracking(1)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, minHeight: 110)
            }
        }
    }
}

// MARK: - MAIN CONTENT SCREEN
struct MainContentScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Binding var shotsMap: [Int : ShotConfig]
    
    // Callbacks
    var onBackClick: () -> Void
    var onDrillsClick: () -> Void
    var onSwapClick: () -> Void
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void
    
    // --- PERSISTENCIA DE AYUDA ---
    @AppStorage("hasSeenManual") private var hasSeenManual = false
    @AppStorage("hasSeenIA") private var hasSeenIA = false
    @AppStorage("hasSeenSliders") private var hasSeenSliders = false
    @AppStorage("hasSeenJoystick") private var hasSeenJoystick = false
    @AppStorage("hasSeenDrills") private var hasSeenDrills = false
    @AppStorage("hasSeenSwap") private var hasSeenSwap = false
    
    // Estados de UI
    @State private var showDeviceSelectionDialog: Bool = false
    @State private var showConfigDialog: Bool = false
    @State private var showJoystickDialog: Bool = false
    @State private var currentConfigMode: DragonBotMode = .NONE
    @State private var gridPhase: CGFloat = 0
    
    // Navegación Manual (para disparar ayuda antes de navegar)
    @State private var navigateToDrills = false
    @State private var navigateToSwap = false
    
    // Estado para el Popup de Ayuda
    @State private var activeHelp: HelpContent? = nil
    @State private var pendingAction: (() -> Void)? = nil

    let helpData: [String: HelpContent] = [
        "MANUAL": HelpContent(title: "MODO MANUAL", description: "CONTROLE SU DRAGONBOT AJUSTANDOLO MANUALMENTE CON LAS PERILLAS DE VELOCIDAD EN LA PARTE TRASERA, ESTE BOTÓN ACTIVARÁ DICHA FUNCIÓN.", icon: "hand.tap.fill", color: .dragonBotPrimary),
        "IA": HelpContent(title: "MODO IA", description: "CONTROL POR VISIÓN ARTIFICIAL, LA DRAGONBOT DETECTA AL JUGADOR AUTOMATICAMENTE Y LANZA POR SI SOLA A SU POSICIÓN ACTUAL", icon: "bolt.shield.fill", color: .dragonBotSecondary),
        "SLIDERS": HelpContent(title: "SLIDERS", description: "AJUSTE LA VELOCIDAD DESDE SU TELÉFONO Y REMOTAMENTE, PRESIONANDO EL BOTÓN DE REMOTO, DESPÚES USTED PODRA MOVER TODOS LOS EJES A SU ANTOJO.", icon: "slider.horizontal.3", color: .dragonBotPrimary),
        "JOYSTICK": HelpContent(title: "CONTROL CARTRACK", description: "CONTROL MANUAL DEL MOVIMIENTO DEL CARRITO. UTILICE EL JOYSTICK IZQUIERDO PARA MOVERSE POR LA PISTA Y EL DERECHO PARA LA ORIENTACIÓN.", icon: "gamecontroller.fill", color: .dragonBotSecondary),
        "DRILLS": HelpContent(title: "SECUENCIAS DE TIRO", description: "EDITE Y PROGRAME UNA SERIE DE TIROS CONSECUTIVOS CON DIFERENTES CONFIGURACIONES DE VELOCIDAD Y POSICIÓN.", icon: "scope", color: .dragonBotPrimary),
        "SWAP": HelpContent(title: "SECUENCIA ÚNICA", description: "CONFIGURACIÓN DE TIRO RÁPIDO CON INTERCAMBIO DE PARÁMETROS DINÁMICOS PARA ENTRENAMIENTO ESPECÍFICO.", icon: "arrow.triangle.2.circlepath", color: .dragonBotSecondary)
    ]

    init(communicator: BLECommunicator, shotsMap: Binding<[Int : ShotConfig]>, onBackClick: @escaping () -> Void, onDrillsClick: @escaping () -> Void, onSwapClick: @escaping () -> Void, onConfigShot: @escaping (Int) -> Void, onAddShot: @escaping () -> Void, onDeleteShot: @escaping (Int) -> Void) {
        self.communicator = communicator
        self._shotsMap = shotsMap
        self.onBackClick = onBackClick
        self.onDrillsClick = onDrillsClick
        self.onSwapClick = onSwapClick
        self.onConfigShot = onConfigShot
        self.onAddShot = onAddShot
        self.onDeleteShot = onDeleteShot
        
        UITableView.appearance().backgroundColor = .clear
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            StarFieldView()
            InfinitePerspectiveGrid(phase: gridPhase)
                .stroke(LinearGradient(colors: [Color.dragonBotSecondary.opacity(0.3), .clear], startPoint: .bottom, endPoint: .top), lineWidth: 1.0)
                .onAppear {
                    withAnimation(Animation.linear(duration: 5.0).repeatForever(autoreverses: false)) { gridPhase = 1.0 }
                }
            
            NavigationView {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        Text("DRAGONBOT")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundColor(.white).tracking(8).padding(.top, 40)
                        
                        ConnectionWarningView(communicator: communicator, onConnectClick: { showDeviceSelectionDialog = true })
                        
                        ControlSection(title: "MODOS RÁPIDOS") {
                            HStack(spacing: 15) {
                                ConfigButton(label: "MANUAL", icon: "hand.tap.fill", color: .dragonBotPrimary) {
                                    checkHelp(key: "MANUAL", wasSeen: hasSeenManual) {
                                        hasSeenManual = true
                                        communicator.sendCommand("[L000]")
                                    }
                                }
                                ConfigButton(label: "MODO IA", icon: "bolt.shield.fill", color: .dragonBotSecondary) {
                                    checkHelp(key: "IA", wasSeen: hasSeenIA) {
                                        hasSeenIA = true
                                        communicator.sendCommand("[F000]")
                                    }
                                }
                            }
                        }

                        ControlSection(title: "CONTROL REMOTO DE CARTRACK") {
                            Button(action: {
                                checkHelp(key: "JOYSTICK", wasSeen: hasSeenJoystick) {
                                    hasSeenJoystick = true
                                    showJoystickDialog = true
                                }
                            }) {
                                NavButtonContent(label: "CONTROL REMOTO EN TIEMPO REAL", icon: "gamecontroller.fill", color: .dragonBotSecondary)
                            }
                        }
                        
                        ControlSection(title: "PROGRAMAS TÁCTICOS") {
                            VStack(spacing: 15) {
                                // Navegación Manual para Drills
                                Button(action: {
                                    checkHelp(key: "DRILLS", wasSeen: hasSeenDrills) {
                                        hasSeenDrills = true
                                        navigateToDrills = true
                                    }
                                }) {
                                    NavButtonContent(label: "EDITOR DE SECUENCIAS DE TIRO", icon: "scope", color: .dragonBotPrimary)
                                }
                                .background(
                                    NavigationLink(destination: DrillScreen(communicator: communicator, shots: $shotsMap, onBackClick: onBackClick, onConfigShot: onConfigShot, onAddShot: onAddShot, onDeleteShot: onDeleteShot), isActive: $navigateToDrills) { EmptyView() }
                                )

                                // Navegación Manual para Swap
                                Button(action: {
                                    checkHelp(key: "SWAP", wasSeen: hasSeenSwap) {
                                        hasSeenSwap = true
                                        navigateToSwap = true
                                    }
                                }) {
                                    NavButtonContent(label: "EDITOR DE SECUENCIAS ÚNICAS", icon: "arrow.triangle.2.circlepath", color: .dragonBotSecondary)
                                }
                                .background(
                                    NavigationLink(destination: SwapConfigScreen(communicator: communicator, onClose: onBackClick), isActive: $navigateToSwap) { EmptyView() }
                                )
                            }
                        }
                        
                        ControlSection(title: "CRITICAL_OVERRIDE") {
                            HStack(spacing: 15) {
                                ConfigButton(label: "SLIDERS", icon: "slider.horizontal.3", color: .dragonBotPrimary) {
                                    checkHelp(key: "SLIDERS", wasSeen: hasSeenSliders) {
                                        hasSeenSliders = true
                                        currentConfigMode = .MANUAL
                                        showConfigDialog = true
                                    }
                                }
                                ConfigButton(label: "TIRO AUTOMÁTICO", icon: "target", color: .white) {
                                    currentConfigMode = .AUTO
                                    showConfigDialog = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 60)
                }
                .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())

            // CAPA DEL POPUP
            if let help = activeHelp {
                HelpPopupView(content: help) {
                    activeHelp = nil
                    pendingAction?()
                    pendingAction = nil
                }
            }
        }
        .sheet(isPresented: $showDeviceSelectionDialog) {
            DeviceSelectionDialog(communicator: communicator, onDeviceSelected: { device in
                communicator.connect(device: device)
                showDeviceSelectionDialog = false
            }, onDismiss: { showDeviceSelectionDialog = false })
        }
        .sheet(isPresented: $showConfigDialog) {
            ModeConfigurationDialog(mode: currentConfigMode, onDismiss: {
                showConfigDialog = false
                currentConfigMode = .NONE
            }, onSave: { command in communicator.sendCommand(command) })
        }
        .fullScreenCover(isPresented: $showJoystickDialog) {
            JoystickRemoteDialog(communicator: communicator) { showJoystickDialog = false }
        }
    }

    private func checkHelp(key: String, wasSeen: Bool, action: @escaping () -> Void) {
        if !wasSeen {
            activeHelp = helpData[key]
            pendingAction = action
        } else {
            action()
        }
    }
}

// Nota: El resto de componentes (JoystickRemoteDialog, HelpPopupView, etc.) se mantienen igual debajo de este bloque.
// MARK: - COMPONENTE DE JOYSTICKS REMOTOS
struct JoystickRemoteDialog: View {
    @ObservedObject var communicator: BLECommunicator
    let onDismiss: () -> Void
    
    // Estado para la animación de la rejilla
    @State private var gridOffset: CGSize = .zero
    @State private var timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    // Velocidad actual derivada de los joysticks
    @State private var currentVelocity: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            // FONDO DINÁMICO: Reacciona a currentVelocity
            ReactiveGridView(color: .dragonBotSecondary, motionOffset: gridOffset)
                .ignoresSafeArea()
                .onReceive(timer) { _ in
                    // Actualizamos la posición de la rejilla basándonos en la velocidad del joystick
                    // La velocidad se multiplica por un factor de escala para el efecto visual
                    gridOffset.width += currentVelocity.width * 10
                    gridOffset.height += currentVelocity.height * 10
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("CONTROL REMOTO DE CARTRACK")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.dragonBotSecondary)
                        Text("SISTEMA DE NAVEGACIÓN ACTIVO")
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
                    // Joystick Izquierdo (Movimiento + Reacción de Rejilla)
                    VStack {
                        Text("MOVIMIENTO").font(.system(size: 10, design: .monospaced)).foregroundColor(.dragonBotPrimary)
                        JoystickView(label: "L") { x, y in
                            // Enviamos comando BLE
                            let cmd = "[LX\(Int(x * 127 + 127))Y\(Int(y * 127 + 127))]"
                            communicator.sendCommand(cmd)
                            
                            // ACTUALIZAMOS LA VELOCIDAD DE LA REJILLA VISUAL
                            // x e y vienen de -1.0 a 1.0
                            withAnimation(.linear(duration: 0.1)) {
                                currentVelocity = CGSize(width: x, height: -y)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Joystick Derecho (Orientación)
                    VStack {
                        Text("CÁMARA").font(.system(size: 10, design: .monospaced)).foregroundColor(.dragonBotSecondary)
                        JoystickView(label: "R") { x, y in
                            let cmd = "[RX\(Int(x * 127 + 127))Y\(Int(y * 127 + 127))]"
                            communicator.sendCommand(cmd)
                        }
                    }
                }
                .padding(40)
                
                // Botones Rápidos HUD
                HStack(spacing: 20) {
                    Button("DETENER") {
                        communicator.sendCommand("[O000]")
                        currentVelocity = .zero
                    }
                    .buttonStyle(TerminalButtonStyle(color: .dragonBotError))
                    
                    Button("CENTRO") { communicator.sendCommand("[C127]") }
                    .buttonStyle(TerminalButtonStyle(color: .white))
                    
                    Button("MAX POTENCIA") { communicator.sendCommand("[E255]") }
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
                    Text("SISTEMA DE CONFIGURACIÓN \(String(describing: mode))")
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
                        Text("MODO AUTOMÁTICO LISTO")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("SISTEMA EN ESPERA...")
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
                    Button("APAGAR") { onSave("[O000]") }.buttonStyle(TerminalButtonStyle(color: .dragonBotError))
                    Button("REMOTO") { onSave("[R000]") }.buttonStyle(TerminalButtonStyle(color: .dragonBotSecondary))
                }
                .padding(.top)
                
                // Lista de Sliders
                VStack(spacing: 30) {
                    SliderItem(label: "ARRIBA (A)", value: $vA) { send(prefix: "A", val: vA) }
                    SliderItem(label: "ABAJO (B)", value: $vB) { send(prefix: "B", val: vB) }
                    SliderItem(label: "VELOCIDAD 1 (C)", value: $vC) { send(prefix: "C", val: vC) }
                    SliderItem(label: "VELOCIDAD 2 (D)", value: $vD) { send(prefix: "D", val: vD) }
                    SliderItem(label: "CADENCIA (E)", value: $vE) { send(prefix: "E", val: vE) }
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
            Text(isConnected ? "CONEXIÓN ESTABLECIDA" : "SIN CONEXIÓN").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(activeColor)
            Spacer()
            if !isConnected {
                Button("ESCANEAR DISPOSITIVOS", action: onConnectClick)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8).background(activeColor.opacity(0.2)).foregroundColor(activeColor).cornerRadius(4)
            }
        }.padding().background(Color.black.opacity(0.3)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct HelpContent {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct HelpPopupView: View {
    let content: HelpContent
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            GlassyContainer(color: content.color) {
                VStack(spacing: 20) {
                    Image(systemName: content.icon)
                        .font(.system(size: 45))
                        .foregroundColor(content.color)
                        .shadow(color: content.color, radius: 10)
                        .padding(.top)
                    
                    VStack(spacing: 10) {
                        Text(content.title)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(content.description)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: onDismiss) {
                        Text("ENTENDIDO")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(content.color.opacity(0.2))
                            .foregroundColor(content.color)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(content.color, lineWidth: 1))
                    }
                    .padding(.bottom)
                }
                .padding()
            }
            .frame(width: 280)
        }
    }
}

struct ReactiveGridView: View {
    var color: Color
    var motionOffset: CGSize // El desplazamiento acumulado
    var spacing: CGFloat = 40
    
    var body: some View {
        Canvas { context, size in
            // Calculamos el desplazamiento relativo para mantener la rejilla "infinita"
            // Usamos modulo para que al llegar al límite del espaciado, reinicie suavemente
            let offsetX = motionOffset.width.truncatingRemainder(dividingBy: spacing)
            let offsetY = motionOffset.height.truncatingRemainder(dividingBy: spacing)
            
            // Líneas Verticales (Movimiento en X)
            for x in stride(from: offsetX - spacing, through: size.width + spacing, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 0.5)
            }
            
            // Líneas Horizontales (Movimiento en Y)
            for y in stride(from: offsetY - spacing, through: size.height + spacing, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 0.5)
            }
        }
    }
}
