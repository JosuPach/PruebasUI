import SwiftUI

// MARK: - Estructura de Configuración con Mixer de Motores
struct SwapConfig {
    var x: Double = 127     // Target: 0-99 (escalado)
    var y: Double = 127     // Target: 0-99 (escalado)
    var power: Double = 127 // Velocidad Base (A+B)
    var spin: Double = 0    // BALANCE DE SPIN (Offset local)
    var feed: Double = 0    // Target: 0-99
    var cx: Double = 127    // Target: 0-20
    var cy: Double = 127    // Target: 0-20
    var ct: Double = 127    // Target: -3000 a 3000
    
    private func scaleTo99(_ value: Double) -> Int {
        Int(((value * 99.0) / 255.0).rounded())
    }
    
    private func scaleTo20(_ value: Double) -> Int {
        Int(((value * 20.0) / 255.0).rounded())
    }
    
    private func scaleToCT(_ value: Double) -> Int {
        let scaled = (value * 6000.0 / 255.0) - 3000.0
        return Int(scaled.rounded())
    }

    // Lógica de Mixer: Calcula vA y vB aplicando el Spin a la potencia base
    func generateCommand() -> String {
        let ix = scaleTo99(x)
        let iy = scaleTo99(y)
        
        // --- CÁLCULO DEL MIXER ---
        let rawA = power + spin
        let rawB = power - spin
        let vA = scaleTo99(rawA)
        let vB = scaleTo99(rawB)
        // -------------------------
        
        let ifeed = scaleTo99(feed)
        let icx = scaleTo20(cx)
        let icy = scaleTo20(cy)
        let ict = scaleToCT(ct)
        
        // El comando usa vA y vB calculados independientemente
        return "[Y\(ix),\(iy),\(vA),\(vB),\(ifeed),\(icx),\(icy),\(ict)]"
    }
    
    func getDisplayValue(for key: String, raw: Double) -> String {
        switch key {
        case "x", "y": return "\(scaleTo99(raw))"
        case "cx", "cy": return "\(scaleTo20(raw))"
        case "ct": return "\(scaleToCT(raw))"
        case "spin": return raw > 0 ? "+\(Int(raw)) TOP" : (raw < 0 ? "\(Int(raw)) BACK" : "0")
        default: return "\(scaleTo99(raw))"
        }
    }
}

