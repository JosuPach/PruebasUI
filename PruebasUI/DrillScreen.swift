import SwiftUI

// MARK: - Mini Preview de la Cancha
struct MiniCourtPreview: View {
    let targetC: Int
    let targetD: Int
    let spin: Int
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.6))
                Group {
                    Rectangle().fill(Color.white.opacity(0.8)).frame(width: 1.5)
                    Rectangle().fill(Color.white.opacity(0.8)).frame(height: 1.5).offset(y: -geo.size.height * 0.2)
                    Rectangle().fill(Color.white.opacity(0.8)).frame(height: 1.5).offset(y: geo.size.height * 0.2)
                }
                let ballSize: CGFloat = 6
                let margin: CGFloat = ballSize / 2 + 2
                let posX = margin + (CGFloat(targetC) / 255.0 * (geo.size.width - margin * 2))
                let posY = margin + (CGFloat(targetD) / 255.0 * (geo.size.height - margin * 2))
                
                if spin != 0 {
                    Circle().stroke(spin > 0 ? Color.green.opacity(0.7) : Color.red.opacity(0.7), lineWidth: 2)
                        .frame(width: ballSize + 6, height: ballSize + 6).position(x: posX, y: posY)
                }
                Circle().fill(Color.yellow).frame(width: ballSize, height: ballSize)
                    .shadow(color: spin > 0 ? .green : (spin < 0 ? .red : .black.opacity(0.5)), radius: 3)
                    .position(x: posX, y: posY)
            }
        }.frame(width: 80, height: 50).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.3), lineWidth: 1)).clipped()
    }
}

// MARK: - LoopPath Animado
struct LoopPath: Shape {
    let count: Int
    let stepHeight: CGFloat = 144
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        let xPos: CGFloat = 41
        let firstY: CGFloat = 45
        let lastY: CGFloat = firstY + CGFloat(count - 1) * stepHeight
        path.move(to: CGPoint(x: xPos, y: firstY))
        path.addLine(to: CGPoint(x: xPos, y: lastY))
        if count > 1 {
            let loopWidth: CGFloat = 30
            let cornerRadius: CGFloat = 15
            path.addLine(to: CGPoint(x: xPos - loopWidth + cornerRadius, y: lastY))
            path.addArc(center: CGPoint(x: xPos - loopWidth + cornerRadius, y: lastY - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: xPos - loopWidth, y: firstY + cornerRadius))
            path.addArc(center: CGPoint(x: xPos - loopWidth + cornerRadius, y: firstY + cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: xPos - 8, y: firstY))
        }
        return path
    }
}

// MARK: - InstructionsView
struct InstructionsView: View {
    @Binding var isPresented: Bool
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture { isPresented = false }
            VStack(spacing: 20) {
                Text("AYUDA DE SECUENCIAS").font(.system(.headline, design: .monospaced)).foregroundColor(.dragonBotPrimary)
                VStack(alignment: .leading, spacing: 15) {
                    Label("Añade tiros para crear una rutina.", systemImage: "plus.circle")
                    Label("Configura bucles para repetir la lista.", systemImage: "arrow.3.trianglepath")
                    Label("Usa el Modo Drill para disparos aleatorios.", systemImage: "target")
                }.font(.footnote).foregroundColor(.white)
                Button("ENTENDIDO") { withAnimation { isPresented = false } }.padding().frame(maxWidth: .infinity).background(Color.dragonBotPrimary).foregroundColor(.black).cornerRadius(10)
            }.padding(30).background(Color(red: 0.1, green: 0.12, blue: 0.18)).cornerRadius(20).padding(40)
        }
    }
}

