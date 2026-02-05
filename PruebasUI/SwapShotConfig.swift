import SwiftUI

// MARK: - Estructura de Configuración
struct SwapConfig {
    var x: Double = 127
    var y: Double = 127
    var speedA: Double = 127
    var speedB: Double = 127
    var feed: Double = 0
    var cx: Double = 127    // Escala 0-255 internamente, se muestra 0-20
    var cy: Double = 127    // Escala 0-255 internamente, se muestra 0-20
    var ct: Double = 127
    
    func scaleTo99(_ value: Double) -> Int { Int(((value * 99.0) / 255.0).rounded()) }
    func scaleTo20(_ value: Double) -> Int { Int(((value * 20.0) / 255.0).rounded()) }
    func scaleToCT(_ value: Double) -> Int { Int(((value * 6000.0 / 255.0) - 3000.0).rounded()) }

    func generateCommand() -> String {
        "[Y\(scaleTo99(x)),\(scaleTo99(y)),\(scaleTo99(speedA)),\(scaleTo99(speedB)),\(scaleTo99(feed)),\(scaleTo20(cx)),\(scaleTo20(cy)),\(scaleToCT(ct))]"
    }
    
    func getDisplayValue(for key: String, raw: Double) -> String {
        switch key {
        case "x", "y": return "\(scaleTo99(raw))"
        case "cx", "cy": return "\(scaleTo20(raw))"
        case "ct": return "\(scaleToCT(raw))"
        default: return "\(scaleTo99(raw))"
        }
    }
}

