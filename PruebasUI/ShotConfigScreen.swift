import SwiftUI


struct ShotConfigScreen: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var shotConfig: ShotConfig
    @ObservedObject var communicator: BLECommunicator

    var onSaveConfig: (ShotConfig) -> Void
    var onCancel: () -> Void

    let dValues: [Int] = [255, 127, 0]
    let cValues: [Int] = [0, 64, 127, 191, 255]

    @State private var speedTemp: Double
    @State private var delayTemp: Double
    @State private var selectedRow: Int
    @State private var selectedCol: Int
    
    private let initialSpeed: Double
    private let initialDelay: Double
    private let initialRow: Int
    private let initialCol: Int
    
    @State private var pulseAnim: CGFloat = 1.0
    @State private var showAbortConfirmation = false
    @State private var glitchOffset: CGFloat = 0
    @State private var glitchOpacity: Double = 1.0
    @State private var confidence: Double = 0.98

    init(
        shotConfig: ShotConfig,
        communicator: BLECommunicator,
        onSaveConfig: @escaping (ShotConfig) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.shotConfig = shotConfig
        self.communicator = communicator
        self.onSaveConfig = onSaveConfig
        self.onCancel = onCancel

        let s = Double(shotConfig.speedAB)
        let d = Double(shotConfig.delayE)
        let row = dValues.firstIndex(of: shotConfig.targetD) ?? 1
        let col = cValues.firstIndex(of: shotConfig.targetC) ?? 2

        _speedTemp = State(initialValue: s)
        _delayTemp = State(initialValue: d)
        _selectedRow = State(initialValue: row)
        _selectedCol = State(initialValue: col)
        
        self.initialSpeed = s
        self.initialDelay = d
        self.initialRow = row
        self.initialCol = col
    }

    private var hasUnsavedChanges: Bool {
        speedTemp != initialSpeed ||
        delayTemp != initialDelay ||
        selectedRow != initialRow ||
        selectedCol != initialCol
    }

    private var shotTypeDescription: String {
        switch selectedRow {
        case 0: return "TIRO LARGO (FONDO)"
        case 1: return "TIRO INTERMEDIO"
        case 2: return "TIRO CORTO (RED)"
        default: return ""
        }
    }

    private func triggerDetectionGlitch() {
        confidence = Double.random(in: 0.92...0.99)
        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.2)) {
            glitchOffset = CGFloat.random(in: -3...3)
            glitchOpacity = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring()) {
                glitchOffset = 0
                glitchOpacity = 1.0
            }
        }
    }

    // Función corregida con el nuevo formato de String [SHx,y,v1,v2,feed,cx,cy,ct]
    private func saveConfigAndReturn() {
        shotConfig.speedAB = Int(speedTemp.rounded())
        shotConfig.delayE = Int(delayTemp.rounded())
        shotConfig.targetD = dValues[selectedRow]
        shotConfig.targetC = cValues[selectedCol]
        
        // Mapeo de valores (asumiendo que los targets adicionales F, G, H ya están en el objeto shotConfig)
        let x = shotConfig.targetC
        let y = shotConfig.targetD
        let v1 = shotConfig.speedAB
        let v2 = shotConfig.speedAB // Usando el mismo para Up/Down como en tu ejemplo
        let feed = shotConfig.delayE
        let cx = shotConfig.targetF
        let cy = shotConfig.targetG
        let ct = shotConfig.targetH
        
        // Formato corregido: [SHx,y,servowheelUp,servowheelDown,Feeder,carX,carY,carTeta]
        // Se eliminan los ceros a la izquierda para cumplir con el formato str('[SH10,10,30,30,50,0,-5,0]')
        let sh = "[SH\(x),\(y),\(v1),\(v2),\(feed),\(cx),\(cy),\(ct)]"
        
        communicator.sendCommand(sh)
        onSaveConfig(shotConfig)
        
        dismiss()
    }

    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            VStack(spacing: 2) {
                ForEach(0..<100, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(0.02)).frame(height: 1)
                }
            }.ignoresSafeArea().allowsHitTesting(false)
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("DRAGONBOT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotSecondary)
                    
                    Text("TIRO #\(shotConfig.shotNumber)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.top)
                .offset(x: glitchOffset)

                // Cancha 3D
                VStack(spacing: 15) {
                    Text(shotTypeDescription)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotPrimary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.dragonBotPrimary.opacity(0.1))
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.dragonBotPrimary.opacity(0.5), lineWidth: 1))
                    
                    ZStack {
                        TennisCourtShape()
                            .fill(LinearGradient(colors: [Color.dragonBotPrimary.opacity(0.05), Color.dragonBotPrimary.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                        
                        TennisCourtLines()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        
                        VStack(spacing: 35) {
                            ForEach(0..<dValues.count, id: \.self) { row in
                                HStack(spacing: 30) {
                                    ForEach(0..<cValues.count, id: \.self) { col in
                                        let isSelected = selectedRow == row && selectedCol == col
                                        ZStack {
                                            if isSelected {
                                                YOLOTargetBox(label: shotTypeDescription.components(separatedBy: " ").first ?? "OBJ", confidence: confidence)
                                                    .frame(width: 55, height: 55)
                                            }
                                            ShotPointView(isSelected: isSelected, pulseAnim: pulseAnim)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                                                selectedRow = row
                                                selectedCol = col
                                                triggerDetectionGlitch()
                                                // Comandos individuales siguen usando el formato original si es necesario
                                                communicator.sendCommand(String(format: "[C%03d]", cValues[col]))
                                                communicator.sendCommand(String(format: "[D%03d]", dValues[row]))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 250)
                    .rotation3DEffect(.degrees(45), axis: (x: 1, y: 0, z: 0))
                    .scaleEffect(0.9)
                    .offset(x: glitchOffset * 2)
                    .opacity(glitchOpacity)
                }
                
                // Controles de Parámetros
                VStack(spacing: 20) {
                    ModernSlider(label: "VELOCIDAD DE LANZAMIENTO", value: $speedTemp, range: 0...255, icon: "bolt.fill") {
                        let v = Int(speedTemp.rounded())
                        communicator.sendCommand(String(format: "[A%03d]", v))
                        communicator.sendCommand(String(format: "[B%03d]", v))
                        triggerDetectionGlitch()
                    }
                    ModernSlider(label: "RETARDO ENTRE PELOTA", value: $delayTemp, range: 0...255, icon: "timer") {
                        communicator.sendCommand(String(format: "[E%03d]", Int(delayTemp.rounded())))
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Botones de Acción
                HStack(spacing: 20) {
                    Button(action: {
                        if hasUnsavedChanges {
                            showAbortConfirmation = true
                        } else {
                            onCancel()
                            dismiss()
                        }
                    }) {
                        Text("CANCELAR")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.dragonBotError.opacity(0.1))
                            .foregroundColor(.dragonBotError)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dragonBotError, lineWidth: 1))
                    }

                    Button(action: saveConfigAndReturn) {
                        Text("GUARDAR CAMBIOS")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.dragonBotPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }

            // POPUP DE CONFIRMACIÓN (Cambios no guardados)
            if showAbortConfirmation {
                Color.black.opacity(0.85).ignoresSafeArea().transition(.opacity)
                
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.dragonBotError)
                        Text("CAMBIOS SIN GUARDAR")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Existen cambios en los parámetros que no han sido sincronizados.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: saveConfigAndReturn) {
                            Text("GUARDAR Y SALIR").font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.dragonBotPrimary).foregroundColor(.black).cornerRadius(8)
                        }
                        
                        Button(action: {
                            onCancel()
                            dismiss()
                        }) {
                            Text("DESCARTAR CAMBIOS").font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.dragonBotError.opacity(0.2)).foregroundColor(.dragonBotError)
                                .cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dragonBotError, lineWidth: 1))
                        }
                        
                        Button(action: { showAbortConfirmation = false }) {
                            Text("SEGUIR EDITANDO").font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.vertical, 40)
                .background(ZStack { Color.dragonBotBackground; RoundedRectangle(cornerRadius: 15).stroke(Color.dragonBotError.opacity(0.5), lineWidth: 2) })
                .frame(maxWidth: 320).padding().transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) { pulseAnim = 1.3 }
        }
    }
}

