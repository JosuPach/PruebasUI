import SwiftUI

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

    // MARK: - Lógica de Control y Comandos
    
    private func handleAddShot() {
        onAddShot()
    }

    private func handleDeleteShot(at index: Int) {
        onDeleteShot(index)
        // La re-indexación ocurre en el componente padre, pero aquí nos aseguramos
        // de que la UI se refresque correctamente.
    }

    private func sendLoopCommand(_ count: Int) {
        let formatted = String(format: "%02d", min(max(count, 0), 99))
        communicator.sendCommand("[N\(formatted)]")
    }

    private func startDrill() {
        guard communicator.isConnected else { return }
        let loopValue = isInfinite ? 255 : min(max(loopCount, 1), 255)
        let loopP = String(format: "%03d", loopValue)
        
        // Ordenar tiros por número para asegurar secuencia lógica
        let sortedShots = shots.values.sorted { $0.shotNumber < $1.shotNumber }
        let shotsCmd = sortedShots.map { cfg in
            String(format: "A%03d:B%03d:C%03d:D%03d:E%03d", cfg.speedAB, cfg.speedAB, cfg.targetC, cfg.targetD, cfg.delayE)
        }.joined(separator: ":")
        
        communicator.sendCommand("[MD]P\(loopP):\(shotsCmd)[GO]")
        withAnimation { isRunning = true }
    }

    private func stopDrill() {
        communicator.sendCommand("[STOP]")
        withAnimation { isRunning = false }
    }

    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Superior
                HStack {
                    Button(action: onBackClick) {
                        Label("VOLVER", systemImage: "chevron.left")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.dragonBotPrimary)
                    }
                    Spacer()
                    Text("RED DE ENTRENAMIENTO")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Spacer()
                    Circle().fill(communicator.isConnected ? Color.dragonBotPrimary : .red).frame(width: 8, height: 8)
                }
                .padding()
                .background(Color.black.opacity(0.5))

                // Panel de Control Fijo (Loops y Botones Maestros)
                VStack(spacing: 15) {
                    HStack(spacing: 12) {
                        Button(action: { communicator.sendCommand("[Z]") }) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Z").font(.caption2).bold()
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Button(action: isRunning ? stopDrill : startDrill) {
                            HStack {
                                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                Text(isRunning ? "STOP" : "INICIAR")
                            }
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(isRunning ? Color.red : Color.dragonBotPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                    }

                    // Contador de Bucle Restaurado
                    HStack {
                        Text("BUCLES:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                if loopCount > 1 { loopCount -= 1; isInfinite = false; sendLoopCommand(loopCount) }
                            }) {
                                Image(systemName: "minus.square.fill").font(.title2)
                            }
                            
                            Text(isInfinite ? "∞" : "\(loopCount)")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .frame(width: 40)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                loopCount += 1; isInfinite = false; sendLoopCommand(loopCount)
                            }) {
                                Image(systemName: "plus.square.fill").font(.title2)
                            }
                            
                            Button(action: {
                                isInfinite.toggle()
                                if isInfinite { communicator.sendCommand("[I]") } else { sendLoopCommand(loopCount) }
                            }) {
                                Text("INF")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(8)
                                    .background(isInfinite ? Color.dragonBotPrimary : Color.white.opacity(0.1))
                                    .foregroundColor(isInfinite ? .black : .white)
                                    .cornerRadius(8)
                            }
                        }
                        .foregroundColor(.dragonBotPrimary)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()

                // ScrollView de los Tiros
                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        let sortedKeys = shots.keys.sorted()
                        
                        // Línea de Conexión Animada
                        if sortedKeys.count > 1 {
                            DataLineView(count: sortedKeys.count, phase: flowPhase, isActive: isRunning)
                                .padding(.top, 45) // Alinea con el primer círculo
                        }

                        VStack(spacing: 30) {
                            ForEach(sortedKeys, id: \.self) { key in
                                if let cfg = shots[key] {
                                    DrillShotCard(
                                        cfg: cfg,
                                        onEdit: { onConfigShot(cfg.shotNumber) },
                                        onDelete: { handleDeleteShot(at: cfg.shotNumber) }
                                    )
                                }
                            }
                            
                            // Botón Añadir Paso
                            Button(action: handleAddShot) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("AÑADIR TIRO \(shots.count + 1)")
                                }
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 15).stroke(Color.dragonBotPrimary, lineWidth: 1))
                                .foregroundColor(.dragonBotPrimary)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                flowPhase = 1.0
            }
        }
    }
}

// MARK: - Componente Línea de Datos
struct DataLineView: View {
    let count: Int
    let phase: CGFloat
    let isActive: Bool
    
    var body: some View {
        Rectangle()
            .fill(Color.dragonBotPrimary.opacity(0.3))
            .frame(width: 2)
            .overlay(
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        ForEach(0..<count, id: \.self) { _ in
                            Circle()
                                .fill(isActive ? Color.white : Color.dragonBotPrimary)
                                .frame(width: 6, height: 6)
                                .shadow(color: .dragonBotPrimary, radius: 4)
                                .offset(y: phase * 120) // Velocidad de flujo
                        }
                    }
                    .mask(Rectangle().frame(height: geo.size.height))
                }
            )
            .frame(width: 2)
            .padding(.leading, 41) // Alineado con el centro del círculo de la tarjeta
            .allowsHitTesting(false)
    }
}

// MARK: - Tarjeta de Tiro Mejorada
struct DrillShotCard: View {
    let cfg: ShotConfig
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicador de Número (Círculo Conector)
            ZStack {
                Circle()
                    .fill(Color.dragonBotPrimary)
                    .frame(width: 34, height: 34)
                Text("\(cfg.shotNumber)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
            }
            .frame(width: 44)
            .zIndex(2)

            // Contenido de la Tarjeta
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TIRO\(cfg.shotNumber)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.subheadline).foregroundColor(.red.opacity(0.8))
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("VEL.").font(.system(size: 8)).foregroundColor(.gray)
                        Text("\(cfg.speedAB)").font(.system(size: 14, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("RETARDO").font(.system(size: 8)).foregroundColor(.gray)
                        Text("\(cfg.delayE)ms").font(.system(size: 14, weight: .bold))
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Text("AJUSTAR")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.dragonBotPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(15)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }
}
