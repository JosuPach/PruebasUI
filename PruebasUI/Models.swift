import Foundation
import CoreBluetooth
import SwiftUI

// MARK: - Protocolo del Comunicador

protocol DragonBotCommunicator: ObservableObject {
    var isConnected: Bool { get }
    var isConnecting: Bool { get }
    var isScanning: Bool { get }
    var discoveredDevices: [DeviceData] { get }
    var deviceData: DeviceData? { get set }
    var centralManager: CBCentralManager? { get }

    func startScan()
    func stopScan()
    func connect(device: DeviceData)
    func disconnect()
    func sendCommand(_ command: String)
}

enum DragonBotMode: String {
    case NONE
    case MANUAL
    case AUTO
}
// MARK: - ShotConfig (CLASE OBSERVADA + Codable)

class ShotConfig: ObservableObject, Identifiable, Equatable, Codable {
    static func == (lhs: ShotConfig, rhs: ShotConfig) -> Bool {
        return lhs.shotNumber == rhs.shotNumber && lhs.id == rhs.id
    }

    var id: UUID
    let shotNumber: Int

    // Propiedades de velocidad independientes
    @Published var speedA: Int
    @Published var speedB: Int
    
    // Propiedades mantenidas por compatibilidad o lógica secundaria
    @Published var speedAB: Int
    @Published var spinBias: Int
    
    @Published var delayE: Int
    @Published var targetD: Int
    @Published var targetC: Int
    @Published var targetF: Double
    @Published var targetG: Double
    @Published var targetH: Double
    @Published var shots: Int
    @Published var interval: Int
    @Published var isRunning: Bool = false

    init(
        id: UUID = UUID(),
        shotNumber: Int,
        speedA: Int = 127,
        speedB: Int = 127,
        speedAB: Int = 127,
        spinBias: Int = 0,
        delayE: Int = 127,
        targetD: Int = 127,
        targetC: Int = 127,
        targetF: Double = 127,
        targetG: Double = 127,
        targetH: Double = 127,
        shots: Int = 1,
        interval: Int = 1000
    ) {
        self.id = id
        self.shotNumber = shotNumber
        self.speedA = speedA
        self.speedB = speedB
        self.speedAB = speedAB
        self.spinBias = spinBias
        self.delayE = delayE
        self.targetD = targetD
        self.targetC = targetC
        self.targetF = targetF
        self.targetG = targetG
        self.targetH = targetH
        self.shots = shots
        self.interval = interval
    }

    // MARK: - Lógica de Escalado Corregida

    private func scaledTo99(_ value: Int) -> Int {
        let v = max(0, min(255, value))
        return Int(round(Double(v) * 99.0 / 255.0))
    }
    
    private func scaledTo20(_ value: Double) -> Int {
        let v = max(0, min(255, value))
        return Int(round(v * 20.0 / 255.0))
    }
    
    private func scaleToH(_ value: Double) -> Int {
        let v = max(0, min(255, value))
        let scaled = (v * 6000.0 / 255.0) - 3000.0
        return Int(scaled.rounded())
    }

    // Genera el comando corto para el protocolo SH
    func shortShotCommand() -> String {
        let x = scaledTo99(self.targetC)
        let y = scaledTo99(self.targetD)
        let v1 = scaledTo99(self.speedA)  // Rueda A
        let v2 = scaledTo99(self.speedB)  // Rueda B
        let v3 = scaledTo99(self.delayE)
        let v4 = scaledTo20(self.targetF)
        let v5 = scaledTo20(self.targetG)
        let v6 = scaleToH(self.targetH)
        
        return String(format: "[SH%02d,%02d,%02d,%02d,%02d,%02d,%02d,%d]", x, y, v1, v2, v3, v4, v5, v6)
    }

    func clone() -> ShotConfig {
        return ShotConfig(
            id: UUID(),
            shotNumber: self.shotNumber,
            speedA: self.speedA,
            speedB: self.speedB,
            speedAB: self.speedAB,
            spinBias: self.spinBias,
            delayE: self.delayE,
            targetD: self.targetD,
            targetC: self.targetC,
            targetF: self.targetF,
            targetG: self.targetG,
            targetH: self.targetH,
            shots: self.shots,
            interval: self.interval
        )
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, shotNumber, speedA, speedB, speedAB, spinBias, delayE, targetD, targetC, targetF, targetG, targetH, shots, interval, isRunning
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let idString = try container.decode(String.self, forKey: .id)
        let id = UUID(uuidString: idString) ?? UUID()
        let shotNumber = try container.decode(Int.self, forKey: .shotNumber)
        
        // Decodificamos A y B, con valores por defecto si no existen en archivos viejos
        let speedA = try container.decodeIfPresent(Int.self, forKey: .speedA) ?? 127
        let speedB = try container.decodeIfPresent(Int.self, forKey: .speedB) ?? 127
        
        let speedAB = try container.decode(Int.self, forKey: .speedAB)
        let spinBias = try container.decodeIfPresent(Int.self, forKey: .spinBias) ?? 0
        let delayE = try container.decode(Int.self, forKey: .delayE)
        let targetD = try container.decode(Int.self, forKey: .targetD)
        let targetC = try container.decode(Int.self, forKey: .targetC)
        let targetF = try container.decode(Double.self, forKey: .targetF)
        let targetG = try container.decode(Double.self, forKey: .targetG)
        let targetH = try container.decode(Double.self, forKey: .targetH)
        let shots = try container.decode(Int.self, forKey: .shots)
        let interval = try container.decode(Int.self, forKey: .interval)
        let isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false

        self.init(
            id: id,
            shotNumber: shotNumber,
            speedA: speedA,
            speedB: speedB,
            speedAB: speedAB,
            spinBias: spinBias,
            delayE: delayE,
            targetD: targetD,
            targetC: targetC,
            targetF: targetF,
            targetG: targetG,
            targetH: targetH,
            shots: shots,
            interval: interval
        )
        self.isRunning = isRunning
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id.uuidString, forKey: .id)
        try container.encode(self.shotNumber, forKey: .shotNumber)
        try container.encode(self.speedA, forKey: .speedA)
        try container.encode(self.speedB, forKey: .speedB)
        try container.encode(self.speedAB, forKey: .speedAB)
        try container.encode(self.spinBias, forKey: .spinBias)
        try container.encode(self.delayE, forKey: .delayE)
        try container.encode(self.targetD, forKey: .targetD)
        try container.encode(self.targetC, forKey: .targetC)
        try container.encode(self.targetF, forKey: .targetF)
        try container.encode(self.targetG, forKey: .targetG)
        try container.encode(self.targetH, forKey: .targetH)
        try container.encode(self.shots, forKey: .shots)
        try container.encode(self.interval, forKey: .interval)
        try container.encode(self.isRunning, forKey: .isRunning)
    }
}

// MARK: - Enums de Navegación

enum Screen: CaseIterable {
    case INICIO, CONTENIDO_PRINCIPAL, drillScreen, swapScreen, shotConfigScreen
}

// MARK: - Tema de Colores

extension Color {
    static let dragonBotPrimary = Color(red: 0.1, green: 0.9, blue: 0.1)
    static let dragonBotSecondary = Color(red: 0.9, green: 0.9, blue: 0.2)
    static let dragonBotError = Color(red: 1.0, green: 0.4, blue: 0.4)
    static let dragonBotBackground = Color.black
    static let dragonBotSurface = Color(white: 0.1)
}
