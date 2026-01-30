import SwiftUI

// MARK: - Forma para el Camino del Bucle
struct LoopPath: Shape {
    let count: Int
    let stepHeight: CGFloat = 114 // Altura de tarjeta (aprox 84) + spacing (30)
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        
        let xPos: CGFloat = 41 // Alineado con el centro del círculo del número
        let firstCircleY: CGFloat = 45
        let lastCircleY: CGFloat = firstCircleY + CGFloat(count - 1) * stepHeight
        
        // 1. Línea vertical que conecta los tiros
        path.move(to: CGPoint(x: xPos, y: firstCircleY))
        path.addLine(to: CGPoint(x: xPos, y: lastCircleY))
        
        // 2. Dibujar flechas pequeñas entre cada tiro
        if count > 1 {
            for i in 0..<count-1 {
                let midY = firstCircleY + CGFloat(i) * stepHeight + (stepHeight / 2)
                drawArrowHead(at: CGPoint(x: xPos, y: midY), in: &path)
            }
        }
        
        // 3. El camino de retorno (Efecto Loop)
        if count > 1 {
            let loopWidth: CGFloat = 30
            let cornerRadius: CGFloat = 15
            
            // Salida desde el último tiro hacia la izquierda
            path.move(to: CGPoint(x: xPos, y: lastCircleY))
            path.addLine(to: CGPoint(x: xPos - loopWidth + cornerRadius, y: lastCircleY))
            
            // Curva inferior izquierda
            path.addArc(center: CGPoint(x: xPos - loopWidth + cornerRadius, y: lastCircleY - cornerRadius),
                        radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            
            // Línea vertical de subida
            path.addLine(to: CGPoint(x: xPos - loopWidth, y: firstCircleY + cornerRadius))
            
            // Curva superior izquierda
            path.addArc(center: CGPoint(x: xPos - loopWidth + cornerRadius, y: firstCircleY + cornerRadius),
                        radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            
            // Línea final hacia el primer tiro
            path.addLine(to: CGPoint(x: xPos - 8, y: firstCircleY))
            
            // Punta de flecha de llegada al primer tiro
            drawArrowHead(at: CGPoint(x: xPos - 8, y: firstCircleY), in: &path, horizontal: true)
        }
        
        return path
    }
    
    private func drawArrowHead(at point: CGPoint, in path: inout Path, horizontal: Bool = false) {
        if horizontal {
            path.move(to: CGPoint(x: point.x - 5, y: point.y - 4))
            path.addLine(to: CGPoint(x: point.x, y: point.y))
            path.addLine(to: CGPoint(x: point.x - 5, y: point.y + 4))
        } else {
            path.move(to: CGPoint(x: point.x - 4, y: point.y - 5))
            path.addLine(to: CGPoint(x: point.x, y: point.y))
            path.addLine(to: CGPoint(x: point.x + 4, y: point.y - 5))
        }
    }
}

struct DrillScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Binding var shots: [Int : ShotConfig]
    
    var onBackClick: () -> Void
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void

    @State private var loopCount: Int = 1
    @State private var isInfinite: Bool = false
    @State private var isRunning: Bool = false
    @State private var flowPhase: CGFloat = 0
    
    @State private var currentShotIndex: Int = 0
    @State private var showInstructions: Bool = false

    private func generateCommand(for cfg: ShotConfig) -> String {
        let xScaled = Int((Double(cfg.targetC) / 255.0) * 99)
        let yScaled = Int((Double(cfg.targetD) / 255.0) * 99)
        let v1Scaled = Int((Double(cfg.speedAB) / 255.0) * 99)
        let feedScaled = Int((Double(cfg.delayE) / 2000.0) * 99)
        let cx = Int((Double(cfg.targetF) / 255.0) * 20)
        let cy = Int((Double(cfg.targetG) / 255.0) * 20)
        let ct = Int((Double(cfg.targetH) / 255.0) * 6000) - 3000
        
        return "[SH\(xScaled),\(yScaled),\(v1Scaled),\(v1Scaled),\(feedScaled),\(cx),\(cy),\(ct)]"
    }

