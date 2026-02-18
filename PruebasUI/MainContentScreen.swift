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

// MARK: - BOTONES DE MODO COMPACTOS (UNIFICADOS)
struct CompactModeButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassyContainer(color: color) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                        .shadow(color: color, radius: 5)
                    Text(label)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 85)
            }
        }
    }
}

// MARK: - NAVEGACIÓN ESTÁNDAR
struct NavButtonContent: View {
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        GlassyContainer(color: color) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(color).shadow(color: color, radius: 5)
                }
                .padding(.leading, 12)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white)
                    Text("INICIAR SECUENCIA").font(.system(size: 7, design: .monospaced)).foregroundColor(color.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right.square.fill").font(.system(size: 14)).foregroundColor(color.opacity(0.5)).padding(.trailing, 12)
            }
            .padding(.vertical, 12)
        }
    }
}

// MARK: - MAIN CONTENT SCREEN (LIMPIA Y SIN CAPAS EXTRA)
struct MainContentScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Binding var shotsMap: [Int : ShotConfig]
    
    var onBackClick: () -> Void
    var onDrillsClick: () -> Void
    var onSwapClick: () -> Void
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void
    
    @AppStorage("hasSeenManual") private var hasSeenManual = false
    @AppStorage("hasSeenIA") private var hasSeenIA = false
    @AppStorage("hasSeenSliders") private var hasSeenSliders = false
    @AppStorage("hasSeenJoystick") private var hasSeenJoystick = false
    @AppStorage("hasSeenDrills") private var hasSeenDrills = false
    @AppStorage("hasSeenSwap") private var hasSeenSwap = false
    
    @State private var showDeviceSelectionDialog = false
    @State private var showConfigDialog = false
    @State private var showJoystickDialog = false
    @State private var showIAPopup = false // <--- NUEVO ESTADO
    @State private var currentConfigMode: DragonBotMode = .NONE
    @State private var gridPhase: CGFloat = 0
    @State private var activeHelp: HelpContent? = nil
    @State private var pendingAction: (() -> Void)? = nil

    let helpData: [String: HelpContent] = [
        "MANUAL": HelpContent(title: "MODO MANUAL", description: "CONTROLE SU DRAGONBOT AJUSTANDOLO MANUALMENTE CON LAS PERILLAS TRASERAS.", icon: "hand.tap.fill", color: .dragonBotPrimary),
        "IA": HelpContent(title: "MODO IA", description: "INTERFAZ DE VISIÓN ARTIFICIAL Y GESTIÓN DE ENERGÍA.", icon: "bolt.shield.fill", color: .dragonBotSecondary),
        "REMOTO": HelpContent(title: "REMOTO", description: "AJUSTE LA VELOCIDAD DESDE SU TELÉFONO REMOTAMENTE.", icon: "slider.horizontal.3", color: .dragonBotPrimary),
        "JOYSTICK": HelpContent(title: "CONTROL CARTRACK", description: "CONTROL MANUAL DEL MOVIMIENTO DEL CARRITO.", icon: "gamecontroller.fill", color: .dragonBotSecondary),
        "DRILLS": HelpContent(title: "SECUENCIAS DE TIRO", description: "EDITE Y PROGRAME UNA SERIE DE TIROS CONSECUTIVOS.", icon: "scope", color: .dragonBotPrimary),
        "SWAP": HelpContent(title: "SECUENCIA ÚNICA", description: "CONFIGURACIÓN DE TIRO RÁPIDO CON INTERCAMBIO DE PARÁMETROS.", icon: "arrow.triangle.2.circlepath", color: .dragonBotSecondary)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StarFieldView()
            InfinitePerspectiveGrid(phase: gridPhase)
                .stroke(LinearGradient(colors: [Color.dragonBotSecondary.opacity(0.3), .clear], startPoint: .bottom, endPoint: .top), lineWidth: 1.0)
                .onAppear { withAnimation(Animation.linear(duration: 5.0).repeatForever(autoreverses: false)) { gridPhase = 1.0 } }
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 5) {
                    Text("DRAGONBOT").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundColor(.white).tracking(6)
                    Text("TACTICAL INTERFACE V1.1").font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                }.padding(.top, 10)
                
                ConnectionWarningView(communicator: communicator, onConnectClick: { showDeviceSelectionDialog = true })
                
                // 1. MODOS DE OPERACIÓN
                // 1. MODOS DE OPERACIÓN
                // 1. MODOS DE OPERACIÓN
                ControlSection(title: "MODOS TÁCTICOS Y NAVEGACIÓN") {
                    VStack(spacing: 12) {
                        
                        // MODO MANUAL: Ahora abre el Joystick (FullScreen)
                        Button(action: {
                                    communicator.sendCommand("[L000]") // Comando directo para activar modo manual
                                    // Aquí puedes añadir una pequeña vibración o feedback visual si lo deseas
                                }) {
                                    NavButtonContentWithGraphic(
                                        label: "MANUAL CONTROL",
                                        color: .dragonBotPrimary,
                                        graphic: ManualIconView(color: .dragonBotPrimary)
                                    )
                                }
                        
                        // MODO IA: Mantiene su popup de Sistema IA
                        Button(action: { showIAPopup = true }) {
                            NavButtonContentWithGraphic(
                                label: "SISTEMA IA",
                                color: .dragonBotSecondary,
                                graphic: IAIconView(color: .dragonBotSecondary)
                            )
                        }
                        
                        // MODO REMOTO: Ahora abre la lista de Sliders (Sheet)
                        Button(action: {
                            currentConfigMode = .MANUAL // Asegúrate de tener este caso en tu enum DragonBotMode
                            showConfigDialog = true     // <--- Invertido: Ahora abre parámetros remotos
                        }) {
                            NavButtonContentWithGraphic(
                                label: "CONTROL REMOTO",
                                color: .orange,
                                graphic: RemoteIconView(color: .orange)
                            )
                        }
                    }
                    .padding(.horizontal, 5)
                }
                // 2. PROGRAMAS TÁCTICOS (AHORA PRIMERO)
                ControlSection(title: "PROGRAMAS TÁCTICOS") {
                    VStack(spacing: 12) {
                        Button(action: {
                            checkHelp(key: "DRILLS", wasSeen: hasSeenDrills) {
                                hasSeenDrills = true
                                onDrillsClick()
                            }
                        }) {
                            NavButtonContentWithGraphic(
                                label: "EDITOR DE SECUENCIAS",
                                color: .dragonBotPrimary,
                                graphic: BuiltInIconView(color: .dragonBotPrimary)
                            )
                        }

                        Button(action: {
                            checkHelp(key: "SWAP", wasSeen: hasSeenSwap) {
                                hasSeenSwap = true
                                onSwapClick()
                            }
                        }) {
                            NavButtonContentWithGraphic(
                                label: "SECUENCIAS ÚNICAS",
                                color: .dragonBotSecondary,
                                graphic: WarmUpIconView(color: .dragonBotSecondary)
                            )
                        }
                    }
                }

                // 3. CONTROL CARTRACK (AHORA SEGUNDO)
                ControlSection(title: "SISTEMA CARTRACK") {
                    Button(action: {
                        checkHelp(key: "JOYSTICK", wasSeen: hasSeenJoystick) {
                            hasSeenJoystick = true
                            showJoystickDialog = true // <--- El popup de Joystick ahora vive aquí
                        }
                    }) {
                        NavButtonContent(
                            label: "CONTROL CARTRACK",
                            icon: "gamecontroller.fill",
                            color: .dragonBotSecondary
                        )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Popups de Ayuda
            if let help = activeHelp {
                HelpPopupView(content: help) {
                    activeHelp = nil
                    pendingAction?()
                    pendingAction = nil
                }
            }
        }
        // --- MODALES ---
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
        // NUEVO POPUP DE IA
        .sheet(isPresented: $showIAPopup) {
            IAConfigurationDialog(onDismiss: { showIAPopup = false }, onSendCommand: { cmd in
                communicator.sendCommand(cmd)
            })
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

// MARK: - CONTROL SECTION COMPONENT
struct ControlSection<Content: View>: View {
    let title: String
    let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(title).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                Rectangle().fill(LinearGradient(colors: [.dragonBotPrimary.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            }
            content()
        }
    }
}

// MARK: - CONNECTION VIEW COMPACTA
struct ConnectionWarningView: View {
    @ObservedObject var communicator: BLECommunicator
    var onConnectClick: () -> Void
    var body: some View {
        let isConnected = communicator.isConnected
        let activeColor = isConnected ? Color.dragonBotPrimary : Color.dragonBotError
        HStack {
            Circle().fill(activeColor).frame(width: 6, height: 6).shadow(color: activeColor, radius: 3)
            Text(isConnected ? "ONLINE" : "OFFLINE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(activeColor)
            Spacer()
            if !isConnected {
                Button("CONECTAR", action: onConnectClick)
                    .font(.system(size: 8, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4).background(activeColor.opacity(0.2)).foregroundColor(activeColor).cornerRadius(4)
            }
        }.padding(10).background(Color.black.opacity(0.4)).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
    var motionOffset: CGSize
    var spacing: CGFloat = 40
    
    var body: some View {
        Canvas { context, size in
            let offsetX = motionOffset.width.truncatingRemainder(dividingBy: spacing)
            let offsetY = motionOffset.height.truncatingRemainder(dividingBy: spacing)
            
            for x in stride(from: offsetX - spacing, through: size.width + spacing, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 0.5)
            }
            
            for y in stride(from: offsetY - spacing, through: size.height + spacing, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 0.5)
            }
        }
    }
}
struct ModeConfigurationDialog: View {
    let mode: DragonBotMode
    let onDismiss: () -> Void
    let onSave: (String) -> Void
    
    var body: some View {
        ZStack {
            // Fondo negro sólido para resaltar los Sliders Cyberpunk
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Cabecera del Panel
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CONTROL DE PARÁMETROS")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.dragonBotPrimary)
                        Text("MODO: \(String(describing: mode))")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.dragonBotError)
                            .font(.title3)
                            .shadow(color: .dragonBotError.opacity(0.3), radius: 5)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                
                // Carga directa de los Sliders estilizados
                ManualSlidersList(onSave: onSave)
            }
        }
    }
}

// MARK: - COMPONENTE DE JOYSTICKS REMOTOS
struct JoystickRemoteDialog: View {
    @ObservedObject var communicator: BLECommunicator
    let onDismiss: () -> Void
    
    @State private var gridOffset: CGSize = .zero
    @State private var timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    @State private var currentVelocity: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            ReactiveGridView(color: .dragonBotSecondary, motionOffset: gridOffset)
                .ignoresSafeArea()
                .onReceive(timer) { _ in
                    gridOffset.width += currentVelocity.width * 10
                    gridOffset.height += currentVelocity.height * 10
                }
            
            VStack(spacing: 0) {
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
                
                HStack {
                    VStack {
                        Text("MOVIMIENTO").font(.system(size: 10, design: .monospaced)).foregroundColor(.dragonBotPrimary)
                        JoystickView(label: "L") { x, y in
                            let cmd = "[LX\(Int(x * 127 + 127))Y\(Int(y * 127 + 127))]"
                            communicator.sendCommand(cmd)
                            withAnimation(.linear(duration: 0.1)) {
                                currentVelocity = CGSize(width: x, height: -y)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("CÁMARA").font(.system(size: 10, design: .monospaced)).foregroundColor(.dragonBotSecondary)
                        JoystickView(label: "R") { x, y in
                            let cmd = "[RX\(Int(x * 127 + 127))Y\(Int(y * 127 + 127))]"
                            communicator.sendCommand(cmd)
                        }
                    }
                }
                .padding(40)
                
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
    let onMove: (Double, Double) -> Void
    
    @State private var offset: CGSize = .zero
    let radius: CGFloat = 70
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: radius * 2, height: radius * 2)
                .background(Circle().fill(Color.black.opacity(0.3)))
                .overlay(
                    Text(label)
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.05))
                )
            
            Circle()
                .fill(RadialGradient(colors: [.white, .dragonBotPrimary], center: .center, startRadius: 0, endRadius: 30))
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
                            onMove(newX / radius, -(newY / radius))
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

struct IAConfigurationDialog: View {
    let onDismiss: () -> Void
    let onSendCommand: (String) -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Text("MODO IA")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotSecondary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.5)).font(.title2)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                
                Spacer()
                
                VStack(spacing: 20) {
                    // Botón que antes era el de IA directo
                    Button(action: {
                        onSendCommand("[F000]")
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "bolt.shield.fill")
                            Text("ACTIVAR IA")
                        }
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.dragonBotSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 25)
                        .background(Color.dragonBotSecondary.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dragonBotSecondary, lineWidth: 2))
                    }
                    
                    // Botón Shutdown movido desde Remoto
                    Button(action: {
                        onSendCommand("[O000]")
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "power")
                            Text("APAGAR IA")
                        }
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.dragonBotError)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 25)
                        .background(Color.dragonBotError.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dragonBotError, lineWidth: 2))
                    }
                }
                .padding(30)
                
                Spacer()
                
                Text("ADVERTENCIA: EL APAGADO DETIENE TODOS LOS MOTORES INMEDIATAMENTE")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - LISTA DE SLIDERS (ACTUALIZADA: SIN SHUTDOWN)
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Ahora solo queda el botón de Modo Remoto aquí
                HStack(spacing: 15) {
                    Button("ESTABLECER MODO REMOTO") { onSave("[R000]") }
                        .buttonStyle(TerminalButtonStyle(color: .dragonBotSecondary))
                }
                .padding(.top, 10)
                
                VStack(spacing: 35) {
                    SliderItem(label: "ELEVACIÓN SUPERIOR (A)", value: $vA, color: .dragonBotPrimary) { send(prefix: "A", val: vA) }
                    SliderItem(label: "ELEVACIÓN INFERIOR (B)", value: $vB, color: .dragonBotPrimary) { send(prefix: "B", val: vB) }
                    SliderItem(label: "POTENCIA TURBINA 1 (C)", value: $vC, color: .dragonBotSecondary) { send(prefix: "C", val: vC) }
                    SliderItem(label: "POTENCIA TURBINA 2 (D)", value: $vD, color: .dragonBotSecondary) { send(prefix: "D", val: vD) }
                    SliderItem(label: "FRECUENCIA DISPARO (E)", value: $vE, color: .white) { send(prefix: "E", val: vE) }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }
}
// MARK: - SLIDER ITEM CYBERPUNK MODERNO
struct SliderItem: View {
    let label: String
    @Binding var value: Float
    let color: Color
    let onAction: () -> Void
    
