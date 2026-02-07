import SwiftUI

// MARK: - Estructura de Configuración
struct SwapConfig {
    var x: Double = 127
    var y: Double = 127
    var speedA: Double = 127
    var speedB: Double = 127
    var feed: Double = 0
    var cx: Double = 127
    var cy: Double = 127
    var ct: Double = 127
    
    func scaleTo99(_ value: Double) -> Int { Int(((value * 99.0) / 255.0).rounded()) }
    func scaleTo20(_ value: Double) -> Int { Int(((value * 20.0) / 255.0).rounded()) }
    func scaleToCT(_ value: Double) -> Int { Int(((value * 6000.0 / 255.0) - 3000.0).rounded()) }
    
    func generateCommand(index: Int) -> String {
        let prefix = "Y\(index)"
        return "[\(prefix),\(scaleTo99(x)),\(scaleTo99(y)),\(scaleTo99(speedA)),\(scaleTo99(speedB)),\(scaleTo99(feed)),\(scaleTo20(cx)),\(scaleTo20(cy)),\(scaleToCT(ct))]"
    }
    
    func getDisplayValue(for key: String, raw: Double) -> String {
        switch key {
        case "x", "y", "feed": return "\(scaleTo99(raw))"
        case "cx", "cy": return "\(scaleTo20(raw))"
        case "ct": return "\(scaleToCT(raw))"
        default: return "\(Int(raw.rounded()))"
        }
    }
}