struct SwapConfigScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Environment(\.dismiss) var dismiss
    var onClose: () -> Void

    @State private var channel1 = SwapConfig()
    @State private var channel2 = SwapConfig()
    @State private var editingSwap: Int? = nil
    @State private var tempConfig = SwapConfig()
    @State private var showInstructions: Bool = false
    
    // Estados para la animación de la cancha
    @State private var pulseAnim: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 25) {
                        // Sección de botones de ejecución
                        VStack(spacing: 12) {
                            actionButton(title: "MODO SWAP", icon: "bolt.horizontal.fill", color: .blue) {
                                communicator.sendCommand("[WA]")
                            }
                            actionButton(title: "EJECUTAR", icon: "play.circle.fill", color: .cyan) {
                                communicator.sendCommand("[PL]")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 15) {
                            Text("CANALES_CONFIGURADOS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding(.horizontal)

                            SwapShotCard(id: 1, config: channel1, color: .orange, onEdit: { openEditor(id: 1) }, onSend: { transmit(id: 1) })
                            SwapShotCard(id: 2, config: channel2, color: .pink, onEdit: { openEditor(id: 2) }, onSend: { transmit(id: 2) })
                        }
                    }
                    .padding(.bottom, 30)
                }
            }

            // Editor Modal con Cancha
            if let id = editingSwap {
                editorModal(id: id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
            
            if showInstructions {
                instructionsPopup
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) { pulseAnim = 2.5 }
        }
    }

    // MARK: - Editor con Preview de Cancha
    @ViewBuilder
    private func editorModal(id: Int) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture { editingSwap = nil }
            
            VStack(spacing: 0) {
                // Header del Editor
                HStack {
                    VStack(alignment: .leading) {
                        Text("CONFIGURACIÓN_VISUAL").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.gray)
                        Text("CANAL_0\(id)").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.cyan)
                    }
                    Spacer()
                    Button(action: { editingSwap = nil }) {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding().background(Color.white.opacity(0.05))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // --- PREVIEW DE CANCHA ---
                        courtPreviewSection
                        
                        // Grupo de Potencia
                        parameterGroup(title: "SISTEMA_DE_LANZAMIENTO_MIXER") {
                            parameterSlider(label: "VELOCIDAD BASE", value: $tempConfig.power, id: "p", range: 0...255)
                            parameterSlider(label: "BALANCE DE SPIN", value: $tempConfig.spin, id: "spin", range: -127...127)
                        }

                        // Grupo de Posición (Los que mueven la pelota en la cancha)
                        parameterGroup(title: "POSICIÓN_REJILLA") {
                            parameterSlider(label: "EJE X (ANCHO)", value: $tempConfig.x, id: "x", range: 0...255)
                            parameterSlider(label: "EJE Y (PROFUNDIDAD)", value: $tempConfig.y, id: "y", range: 0...255)
                        }
                        
                        parameterGroup(title: "MOVIMIENTO_Y_GIRO") {
                            parameterSlider(label: "CADENCIA", value: $tempConfig.feed, id: "f", range: 0...255)
                            parameterSlider(label: "GIRO CARTRACK (H)", value: $tempConfig.ct, id: "ct", range: 0...255)
                        }
                    }
                    .padding(20)
                }

                // Footer con Comando y Botón Guardar
                VStack(spacing: 12) {
                    Text(tempConfig.generateCommand())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(10).frame(maxWidth: .infinity).background(Color.black.opacity(0.4)).cornerRadius(8)
                    
                    Button(action: { saveChanges(id: id) }) {
                        Text("ACTUALIZAR DISPARO").font(.system(size: 14, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.cyan).foregroundColor(.black).cornerRadius(10)
                    }
                }
                .padding(20).background(Color(red: 0.1, green: 0.1, blue: 0.12))
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09))
            .cornerRadius(24).padding(.horizontal, 15).padding(.vertical, 40)
        }
    }

    // MARK: - Componente de Cancha para Swap
    private var courtPreviewSection: some View {
        ZStack {
            // Dibujo de la cancha (Reutilizando tus formas)
            ZStack(alignment: .bottom) {
                TennisCourtShape()
                    .fill(Color.cyan.opacity(0.1))
                    .overlay(TennisCourtLines().stroke(Color.white.opacity(0.2), lineWidth: 1))
                
                // Representación de la Pelota
                // Mapeamos 0-255 a la posición relativa de la vista
                GeometryReader { geo in
                    let ballX = CGFloat(tempConfig.x / 255.0) * geo.size.width
                    let ballY = (1.0 - CGFloat(tempConfig.y / 255.0)) * geo.size.height
                    
                    ZStack {
                        Circle()
                            .stroke(Color.cyan, lineWidth: 1)
                            .frame(width: 15, height: 15)
                            .scaleEffect(pulseAnim)
                            .opacity(2.5 - pulseAnim)
                        
                        Circle()
                            .fill(Color(red: 0.82, green: 0.98, blue: 0.0))
                            .frame(width: 10, height: 10)
                            .shadow(color: .black, radius: 2)
                    }
                    .position(x: ballX, y: ballY)
                }
            }
            .frame(height: 160)
            .padding(10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            
            // Etiqueta de posición
            VStack {
                HStack {
                    Text("PREVIEW_IMPACTO").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                    Spacer()
                }
                Spacer()
            }.padding(8)
        }
    }

    // ... (Mantén tus funciones privadas como headerView, openEditor, saveChanges, etc. igual)
    private func openEditor(id: Int) {
        tempConfig = (id == 1) ? channel1 : channel2
        editingSwap = id
    }

    private func saveChanges(id: Int) {
        if id == 1 { channel1 = tempConfig }
        else { channel2 = tempConfig }
        editingSwap = nil
    }

    private func transmit(id: Int) {
        let config = (id == 1) ? channel1 : channel2
        communicator.sendCommand(config.generateCommand())
    }

    private func parameterGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.cyan.opacity(0.7))
            content()
        }
        .padding(12).background(Color.white.opacity(0.03)).cornerRadius(10)
    }

    private func parameterSlider(label: String, value: Binding<Double>, id: String, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(tempConfig.getDisplayValue(for: id, raw: value.wrappedValue))
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
            }
            Slider(value: value, in: range, step: 1).accentColor(.cyan)
        }
    }
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Image(systemName: icon); Text(title) }
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(color.opacity(0.15)).foregroundColor(color).cornerRadius(10)
        }
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            Text("CONTROL SWAP").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(.white)
            Spacer()
            
            Button(action: { withAnimation(.spring()) { showInstructions = true } }) {
                Image(systemName: "questionmark.circle").font(.system(size: 18)).foregroundColor(.cyan)
            }
            .padding(.trailing, 8)

            Circle().fill(communicator.isConnected ? Color.green : .red).frame(width: 8, height: 8)
        }
        .padding().background(Color.black.opacity(0.8))
    }
    
    private var instructionsPopup: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture { withAnimation { showInstructions = false } }
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right.square.fill").font(.system(size: 30)).foregroundColor(.cyan)
                    Text("INSTRUCCIONES SWAP").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 15) {
                    instructionItem(icon: "plus.circle.fill", title: "Cargar Canales", desc: "Configura CH01 y CH02. Pulsa 'ENVIAR' para que el robot guarde ambos.")
                    instructionItem(icon: "bolt.fill", title: "Modo [WA]", desc: "Activa la espera de intercambio con el botón azul.")
                    instructionItem(icon: "play.fill", title: "Ejecutar [PL]", desc: "Inicia la secuencia alterna entre canales.")
                }
                Button(action: { withAnimation { showInstructions = false } }) {
                    Text("ENTENDIDO").font(.system(size: 14, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding().background(Color.cyan).foregroundColor(.black).cornerRadius(10)
                }
            }
            .padding(30).background(Color(red: 0.1, green: 0.1, blue: 0.12)).cornerRadius(20).frame(maxWidth: 340)
        }
    }

    private func instructionItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(.cyan).font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Text(desc).font(.system(size: 10)).foregroundColor(.gray).lineLimit(2)
            }
        }
    }
}

struct SwapShotCard: View {
    let id: Int; let config: SwapConfig; let color: Color; var onEdit: () -> Void; var onSend: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            VStack { Text("CH"); Text("0\(id)") }.font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(.black).frame(width: 40).frame(maxHeight: .infinity).background(color)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(config.generateCommand()).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    Spacer()
                    Button(action: onEdit) { Image(systemName: "slider.horizontal.3").font(.title3).foregroundColor(color) }
                }
                Button(action: onSend) {
                    Text("ENVIAR A ROBOT").font(.system(size: 9, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 6).background(color.opacity(0.2)).foregroundColor(color).cornerRadius(4)
                }
            }.padding(10).background(Color.white.opacity(0.05))
        }.frame(height: 85).cornerRadius(10).padding(.horizontal)
    }
}
