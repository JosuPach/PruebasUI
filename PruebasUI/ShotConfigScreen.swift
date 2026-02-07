import SwiftUI

// MARK: - Vista Principal ShotConfig
struct ShotConfigScreen: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var shotConfig: ShotConfig
    @ObservedObject var communicator: BLECommunicator

    var onSaveConfig: (ShotConfig) -> Void
    var onCancel: () -> Void

    let dValues: [Int] = [0, 127, 255]
    let cValues: [Int] = [0, 64, 127, 191, 255]

    @State private var speedATemp: Double
    @State private var speedBTemp: Double
    @State private var delayTemp: Double
    @State private var targetFTemp: Double
    @State private var targetGTemp: Double
    @State private var targetHTemp: Double
    @State private var selectedRow: Int
    @State private var selectedCol: Int
    @State private var pulseAnim: CGFloat = 1.0

    init(shotConfig: ShotConfig, communicator: BLECommunicator, onSaveConfig: @escaping (ShotConfig) -> Void, onCancel: @escaping () -> Void) {
        self.shotConfig = shotConfig
        self.communicator = communicator
        self.onSaveConfig = onSaveConfig
        self.onCancel = onCancel

        _speedATemp = State(initialValue: Double(shotConfig.speedA))
        _speedBTemp = State(initialValue: Double(shotConfig.speedB))
        _delayTemp = State(initialValue: Double(shotConfig.delayE))
        _targetFTemp = State(initialValue: shotConfig.targetF)
        _targetGTemp = State(initialValue: shotConfig.targetG)
        _targetHTemp = State(initialValue: shotConfig.targetH)
        
        let row = dValues.firstIndex(of: shotConfig.targetD) ?? 1
        let col = cValues.firstIndex(of: shotConfig.targetC) ?? 2
        _selectedRow = State(initialValue: row)
        _selectedCol = State(initialValue: col)
    }

    // MARK: - Funciones de Escalado
    private func scaleTo99(_ value: Double) -> Int { Int(((max(0, min(255, value)) * 99.0) / 255.0).rounded()) }
    private func scaleTo20(_ value: Double) -> Int { Int(((value * 20.0) / 255.0).rounded()) }
    private func scaleToCT(_ value: Double) -> Int { Int(((value * 6000.0 / 255.0) - 3000.0).rounded()) }

    private func generateSHCommand() -> String {
        return "[SH\(scaleTo99(Double(cValues[selectedCol]))),\(scaleTo99(Double(dValues[selectedRow]))),\(scaleTo99(speedATemp)),\(scaleTo99(speedBTemp)),\(scaleTo99(delayTemp)),\(scaleTo20(targetFTemp)),\(scaleTo20(targetGTemp)),\(scaleToCT(targetHTemp))]"
    }

    private var isModified: Bool {
        Int(speedATemp.rounded()) != shotConfig.speedA ||
        Int(speedBTemp.rounded()) != shotConfig.speedB ||
        Int(delayTemp.rounded()) != shotConfig.delayE ||
        targetFTemp.rounded() != shotConfig.targetF ||
        targetGTemp.rounded() != shotConfig.targetG ||
        targetHTemp.rounded() != shotConfig.targetH ||
        selectedRow != (dValues.firstIndex(of: shotConfig.targetD) ?? 1) ||
        selectedCol != (cValues.firstIndex(of: shotConfig.targetC) ?? 2)
    }
    
    // MARK: - Lógica de Test (Modo Remoto Silencioso)
    private func runCadenceTest() {
        // 1. Cambiar a modo remoto
        communicator.sendCommand("[R000]")
        // 2. Detener cualquier proceso previo
        communicator.sendCommand("[Z]")
        // 3. Enviar valor de cadencia escalado 0-255 en formato [EXXX]
        let cadenceValue = Int(delayTemp.rounded())
        let cmdE = "[E\(String(format: "%03d", cadenceValue))]"
        
        communicator.sendCommand(cmdE)
        print(cmdE)
        
        // Feedback háptico
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func saveAndSend() {
        // Al guardar, reactivamos el modo Drill para que los cambios se apliquen a la rutina
        communicator.sendCommand("[MD]")
        
        shotConfig.speedA = Int(speedATemp.rounded()); shotConfig.speedB = Int(speedBTemp.rounded())
        shotConfig.delayE = Int(delayTemp.rounded()); shotConfig.targetF = targetFTemp.rounded()
        shotConfig.targetG = targetGTemp.rounded(); shotConfig.targetH = targetHTemp.rounded()
        shotConfig.targetD = dValues[selectedRow]; shotConfig.targetC = cValues[selectedCol]
        onSaveConfig(shotConfig)
        dismiss()
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                VStack {
                    Spacer()
                    courtVisualization
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                
                VStack(spacing: 16) {
                    VStack(spacing: 14) {
                        CompactParameterSlider(label: "RUEDA A", value: $speedATemp, range: 0...255, icon: "arrow.up.circle", displayValue: "\(scaleTo99(speedATemp))", color: .cyan)
                        CompactParameterSlider(label: "RUEDA B", value: $speedBTemp, range: 0...255, icon: "arrow.down.circle", displayValue: "\(scaleTo99(speedBTemp))", color: .cyan)
                        CompactParameterSlider(label: "CADENCIA", value: $delayTemp, range: 0...255, icon: "clock.fill", displayValue: "\(scaleTo99(delayTemp))", color: .green)
                        CompactParameterSlider(label: "GIRO CT", value: $targetHTemp, range: 0...255, icon: "move.3d", displayValue: "\(scaleToCT(targetHTemp))", color: .orange)
                        CompactParameterSlider(label: "CART. X", value: $targetFTemp, range: 0...255, icon: "arrow.left.and.right", displayValue: "\(scaleTo20(targetFTemp))", color: .white)
                        CompactParameterSlider(label: "CART. Y", value: $targetGTemp, range: 0...255, icon: "arrow.up.and.down", displayValue: "\(scaleTo20(targetGTemp))", color: .white)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(20)
                    
                    Text("COMANDO: \(generateSHCommand())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.4))
                        .padding(.top, 4)
                    
                    actionButtons
                        .padding(.bottom, 10)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseAnim = 1.3 }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DRAGONBOT OS").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                Text("EDITAR TIRO").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(.white)
            }
            
            Spacer()

            // BOTÓN DE TEST INTEGRADO
            Button(action: runCadenceTest) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text("TEST CADENCIA")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }
            .padding(.trailing, 8)
            
            VStack(alignment: .trailing) {
                Circle().fill(communicator.isConnected ? Color.green : Color.red).frame(width: 8, height: 8)
                Text(communicator.isConnected ? "CONECTADO" : "DESCONECTADO").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.gray)
            }
        }.padding([.horizontal, .top])
    }

    private var courtVisualization: some View {
        VStack(spacing: 0) {
            ZStack {
                TennisCourtShape()
                    .fill(LinearGradient(colors: [Color.cyan.opacity(0.15), Color.clear], startPoint: .bottom, endPoint: .top))
                    .overlay(TennisCourtLines().stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                    .frame(width: 320, height: 180)

                VStack(spacing: 24) {
                    ForEach((0...2).reversed(), id: \.self) { row in
                        HStack(spacing: 35) {
                            ForEach(0..<cValues.count, id: \.self) { col in
                                let isSelected = selectedRow == row && selectedCol == col
                                Button(action: {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    withAnimation(.spring(response: 0.3)) { selectedRow = row; selectedCol = col }
                                }) {
                                    ZStack {
                                        if isSelected {
                                            Circle().stroke(Color.cyan, lineWidth: 2).frame(width: 34, height: 34)
                                                .scaleEffect(pulseAnim).opacity(1.3 - pulseAnim)
                                        }
                                        Circle().fill(isSelected ? Color(red: 0.82, green: 0.98, blue: 0.0) : Color.white.opacity(0.2))
                                            .frame(width: 22, height: 22)
                                            .overlay(Image(systemName: "tennisball.fill").resizable().padding(6).foregroundColor(isSelected ? .black : .clear))
                                    }
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .offset(y: -10)
            }
            .rotation3DEffect(.degrees(-12), axis: (x: 1, y: 0, z: 0))
            
            TennisNetView()
                .scaleEffect(1.0)
                .offset(y: -25)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 15) {
            Button(action: {
                communicator.sendCommand("[DR]") // Regresar a modo Drill al cancelar
                onCancel()
                dismiss()
            }) {
                Text("CANCELAR").font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.white.opacity(0.05)).foregroundColor(.white).cornerRadius(12)
            }
            Button(action: saveAndSend) {
                Text("GUARDAR Y ENVIAR").font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(isModified ? Color.cyan : Color.white.opacity(0.1))
                    .foregroundColor(isModified ? .black : .white.opacity(0.2)).cornerRadius(12)
            }.disabled(!isModified)
        }
    }
}

// MARK: - Componentes de Soporte (Slidery Barras)

struct CompactParameterSlider: View {
    let label: String; @Binding var value: Double; let range: ClosedRange<Double>
    let icon: String; let displayValue: String; let color: Color
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(displayValue).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(color)
            }
            CustomModernBar(value: $value, range: range, isDragging: $isDragging, mainColor: color)
                .frame(height: 12)
        }
    }
}

struct CustomModernBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Binding var isDragging: Bool
    let mainColor: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.3))
                
                HStack(spacing: 0) {
                    ForEach(0..<10) { _ in
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 8)
                        Spacer()
                    }
                }
                
                Capsule()
                    .fill(LinearGradient(colors: [mainColor.opacity(0.3), mainColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, percentage * width))
                
                ZStack {
                    Circle().fill(Color.black).frame(width: 18, height: 18)
                    Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 14, height: 14)
                }
                .offset(x: (percentage * width) - 9)
                .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        isDragging = true
                        let percent = Double(val.location.x / width)
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * percent
                        self.value = min(max(range.lowerBound, newValue), range.upperBound)
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
    }
}

// MARK: - Componentes de Estética Visual

struct TennisCourtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.25, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.98, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.02, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct TennisCourtLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.25, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.98, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.02, y: rect.height))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height))
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.45))
        return path
    }
}

struct TennisNetView: View {
    var body: some View {
        ZStack {
            HStack {
                Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 2, height: 25)
                Spacer()
                Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 2, height: 25)
            }
            .frame(width: 325)
            
            Path { path in
                let hStep: CGFloat = 6
                let vStep: CGFloat = 5
                for i in 0...54 {
                    let x = CGFloat(i) * hStep
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: 20))
                }
                for i in 0...4 {
                    let y = CGFloat(i) * vStep
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: 320, y: y))
                }
            }
            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            .frame(width: 320, height: 20)
            
            VStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(height: 2.5)
                    .shadow(color: .white.opacity(0.3), radius: 2)
                Spacer()
            }
            .frame(width: 326, height: 22)
        }
    }
}
