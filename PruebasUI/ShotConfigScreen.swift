import SwiftUI

struct ShotConfigScreen: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var shotConfig: ShotConfig
    @ObservedObject var communicator: BLECommunicator

    // Callbacks para sincronización con DrillScreen
    var onSaveConfig: (ShotConfig) -> Void
    var onCancel: () -> Void

    // Valores maestros de la red de tiro
    let dValues: [Int] = [255, 127, 0]
    let cValues: [Int] = [0, 64, 127, 191, 255]

    // Estados temporales para edición
    @State private var speedTemp: Double
    @State private var delayTemp: Double
    @State private var targetFTemp: Double
    @State private var targetGTemp: Double
    @State private var targetHTemp: Double
    @State private var selectedRow: Int
    @State private var selectedCol: Int
    
    // Backup para detección de cambios
    private let initialSpeed: Double
    private let initialDelay: Double
    private let initialF: Double
    private let initialG: Double
    private let initialH: Double
    private let initialRow: Int
    private let initialCol: Int
    
    // Animaciones y UI
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

        // Inicializamos estados con valores actuales
        _speedTemp = State(initialValue: Double(shotConfig.speedAB))
        _delayTemp = State(initialValue: Double(shotConfig.delayE))
        _targetFTemp = State(initialValue: shotConfig.targetF)
        _targetGTemp = State(initialValue: shotConfig.targetG)
        _targetHTemp = State(initialValue: shotConfig.targetH)
        
        let row = dValues.firstIndex(of: shotConfig.targetD) ?? 1
        let col = cValues.firstIndex(of: shotConfig.targetC) ?? 2
        _selectedRow = State(initialValue: row)
        _selectedCol = State(initialValue: col)
        
        // Guardamos copia inicial
        self.initialSpeed = Double(shotConfig.speedAB)
        self.initialDelay = Double(shotConfig.delayE)
        self.initialF = shotConfig.targetF
        self.initialG = shotConfig.targetG
        self.initialH = shotConfig.targetH
        self.initialRow = row
        self.initialCol = col
    }

    // MARK: - Navegación
    
    private func navigateToDrills() {
        dismiss()
    }

    private func saveConfigAndReturn() {
        // 1. Persistir cambios en el objeto observado
        shotConfig.speedAB = Int(speedTemp.rounded())
        shotConfig.delayE = Int(delayTemp.rounded())
        shotConfig.targetF = targetFTemp.rounded()
        shotConfig.targetG = targetGTemp.rounded()
        shotConfig.targetH = targetHTemp.rounded()
        shotConfig.targetD = dValues[selectedRow]
        shotConfig.targetC = cValues[selectedCol]

        // 2. Generar y enviar comando de prueba (opcional)
        let xS = mapValue(Double(shotConfig.targetC), from: 0...255, to: 0...99)
        let yS = mapValue(Double(shotConfig.targetD), from: 0...255, to: 0...99)
        let vS = mapValue(speedTemp, from: 0...255, to: 0...99)
        let fS = mapValue(delayTemp, from: 0...2000, to: 0...99)
        let cxS = mapValue(targetFTemp, from: 0...255, to: 0...20)
        let cyS = mapValue(targetGTemp, from: 0...255, to: 0...20)
        let ctS = mapValue(targetHTemp, from: 0...255, to: -3000...3000)
        
        let sh = "[SH\(xS),\(yS),\(vS),\(vS),\(fS),\(cxS),\(cyS),\(ctS)]"
        print("DEBUG: Comando de test enviado: \(sh)")
        communicator.sendCommand(sh)
        
        // 3. Callback y salida
        onSaveConfig(shotConfig)
        navigateToDrills()
    }

    private func cancelAndReturn() {
        onCancel()
        navigateToDrills()
    }

    // MARK: - Helpers
    
    private func mapValue(_ value: Double, from: ClosedRange<Double>, to: ClosedRange<Double>) -> Int {
        let result = to.lowerBound + (to.upperBound - to.lowerBound) * (value - from.lowerBound) / (from.upperBound - from.lowerBound)
        return Int(result.rounded())
    }

    private var hasUnsavedChanges: Bool {
        speedTemp != initialSpeed || delayTemp != initialDelay || targetFTemp != initialF ||
        targetGTemp != initialG || targetHTemp != initialH || selectedRow != initialRow || selectedCol != initialCol
    }

    private var shotTypeDescription: String {
        switch selectedRow {
        case 0: return "TIRO LARGO (FONDO)"
        case 1: return "TIRO INTERMEDIO"
        case 2: return "TIRO CORTO (RED)"
        default: return ""
        }
    }

    private func triggerGlitch() {
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

    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            // Rejilla decorativa de fondo
            VStack(spacing: 2) {
                ForEach(0..<100, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(0.02)).frame(height: 1)
                }
            }.ignoresSafeArea().allowsHitTesting(false)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 4) {
                        Text("DRAGONBOT SYSTEM").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.dragonBotSecondary)
                        Text("CONFIG TIRO #\(shotConfig.shotNumber)").font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(.white)
                    }
                    .padding(.top).offset(x: glitchOffset)

                    // Área de Cancha
                    VStack(spacing: 15) {
                        Text(shotTypeDescription).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.dragonBotPrimary).padding(.vertical, 6).padding(.horizontal, 12).background(Color.dragonBotPrimary.opacity(0.1)).cornerRadius(5).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.dragonBotPrimary.opacity(0.5), lineWidth: 1))
                        
                        ZStack {
                            TennisCourtShape().fill(LinearGradient(colors: [Color.dragonBotPrimary.opacity(0.05), Color.dragonBotPrimary.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                            TennisCourtLines().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            
                            VStack(spacing: 35) {
                                ForEach(0..<dValues.count, id: \.self) { row in
                                    HStack(spacing: 30) {
                                        ForEach(0..<cValues.count, id: \.self) { col in
                                            let isSelected = selectedRow == row && selectedCol == col
                                            ZStack {
                                                if isSelected {
                                                    YOLOTargetBox(label: "OBJ", confidence: confidence).frame(width: 55, height: 55)
                                                }
                                                ShotPointView(isSelected: isSelected, pulseAnim: pulseAnim)
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                                                    selectedRow = row
                                                    selectedCol = col
                                                    triggerGlitch()
                                                }
                                            }
                                        }
                                    }
                                }
                            }.padding(.vertical, 40)
                        }
                        .frame(height: 220).rotation3DEffect(.degrees(45), axis: (x: 1, y: 0, z: 0)).scaleEffect(0.9).opacity(glitchOpacity)
                    }
                    
                    // Panel de Control
                    VStack(spacing: 12) {
                        ModernSlider(label: "VELOCIDAD MOTORES", value: $speedTemp, range: 0...255, icon: "bolt.fill") { triggerGlitch() }
                        ModernSlider(label: "CADENCIA (ms)", value: $delayTemp, range: 0...2000, icon: "timer") { triggerGlitch() }
                        ModernSlider(label: "CARRO X", value: $targetFTemp, range: 0...255, icon: "arrow.left.and.right") { triggerGlitch() }
                        ModernSlider(label: "CARRO Y", value: $targetGTemp, range: 0...255, icon: "arrow.up.and.down") { triggerGlitch() }
                        ModernSlider(label: "CARRO T (GIRO)", value: $targetHTemp, range: 0...255, icon: "rotate.right") { triggerGlitch() }
                    }
                    .padding(.horizontal)

                    // Botones
                    HStack(spacing: 20) {
                        Button(action: {
                            if hasUnsavedChanges { showAbortConfirmation = true }
                            else { cancelAndReturn() }
                        }) {
                            Text("CANCELAR").font(.system(size: 14, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).foregroundColor(.red).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red, lineWidth: 1))
                        }
                        
                        Button(action: saveConfigAndReturn) {
                            Text("GUARDAR").font(.system(size: 14, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding().background(Color.dragonBotPrimary).foregroundColor(.black).cornerRadius(12)
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 40)
                }
            }

            if showAbortConfirmation {
                abortPopup
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.0).repeatForever()) { pulseAnim = 1.3 } }
        .navigationBarHidden(true)
    }

    private var abortPopup: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundColor(.red)
                Text("CAMBIOS SIN GUARDAR").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.white).multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button(action: saveConfigAndReturn) {
                        Text("GUARDAR AHORA").font(.system(size: 14, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding().background(Color.dragonBotPrimary).foregroundColor(.black).cornerRadius(8)
                    }
                    Button(action: cancelAndReturn) {
                        Text("DESCARTAR CAMBIOS").font(.system(size: 14, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                    }
                    Button(action: { showAbortConfirmation = false }) {
                        Text("VOLVER A EDITAR").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.4)).padding(.top, 5)
                    }
                }
            }
            .padding(30).background(Color.dragonBotBackground).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.red.opacity(0.5), lineWidth: 2)).frame(maxWidth: 320)
        }
    }
}