// MARK: - DrillShotCard
struct DrillShotCard: View {
    let cfg: ShotConfig
    var isCurrent: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(isCurrent ? Color.white : Color.dragonBotPrimary).frame(width: 34, height: 34)
                Text("\(cfg.shotNumber)").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.black)
            }.frame(width: 44)
            HStack(spacing: 15) {
                MiniCourtPreview(targetC: cfg.targetC, targetD: cfg.targetD, spin: Int(cfg.targetH))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("TIRO \(cfg.shotNumber)").font(.system(size: 10, weight: .black)).foregroundColor(isCurrent ? .white : .gray)
                        Spacer()
                        if !isCurrent { Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.red.opacity(0.7)) } }
                    }
                    Text("\(cfg.speedAB) km/h").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    HStack(spacing: 4) {
                        Text("\(Int(cfg.targetH)) RPM").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                        Text(cfg.targetH > 0 ? "TOP" : (cfg.targetH < 0 ? "BACK" : "FLAT")).font(.system(size: 7, weight: .black)).padding(.horizontal, 4).padding(.vertical, 1).background(cfg.targetH > 0 ? Color.green.opacity(0.3) : (cfg.targetH < 0 ? Color.red.opacity(0.3) : Color.gray.opacity(0.3))).cornerRadius(3).foregroundColor(.white)
                    }
                    HStack {
                        Text("DELAY: \(cfg.delayE)ms").font(.system(size: 9, weight: .bold)).foregroundColor(.dragonBotPrimary)
                        Spacer()
                        Button(action: onEdit) { Text("EDITAR").font(.system(size: 9, weight: .black)).padding(.horizontal, 10).padding(.vertical, 4).background(isCurrent ? Color.white.opacity(0.2) : Color.dragonBotPrimary).foregroundColor(isCurrent ? .white : .black).cornerRadius(4) }.disabled(isCurrent)
                    }
                }
            }.padding(12).background(isCurrent ? Color.dragonBotPrimary.opacity(0.2) : Color.white.opacity(0.08)).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(isCurrent ? Color.dragonBotPrimary : Color.white.opacity(0.1), lineWidth: 1))
        }.padding(.horizontal)
    }
}