    @State private var isDragging: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header del Slider
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Barra decorativa pequeña
                    Rectangle()
                        .fill(color.opacity(0.5))
                        .frame(width: 30, height: 2)
                }
                
                Spacer()
                
                // Valor numérico con efecto de brillo
                Text("\(Int(value))")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(isDragging ? .white : color)
                    .shadow(color: color.opacity(isDragging ? 0.8 : 0.4), radius: isDragging ? 8 : 2)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isDragging)
            }
            
            // Componente de Slider Personalizado
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fondo del carril (Track)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 8)
                    
                    // Marcas de graduación decorativas
                    HStack(spacing: (geometry.size.width / 10) - 1) {
                        ForEach(0..<10) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 1, height: 12)
                        }
                    }
                    
                    // Progreso (Fill)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(value / 255), height: 8)
                        .shadow(color: color.opacity(0.5), radius: 5)
                    
                    // Tirador (Thumb) personalizado
                    Circle()
                        .fill(Color.black)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(color, lineWidth: 3)
                                .shadow(color: color, radius: isDragging ? 10 : 0)
                        )
                        .overlay(
                            Circle()
                                .fill(isDragging ? color : .white)
                                .frame(width: 8, height: 8)
                        )
                        .offset(x: (geometry.size.width * CGFloat(value / 255)) - 12)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    isDragging = true
                                    let percentage = min(max(0, v.location.x / geometry.size.width), 1)
                                    value = Float(percentage * 255)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    onAction()
                                }
                        )
                }
            }
            .frame(height: 24)
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

