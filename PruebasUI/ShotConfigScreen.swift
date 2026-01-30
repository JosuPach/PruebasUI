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

    @State private var powerTemp: Double
    @State private var spinTemp: Double
    @State private var delayTemp: Double
    @State private var targetFTemp: Double
    @State private var targetGTemp: Double
    @State private var targetHTemp: Double
    @State private var selectedRow: Int
    @State private var selectedCol: Int
    @State private var pulseAnim: CGFloat = 1.0

    init(shotConfig: ShotConfig, communicator: BLECommunicator, onSaveConfig: @escaping (ShotConfig) -> Void, onCancel: @escaping ( ) -> Void) {
        self.shotConfig = shotConfig
        self.communicator = communicator
        self.onSaveConfig = onSaveConfig
        self.onCancel = onCancel

        // Inicializamos con los valores actuales del objeto
        _powerTemp = State(initialValue: Double(shotConfig.speedAB))
        _spinTemp = State(initialValue: Double(shotConfig.spinBias))
        _delayTemp = State(initialValue: Double(shotConfig.delayE))
        _targetFTemp = State(initialValue: shotConfig.targetF)
        _targetGTemp = State(initialValue: shotConfig.targetG)
        _targetHTemp = State(initialValue: shotConfig.targetH)
        
        let row = dValues.firstIndex(of: shotConfig.targetD) ?? 1
        let col = cValues.firstIndex(of: shotConfig.targetC) ?? 2
        _selectedRow = State(initialValue: row)
        _selectedCol = State(initialValue: col)
    }

    // --- LÓGICA DE ESCALADO UNIFICADA ---
    private func scaleTo99(_ value: Double) -> Int {
        let clamped = max(0, min(255, value))
        return Int(((clamped * 99.0) / 255.0).rounded())
    }
    
    private func scaleTo20(_ value: Double) -> Int { Int(((value * 20.0) / 255.0).rounded()) }
    private func scaleToCT(_ value: Double) -> Int { Int(((value * 6000.0 / 255.0) - 3000.0).rounded()) }

    private func generateSHCommand() -> String {
        let ix = scaleTo99(Double(cValues[selectedCol]))
        let iy = scaleTo99(Double(dValues[selectedRow]))
        
        // Mixer de motores: Importante usar el mismo escalado que en DrillScreen
        let vA = scaleTo99(powerTemp + spinTemp)
        let vB = scaleTo99(powerTemp - spinTemp)
        
        let ifeed = scaleTo99(delayTemp)
        let icx = scaleTo20(targetFTemp)
        let icy = scaleTo20(targetGTemp)
        let ict = scaleToCT(targetHTemp)
        
        return "[SH\(ix),\(iy),\(vA),\(vB),\(ifeed),\(icx),\(icy),\(ict)]"
    }

    private var isModified: Bool {
        Int(powerTemp.rounded()) != shotConfig.speedAB ||
        Int(spinTemp.rounded()) != shotConfig.spinBias ||
        Int(delayTemp.rounded()) != shotConfig.delayE || // Añadido para detectar cambios en delay
        selectedRow != (dValues.firstIndex(of: shotConfig.targetD) ?? 1) ||
        selectedCol != (cValues.firstIndex(of: shotConfig.targetC) ?? 2)
    }

    private func saveAndSend() {
        let command = generateSHCommand()
        print("""
        ---------------------------------
        💾 GUARDANDO CONFIGURACIÓN:
        Valores Brutos -> P:\(powerTemp), S:\(spinTemp), D:\(delayTemp)
        Comando Final  -> \(command)
        ---------------------------------
        """)
        
        // PERSISTENCIA: Guardamos los valores en base 0-255
        // para que getSHString en DrillScreen haga el mapeo final correctamente.
        shotConfig.speedAB = Int(powerTemp.rounded())
        shotConfig.spinBias = Int(spinTemp.rounded())
        shotConfig.delayE = Int(delayTemp.rounded())
        shotConfig.targetF = targetFTemp.rounded()
        shotConfig.targetG = targetGTemp.rounded()
        shotConfig.targetH = targetHTemp.rounded()
        shotConfig.targetD = dValues[selectedRow]
        shotConfig.targetC = cValues[selectedCol]

        onSaveConfig(shotConfig)
        dismiss()
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 15) {
                headerView
                
                courtVisualization
                    .frame(height: 220)
                
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ModernParameterSlider(label: "POTENCIA", value: $powerTemp, range: 0...255, icon: "bolt.fill", displayValue: "\(scaleTo99(powerTemp))")
                        ModernParameterSlider(label: "SPIN BALL", value: $spinTemp, range: -127...127, icon: "rotate.3d", displayValue: spinTemp > 0 ? "TOP" : (spinTemp < 0 ? "BACK" : "0"))
                    }
                    
                    HStack(spacing: 10) {
                        // Cambiado displayValue para mostrar 0-99 y ser consistente
                        ModernParameterSlider(label: "CADENCIA", value: $delayTemp, range: 0...255, icon: "speedometer", displayValue: "\(scaleTo99(delayTemp))")
                        ModernParameterSlider(label: "GIRO CT", value: $targetHTemp, range: 0...255, icon: "move.3d", displayValue: "\(scaleToCT(targetHTemp))")
                    }
                    
                    HStack(spacing: 10) {
                        ModernMiniSlider(label: "CARTRACK X", value: $targetFTemp, range: 0...255, displayValue: "\(scaleTo20(targetFTemp))")
                        ModernMiniSlider(label: "CARTRACK Y", value: $targetGTemp, range: 0...255, displayValue: "\(scaleTo20(targetGTemp))")
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Texto de depuración en tiempo real
                Text("PROTOTIPO: \(generateSHCommand())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.5))
                
                actionButtons
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseAnim = 1.3 }
        }
    }
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("DRAGONBOT OS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                Text("MIXER MANUAL").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "cpu").foregroundColor(.cyan)
        }.padding([.horizontal, .top])
    }

    private var courtVisualization: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.4))
            
            ZStack(alignment: .bottom) {
                TennisCourtShape()
                    .fill(LinearGradient(colors: [Color.cyan.opacity(0.2), Color.clear], startPoint: .bottom, endPoint: .top))
                    .overlay(TennisCourtLines().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .frame(width: 280, height: 160)
                    .rotation3DEffect(.degrees(-20), axis: (x: 1, y: 0, z: 0))

                VStack(spacing: 18) {
                    ForEach((0...2).reversed(), id: \.self) { row in
                        HStack(spacing: 28) {
                            ForEach(0..<cValues.count, id: \.self) { col in
                                let isSelected = selectedRow == row && selectedCol == col
                                
                                ZStack {
                                    if isSelected {
                                        Circle()
                                            .stroke(Color.cyan, lineWidth: 2)
                                            .frame(width: 38, height: 38)
                                            .scaleEffect(pulseAnim)
                                            .opacity(1.3 - pulseAnim)
                                    }
                                    
                                    // Esferas grandes
                                    Circle()
                                        .fill(isSelected ? Color(red: 0.82, green: 0.98, blue: 0.0) : Color.white.opacity(0.1))
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Image(systemName: "tennisball.fill")
                                                .resizable().padding(5)
                                                .foregroundColor(isSelected ? .black.opacity(0.6) : .clear)
                                        )
                                        .shadow(color: isSelected ? .cyan.opacity(0.4) : .clear, radius: 8)
                                }
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
                .rotation3DEffect(.degrees(-20), axis: (x: 1, y: 0, z: 0))
                .offset(y: -20)
            }
        }.padding(.horizontal)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Text("CANCELAR").font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Color.white.opacity(0.05)).foregroundColor(.white).cornerRadius(10)
            }
            Button(action: saveAndSend) {
                Text("GUARDAR Y ENVIAR").font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(isModified ? Color.cyan : Color.white.opacity(0.1))
                    .foregroundColor(isModified ? .black : .white.opacity(0.2)).cornerRadius(10)
            }.disabled(!isModified)
        }.padding(.horizontal).padding(.bottom, 15)
    }
}