// MARK: - Pantalla Principal Swap
struct SwapConfigScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Environment(\.dismiss) var dismiss // Permite cerrar la vista actual
    
    @State private var channel1 = SwapConfig()
    @State private var channel2 = SwapConfig()
    @State private var editingSwap: Int? = nil
    @State private var tempConfig = SwapConfig()
    @State private var isDraggingSlider = false
    @State private var isInfiniteActive: Bool = false
    
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Cabezal de Conexión y Navegación
                mainHeader
                
                connectionStatusHeader
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        executionButtons
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("CANALES CONFIGURADOS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            SwapShotCard(id: 1, config: channel1, index: 0, color: .orange, onEdit: { openEditor(id: 1) }, onSend: { transmit(id: 1) })
                            SwapShotCard(id: 2, config: channel2, index: 1, color: .pink, onEdit: { openEditor(id: 2) }, onSend: { transmit(id: 2) })
                        }
                    }.padding(.vertical, 20)
                }
            }
            
            // Modal de Edición
            if let id = editingSwap {
                editorModal(id: id)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Componente: Cabezal de Navegación (NUEVO)
    private var mainHeader: some View {
        HStack {
            Button(action: {
                // Al volver, podrías enviar un comando de stop para seguridad
                communicator.sendCommand("[Z]")
                onClose() // Llama al callback original
                dismiss() // Cierra la pantalla de Swap
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("VOLVER")
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("SWAP ENGINE").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text("v2.4.0").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Lógica de Comunicación
    private func openEditor(id: Int) {
        tempConfig = (id == 1) ? channel1 : channel2
        withAnimation(.spring()) { editingSwap = id }
    }
    
    private func saveChanges(id: Int) {
        communicator.sendCommand("[WA]") // Regresar a modo Swap
        if id == 1 { channel1 = tempConfig } else { channel2 = tempConfig }
        withAnimation { editingSwap = nil }
    }
    
    private func transmit(id: Int) {
        let config = (id == 1) ? channel1 : channel2
        communicator.sendCommand(config.generateCommand(index: id - 1))
    }

    private func runCadenceTest() {
        communicator.sendCommand("[R000]")
        communicator.sendCommand("[Z]")
        let cadenceValue = Int(tempConfig.feed.rounded())
        let cmdE = "[E\(String(format: "%03d", cadenceValue))]"
        communicator.sendCommand(cmdE)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Editor Modal y Header de Modal
    @ViewBuilder
    private func editorModal(id: Int) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture {
                communicator.sendCommand("[WA]")
                withAnimation { editingSwap = nil }
            }
            
            VStack(spacing: 0) {
                editorHeader(id: id)
                ScrollView {
                    VStack(spacing: 25) {
                        ZStack(alignment: .bottom) {
                            TennisCourtShape().fill(LinearGradient(colors: [Color.cyan.opacity(0.15), Color.cyan.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            TennisCourtLines().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            courtArcLayer
                            TennisNetView().offset(y: 10)
                            courtBallInteraction
                        }
                        .frame(height: 200).padding(.top, 10)
                        
                        parameterGroup(title: "POTENCIA Y CADENCIA") {
                            parameterSlider(label: "RUEDA A", value: $tempConfig.speedA, id: "speedA", range: 0...255)
                            parameterSlider(label: "RUEDA B", value: $tempConfig.speedB, id: "speedB", range: 0...255)
                            parameterSlider(label: "CADENCIA (FEED)", value: $tempConfig.feed, id: "feed", range: 0...255)
                        }
                        
                        parameterGroup(title: "AJUSTES DE GIRO") {
                            parameterSlider(label: "GIRO TOTAL (CT)", value: $tempConfig.ct, id: "ct", range: 0...255)
                        }
                        
                        parameterGroup(title: "COORDENADAS TÁCTILES") {
                            parameterSlider(label: "EJE X (ANCHO)", value: $tempConfig.x, id: "x", range: 0...255)
                            parameterSlider(label: "EJE Y (LARGO)", value: $tempConfig.y, id: "y", range: 0...255)
                        }
                    }.padding(20)
                }
                editorFooter(id: id)
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.07)).cornerRadius(28).padding(15)
        }
    }

    private func editorHeader(id: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CONFIGURACIÓN CANAL 0\(id)").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.cyan)
                Text("MODO SWAP").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer()
            Button(action: runCadenceTest) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text("TEST").font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.orange.opacity(0.2)).foregroundColor(.orange).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }
            .padding(.trailing, 10)
            Button(action: {
                communicator.sendCommand("[WA]")
                withAnimation { editingSwap = nil }
            }) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.white.opacity(0.2)) }
        }.padding()
    }

    // --- Otros subcomponentes estéticos ---
    private var courtArcLayer: some View {
        GeometryReader { geo in
            let ballX = (tempConfig.x / 255.0) * geo.size.width
            let ballY = (1.0 - (tempConfig.y / 255.0)) * geo.size.height
            let startPoint = CGPoint(x: geo.size.width / 2, y: geo.size.height)
            Path { path in
                path.move(to: startPoint)
                let controlY = ballY - (geo.size.height - ballY) * 0.5
                path.addQuadCurve(to: CGPoint(x: ballX, y: ballY), control: CGPoint(x: (ballX + startPoint.x) / 2, y: controlY))
            }
            .stroke(LinearGradient(colors: [.white.opacity(0.5), .yellow.opacity(0.8)], startPoint: .bottom, endPoint: .top), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
        }
    }

    private var courtBallInteraction: some View {
        GeometryReader { geo in
            let ballX = (tempConfig.x / 255.0) * geo.size.width
            let ballY = (1.0 - (tempConfig.y / 255.0)) * geo.size.height
            Circle().fill(Color.yellow).frame(width: 22, height: 22).shadow(color: .yellow.opacity(0.6), radius: 8)
                .position(x: ballX, y: ballY)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    tempConfig.x = min(max(0, (value.location.x / geo.size.width) * 255.0), 255)
                    tempConfig.y = min(max(0, (1.0 - (value.location.y / geo.size.height)) * 255.0), 255)
                })
        }
    }

    private var connectionStatusHeader: some View {
        HStack {
            Circle().fill(communicator.isConnected ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(communicator.isConnected ? "DRAGONBOT CONECTADA" : "DESCONECTADO").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(communicator.isConnected ? .green : .red)
            Spacer()
        }.padding(.horizontal).padding(.vertical, 10).background(Color.black.opacity(0.4))
    }

    private var executionButtons: some View {
        VStack(spacing: 12) {
            actionButton(title: "ACTIVAR MODO SWAP", icon: "bolt.horizontal.fill", color: .blue) { communicator.sendCommand("[WA]") }
            HStack(spacing: 12) {
                actionButton(title: "EJECUTAR", icon: "play.circle.fill", color: .cyan) { communicator.sendCommand("[PL]") }
                Button(action: { isInfiniteActive.toggle(); communicator.sendCommand("[U]") }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(isInfiniteActive ? Color.purple : Color.purple.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple, lineWidth: 1.5))
                        VStack(spacing: 2) {
                            Image(systemName: "infinity").font(.system(size: 18, weight: .bold))
                            Text(isInfiniteActive ? "ON" : "SIN FIN").font(.system(size: 8, weight: .black, design: .monospaced))
                        }.foregroundColor(isInfiniteActive ? .white : .purple)
                    }.frame(width: 80, height: 48)
                }
            }
        }.padding(.horizontal)
    }

    private func editorFooter(id: Int) -> some View {
        VStack(spacing: 12) {
            Text(tempConfig.generateCommand(index: id - 1)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.cyan).padding(12).frame(maxWidth: .infinity).background(Color.black.opacity(0.4)).cornerRadius(10)
            Button(action: { saveChanges(id: id) }) {
                Text("GUARDAR CAMBIOS").font(.system(size: 14, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.cyan).foregroundColor(.black).cornerRadius(12)
            }
        }.padding(20).background(Color.white.opacity(0.03))
    }

    private func parameterGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.cyan.opacity(0.8))
            content()
        }.padding(15).background(Color.white.opacity(0.03)).cornerRadius(16)
    }

    private func parameterSlider(label: String, value: Binding<Double>, id: String, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                Spacer()
                Text(tempConfig.getDisplayValue(for: id, raw: value.wrappedValue)).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.cyan)
            }
            CustomModernBar(value: value, range: range, isDragging: $isDraggingSlider, mainColor: .cyan).frame(height: 12)
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Image(systemName: icon); Text(title) }.font(.system(size: 12, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 14).background(color.opacity(0.15)).foregroundColor(color).cornerRadius(10)
        }
    }
}

// MARK: - Card Component
struct SwapShotCard: View {
    let id: Int; let config: SwapConfig; let index: Int; let color: Color
    var onEdit: () -> Void; var onSend: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            VStack { Text("CH"); Text("0\(id)") }.font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(.black).frame(width: 45).frame(maxHeight: .infinity).background(color)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(config.generateCommand(index: index)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    Spacer()
                    Button(action: onEdit) { Image(systemName: "slider.horizontal.3").font(.title3).foregroundColor(color) }
                }
                Button(action: onSend) {
                    Text("ENVIAR A ROBOT").font(.system(size: 9, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 8).background(color.opacity(0.15)).foregroundColor(color).cornerRadius(6)
                }
            }.padding(12).background(Color.white.opacity(0.05))
        }.frame(height: 90).cornerRadius(12).padding(.horizontal)
    }
}
