import SwiftUI

// MARK: - Vista Principal
struct ShotConfigScreen: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var shotConfig: ShotConfig
    @ObservedObject var communicator: BLECommunicator

    // Callbacks de flujo
    var onSaveConfig: (ShotConfig) -> Void
    var onCancel: () -> Void

    // Valores permitidos para la rejilla (D=Y, C=X)
    let dValues: [Int] = [0, 127, 255]
    let cValues: [Int] = [0, 64, 127, 191, 255]

    // ESTADOS TEMPORALES
    @State private var speedBaseTemp: Double
    @State private var spinBiasTemp: Double // Corregido: ahora persiste
    @State private var delayTemp: Double
    @State private var targetFTemp: Double
    @State private var targetGTemp: Double
    @State private var targetHTemp: Double
    @State private var selectedRow: Int
    @State private var selectedCol: Int
    
    // Estados visuales
    @State private var pulseAnim: CGFloat = 1.0
    @State private var jitterX: CGFloat = 0
    @State private var jitterY: CGFloat = 0
    @State private var aiOpacity: Double = 1.0
    @State private var confidence: Double = 0.98
    
    let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

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

        // Cargamos los valores actuales del objeto para que aparezcan en los sliders
        _speedBaseTemp = State(initialValue: Double(shotConfig.speedAB))
        _spinBiasTemp = State(initialValue: Double(shotConfig.spinBias)) // <-- CARGA VALOR GUARDADO
        _delayTemp = State(initialValue: Double(shotConfig.delayE))
        _targetFTemp = State(initialValue: shotConfig.targetF)
        _targetGTemp = State(initialValue: shotConfig.targetG)
        _targetHTemp = State(initialValue: shotConfig.targetH)
        
        let row = dValues.firstIndex(of: shotConfig.targetD) ?? 1
        let col = cValues.firstIndex(of: shotConfig.targetC) ?? 2
        _selectedRow = State(initialValue: row)
        _selectedCol = State(initialValue: col)
    }

    private var isModified: Bool {
        Int(speedBaseTemp.rounded()) != shotConfig.speedAB ||
        Int(spinBiasTemp.rounded()) != shotConfig.spinBias || // <-- DETECTA CAMBIOS EN SPIN
        Int(delayTemp.rounded()) != shotConfig.delayE ||
        targetFTemp.rounded() != shotConfig.targetF ||
        targetGTemp.rounded() != shotConfig.targetG ||
        targetHTemp.rounded() != shotConfig.targetH ||
        selectedRow != (dValues.firstIndex(of: shotConfig.targetD) ?? 1) ||
        selectedCol != (cValues.firstIndex(of: shotConfig.targetC) ?? 2)
    }

    private func saveConfigAndReturn() {
        // Cálculo con balance de spin aplicado a los motores
        let calculatedMotorA = speedBaseTemp + spinBiasTemp
        let calculatedMotorB = speedBaseTemp - spinBiasTemp
        
        let vA = mapValue(calculatedMotorA, from: 0...255, to: 0...99)
        let vB = mapValue(calculatedMotorB, from: 0...255, to: 0...99)
        let xS = mapValue(Double(dValues[selectedRow]), from: 0...255, to: 0...99)
        let yS = mapValue(Double(cValues[selectedCol]), from: 0...255, to: 0...99)
        let fS = mapValue(delayTemp, from: 200...2000, to: 0...99)
        let cxS = mapValue(targetFTemp, from: 0...255, to: 0...20)
        let cyS = mapValue(targetGTemp, from: 0...255, to: 0...20)
        let ctS = mapValue(targetHTemp, from: 0...255, to: -3000...3000)
        
        let shString = "[SH\(xS),\(yS),\(vA),\(vB),\(fS),\(cxS),\(cyS),\(ctS)]"
        
        // ACTUALIZACIÓN DEL MODELO (PERSISTENCIA)
        shotConfig.speedAB = Int(speedBaseTemp.rounded())
        shotConfig.spinBias = Int(spinBiasTemp.rounded()) // <-- GUARDA EL VALOR DEL SLIDER
        shotConfig.delayE = Int(delayTemp.rounded())
        shotConfig.targetF = targetFTemp.rounded()
        shotConfig.targetG = targetGTemp.rounded()
        shotConfig.targetH = targetHTemp.rounded()
        shotConfig.targetD = dValues[selectedRow]
        shotConfig.targetC = cValues[selectedCol]

        communicator.sendCommand(shString)
        onSaveConfig(shotConfig)
        dismiss()
    }

    private func mapValue(_ value: Double, from: ClosedRange<Double>, to: ClosedRange<Double>) -> Int {
        let clampedValue = max(from.lowerBound, min(from.upperBound, value))
        let result = to.lowerBound + (to.upperBound - to.lowerBound) * (clampedValue - from.lowerBound) / (from.upperBound - from.lowerBound)
        return Int(result.rounded())
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        courtVisualization
                        helpBanner

                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("CONFIGURACIÓN DE RUEDAS")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan).opacity(0.8)
                                
                                ParameterSlider(label: "VELOCIDAD (A + B)", value: $speedBaseTemp, range: 0...255, icon: "bolt.fill")
                                
                                ParameterSlider(label: "BALANCE DE SPIN (OFFSET)", value: $spinBiasTemp, range: -127...127, icon: "arrow.up.and.down.righttriangle.up.righttriangle.down.fill")
                                    .overlay(
                                        Text(spinBiasTemp > 0 ? "TOP" : (spinBiasTemp < 0 ? "BACK" : "NEUTRO"))
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundColor(.cyan)
                                            .offset(y: -18),
                                        alignment: .topTrailing
                                    )
                            }
                            .padding(12).background(Color.white.opacity(0.03)).cornerRadius(15)

                            ParameterSlider(label: "INTERVALO DISPARO (ms)", value: $delayTemp, range: 200...2000, icon: "clock")
                            
                            HStack(spacing: 10) {
                                ParameterMiniSlider(label: "OFFSET F", value: $targetFTemp, range: 0...255)
                                ParameterMiniSlider(label: "OFFSET G", value: $targetGTemp, range: 0...255)
                            }
                            
                            ParameterSlider(label: "GIRO CABEZAL (H)", value: $targetHTemp, range: 0...255, icon: "rotate.right.fill")
                        }
                        .padding(.horizontal)

                        actionButtons
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onReceive(timer) { _ in
            jitterX = CGFloat.random(in: -0.6...0.6)
            jitterY = CGFloat.random(in: -0.6...0.6)
            aiOpacity = Double.random(in: 0.9...1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) { pulseAnim = 3.5 }
        }
    }

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DRAGONBOT VISION OS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(Color.cyan)
                Text("MIXER DE TIRO").font(.system(size: 22, weight: .black, design: .monospaced)).foregroundColor(.white)
            }
            Spacer()
            Text("OS_V2").font(.system(size: 10, design: .monospaced)).foregroundColor(Color.cyan).padding(4).border(Color.cyan)
        }.padding()
    }

    private var courtVisualization: some View {
        VStack(spacing: 10) {
            HStack {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Text("PREDICCIÓN DE IMPACTO").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Spacer()
                Text("ZONA \(selectedRow),\(selectedCol)").font(.system(size: 10, design: .monospaced)).foregroundColor(Color.cyan)
            }.padding(.horizontal)

            ZStack {
                ZStack(alignment: .bottom) {
                    TennisCourtShape().fill(LinearGradient(colors: [Color.cyan.opacity(0.15), Color.clear], startPoint: .bottom, endPoint: .top))
                        .overlay(TennisCourtLines().stroke(Color.white.opacity(0.2), lineWidth: 1.2))

                    VStack(spacing: 12) {
                        ForEach((0...2).reversed(), id: \.self) { row in
                            HStack(spacing: 28) {
                                ForEach(0..<cValues.count, id: \.self) { col in
                                    let isSelected = selectedRow == row && selectedCol == col
                                    let scaleFactor: CGFloat = 0.75 + (CGFloat(row) * 0.12)
                                    
                                    ZStack {
                                        if isSelected {
                                            DetectionBox(confidence: confidence)
                                                .frame(width: 48, height: 48)
                                                .offset(x: jitterX, y: jitterY)
                                                .opacity(aiOpacity)
                                            
                                            Circle()
                                                .stroke(Color.cyan, lineWidth: 1.5)
                                                .frame(width: 12, height: 12)
                                                .scaleEffect(pulseAnim)
                                                .opacity(2.0 - pulseAnim)
                                        }
                                        TennisBallView(isSelected: isSelected).frame(width: 20, height: 20)
                                    }
                                    .scaleEffect(scaleFactor)
                                    .frame(width: 42, height: 42)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedRow = row; selectedCol = col
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 25)
                }
                .frame(width: 380, height: 260)
                .rotation3DEffect(.degrees(-35), axis: (x: 1, y: 0, z: 0))
                .offset(y: -15)

                TennisNetView()
                    .frame(width: 340, height: 40)
                    .offset(y: 108)
            }
            .frame(height: 280).background(Color.black.opacity(0.3)).cornerRadius(20).clipped()
        }.padding(.horizontal)
    }

    private var helpBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundColor(.cyan)
            Text("Selecciona el punto de impacto para configurar la trayectoria.")
                .font(.system(size: 9)).foregroundColor(.white.opacity(0.5))
        }.padding(.horizontal).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        HStack(spacing: 15) {
            Button(action: { onCancel(); dismiss() }) {
                Text("CANCELAR").font(.system(size: 13, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding().background(Color.white.opacity(0.1)).foregroundColor(.white).cornerRadius(12)
            }
            Button(action: saveConfigAndReturn) {
                Text("GUARDAR Y ENVIAR").font(.system(size: 13, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding().background(isModified ? Color.cyan : Color.white.opacity(0.05)).foregroundColor(isModified ? .black : .white.opacity(0.3)).cornerRadius(12)
            }
            .disabled(!isModified)
        }.padding(.horizontal).padding(.bottom, 40)
    }
}

// MARK: - Sub-componentes Visuales

struct TennisBallView: View {
    let isSelected: Bool
    var body: some View {
        ZStack {
            if isSelected { Circle().fill(Color(red: 0.8, green: 1.0, blue: 0.0).opacity(0.3)).blur(radius: 8) }
            Circle().fill(isSelected ? Color(red: 0.82, green: 0.98, blue: 0.0) : Color.white.opacity(0.15))
            if isSelected {
                Image(systemName: "tennisball.fill")
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white.opacity(0.5), Color(red: 0.82, green: 0.98, blue: 0.0))
                    .padding(3)
            }
        }
    }
}

struct DetectionBox: View {
    let confidence: Double
    var body: some View {
        ZStack(alignment: .topLeading) {
            DetectionBoxShape().stroke(Color.cyan, lineWidth: 1.5)
            Text("POS \(Int(confidence * 100))%")
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.cyan)
                .foregroundColor(.black)
                .offset(y: -8)
        }
    }
}

struct DetectionBoxShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); let l: CGFloat = 8
        path.move(to: CGPoint(x: 0, y: l)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: l, y: 0))
        path.move(to: CGPoint(x: rect.width - l, y: 0)); path.addLine(to: CGPoint(x: rect.width, y: 0)); path.addLine(to: CGPoint(x: rect.width, y: l))
        path.move(to: CGPoint(x: rect.width, y: rect.height - l)); path.addLine(to: CGPoint(x: rect.width, y: rect.height)); path.addLine(to: CGPoint(x: rect.width - l, y: rect.height))
        path.move(to: CGPoint(x: l, y: rect.height)); path.addLine(to: CGPoint(x: 0, y: rect.height)); path.addLine(to: CGPoint(x: 0, y: rect.height - l))
        return path
    }
}