    private func startDrill() {
        guard communicator.isConnected && !shots.isEmpty else { return }
        if isInfinite { communicator.sendCommand("[I]") }
        else { communicator.sendCommand(String(format: "[N%02d]", loopCount)) }
        
        let sortedShots = shots.values.sorted { $0.shotNumber < $1.shotNumber }
        for config in sortedShots {
            communicator.sendCommand(generateCommand(for: config))
        }
        communicator.sendCommand("[GO]")
        withAnimation { isRunning = true }
    }

    private func stopDrill() {
        communicator.sendCommand("[STOP]")
        withAnimation {
            isRunning = false
            currentShotIndex = 0
        }
    }

    var body: some View {
        let sortedShotList = shots.values.sorted { $0.shotNumber < $1.shotNumber }

        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack(spacing: 15) {
                    Button(action: onBackClick) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("RED DE ENTRENAMIENTO")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { withAnimation(.spring()) { showInstructions = true } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                            Text("AYUDA").font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.dragonBotPrimary.opacity(0.1))
                        .foregroundColor(.dragonBotPrimary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.dragonBotPrimary.opacity(0.4), lineWidth: 1))
                    }
                    
                    Circle()
                        .fill(communicator.isConnected ? Color.dragonBotPrimary : .red)
                        .frame(width: 8, height: 8)
                        .shadow(color: communicator.isConnected ? Color.dragonBotPrimary : .red, radius: 4)
                }
                .padding()
                .background(Color.black.opacity(0.5))

                // MARK: - Panel de Control
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Button(action: { communicator.sendCommand("[MD]") }) {
                            VStack(spacing: 4) {
                                Image(systemName: "target")
                                Text("MODO DRILL").font(.system(size: 8, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Color.dragonBotSecondary.opacity(0.2)).foregroundColor(.dragonBotSecondary)
                            .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dragonBotSecondary, lineWidth: 1))
                        }.disabled(isRunning)

                        VStack(spacing: 4) {
                            Text("BUCLES").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                            HStack(spacing: 10) {
                                Button(action: { if loopCount > 1 { loopCount -= 1 } }) { Image(systemName: "minus.square.fill") }
                                Text("\(loopCount)").font(.system(size: 18, weight: .black)).frame(width: 30)
                                Button(action: { if loopCount < 99 { loopCount += 1 } }) { Image(systemName: "plus.square.fill") }
                            }.foregroundColor(.dragonBotPrimary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.white.opacity(0.05))
                        .cornerRadius(12).opacity(isInfinite ? 0.3 : 1.0).disabled(isInfinite || isRunning)

                        Button(action: { isInfinite.toggle() }) {
                            VStack(spacing: 4) {
                                Image(systemName: "infinity").font(.system(size: 18, weight: .bold))
                                    .foregroundColor(isInfinite ? .dragonBotPrimary : .gray)
                                Text("INFINITO").font(.system(size: 8, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(isInfinite ? Color.dragonBotPrimary.opacity(0.15) : Color.white.opacity(0.05))
                            .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isInfinite ? Color.dragonBotPrimary : Color.clear, lineWidth: 1))
                        }.disabled(isRunning)
                    }

                    HStack(spacing: 12) {
                        Button(action: { communicator.sendCommand("[Z]") }) {
                            VStack { Image(systemName: "arrow.counterclockwise"); Text("Z").font(.caption2).bold() }
                            .frame(width: 50, height: 50).background(Color.white.opacity(0.1)).cornerRadius(12)
                        }.disabled(isRunning)

                        Button(action: isRunning ? stopDrill : startDrill) {
                            HStack {
                                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                Text(isRunning ? "DETENER" : "INICIAR SECUENCIA")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(isRunning ? Color.red : Color.dragonBotPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .shadow(color: isRunning ? .red.opacity(0.3) : .dragonBotPrimary.opacity(0.3), radius: 10)
                        }
                    }
                }
                .padding()

                // MARK: - Lista de Tiros con Bucle Visual
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Capa del Bucle (Path)
                        if sortedShotList.count > 1 {
                            LoopPath(count: sortedShotList.count)
                                .stroke(isRunning ? Color.dragonBotPrimary : Color.white.opacity(0.2),
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .frame(width: 60)
                                .offset(y: 0)
                        }
                        
                        VStack(spacing: 30) { // Spacing fijo para que el Path coincida
                            ForEach(sortedShotList, id: \.shotNumber) { cfg in
                                DrillShotCard(cfg: cfg, isCurrent: isRunning && cfg.shotNumber == 1, onEdit: {
                                    onConfigShot(cfg.shotNumber)
                                }, onDelete: {
                                    communicator.sendCommand("[X]")
                                    onDeleteShot(cfg.shotNumber)
                                })
                            }

                            Button(action: onAddShot) {
                                Label("AÑADIR NUEVO TIRO", systemImage: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .padding().frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 15).stroke(Color.dragonBotPrimary, lineWidth: 1))
                            }
                            .foregroundColor(.dragonBotPrimary).padding(.horizontal).padding(.bottom, 100).disabled(isRunning)
                        }
                    }
                    .padding(.vertical)
                }
            }
            
            if showInstructions {
                instructionsPopup
            }
        }
        .onAppear { withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { flowPhase = 1.0 } }
        .navigationBarHidden(true)
    }
    
    // MARK: - Popup de Instrucciones
    private var instructionsPopup: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { withAnimation { showInstructions = false } }
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.dragonBotPrimary)
                    Text("GESTIÓN DE SECUENCIAS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 18) {
                    instructionItem(icon: "plus.square.dashed", title: "CREAR SECUENCIA", desc: "Añade múltiples tiros con dirección y velocidad personalizada.")
                    instructionItem(icon: "arrow.3.trianglepath", title: "REPETICIÓN", desc: "Define cuántas veces quieres que se repita la lista o activa el modo infinito.")
                    instructionItem(icon: "play.fill", title: "INICIAR", desc: "Al iniciar, se enviarán todos los datos de los tiros configurados automáticamente.")
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
}

