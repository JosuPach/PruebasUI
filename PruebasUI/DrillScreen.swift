import SwiftUI

struct DrillScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Binding var shots: [Int : ShotConfig]
    
    var onBackClick: () -> Void
    var onConfigShot: (Int) -> Void
    var onAddShot: () -> Void
    var onDeleteShot: (Int) -> Void

    // Estado UI
    @State private var loopCount: Int = 1
    @State private var isInfinite: Bool = false
    @State private var isRunning: Bool = false
    @State private var scanlineOffset: CGFloat = 0

    // MARK: - Helpers
    private func sendLoopCommand(_ count: Int) {
        let formatted = String(format: "%02d", min(max(count, 0), 99))
        communicator.sendCommand("[N\(formatted)]")
    }

    private func buildConsolidatedShotsCommand() -> String {
        let ordered = shots.values.sorted { $0.shotNumber < $1.shotNumber }
        let joined = ordered.map { cfg in
            String(format: "A%03d:B%03d:C%03d:D%03d:E%03d",
                   cfg.speedAB, cfg.speedAB, cfg.targetC, cfg.targetD, cfg.delayE)
        }.joined(separator: ":")
        return joined
    }

    private func startDrill() {
        guard communicator.isConnected else { return }
        communicator.sendCommand("[MD]")
        let loopValue = isInfinite ? 255 : min(max(loopCount, 1), 255)
        let loopP = String(format: "%03d", loopValue)
        let shotsCmd = buildConsolidatedShotsCommand()
        let final = "[MD]P\(loopP):\(shotsCmd)[GO]"
        communicator.sendCommand(final)
        withAnimation { isRunning = true }
    }

    private func stopDrill() {
        communicator.sendCommand("[Z]")
        withAnimation { isRunning = false }
    }

    var body: some View {
        ZStack {
            // Fondo Base
            Color.dragonBotBackground.ignoresSafeArea()
            
            // Scanlines decorativos
            GeometryReader { geo in
                VStack(spacing: 2) {
                    let lineCount = Int(geo.size.height / 4)
                    ForEach(0..<lineCount, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.015))
                            .frame(height: 1)
                    }
                }
            }.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button(action: onBackClick) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotPrimary)
                    }
                    Spacer()
                    Text("DRILL_SEQUENCE_EDITOR")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Circle()
                        .fill(communicator.isConnected ? Color.dragonBotPrimary : Color.dragonBotError)
                        .frame(width: 8, height: 8)
                        .shadow(color: communicator.isConnected ? .dragonBotPrimary : .dragonBotError, radius: 4)
                }
                .padding()
                .background(Color.black.opacity(0.3))

                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Panel de Control Superior (Loop Counter)
                        VStack(spacing: 15) {
                            HStack {
                                Text("EXECUTION_CYCLES")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.dragonBotSecondary)
                                Spacer()
                                if isInfinite {
                                    Text("∞ INFINITE_MODE")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.dragonBotPrimary)
                                }
                            }
                            
                            LoopCounter(
                                loopCount: loopCount,
                                isInfinite: isInfinite,
                                onIncrement: {
                                    loopCount += 1
                                    isInfinite = false
                                    sendLoopCommand(loopCount)
                                },
                                onDecrement: {
                                    if loopCount > 1 {
                                        loopCount -= 1
                                        isInfinite = false
                                        sendLoopCommand(loopCount)
                                    }
                                },
                                onSetInfinite: {
                                    isInfinite = true
                                    communicator.sendCommand("[I]")
                                },
                                onSetFinite: {
                                    isInfinite = false
                                    sendLoopCommand(loopCount)
                                }
                            )
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Lista de Tiros
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("SEQUENCE_QUEUE")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(shots.count) UNITS")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.dragonBotPrimary)
                            }
                            .padding(.horizontal)

                            if shots.isEmpty {
                                EmptyStateView(action: onAddShot)
                            } else {
                                ForEach(shots.keys.sorted(), id: \.self) { key in
                                    if let cfg = shots[key] {
                                        DrillShotCard(
                                            cfg: cfg,
                                            onEdit: { onConfigShot(cfg.shotNumber) },
                                            onDelete: { onDeleteShot(cfg.shotNumber) }
                                        )
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                    }
                                }
                                
                                Button(action: onAddShot) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("APPEND_NEW_SHOT")
                                    }
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.dragonBotPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.dragonBotPrimary, lineWidth: 1))
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Status Indicator si está corriendo
                        if isRunning {
                            HStack {
                                Circle().fill(Color.dragonBotPrimary).frame(width: 8, height: 8)
                                    .opacity(scanlineOffset)
                                Text("SYSTEM_ACTIVE: EXECUTING_DRILL...")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.dragonBotPrimary)
                            }
                            .padding()
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                                    scanlineOffset = 1.0
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
            }

            // BOTONES DE ACCIÓN FLOTANTES (Sticky Bottom)
            VStack {
                Spacer()
                HStack(spacing: 15) {
                    if isRunning {
                        Button(action: stopDrill) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("HALT_SYSTEM")
                            }
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.dragonBotError)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: .dragonBotError.opacity(0.4), radius: 10)
                        }
                    } else {
                        Button(action: startDrill) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("INITIATE_DRILL")
                            }
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(shots.isEmpty ? Color.gray : Color.dragonBotPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(15)
                            .shadow(color: .dragonBotPrimary.opacity(0.3), radius: 10)
                        }
                        .disabled(shots.isEmpty)
                    }
                }
                .padding()
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                )
            }
        }
    }
}

// MARK: - Subcomponentes Visuales

struct DrillShotCard: View {
    let cfg: ShotConfig
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Indicador de número lateral
            VStack {
                Text("#")
                    .font(.system(size: 10, weight: .bold))
                Text("\(cfg.shotNumber)")
                    .font(.system(size: 18, weight: .black))
            }
            .foregroundColor(.black)
            .frame(width: 50)
            .frame(maxHeight: .infinity)
            .background(Color.dragonBotPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SHOT_CONFIG_DATA")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.dragonBotSecondary)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "xmark.square.fill")
                            .foregroundColor(.dragonBotError.opacity(0.7))
                    }
                }
                
                HStack(spacing: 15) {
                    VStack(alignment: .leading) {
                        Label("PWR", systemImage: "bolt.fill")
                        Text("\(cfg.speedAB)").font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading) {
                        Label("DLY", systemImage: "timer")
                        Text("\(cfg.delayE)ms").font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    
                    Spacer()
                    
                    Button(action: onEdit) {
                        Text("EDIT")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.dragonBotPrimary.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.dragonBotPrimary, lineWidth: 1))
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.05))
        }
        .frame(height: 90)
        .cornerRadius(10)
        .padding(.horizontal)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .padding(.horizontal)
        )
    }
}

struct EmptyStateView: View {
    var action: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cpu")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.1))
            Text("NO_SEQUENCE_LOADED")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Button(action: action) {
                Text("CREATE_FIRST_SHOT")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding()
                    .background(Color.dragonBotPrimary)
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
