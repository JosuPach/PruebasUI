import SwiftUI

struct DeviceSelectionDialog: View {
    
    @ObservedObject var communicator: BLECommunicator
    var onDeviceSelected: (DeviceData) -> Void
    var onDismiss: () -> Void
    
    // ⭐️ Nuevo: Duración del escaneo (ej. 10 segundos)
    private let scanDuration: TimeInterval = 10.0
    
    @State private var scanTimer: Timer? = nil

    // MARK: - Lógica del Escaneo (Replicando DisposableEffect)
    
    private func startScanning() {
        // Asegurarse de detener cualquier escaneo y temporizador anterior.
        communicator.stopScan()
        scanTimer?.invalidate()
        
        // 1. Iniciar el escaneo
        communicator.startScan()
        
        // 2. Programar el temporizador para detener el escaneo
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanDuration, repeats: false) { _ in
            communicator.stopScan()
            print("Escaneo detenido automáticamente después de \(scanDuration) segundos.")
        }
    }
    
    private func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        communicator.stopScan()
    }
    
    var body: some View {
        VStack(spacing: 15) {
            
            // --- Título del Diálogo ---
            Text("Selecciona tu DragonBot")
                .font(.title2.bold())
                .foregroundColor(DragonBotTheme.primary)
                .padding(.bottom, 5)

            // --- Estado del Escaneo y Spinner ---
            HStack {
                Text(communicator.isScanning ? "Buscando dispositivos cercanos..." : "Escaneo Detenido.")
                    .font(.callout)
                    .foregroundColor(DragonBotTheme.secondary)
                
                if communicator.isScanning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DragonBotTheme.secondary))
                }
            }
            
            // --- Lista de Dispositivos Encontrados ---
            ScrollView {
                VStack(spacing: 8) {
                    if communicator.discoveredDevices.isEmpty && !communicator.isScanning {
                        Text("No se encontraron dispositivos.")
                            .foregroundColor(DragonBotTheme.error)
                            .padding()
                    } else {
                        ForEach(communicator.discoveredDevices) { device in
                            DeviceRow(device: device)
                                .onTapGesture {
                                    stopScanning() // Detener escaneo antes de conectar
                                    onDeviceSelected(device)
                                    onDismiss()
                                }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 250) // Limitar la altura de la lista
            
            // --- Botones de Acción ---
            HStack(spacing: 15) {
                // ⭐️ Botón CANCELAR / REINTENTAR
                Button(communicator.isScanning ? "CANCELAR" : "REINTENTAR ESCANEO") {
                    if communicator.isScanning {
                        stopScanning()
                    } else {
                        startScanning()
                    }
                }
                .buttonStyle(DragonBotButtonStyle(color: communicator.isScanning ? DragonBotTheme.error : DragonBotTheme.secondary))
                
                // Botón CERRAR
                Button("CERRAR") {
                    stopScanning()
                    onDismiss()
                }
                .buttonStyle(DragonBotButtonStyle(color: DragonBotTheme.tertiary))
            }
        }
        .padding(20)
        .background(DragonBotTheme.background)
        .cornerRadius(15)
        .shadow(color: DragonBotTheme.primary.opacity(0.5), radius: 10)
        
        // ⭐️ Efecto de Ciclo de Vida (similar al DisposableEffect de Compose)
        .onAppear {
            // Iniciar escaneo al aparecer la vista
            communicator.startScan()
        }
        .onDisappear {
            // Detener escaneo al desaparecer la vista
            communicator.stopScan()
        }
    }
}

// MARK: - Sub-Vista para la Fila del Dispositivo

struct DeviceRow: View {
    let device: DeviceData
    
    var body: some View {
        HStack {
            Image(systemName: "b.circle.fill")
                .foregroundColor(DragonBotTheme.primary)
            
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(DragonBotTheme.primary)
                Text("BLE: \(device.macAddress)")
                    .font(.caption)
                    .foregroundColor(DragonBotTheme.onBackground.opacity(0.7))
            }
            
            Spacer()
            
            Text("RSSI: \(device.rssi) dBm")
                .font(.caption2)
                .foregroundColor(DragonBotTheme.secondary)
        }
        .padding(10)
        .background(DragonBotTheme.darkBlack.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DragonBotTheme.tertiary.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Estilo de Botón Auxiliar

struct DragonBotButtonStyle: ButtonStyle {
    var color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundColor(DragonBotTheme.surface) // Color de texto negro/oscuro
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
