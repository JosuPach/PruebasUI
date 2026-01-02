import Foundation
import CoreBluetooth
import SwiftUI
import Combine

// MARK: - 1. Modelos de Datos
/// Representa un dispositivo Bluetooth encontrado durante el escaneo.
struct DeviceData: Identifiable {
    let id = UUID()
    let name: String
    let macAddress: String // Usamos el UUID del periférico
    let peripheral: CBPeripheral // El objeto Core Bluetooth
    var isConnected: Bool = false
    var isPaired: Bool = false
    var rssi: Int // Intensidad de la señal
}

// MARK: - 2. Protocolo de Servicios (UUIDs - Confirmado para HM-10)
struct DragonBotService {
    static let DRAGONBOT_SERVICE_UUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    static let COMMUNICATION_CHARACTERISTIC_UUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    static let RX_CHARACTERISTIC_UUID = COMMUNICATION_CHARACTERISTIC_UUID
    static let TX_CHARACTERISTIC_UUID = COMMUNICATION_CHARACTERISTIC_UUID
}

// MARK: - 3. La Clase de Comunicación Principal

class BLECommunicator: NSObject, ObservableObject {
    
    // MARK: - Propiedades Publicadas (Estado de la UI)
    
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [DeviceData] = []
    
    // MARK: - Propiedades Internas
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    // ⭐️ IMPORTANTE: Esta bandera es clave para que el escaneo se reactive.
    private var shouldScanWhenReady: Bool = false
    private var currentDeviceToConnect: DeviceData?

    var centralManagerWrapper: CBCentralManager? {
        return centralManager
    }

    // MARK: - Inicialización
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Lógica de Escaneo
    
    func startScan() {
        guard centralManager.state == .poweredOn else {
            // ⭐️ MEJORA CLAVE: Solo establecer la bandera y salir.
            // El escaneo real se hará en centralManagerDidUpdateState.
            self.shouldScanWhenReady = true
            print("Bluetooth no listo. Escaneo programado para cuando esté PoweredOn.")
            return
        }
        
        let scanOptions: [String: Any]? = [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ]

        centralManager.scanForPeripherals(withServices: nil, options: scanOptions)
        
        self.isScanning = true
        self.discoveredDevices.removeAll()
        self.shouldScanWhenReady = false // La reseteamos solo si el escaneo inicia
        print("Escaneo general de todos los periféricos BLE iniciado.")
    }
    
    func stopScan() {
        // ⭐️ MEJORA: Evitar llamar a .stopScan() si el centralManager es nil o no está escaneando.
        guard centralManager.isScanning else {
            self.isScanning = false
            return
        }
        centralManager.stopScan()
        self.isScanning = false
        print("Escaneo detenido.")
    }

    // MARK: - Lógica de Conexión
    
    func connect(device: DeviceData) {
        self.stopScan()
        self.currentDeviceToConnect = device
        self.isConnecting = true
        centralManager.connect(device.peripheral, options: nil)
        print("Intentando conectar a: \(device.name)")
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        self.isConnected = false
        self.connectedPeripheral = nil
        self.writeCharacteristic = nil
        print("Desconectado por el usuario.")
    }

    // MARK: - Lógica de Envío de Datos
    
    // ⭐️ CORRECCIÓN CLAVE: Renombré la función de 'send(command:)' a 'sendCommand(_ command:)'
    // para que coincida con las llamadas en las vistas (DrillScreen y ShotConfigScreen).
    func sendCommand(_ command: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else {
            print("Error: No hay conexión o característica de escritura no encontrada.")
            return
        }
        
        if let data = command.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            print("Comando enviado: \(command)")
        }
    }
}

// MARK: - 4. Extensión CBCentralManagerDelegate

extension BLECommunicator: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Estado del Central Manager actualizado a: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            print("Bluetooth encendido. Listo.")
            // ⭐️ CLAVE: Si se había programado un escaneo, iniciarlo ahora.
            if shouldScanWhenReady {
                self.startScan()
            }
            
        case .poweredOff:
            print("Bluetooth apagado. Desconectado.")
            self.isScanning = false
            self.isConnected = false
            self.isConnecting = false
            self.discoveredDevices.removeAll()
            
        case .unauthorized, .unsupported, .unknown, .resetting:
            print("Estado BT no óptimo: \(central.state.rawValue)")
            self.isScanning = false
            self.isConnected = false
            self.isConnecting = false
            
        @unknown default:
            print("Nuevo estado BT desconocido.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Dispositivo Desconocido (\(peripheral.identifier.uuidString.prefix(4)))"
        
        let newDevice = DeviceData(
            name: name,
            macAddress: peripheral.identifier.uuidString,
            peripheral: peripheral,
            isConnected: false,
            isPaired: false,
            rssi: RSSI.intValue
        )
        
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            self.discoveredDevices.append(newDevice)
            print("Descubierto: \(name) | RSSI: \(RSSI)")
        } else {
            if let index = discoveredDevices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
                discoveredDevices[index].rssi = RSSI.intValue
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Conectado exitosamente a \(peripheral.name ?? "dispositivo")")
        self.isConnecting = false
        self.isConnected = true
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([DragonBotService.DRAGONBOT_SERVICE_UUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Fallo de conexión: \(error?.localizedDescription ?? "desconocido")")
        self.isConnecting = false
        self.isConnected = false
        self.currentDeviceToConnect = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Desconectado de \(peripheral.name ?? "dispositivo").")
        self.isConnected = false
        self.isConnecting = false
        self.connectedPeripheral = nil
        self.writeCharacteristic = nil
    }
}

// MARK: - 5. Extensión CBPeripheralDelegate

extension BLECommunicator: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            print("Error: No se pudieron descubrir servicios: \(error?.localizedDescription ?? "desconocido")")
            self.centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        
        for service in services {
            if service.uuid == DragonBotService.DRAGONBOT_SERVICE_UUID {
                print("Servicio HM-10 (FFE0) encontrado. Buscando característica de comunicación...")
                peripheral.discoverCharacteristics([DragonBotService.COMMUNICATION_CHARACTERISTIC_UUID], for: service)
                return
            }
        }
        
        print("Error: Servicio DragonBot/HM-10 (FFE0) no encontrado en el periférico. Desconectando.")
        self.centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        var foundCharacteristic = false
        
        for characteristic in characteristics {
            if characteristic.uuid == DragonBotService.COMMUNICATION_CHARACTERISTIC_UUID {
                self.writeCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("Característica HM-10 (FFE1) configurada para Escritura y Notificación.")
                foundCharacteristic = true
            }
        }
        
        if !foundCharacteristic {
            print("Error: No se encontró la característica de comunicación HM-10 (FFE1). Desconectando.")
            self.centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == DragonBotService.COMMUNICATION_CHARACTERISTIC_UUID,
              let data = characteristic.value else { return }
        
        if let message = String(data: data, encoding: .utf8) {
            print("Datos recibidos del HM-10: \(message)")
        }
    }
}