// MARK: - Componentes Visuales

struct ModernSlider: View {
    let label: String; @Binding var value: Double; let range: ClosedRange<Double>; let icon: String; var onChange: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(.dragonBotPrimary).font(.system(size: 12))
                Text(label).font(.system(size: 9, weight: .bold, design: .monospaced))
                Spacer()
                Text("\(Int(value))").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.dragonBotPrimary)
            }.foregroundColor(.white.opacity(0.8))
            Slider(value: $value, in: range, step: 1) { editing in if !editing { onChange() } }.accentColor(.dragonBotPrimary)
        }.padding(10).background(Color.white.opacity(0.05)).cornerRadius(8)
    }
}

struct YOLOTargetBox: View {
    let label: String; let confidence: Double; @State private var shakeOffset = CGSize.zero
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2).stroke(Color.yellow, lineWidth: 1.5).background(Color.yellow.opacity(0.1))
            HStack(spacing: 2) { Text(label); Text(String(format: "%.2f", confidence)).opacity(0.8) }
                .font(.system(size: 8, weight: .black, design: .monospaced)).padding(.horizontal, 4).padding(.vertical, 2).background(Color.yellow).foregroundColor(.black).offset(y: -14)
        }.offset(shakeOffset).onAppear { withAnimation(.interactiveSpring().repeatForever()) { shakeOffset = CGSize(width: 1, height: 1) } }
    }
}