struct WarmUpIconView: View {
    var color: Color
    var body: some View {
        ZStack {
            // Mini cancha
            TennisCourtShape()
                .fill(color.opacity(0.1))
                .overlay(TennisCourtLines().stroke(color.opacity(0.3), lineWidth: 0.5))
            
            // Red central
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(height: 1)
                .offset(y: -10) // Ajustado a la perspectiva de tu TennisCourtShape
            
            // Trayectorias de calentamiento (líneas punteadas)
            Path { path in
                path.move(to: CGPoint(x: 30, y: 35))
                path.addQuadCurve(to: CGPoint(x: 10, y: 5), control: CGPoint(x: 20, y: 15))
                
                path.move(to: CGPoint(x: 30, y: 35))
                path.addQuadCurve(to: CGPoint(x: 50, y: 5), control: CGPoint(x: 40, y: 15))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 3]))
            
            // Punto de origen
            Circle().fill(color).frame(width: 4, height: 4).offset(y: 15)
        }
        .frame(width: 60, height: 40)
    }
}

struct BuiltInIconView: View {
    var color: Color
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // Bloque Superior
                sequenceBlock
                
                // Bloque Inferior
                sequenceBlock
            }
            
            // Flechas de flujo (Loop)
            flowArrows
        }
        .frame(width: 60, height: 40)
    }
    
    // Representación de los rectángulos con puntos (tiros)
    private var sequenceBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(color, lineWidth: 1)
                .frame(width: 40, height: 14)
                .background(RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.1)))
            
            // Rejilla de puntos estilo la imagen de referencia
            VStack(spacing: 2) {
                ForEach(0..<2) { _ in
                    HStack(spacing: 2) {
                        ForEach(0..<5) { _ in
                            Circle()
                                .fill(color.opacity(0.6))
                                .frame(width: 2, height: 2)
                        }
                    }
                }
            }
        }
    }
    
    // Dibujo de las flechas laterales y de conexión
    private var flowArrows: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let colorIn = color
            
            var path = Path()
            
            // Flecha de bajada (derecha)
            path.move(to: CGPoint(x: w * 0.85, y: h * 0.35))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.65))
            
            // Flecha de retorno (izquierda - el bucle)
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.05, y: h * 0.65)) // Salida lateral
            path.addLine(to: CGPoint(x: w * 0.05, y: h * 0.35)) // Subida
            path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.35)) // Re-entrada
            
            context.stroke(path, with: .color(colorIn.opacity(0.8)), lineWidth: 1)
            
            // Cabezas de flecha pequeñas
            // (Opcional: puedes añadir pequeños triángulos al final de las líneas para más detalle)
        }
    }
}