// MARK: - Componentes Visuales

struct YOLOTargetBox: View {
    let label: String
    let confidence: Double
    @State private var shakeOffset = CGSize.zero
    @State private var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2).stroke(Color.yellow, lineWidth: 1.5).background(Color.yellow.opacity(0.1))
            ZStack {
                cornerShape(rotation: 0)
                cornerShape(rotation: 90)
                cornerShape(rotation: 180)
                cornerShape(rotation: 270)
            }.foregroundColor(.yellow)
            
            HStack(spacing: 2) {
                Text(label)
                Text(String(format: "%.2f", confidence)).opacity(0.8)
            }
            .font(.system(size: 8, weight: .black, design: .monospaced)).padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color.yellow).foregroundColor(.black).offset(y: -14)
        }
        .offset(shakeOffset)
        .onReceive(timer) { _ in
            withAnimation(.interactiveSpring(response: 0.05, dampingFraction: 0.1)) {
                shakeOffset = CGSize(width: CGFloat.random(in: -1.2...1.2), height: CGFloat.random(in: -1.2...1.2))
            }
        }
    }
    
    @ViewBuilder private func cornerShape(rotation: Double) -> some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 8))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 8, y: 0))
            }
            .stroke(lineWidth: 3).rotationEffect(.degrees(rotation)).frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct ShotPointView: View {
    let isSelected: Bool
    let pulseAnim: CGFloat
    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.dragonBotPrimary.opacity(0.3)).frame(width: 30, height: 30).scaleEffect(pulseAnim)
                Circle().fill(Color.dragonBotPrimary).frame(width: 14, height: 14).shadow(color: .dragonBotPrimary, radius: 10)
            } else {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 10, height: 10)
            }
        }
    }
}

struct TennisCourtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct TennisCourtLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        path.move(to: CGPoint(x: rect.width * 0.07, y: rect.height * 0.33))
        path.addLine(to: CGPoint(x: rect.width * 0.93, y: rect.height * 0.33))
        path.move(to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.66))
        path.addLine(to: CGPoint(x: rect.width * 0.97, y: rect.height * 0.66))
        return path
    }
}

struct ModernSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String
    var onFinished: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(.dragonBotPrimary)
                Text(label)
                Spacer()
                Text("\(Int(value))").foregroundColor(.dragonBotPrimary)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.8))
            
            Slider(value: $value, in: range, step: 1) { editing in
                if !editing { onFinished() }
            }.accentColor(.dragonBotPrimary)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}
