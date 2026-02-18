import SwiftUI

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        // Esto vincula el gesto físico al delegado para que no se apague
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Solo permite deslizar si hay una pantalla a la cual regresar
        return viewControllers.count > 1
    }
}

// MARK: - Mini Preview de la Cancha
struct MiniCourtPreview: View {
    let targetC: Double
    let targetD: Double
    let spin: Int
    
    // Configuración de límites para que no se salga
    private let ballSize: CGFloat = 10
    private let padding: CGFloat = 6 // Margen mínimo desde el borde
    
    var body: some View {
        ZStack {
            // 1. Fondo con gradiente
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.15, blue: 0.25)]),
                    startPoint: .top, endPoint: .bottom
                ))
            
            // 2. Malla de la cancha
            VStack(spacing: 0) {
                ForEach(0..<4) { _ in
                    Divider().background(Color.white.opacity(0.05))
                    Spacer()
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<3) { _ in
                    Divider().background(Color.white.opacity(0.05))
                    Spacer()
                }
            }

            // 3. Líneas de referencia
            Canvas { context, size in
                let w = size.width
                let h = size.height
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w, y: h * 0.15))
                }, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
            }
            
            // 4. PUNTO DE IMPACTO (La Pelota) con ajuste de límites
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                // Mapeo con zona de seguridad:
                // En lugar de usar de 0 a w, usamos de 'padding' a 'w - padding'
                let xPos = padding + (CGFloat(targetC / 255.0) * (w - (padding * 2)))
                let yPos = padding + (CGFloat(targetD / 255.0) * (h - (padding * 2)))
                
                ZStack {
                    // Resplandor (Glow)
                    Circle()
                        .fill(spinColor.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .blur(radius: 4)
                    
                    // Punto central
                    Circle()
                        .fill(spinColor)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .frame(width: ballSize, height: ballSize)
                    
                    // Icono de dirección de Spin
                    Image(systemName: spin > 0 ? "chevron.up" : (spin < 0 ? "chevron.down" : "circle"))
                        .font(.system(size: 6, weight: .black))
                        .foregroundColor(.black)
                }
                .position(x: xPos, y: yPos)
            }
        }
        .frame(width: 65, height: 85)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6)) // Asegura que nada sobresalga
    }
    
    var spinColor: Color {
        if spin > 10 { return .green }      // Topspin significativo
        if spin < -10 { return .red }       // Backspin significativo
        return Color.cyan                   // Flat / Neutral
    }
}
// MARK: - LoopPath Animado
struct LoopPath: Shape {
    let count: Int
    let stepHeight: CGFloat = 144
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        let xPos: CGFloat = 41
        let firstY: CGFloat = 45
        let lastY: CGFloat = firstY + CGFloat(count - 1) * stepHeight
        path.move(to: CGPoint(x: xPos, y: firstY))
        path.addLine(to: CGPoint(x: xPos, y: lastY))
        if count > 1 {
            let loopWidth: CGFloat = 30
            let cornerRadius: CGFloat = 15
            path.addLine(to: CGPoint(x: xPos - loopWidth + cornerRadius, y: lastY))
            path.addArc(center: CGPoint(x: xPos - loopWidth + cornerRadius, y: lastY - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: xPos - loopWidth, y: firstY + cornerRadius))
            path.addArc(center: CGPoint(x: xPos - loopWidth + cornerRadius, y: firstY + cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: xPos - 8, y: firstY))
        }
        return path
    }
}