// MARK: - BOTÓN DE NAVEGACIÓN ACTUALIZADO
struct NavButtonContentWithGraphic<Graphic: View>: View {
    let label: String
    let color: Color
    let graphic: Graphic
    
    var body: some View {
        HStack(spacing: 15) {
            // El gráfico estilo la imagen compartida
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 80, height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.5), lineWidth: 1))
                
                graphic
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("SISTEMA TÁCTICO")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(color.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color.opacity(0.5))
        }
        .padding(10)
        .background(color.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct ManualIconView: View {
    var color: Color
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<3) { i in
                ZStack(alignment: .bottom) {
                    Rectangle() // Carril
                        .fill(color.opacity(0.2))
                        .frame(width: 2, height: 25)
                    
                    Circle() // Knob
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .offset(y: i == 1 ? -15 : -5) // Diferentes alturas
                        .shadow(color: color, radius: 2)
                }
            }
        }
        .frame(width: 60, height: 40)
    }
}

struct IAIconView: View {
    var color: Color
    var body: some View {
        ZStack {
            // Conexiones de fondo
            Path { path in
                path.move(to: CGPoint(x: 15, y: 10))
                path.addLine(to: CGPoint(x: 45, y: 30))
                path.move(to: CGPoint(x: 15, y: 30))
                path.addLine(to: CGPoint(x: 45, y: 10))
                path.move(to: CGPoint(x: 30, y: 5))
                path.addLine(to: CGPoint(x: 30, y: 35))
            }
            .stroke(color.opacity(0.3), lineWidth: 1)
            
            // Nodos
            let positions = [
                CGPoint(x: 15, y: 10), CGPoint(x: 45, y: 10),
                CGPoint(x: 30, y: 20),
                CGPoint(x: 15, y: 30), CGPoint(x: 45, y: 30)
            ]
            
            ForEach(0..<positions.count, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .position(positions[i])
                    .shadow(color: color, radius: 3)
            }
        }
        .frame(width: 60, height: 40)
    }
}