struct SwapConfigScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @State private var channel1 = SwapConfig()
    @State private var channel2 = SwapConfig()
    @State private var editingSwap: Int? = nil
    @State private var tempConfig = SwapConfig()
    @State private var showInstructions: Bool = false
    @State private var pulseAnim: CGFloat = 1.0
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                ScrollView {
                    VStack(spacing: 25) {
                        executionButtons
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("CANALES_CONFIGURADOS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.gray).padding(.horizontal)
                            SwapShotCard(id: 1, config: channel1, color: .orange, onEdit: { openEditor(id: 1) }, onSend: { transmit(id: 1) })
                            SwapShotCard(id: 2, config: channel2, color: .pink, onEdit: { openEditor(id: 2) }, onSend: { transmit(id: 2) })
                        }
                    }.padding(.vertical, 20)
                }
            }

            if let id = editingSwap {
                editorModal(id: id)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) { pulseAnim = 2.5 } }
    }

    // MARK: - Editor con Control Táctil y Trayectoria
    @ViewBuilder
    private func editorModal(id: Int) -> some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea().onTapGesture { editingSwap = nil }
            
            VStack(spacing: 0) {
                editorHeader(id: id)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        courtPreviewWithTrajectory
                        
                        parameterGroup(title: "MOTORES_LANZAMIENTO") {
                            parameterSlider(label: "RUEDA A (SUP)", value: $tempConfig.speedA, id: "vA", range: 0...255)
                            parameterSlider(label: "RUEDA B (INF)", value: $tempConfig.speedB, id: "vB", range: 0...255)
                        }

                        parameterGroup(title: "POSICIÓN_REJILLA (TÁCTIL)") {
                            parameterSlider(label: "EJE X (ANCHO)", value: $tempConfig.x, id: "x", range: 0...255)
                            parameterSlider(label: "EJE Y (PROFUNDIDAD)", value: $tempConfig.y, id: "y", range: 0...255)
                        }

                        parameterGroup(title: "OFFSET_CAR_MOTORS (0-20)") {
                            parameterSlider(label: "CAR X (OFFSET)", value: $tempConfig.cx, id: "cx", range: 0...255)
                            parameterSlider(label: "CAR Y (OFFSET)", value: $tempConfig.cy, id: "cy", range: 0...255)
                        }
                        
                        parameterGroup(title: "DINÁMICA_TIRO") {
                            parameterSlider(label: "CADENCIA", value: $tempConfig.feed, id: "f", range: 0...255)
                            parameterSlider(label: "GIRO CARTRACK", value: $tempConfig.ct, id: "ct", range: 0...255)
                        }
                    }.padding(20)
                }

                editorFooter(id: id)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09))
            .cornerRadius(24).padding(.horizontal, 15).padding(.vertical, 40)
        }
    }

    private var courtPreviewWithTrajectory: some View {
        ZStack(alignment: .bottom) {
            TennisCourtShape()
                .fill(Color.cyan.opacity(0.1))
                .overlay(TennisCourtLines().stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            GeometryReader { geo in
                let ballX = CGFloat(tempConfig.x / 255.0) * geo.size.width
                let ballY = (1.0 - CGFloat(tempConfig.y / 255.0)) * geo.size.height
                let originX = geo.size.width / 2
                let originY = geo.size.height
                
                // Estela de trayectoria punteada
                Path { path in
                    path.move(to: CGPoint(x: originX, y: originY))
                    path.addLine(to: CGPoint(x: ballX, y: ballY))
                }
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [.clear, .white.opacity(0.6)]), startPoint: .bottom, endPoint: .top),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 8])
                )

                // Pelota con Radar (Control Táctil)
                ZStack {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 1)
                        .frame(width: 25, height: 25)
                        .scaleEffect(pulseAnim * 0.5 + 0.5)
                        .opacity(2.5 - pulseAnim)
                    
                    Circle()
                        .fill(Color(red: 0.82, green: 0.98, blue: 0.0))
                        .frame(width: 20, height: 20) // Pelotita más grande como pediste
                        .shadow(color: .black, radius: 3)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                }
                .position(x: ballX, y: ballY)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clampedX = max(0, min(geo.size.width, value.location.x))
                            let clampedY = max(0, min(geo.size.height, value.location.y))
                            
                            // Mapeo de coordenadas a escala 0-255
                            tempConfig.x = Double((clampedX / geo.size.width) * 255.0)
                            tempConfig.y = Double((1.0 - (clampedY / geo.size.height)) * 255.0)
                        }
                )
            }
        }
        .frame(height: 180)
        .padding(10)
        .background(Color.black.opacity(0.4))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Subvistas Auxiliares
    private var executionButtons: some View {
        VStack(spacing: 12) {
            actionButton(title: "MODO SWAP", icon: "bolt.horizontal.fill", color: .blue) { communicator.sendCommand("[WA]") }
            actionButton(title: "EJECUTAR", icon: "play.circle.fill", color: .cyan) { communicator.sendCommand("[PL]") }
        }.padding(.horizontal)
    }

    private func editorHeader(id: Int) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("CALIBRACIÓN TÉCNICA").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.gray)
                Text("CANAL_0\(id)").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.cyan)
            }
            Spacer()
            Button(action: { editingSwap = nil }) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.white.opacity(0.3)) }
        }.padding().background(Color.white.opacity(0.05))
    }

    private func editorFooter(id: Int) -> some View {
        VStack(spacing: 12) {
            Text(tempConfig.generateCommand()).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(.cyan)
                .padding(10).frame(maxWidth: .infinity).background(Color.black.opacity(0.4)).cornerRadius(8)
            Button(action: { saveChanges(id: id) }) {
                Text("GUARDAR CONFIGURACIÓN").font(.system(size: 14, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.cyan).foregroundColor(.black).cornerRadius(10)
            }
        }.padding(20).background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }

    // MARK: - Lógica
    private func openEditor(id: Int) { tempConfig = (id == 1) ? channel1 : channel2; editingSwap = id }
    private func saveChanges(id: Int) { if id == 1 { channel1 = tempConfig } else { channel2 = tempConfig }; editingSwap = nil }
    private func transmit(id: Int) { let config = (id == 1) ? channel1 : channel2; communicator.sendCommand(config.generateCommand()) }
    
    private func parameterGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.cyan.opacity(0.7))
            content()
        }.padding(12).background(Color.white.opacity(0.03)).cornerRadius(10)
    }

    private func parameterSlider(label: String, value: Binding<Double>, id: String, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(tempConfig.getDisplayValue(for: id, raw: value.wrappedValue)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
            }
            Slider(value: value, in: range, step: 1).accentColor(.cyan)
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Image(systemName: icon); Text(title) }.font(.system(size: 12, weight: .black, design: .monospaced))
                .frame(maxWidth: .infinity).padding(.vertical, 14).background(color.opacity(0.15)).foregroundColor(color).cornerRadius(10)
        }
    }

    private var headerView: some View {
        HStack {
            Spacer()
            Circle().fill(communicator.isConnected ? Color.green : .red).frame(width: 8, height: 8)
        }.padding().background(Color.black)
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