// MARK: - InstructionsView
struct InstructionsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 25) {
                // Título
                Text("GUIDE")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.dragonBotPrimary)
                
                VStack(alignment: .leading, spacing: 20) {
                    // SECCIÓN: FLUJO DE CARGA
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PASO 1: SINCRONIZACIÓN")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.dragonBotSecondary)
                        
                        Label("Usa 'ENVIAR SECUENCIA' para cargar los tiros. El botón de inicio se desbloqueará tras el envío.", systemImage: "arrow.up.doc.fill")
                    }
                    
                    // SECCIÓN: EJECUCIÓN
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PASO 2: EJECUCIÓN")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.dragonBotPrimary)
                        
                        Label("'INICIAR' activa la rutina cargada. 'DETENER' apaga todos los tiros y motores inmediatamente.", systemImage: "play.pause.fill")
                    }
                    
                    // SECCIÓN: EDICIÓN Y BORRADO
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONTROLES TÉCNICOS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.gray)
                        
                        Label("EDITAR (en la tarjeta): Modifica los parámetros de ese tiro individual.", systemImage: "slider.horizontal.3")
                        Label("RESET (Z): Borra la lista completa de tiros para reiniciar la secuencia.", systemImage: "trash.fill")
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                
                // Botón de cierre (Único botón interactivo)
                Button(action: { withAnimation { isPresented = false } }) {
                    Text("ENTENDIDO")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.dragonBotPrimary)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color(red: 0.1, green: 0.12, blue: 0.18))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.dragonBotPrimary.opacity(0.3), lineWidth: 1)
            )
            .padding(40)
        }
    }
}
// MARK: - DrillShotCard
struct DrillShotCard: View {
    let cfg: ShotConfig
    var isCurrent: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(isCurrent ? Color.white : Color.dragonBotPrimary).frame(width: 34, height: 34)
                Text("\(cfg.shotNumber)").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.black)
            }.frame(width: 44)
            HStack(spacing: 15) {
                // En DrillShotCard, dentro de la llamada a MiniCourtPreview:
                MiniCourtPreview(
                    targetC: Double(cfg.targetC),
                    targetD: Double(cfg.targetD),
                    spin: Int(cfg.targetH) - 128 // Si 128 es el centro, esto dará negativos y positivos
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("TIRO \(cfg.shotNumber)").font(.system(size: 10, weight: .black)).foregroundColor(isCurrent ? .white : .gray)
                        Spacer()
                        if !isCurrent { Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.red.opacity(0.7)) } }
                    }
                    
                    HStack(spacing: 10) {
                        Text("A: \(cfg.speedA)").font(.system(size: 13, weight: .bold)).foregroundColor(.dragonBotSecondary)
                        Text("B: \(cfg.speedB)").font(.system(size: 13, weight: .bold)).foregroundColor(.dragonBotPrimary)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(Int(cfg.targetH)) RPM").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                        Text(cfg.targetH > 0 ? "TOP" : (cfg.targetH < 0 ? "BACK" : "FLAT")).font(.system(size: 7, weight: .black)).padding(.horizontal, 4).padding(.vertical, 1).background(cfg.targetH > 0 ? Color.green.opacity(0.3) : (cfg.targetH < 0 ? Color.red.opacity(0.3) : Color.gray.opacity(0.3))).cornerRadius(3).foregroundColor(.white)
                    }
                    HStack {
                        Text("DELAY: \(cfg.delayE)ms").font(.system(size: 9, weight: .bold)).foregroundColor(.dragonBotPrimary)
                        Spacer()
                        Button(action: onEdit) { Text("EDITAR").font(.system(size: 9, weight: .black)).padding(.horizontal, 10).padding(.vertical, 4).background(isCurrent ? Color.white.opacity(0.2) : Color.dragonBotPrimary).foregroundColor(isCurrent ? .white : .black).cornerRadius(4) }.disabled(isCurrent)
                    }
                }
            }// Dentro de DrillShotCard, en el contenedor de la derecha
                .padding(12)
                .background(
                    isCurrent ?
                    Color.dragonBotPrimary.opacity(0.15) :
                    Color.white.opacity(0.05)
                )
                .cornerRadius(15)
                .shadow(color: isCurrent ? Color.dragonBotPrimary.opacity(0.2) : .clear, radius: 8)
        }.padding(.horizontal)
    }
}