struct RemoteIconView: View {
    var color: Color
    var body: some View {
        VStack(spacing: 2) {
            // Ondas de señal
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4) { i in
                    Rectangle()
                        .fill(color.opacity(Double(i + 1) * 0.2))
                        .frame(width: 3, height: CGFloat(5 + (i * 4)))
                }
            }
            
            // Mini Joystick / D-Pad
            ZStack {
                Circle().stroke(color, lineWidth: 1).frame(width: 20, height: 20)
                Rectangle().fill(color).frame(width: 1, height: 10)
                Rectangle().fill(color).frame(width: 10, height: 1)
            }
        }
        .frame(width: 60, height: 40)
    }
}

struct CartrackIconView: View {
    var color: Color
    var body: some View {
        ZStack {
            // Rejilla de coordenadas de fondo
            HStack(spacing: 10) {
                ForEach(0..<3) { _ in
                    Rectangle().fill(color.opacity(0.1)).frame(width: 1)
                }
            }
            
            // "Robot" o Carrito
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: 25, height: 15)
                    .background(color.opacity(0.1))
                    .overlay(
                        HStack {
                            Circle().fill(color).frame(width: 4)
                            Spacer()
                            Circle().fill(color).frame(width: 4)
                        }.padding(.horizontal, 2)
                    )
                
                // Rastro de movimiento
                Path { path in
                    path.move(to: CGPoint(x: -10, y: 5))
                    path.addLine(to: CGPoint(x: 10, y: 5))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 20, height: 1)
            }
        }
        .frame(width: 60, height: 40)
    }
}
