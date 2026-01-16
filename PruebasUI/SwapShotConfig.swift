import SwiftUI

// Estructura con lógica de escalado diferenciada por parámetro
struct SwapConfig {
    var x: Double = 127     // Target: 0-20
    var y: Double = 127     // Target: 0-20
    var power: Double = 127 // Target: 0-99
    var feed: Double = 0    // Target: 0-99
    var cx: Double = 127    // Target: 0-99
    var cy: Double = 127    // Target: 0-99
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

    func generateCommand() -> String {
        let ix = scaleTo99(x)
        let iy = scaleTo99(y)
        let ip = scaleTo99(power)
        let ifeed = scaleTo99(feed)
        let icx = scaleTo20(cx)
        let icy = scaleTo20(cy)
        let ict = scaleToCT(ct)
        
        let cmd = "[Y\(ix),\(iy),\(ip),\(ip),\(ifeed),\(icx),\(icy),\(ict)]"
        return cmd
    }
    
    func getDisplayValue(for key: String, raw: Double) -> String {
        switch key {
        case "x", "y": return "\(scaleTo20(raw))"
        case "ct": return "\(scaleToCT(raw))"
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
    
    // Estado para el popup de instrucciones
    @State private var showInstructions: Bool = false

    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 25) {
                        VStack(spacing: 12) {
                            actionButton(title: "MODO SWAP", icon: "bolt.horizontal.fill", color: .blue) {
                                communicator.sendCommand("[WA]")
                            }
                            actionButton(title: "EJECUTAR", icon: "play.circle.fill", color: .dragonBotPrimary) {
                                communicator.sendCommand("[PL]")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 15) {
                            Text("CANALES_CONFIGURADOS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.dragonBotSecondary)
                                .padding(.horizontal)

                            SwapShotCard(id: 1, config: channel1, color: .orange, onEdit: { openEditor(id: 1) }, onSend: { transmit(id: 1) })
                            SwapShotCard(id: 2, config: channel2, color: .pink, onEdit: { openEditor(id: 2) }, onSend: { transmit(id: 2) })
                        }
                    }
                    .padding(.bottom, 30)
                }
            }

            // Modal de edición
            if let id = editingSwap {
                editorModal(id: id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
            
            // Popup de Instrucciones
            if showInstructions {
                instructionsPopup
            }
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { onClose(); dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("VOLVER")
                }
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.dragonBotPrimary)
            
            Spacer()
            
            Text("CONTROL SWAP")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            // Botón de Ayuda
            Button(action: { withAnimation(.spring()) { showInstructions = true } }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.dragonBotPrimary)
            }
            .padding(.trailing, 8)

            Circle().fill(communicator.isConnected ? Color.dragonBotPrimary : .red).frame(width: 8, height: 8)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Popup de Instrucciones Swap
    private var instructionsPopup: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { withAnimation { showInstructions = false } }
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right.square.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.dragonBotPrimary)
                    Text("MODO SWAP (INTERCAMBIO)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 18) {
                    instructionItem(icon: "1.circle.fill", title: "CARGAR CANALES", desc: "Configura CH01 y CH02. Pulsa 'ENVIAR' en cada uno para que el robot guarde ambos objetivos.")
                    
                    instructionItem(icon: "bolt.fill", title: "ACTIVAR MODO [WA]", desc: "Antes de empezar, pulsa el botón azul para poner el robot en espera de intercambio.")
                    
                    instructionItem(icon: "play.fill", title: "EJECUTAR [PL]", desc: "Pulsa EJECUTAR para disparar. El robot alternará entre el Canal 1 y el Canal 2 automáticamente.")
                }
                .padding(.vertical, 10)
                
                Button(action: { withAnimation { showInstructions = false } }) {
                    Text("ENTENDIDO")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.dragonBotPrimary)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color.dragonBotBackground)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.dragonBotPrimary.opacity(0.3), lineWidth: 1))
            .frame(maxWidth: 340)
        }
    }

    private func instructionItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.dragonBotPrimary)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Text(desc).font(.system(size: 11)).foregroundColor(.white.opacity(0.6)).lineLimit(3)
            }
        }
    }

    @ViewBuilder
    private func editorModal(id: Int) -> some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture { editingSwap = nil }
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("CONFIGURACIÓN_AVANZADA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.dragonBotSecondary)
                        Text("CANAL_0\(id)")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.dragonBotPrimary)
                    }
                    Spacer()
                    Button(action: { editingSwap = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 24) {
                        parameterGroup(title: "POTENCIA_Y_POSICIÓN") {
                            parameterSlider(label: "VELOCIDAD DE LANZAMIENTO (0-99)", value: $tempConfig.power, id: "p")
                            parameterSlider(label: "ALTA (0-20)", value: $tempConfig.x, id: "x")
                            parameterSlider(label: "BAJA (0-20)", value: $tempConfig.y, id: "y")
                        }
                        
                        parameterGroup(title: "MOVIMIENTO_Y_CURVA") {
                            parameterSlider(label: "CADENCIA (0-99)", value: $tempConfig.feed, id: "f")
                            parameterSlider(label: "Cartrack-X (0-99)", value: $tempConfig.cx, id: "cx")
                            parameterSlider(label: "Cartrack-Y (0-99)", value: $tempConfig.cy, id: "cy")
                        }
                        
                        parameterGroup(title: "GIRO") {
                            parameterSlider(label: "Ángulo de giro de Cartrack (-3000 a 3000)", value: $tempConfig.ct, id: "ct")
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
                .frame(maxHeight: 450)

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VISTA_PREVIA_COMANDO")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.dragonBotSecondary)
                        Text(tempConfig.generateCommand())
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.dragonBotPrimary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                    }
                    
                    Button(action: { saveChanges(id: id) }) {
                        Text("GUARDAR CONFIGURACIÓN")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.dragonBotPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                }
                .padding(20)
                .background(Color.dragonBotBackground)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.1)), alignment: .top)
            }
            .background(Color.dragonBotBackground)
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
    }

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
        let command = config.generateCommand()
        communicator.sendCommand(command)
    }

    private func parameterGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.dragonBotSecondary)
            content()
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }

    private func parameterSlider(label: String, value: Binding<Double>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(tempConfig.getDisplayValue(for: id, raw: value.wrappedValue))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.dragonBotPrimary)
            }
            Slider(value: value, in: 0...255, step: 1).accentColor(.dragonBotPrimary)
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
}

struct SwapShotCard: View {
    let id: Int
    let config: SwapConfig
    let color: Color
    var onEdit: () -> Void
    var onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            VStack { Text("CH"); Text("0\(id)") }
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.black).frame(width: 40).frame(maxHeight: .infinity).background(color)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(config.generateCommand()).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill").font(.title3).foregroundColor(color)
                    }
                }
                Button(action: onSend) {
                    Text("ENVIAR").font(.system(size: 10, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity).padding(.vertical, 6).background(color.opacity(0.2)).foregroundColor(color).cornerRadius(4)
                }
            }.padding(10).background(Color.white.opacity(0.05))
        }.frame(height: 85).cornerRadius(10).padding(.horizontal)
    }
}