// MARK: - DrillScreen Principal
struct DrillScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Binding var shots: [Int : ShotConfig]
    @Environment(\.dismiss) var dismiss // Permite cerrar la vista
    
    var onBackClick: () -> Void
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void

    @State private var loopCount: Int = 1
    @State private var isInfinite: Bool = false
    @State private var isRunning: Bool = false
    @State private var showInstructions: Bool = false
    @State private var dashPhase: CGFloat = 0
    @State private var isDataLoaded: Bool = false

    // MARK: - Funciones de Utilidad
    private func getSHString(for cfg: ShotConfig) -> String {
        let vA = mapValue(Double(cfg.speedA), from: 0...255, to: 0...99)
        let vB = mapValue(Double(cfg.speedB), from: 0...255, to: 0...99)
        let xS = mapValue(Double(cfg.targetC), from: 0...255, to: 0...99)
        let yS = mapValue(Double(cfg.targetD), from: 0...255, to: 0...99)
        let fS = mapValue(Double(cfg.delayE), from: 0...255, to: 0...99)
        let cxS = mapValue(cfg.targetF, from: 0...255, to: 0...20)
        let cyS = mapValue(cfg.targetG, from: 0...255, to: 0...20)
        let ctS = mapValue(cfg.targetH, from: 0...255, to: -3000...3000)
        
        return "[SH\(xS),\(yS),\(vA),\(vB),\(fS),\(cxS),\(cyS),\(ctS)]"
    }

    private func mapValue(_ value: Double, from: ClosedRange<Double>, to: ClosedRange<Double>) -> Int {
        let clampedValue = max(from.lowerBound, min(from.upperBound, value))
        let result = to.lowerBound + (to.upperBound - to.lowerBound) * (clampedValue - from.lowerBound) / (from.upperBound - from.lowerBound)
        return Int(result.rounded())
    }

    // MARK: - Body
    var body: some View {
        let sortedShotList = shots.values.sorted { $0.shotNumber < $1.shotNumber }

        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- HEADER SUPERIOR ---
                HStack(spacing: 15) {
                    Button(action: {
                        // Seguridad: Si está corriendo, pausamos antes de salir
                        if isRunning {
                            communicator.sendCommand("[P]")
                        }
                        onBackClick()
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("VOLVER")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.dragonBotPrimary.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dragonBotPrimary.opacity(0.3), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("DRAGONBOT OS").font(.system(size: 8, weight: .black)).foregroundColor(.dragonBotPrimary.opacity(0.6))
                        Text("SECUENCIAS").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: { showInstructions = true }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.4))

                // --- ESTADO DE CONEXIÓN ---
                HStack {
                    Circle()
                        .fill(communicator.isConnected ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(communicator.isConnected ? "DRAGONBOT CONECTADA" : "SISTEMA DESCONECTADO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(communicator.isConnected ? .green : .red)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))

                // --- PANEL DE CONTROLES ---
                VStack(spacing: 15) {
                    HStack(spacing: 12) {
                        Button(action: {
                            print("📤 Enviando MODO DRILL: [MD]")
                            communicator.sendCommand("[MD]")
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "target")
                                Text("MODO DRILL").font(.system(size: 8, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.dragonBotSecondary.opacity(0.2))
                            .foregroundColor(.dragonBotSecondary)
                            .cornerRadius(12)
                        }
                        
                        VStack(spacing: 4) {
                            Text("BUCLES").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                            HStack(spacing: 10) {
                                Button(action: {
                                    if loopCount > 1 {
                                        loopCount -= 1
                                        communicator.sendCommand("[N\(loopCount)]")
                                    }
                                }) { Image(systemName: "minus.square.fill") }
                                
                                Text("\(loopCount)").font(.system(size: 18, weight: .black)).frame(width: 30)
                                
                                Button(action: {
                                    if loopCount < 99 {
                                        loopCount += 1
                                        communicator.sendCommand("[N\(loopCount)]")
                                    }
                                }) { Image(systemName: "plus.square.fill") }
                            }.foregroundColor(.dragonBotPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)

                        Button(action: {
                            isInfinite.toggle()
                            let cmd = isInfinite ? "[I]" : "[N\(loopCount)]"
                            communicator.sendCommand(cmd)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "infinity")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(isInfinite ? .dragonBotPrimary : .gray)
                                Text("INFINITO").font(.system(size: 8, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isInfinite ? Color.dragonBotPrimary.opacity(0.15) : Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Button(action: {
                                communicator.sendCommand("[X]")
                                isDataLoaded = false
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("RESET").font(.system(size: 8, weight: .bold))
                                }
                                .frame(width: 60, height: 55)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                print("🚀 CARGANDO SECUENCIA...")
                                for shot in sortedShotList {
                                    communicator.sendCommand(getSHString(for: shot))
                                }
                                withAnimation { isDataLoaded = true }
                            }) {
                                HStack {
                                    Image(systemName: isDataLoaded ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                                    Text(isDataLoaded ? "DATOS CARGADOS" : "ENVIAR SECUENCIA")
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity, minHeight: 55)
                                .background(isDataLoaded ? Color.green.opacity(0.8) : Color.dragonBotSecondary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        Button(action: {
                            if !isRunning {
                                communicator.sendCommand("[GO]")
                            } else {
                                communicator.sendCommand("[Z]")
                            }
                            isRunning.toggle()
                        }) {
                            HStack {
                                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                Text(isRunning ? "DETENER" : (isDataLoaded ? "INICIAR SECUENCIA" : "CARGUE DATOS"))
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 65)
                            .background(isRunning ? Color.red : (isDataLoaded ? Color.dragonBotPrimary : Color.gray.opacity(0.3)))
                            .foregroundColor(isDataLoaded || isRunning ? .black : .white.opacity(0.5))
                            .cornerRadius(12)
                        }
                        .disabled(!isDataLoaded && !isRunning)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 15)

                // --- LISTA DE TIROS ---
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        if sortedShotList.count > 1 {
                            LoopPath(count: sortedShotList.count)
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: isRunning ? [10, 6] : [], dashPhase: dashPhase))
                                .foregroundColor(isRunning ? .dragonBotPrimary : .white.opacity(0.2))
                                .frame(width: 60)
                                .onAppear {
                                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { dashPhase -= 16 }
                                }
                        }
                        
                        VStack(spacing: 0) {
                            ForEach(Array(sortedShotList.enumerated()), id: \.element.shotNumber) { index, cfg in
                                DrillShotCard(
                                    cfg: cfg,
                                    isCurrent: isRunning && index == 0,
                                    onEdit: { onConfigShot(cfg.shotNumber) },
                                    onDelete: {
                                        onDeleteShot(cfg.shotNumber)
                                        isDataLoaded = false
                                    }
                                )
                                
                                if index < sortedShotList.count - 1 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.2.circlepath")
                                        Text("ESPERA: \(String(format: "%.1f", Double(cfg.delayE) / 1000.0))s")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    }
                                    .foregroundColor(isRunning ? .dragonBotPrimary : .white.opacity(0.4))
                                    .padding(.leading, 70)
                                    .frame(height: 30)
                                } else {
                                    Spacer().frame(height: 30)
                                }
                            }
                            
                            Button(action: {
                                onAddShot()
                                isDataLoaded = false
                            }) {
                                Label("AÑADIR NUEVO TIRO", systemImage: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 15).stroke(Color.dragonBotPrimary, lineWidth: 1))
                            }
                            .foregroundColor(.dragonBotPrimary)
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                    .padding(.vertical)
                }
            }
            
            if showInstructions { InstructionsView(isPresented: $showInstructions) }
        }
        .navigationBarBackButtonHidden(true)
    }
}
