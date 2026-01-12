import SwiftUI

struct SwapConfigScreen: View {
    @ObservedObject var communicator: BLECommunicator
    @Environment(\.dismiss) var dismiss
    var onClose: () -> Void

    // Estado para los valores de los dos tiros de Swap
    @State private var swap1Speed: Double = 70
    @State private var swap1Delay: Double = 99
    @State private var swap2Speed: Double = 105
    @State private var swap2Delay: Double = 0
    
    // Estado para el popup de edición
    @State private var editingSwap: Int? = nil // nil, 1 o 2
    @State private var tempSpeed: Double = 0
    @State private var tempDelay: Double = 0

    var body: some View {
        ZStack {
            Color.dragonBotBackground.ignoresSafeArea()
            
            // Efecto de cuadrícula de fondo
            VStack(spacing: 2) {
                ForEach(0..<60, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(0.01)).frame(height: 1)
                }
            }.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        onClose()
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.dragonBotPrimary)
                    
                    Spacer()
                    Text("SWAP_MODULE_v2.0")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    
                    // Status dot
                    Circle()
                        .fill(communicator.isConnected ? Color.dragonBotPrimary : Color.dragonBotError)
                        .frame(width: 6, height: 6)
                }
                .padding()
                .background(Color.black.opacity(0.4))

                ScrollView {
                    VStack(spacing: 25) {
                        
                        // Panel Principal de Control
                        VStack(spacing: 15) {
                            actionButton(title: "ACTIVATE SWAP MODE [WA]", icon: "arrow.left.and.right.square", color: .blue) {
                                communicator.sendCommand("[WA]")
                            }
                            
                            actionButton(title: "EXECUTE SWAP SEQUENCE [PL]", icon: "play.fill", color: .dragonBotPrimary) {
                                communicator.sendCommand("[PL]")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Sección de Configuración de Tiros
                        VStack(alignment: .leading, spacing: 15) {
                            Text("SWAP_CHANNELS_CONFIGURATION")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.dragonBotSecondary)
                                .padding(.horizontal)

                            // CARD SWAP 1
                            SwapShotCard(
                                id: 1,
                                speed: Int(swap1Speed),
                                delay: Int(swap1Delay),
                                color: .orange,
                                onEdit: {
                                    tempSpeed = swap1Speed
                                    tempDelay = swap1Delay
                                    editingSwap = 1
                                },
                                onSend: {
                                    sendSwapCommand(id: 1, speed: swap1Speed, delay: swap1Delay)
                                }
                            )

                            // CARD SWAP 2
                            SwapShotCard(
                                id: 2,
                                speed: Int(swap2Speed),
                                delay: Int(swap2Delay),
                                color: .pink,
                                onEdit: {
                                    tempSpeed = swap2Speed
                                    tempDelay = swap2Delay
                                    editingSwap = 2
                                },
                                onSend: {
                                    sendSwapCommand(id: 2, speed: swap2Speed, delay: swap2Delay)
                                }
                            )
                        }
                    }
                    .padding(.bottom, 100)
                }
            }

            // POPUP DE EDICIÓN (MODAL)
            if let id = editingSwap {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture { editingSwap = nil }
                
                VStack(spacing: 25) {
                    VStack(spacing: 5) {
                        Text("EDIT_SWAP_CHANNEL_0\(id)")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.dragonBotPrimary)
                        Rectangle().fill(Color.dragonBotPrimary).frame(height: 1)
                    }
                    
                    VStack(spacing: 20) {
                        // Sliders de configuración
                        VStack(alignment: .leading, spacing: 10) {
                            Label("CHANNEL_POWER: \(Int(tempSpeed))", systemImage: "bolt.fill")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Slider(value: $tempSpeed, in: 0...255, step: 1)
                                .accentColor(.dragonBotPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Label("TRANSITION_DELAY: \(Int(tempDelay))", systemImage: "timer")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Slider(value: $tempDelay, in: 0...255, step: 1)
                                .accentColor(.dragonBotPrimary)
                        }
                    }
                    
                    HStack(spacing: 15) {
                        Button(action: { editingSwap = nil }) {
                            Text("CANCEL")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            if id == 1 {
                                swap1Speed = tempSpeed
                                swap1Delay = tempDelay
                            } else {
                                swap2Speed = tempSpeed
                                swap2Delay = tempDelay
                            }
                            editingSwap = nil
                        }) {
                            Text("COMMIT")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.dragonBotPrimary)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(25)
                .background(Color.dragonBotBackground)
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.dragonBotPrimary.opacity(0.5), lineWidth: 2))
                .frame(maxWidth: 320)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Helper Functions

    private func sendSwapCommand(id: Int, speed: Double, delay: Double) {
        let s = String(format: "%03d", Int(speed))
        let d = String(format: "%02d", Int(delay))
        let cmd = "[Y\(s)992727\(d)0000]"
        
        communicator.sendCommand(cmd)
        print("Swap \(id) Command Sent: \(cmd)")
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.5), lineWidth: 1))
        }
    }
}

struct SwapShotCard: View {
    let id: Int
    let speed: Int
    let delay: Int
    let color: Color
    var onEdit: () -> Void
    var onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Lado Izquierdo: ID
            VStack {
                Text("CH")
                Text("0\(id)")
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundColor(.black)
            .frame(width: 50)
            .frame(maxHeight: .infinity)
            .background(color)
            
            // Centro: Info
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("POWER")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.dragonBotSecondary)
                        Text("\(speed)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading) {
                        Text("DELAY")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.dragonBotSecondary)
                        Text("\(delay)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    // Botón Editar
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                }
                
                // Botón Enviar Específico
                Button(action: onSend) {
                    Text("TRANSMIT_DATA")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
        }
        .frame(height: 100)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