// MARK: - Componentes de Sliders Modernos
struct ModernParameterSlider: View {
    let label: String; @Binding var value: Double; let range: ClosedRange<Double>; let icon: String; let displayValue: String
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).font(.system(size: 9)).foregroundColor(.cyan)
                Text(label).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.gray)
                Spacer()
                Text(displayValue).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white)
            }
            CustomModernBar(value: $value, range: range, isDragging: $isDragging)
                .frame(height: 20)
        }
        .padding(10).background(Color.white.opacity(0.03)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isDragging ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1))
    }
}



struct CustomModernBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Binding var isDragging: Bool

    var body: some View {
        GeometryReader { geo in
            // Definimos el radio de la bolita para los cálculos
            let thumbRadius: CGFloat = 8
            // Calculamos el ancho útil restando el espacio que ocupa la bolita en los extremos
            let usableWidth = geo.size.width - (thumbRadius * 2)
            
            // Calculamos el porcentaje actual (0.0 a 1.0)
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            
            ZStack(alignment: .leading) {
                // Fondo de la barra
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 4)
                
                // Progreso
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, percentage * usableWidth + thumbRadius), height: 4)
                
                // Bolita (Thumb)
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                    .shadow(color: .cyan.opacity(isDragging ? 0.8 : 0), radius: 6)
                    // El offset ahora se mueve solo dentro del usableWidth
                    .offset(x: percentage * usableWidth)
            }
            // Centramos el contenido verticalmente
            .frame(maxHeight: .infinity)
            // Añadimos un padding horizontal para que la bolita no toque el borde del contenedor
            .padding(.horizontal, 0)
            .contentShape(Rectangle()) // Hace que toda el área sea táctil
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        isDragging = true
                        // Ajustamos el cálculo del toque para que coincida con el área útil
                        let dragLocation = val.location.x - thumbRadius
                        let percent = Double(dragLocation / usableWidth)
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * percent
                        self.value = min(max(range.lowerBound, newValue), range.upperBound)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.2)) { isDragging = false }
                    }
            )
        }
    }
}

struct ModernMiniSlider: View {
    let label: String; @Binding var value: Double; let range: ClosedRange<Double>; let displayValue: String
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.gray)
            HStack(spacing: 8) {
                CustomModernBar(value: $value, range: range, isDragging: $isDragging)
                Text(displayValue).font(.system(size: 10, design: .monospaced)).foregroundColor(.cyan).frame(width: 28)
            }
        }
        .padding(10).background(Color.white.opacity(0.03)).cornerRadius(12)
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