// MARK: - DrillScreen
// MARK: - DrillScreen
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
    @State private var showInstructions: Bool = false
    @State private var dashPhase: CGFloat = 0

    // MARK: - Lógica de Formateo SH (Igual que en el Editor)
    private func getSHString(for cfg: ShotConfig) -> String {
        let speedBase = Double(cfg.speedAB)
        let spinBias = Double(cfg.spinBias)
        
        // Cálculo de motores con balance de spin
        let vA = mapValue(speedBase + spinBias, from: 0...255, to: 0...99)
        let vB = mapValue(speedBase - spinBias, from: 0...255, to: 0...99)
        
        // Mapeo de coordenadas y tiempos
        let xS = mapValue(Double(cfg.targetD), from: 0...255, to: 0...99)
        let yS = mapValue(Double(cfg.targetC), from: 0...255, to: 0...99)
        let fS = mapValue(Double(cfg.delayE), from: 200...2000, to: 0...99)
        let cxS = mapValue(cfg.targetF, from: 0...255, to: 0...20)
        let cyS = mapValue(cfg.targetG, from: 0...255, to: 0...20)
        let ctS = mapValue(cfg.targetH, from: 0...255, to: -3000...3000)
        
        return "[SH\(xS),\(yS),\(vA),\(vB),\(fS),\(cxS),\(cyS),\(ctS)]"
    }

    private func mapValue(_ value: Double, from: ClosedRange<Double>, to: ClosedRange<Double>) -> Int {
        let clampedValue = max(from.lowerBound, min(from.upperBound, value))
        let result = to.lowerBound + (to.upperBound - to.lowerBound) * (clampedValue - from.lowerBound) / (from.upperBound - from.lowerBound)
        return Int(result.rounded())
    }

    var body: some View {
        let sortedShotList = shots.values.sorted { $0.shotNumber < $1.shotNumber }

        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // ... Header existente ...
                HStack(spacing: 15) {
                    Button(action: onBackClick) { Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundColor(.white) }
                    Text("RED DE ENTRENAMIENTO").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
                    Spacer()
                    Button(action: { withAnimation { showInstructions = true } }) { Image(systemName: "questionmark.circle").foregroundColor(.dragonBotPrimary) }
                }.padding().background(Color.black.opacity(0.5))

                VStack(spacing: 20) {
                    // ... Controles de Bucle y Modo Drill existentes ...
                    HStack(spacing: 12) {
                        Button(action: {
                            print("DEBUG: Enviando Modo Drill [MD]")
                            communicator.sendCommand("[MD]")
                        }) {
                            VStack(spacing: 4) { Image(systemName: "target"); Text("MODO DRILL").font(.system(size: 8, weight: .bold)) }
                            .frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.dragonBotSecondary.opacity(0.2)).foregroundColor(.dragonBotSecondary).cornerRadius(12)
                        }
                        
                        VStack(spacing: 4) {
                            Text("BUCLES").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                            HStack(spacing: 10) {
                                Button(action: { if loopCount > 1 { loopCount -= 1; communicator.sendCommand("[N\(loopCount)]") } }) { Image(systemName: "minus.square.fill") }
                                Text("\(loopCount)").font(.system(size: 18, weight: .black)).frame(width: 30)
                                Button(action: { if loopCount < 99 { loopCount += 1; communicator.sendCommand("[N\(loopCount)]") } }) { Image(systemName: "plus.square.fill") }
                            }.foregroundColor(.dragonBotPrimary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.white.opacity(0.05)).cornerRadius(12)

                        Button(action: {
                            isInfinite.toggle()
                            communicator.sendCommand(isInfinite ? "[I]" : "[N\(loopCount)]")
                        }) {
                            VStack(spacing: 4) { Image(systemName: "infinity").font(.system(size: 18, weight: .bold)).foregroundColor(isInfinite ? .dragonBotPrimary : .gray); Text("INFINITO").font(.system(size: 8, weight: .bold)) }.frame(maxWidth: .infinity).padding(.vertical, 8).background(isInfinite ? Color.dragonBotPrimary.opacity(0.15) : Color.white.opacity(0.05)).cornerRadius(12)
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: { print("DEBUG: Reset [Z]"); communicator.sendCommand("[Z]") }) { Image(systemName: "arrow.counterclockwise").frame(width: 50, height: 50).background(Color.white.opacity(0.1)).cornerRadius(12) }
                        
                        // --- BOTÓN DE INICIO ACTUALIZADO ---
                        Button(action: {
                            if !isRunning {
                                print("🚀 --- INICIANDO TRANSMISIÓN DE SECUENCIA ---")
                                for shot in sortedShotList {
                                    let cmd = getSHString(for: shot)
                                    print("📡 ENVIANDO TIRO \(shot.shotNumber): \(cmd)")
                                    communicator.sendCommand(cmd)
                                }
                                print("✅ ENVIANDO COMANDO DE DISPARO [S]")
                                communicator.sendCommand("[S]")
                            } else {
                                print("🛑 PARADA DE EMERGENCIA [P]")
                                communicator.sendCommand("[P]")
                            }
                            isRunning.toggle()
                        }) {
                            HStack {
                                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                Text(isRunning ? "DETENER" : "INICIAR SECUENCIA").font(.system(size: 14, weight: .black, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(isRunning ? Color.red : Color.dragonBotPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                    }
                }.padding()

                // ... Resto del ScrollView con la lista de tiros ...
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        if sortedShotList.count > 1 {
                            LoopPath(count: sortedShotList.count).stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: isRunning ? [10, 6] : [], dashPhase: dashPhase)).foregroundColor(isRunning ? .dragonBotPrimary : .white.opacity(0.2)).frame(width: 60).onAppear { withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { dashPhase -= 16 } }
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(sortedShotList.enumerated()), id: \.element.shotNumber) { index, cfg in
                                DrillShotCard(cfg: cfg, isCurrent: isRunning && index == 0, onEdit: { onConfigShot(cfg.shotNumber) }, onDelete: { onDeleteShot(cfg.shotNumber) })
                                if index < sortedShotList.count - 1 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.2.circlepath").rotationEffect(.degrees(isRunning ? 360 : 0))
                                        Text("ESPERA: \(String(format: "%.1f", Double(cfg.delayE) / 1000.0))s").font(.system(size: 10, weight: .bold, design: .monospaced))
                                    }.foregroundColor(isRunning ? .dragonBotPrimary : .white.opacity(0.4)).padding(.leading, 70).frame(height: 30)
                                } else { Spacer().frame(height: 30) }
                            }
                            Button(action: onAddShot) { Label("AÑADIR NUEVO TIRO", systemImage: "plus.circle.fill").font(.system(size: 14, weight: .bold, design: .monospaced)).padding().frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 15).stroke(Color.dragonBotPrimary, lineWidth: 1)) }.foregroundColor(.dragonBotPrimary).padding(.horizontal).padding(.bottom, 100)
                        }
                    }.padding(.vertical)
                }
            }
            if showInstructions { InstructionsView(isPresented: $showInstructions) }
        }
    }
}