struct ParameterSlider: View {
    let label: String; @Binding var value: Double; let range: ClosedRange<Double>; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(.cyan).font(.system(size: 10))
                Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("\(Int(value))").font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(.cyan)
            }
            Slider(value: $value, in: range).tint(.cyan)
        }.padding(12).background(Color.white.opacity(0.04)).cornerRadius(12)
    }
}

struct ParameterMiniSlider: View {
    let label: String; @Binding var value: Double; let range: ClosedRange<Double>
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.4))
            HStack {
                Slider(value: $value, in: range).tint(.cyan)
                Text("\(Int(value))").font(.system(size: 10, design: .monospaced)).foregroundColor(.white).frame(width: 25)
            }
        }.padding(10).background(Color.white.opacity(0.04)).cornerRadius(12)
    }
}

struct TennisCourtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.2, y: 0)); path.addLine(to: CGPoint(x: rect.width * 0.8, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height)); path.addLine(to: CGPoint(x: rect.width * 0.05, y: rect.height)); path.closeSubpath()
        return path
    }
}

struct TennisCourtLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.2, y: 0)); path.addLine(to: CGPoint(x: rect.width * 0.8, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height)); path.addLine(to: CGPoint(x: rect.width * 0.05, y: rect.height)); path.closeSubpath()
        path.move(to: CGPoint(x: rect.width * 0.5, y: 0)); path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height))
        path.move(to: CGPoint(x: rect.width * 0.12, y: rect.height * 0.5)); path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.5))
        return path
    }
}

struct TennisNetView: View {
    var body: some View {
        ZStack {
            HStack {
                Capsule().fill(Color.gray).frame(width: 3, height: 40)
                Spacer()
                Capsule().fill(Color.gray).frame(width: 3, height: 40)
            }
            ZStack {
                Path { path in
                    let hStep: CGFloat = 7
                    let vStep: CGFloat = 6
                    for i in 0...50 {
                        let x = CGFloat(i) * hStep
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: 35))
                    }
                    for i in 0...6 {
                        let y = CGFloat(i) * vStep
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: 340, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                
                VStack {
                    Rectangle().fill(Color.white).frame(height: 3)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    Spacer()
                }
            }
            .frame(width: 330, height: 35)
        }
    }
}