// MARK: - Componentes Visuales

struct DrillShotCard: View {
    let cfg: ShotConfig
    var isCurrent: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                // El círculo ahora queda por encima del Path gracias al ZStack de la lista
                Circle().fill(isCurrent ? Color.white : Color.dragonBotPrimary).frame(width: 34, height: 34)
                Text("\(cfg.shotNumber)").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.black)
            }.frame(width: 44)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("CONFIGURACIÓN TIRO \(cfg.shotNumber)").font(.system(size: 10, weight: .bold)).foregroundColor(isCurrent ? .white : .gray)
                    Spacer()
                    if !isCurrent {
                        Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) }
                    }
                }
                HStack {
                    VStack(alignment: .leading) { Text("VEL.").font(.system(size: 8)); Text("\(cfg.speedAB)").bold() }
                    Spacer()
                    VStack(alignment: .leading) { Text("RETARDO").font(.system(size: 8)); Text("\(cfg.delayE)ms").bold() }
                    Spacer()
                    Button(action: onEdit) {
                        Text("EDITAR").font(.system(size: 10, weight: .black)).padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isCurrent ? Color.white.opacity(0.2) : Color.dragonBotPrimary)
                            .foregroundColor(isCurrent ? .white : .black).cornerRadius(6)
                    }.disabled(isCurrent)
                }
            }
            .padding().background(isCurrent ? Color.dragonBotPrimary.opacity(0.2) : Color.white.opacity(0.08))
            .cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(isCurrent ? Color.dragonBotPrimary : Color.white.opacity(0.1), lineWidth: 1))
        }.padding(.horizontal)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
