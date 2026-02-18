import SwiftUI

struct DeviceSelectionDialog: View {
    @ObservedObject var communicator: BLECommunicator
    var onDeviceSelected: (DeviceData) -> Void
    var onDismiss: () -> Void
    
    private let scanDuration: TimeInterval = 10.0
    @State private var scanTimer: Timer? = nil
    @State private var scanRotation: Double = 0
    
    // MARK: - Lógica de Escaneo
    private func startScanning() {
        communicator.stopScan()
        scanTimer?.invalidate()
        communicator.startScan()
        
        // Animación de radar
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            scanRotation = 360
        }
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanDuration, repeats: false) { _ in
            stopScanning()
        }
    }
    
    private func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        scanRotation = 0
        communicator.stopScan()
    }
    
    // MARK: - Body Principal
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            deviceListSection
            
            controlPanelSection
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.12))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DragonBotTheme.primary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .padding(25)
        .onAppear { startScanning() }
        .onDisappear { stopScanning() }
    }
    
    // MARK: - Sub-vistas (Para evitar error de compilación)
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SISTEMA DE ENLACE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(DragonBotTheme.primary.opacity(0.7))
                Text("BUSCANDO HARDWARE")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
            
            // Indicador de Radar
            ZStack {
                Circle()
                    .stroke(DragonBotTheme.primary.opacity(0.2), lineWidth: 1)
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(DragonBotTheme.primary, lineWidth: 2)
                    .rotationEffect(.degrees(scanRotation))
            }
            .frame(width: 30, height: 30)
        }
        .padding(20)
        .background(Color.black.opacity(0.3))
    }
    
    private var deviceListSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                if communicator.discoveredDevices.isEmpty {
                    emptyStateView
                } else {
                    ForEach(communicator.discoveredDevices) { device in
                        DeviceRow(device: device)
                            .onTapGesture {
                                stopScanning()
                                onDeviceSelected(device)
                                onDismiss()
                            }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxHeight: 300)
        .background(Color.black.opacity(0.1))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 30))
                .foregroundColor(DragonBotTheme.primary.opacity(0.3))
            Text(communicator.isScanning ? "ESCANEO EN CURSO..." : "NO SE DETECTARON DISPOSITIVOS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.top, 40)
    }
    
    private var controlPanelSection: some View {
        VStack(spacing: 12) {
            Divider().background(DragonBotTheme.primary.opacity(0.2))
            
            HStack(spacing: 12) {
                // Botón REESCANEAR / DETENER
                Button(action: {
                    if communicator.isScanning { stopScanning() }
                    else { startScanning() }
                }) {
                    HStack {
                        Image(systemName: communicator.isScanning ? "xmark.circle" : "arrow.clockwise")
                        Text(communicator.isScanning ? "DETENER" : "REESCANEAR")
                    }
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(communicator.isScanning ? .red : DragonBotTheme.secondary)
                    .frame(maxWidth: .infinity) // Ocupa el espacio disponible
                    .frame(height: 45)         // Altura fija para evitar el error de minHeight
                    .background(communicator.isScanning ? Color.red.opacity(0.2) : DragonBotTheme.secondary.opacity(0.2))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(communicator.isScanning ? Color.red.opacity(0.4) : DragonBotTheme.secondary.opacity(0.4), lineWidth: 1)
                    )
                }
                
                // Botón CERRAR
                Button(action: {
                    stopScanning()
                    onDismiss()
                }) {
                    Text("CERRAR")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 100)  // Ancho fijo para el botón cerrar
                        .frame(height: 45)  // Altura fija
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - Fila de Dispositivo
    struct DeviceRow: View {
        let device: DeviceData
        
        var body: some View {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(DragonBotTheme.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "cpu")
                        .foregroundColor(DragonBotTheme.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name.isEmpty ? "UNKNOWN DEVICE" : device.name.uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text(device.macAddress)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(device.rssi) dBm")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(rssiColor(device.rssi))
                    
                    HStack(spacing: 2) {
                        ForEach(0..<4) { i in
                            Capsule()
                                .fill(i < signalBars(device.rssi) ? DragonBotTheme.primary : Color.white.opacity(0.1))
                                .frame(width: 3, height: CGFloat(i + 1) * 3)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        
        private func signalBars(_ rssi: Int) -> Int {
            if rssi > -60 { return 4 }
            if rssi > -70 { return 3 }
            if rssi > -80 { return 2 }
            return 1
        }
        
        private func rssiColor(_ rssi: Int) -> Color {
            if rssi > -70 { return .green }
            if rssi > -90 { return .yellow }
            return .red
        }
    }
}