struct ShotPointView: View {
    let isSelected: Bool; let pulseAnim: CGFloat
    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.dragonBotPrimary.opacity(0.3)).frame(width: 30, height: 30).scaleEffect(pulseAnim)
                Circle().fill(Color.dragonBotPrimary).frame(width: 14, height: 14).shadow(color: .dragonBotPrimary, radius: 10)
            } else { Circle().fill(Color.white.opacity(0.2)).frame(width: 10, height: 10) }
        }
    }
}

struct TennisCourtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: CGPoint(x: rect.width * 0.15, y: 0)); path.addLine(to: CGPoint(x: rect.width * 0.85, y: 0)); path.addLine(to: CGPoint(x: rect.width, y: rect.height)); path.addLine(to: CGPoint(x: 0, y: rect.height)); path.closeSubpath(); return path
    }
}

struct TennisCourtLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: CGPoint(x: rect.midX, y: 0)); path.addLine(to: CGPoint(x: rect.midX, y: rect.height)); path.move(to: CGPoint(x: rect.width * 0.07, y: rect.height * 0.33)); path.addLine(to: CGPoint(x: rect.width * 0.93, y: rect.height * 0.33)); path.move(to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.66)); path.addLine(to: CGPoint(x: rect.width * 0.97, y: rect.height * 0.66)); return path
    }
}
