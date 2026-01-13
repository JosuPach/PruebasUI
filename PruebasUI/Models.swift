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

    // guardamos id para persistencia
    var id: UUID
    let shotNumber: Int

    // propiedades observables
    @Published var speedAB: Int
    @Published var delayE: Int
    @Published var targetD: Int
    @Published var targetC: Int
    @Published var targetF: Int
    @Published var targetG: Int
    @Published var targetH: Int
    @Published var shots: Int
    @Published var interval: Int
    @Published var isRunning: Bool = false

    init(
        id: UUID = UUID(),
        shotNumber: Int,
        speedAB: Int = 127,
        delayE: Int = 500,
        targetD: Int = 127,
        targetC: Int = 127,
        targetF: Int = 127,
        targetG: Int = 127,
        targetH: Int = 127,
        shots: Int = 1,
        interval: Int = 1000
    ) {
        self.id = id
        self.shotNumber = shotNumber
        self.speedAB = speedAB
        self.delayE = delayE
        self.targetD = targetD
        self.targetC = targetC
        self.targetF = targetF
        self.targetG = targetG
        self.targetH = targetH
        self.shots = shots
        self.interval = interval
    }

    // MARK: - Computed full command string (existente)
    var commandString: String {
        let cmd = "S\(String(format: "%03d", shots))" +
                  "I\(String(format: "%04d", interval))" +
                  "A\(String(format: "%03d", speedAB))" +
                  "B\(String(format: "%03d", speedAB))" +
                  "C\(String(format: "%03d", targetC))" +
                  "D\(String(format: "%03d", targetD))" +
                  "F\(String(format: "%03d", targetF))" +
                  "G\(String(format: "%03d", targetG))" +
                  "H\(String(format: "%03d", targetH))" +
                  "E\(String(format: "%04d", delayE))"

        return "[SHOT] \(shotNumber) \(cmd)"
    }

    // MARK: - Short SH command required by your firmware: [SHxxYYVVWW]
    // maps 0..255 -> 0..99 (0->0, 255->99)
    private func scaledTo99(_ value: Int) -> Int {
        let v = max(0, min(255, value))
        // Double scaling and rounding
        let scaled = Int(round(Double(v) * 99.0 / 255.0))
        return max(0, min(99, scaled))
    }

    /// Generates the short SH command like "[SH30995050]"
    /// Order: X (targetC scaled), Y (targetD scaled), V1 (speed scaled), V2 (speed scaled)
    /// All values are two digits (00..99)
    func shortShotCommand() -> String {
        let x = scaledTo99(self.targetC)
        let y = scaledTo99(self.targetD)
        let v1 = scaledTo99(self.speedAB)  // you said both wheels same value from slider
        let v2 = scaledTo99(self.speedAB)
        let v3 = scaledTo99(self.delayE)
        let v4 = scaledTo99(self.targetF)
        let v5 = scaledTo99(self.targetG)
        let v6 = scaledTo99(self.targetH)
        return String(format: "[SH%02d%02d%02d%02d%02d%02d%02d%02d]", x, y, v1, v2,v3,v4,v5,v6)
    }

    // Optional: a method to update numeric fields from a short command decode (if needed)
    func applyShortValues(x: Int, y: Int, v1: Int, v2: Int) {
        // reverse-scaling is lossy; use direct values for UI if needed
        self.targetC = Int(round(Double(x) * 255.0 / 99.0))
        self.targetD = Int(round(Double(y) * 255.0 / 99.0))
        self.speedAB = Int(round(Double((v1 + v2) / 2) * 255.0 / 99.0))
    }

    // MARK: - Clonación
    func clone() -> ShotConfig {
        return ShotConfig(
            id: UUID(),
            shotNumber: self.shotNumber,
            speedAB: self.speedAB,
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

    // MARK: - Codable manual (porque usamos @Published)
    enum CodingKeys: String, CodingKey {
        case id
        case shotNumber
        case speedAB
        case delayE
        case targetD
        case targetC
        case targetF
        case targetG
        case targetH
        case shots
        case interval
        case isRunning
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        let id = UUID(uuidString: idString) ?? UUID()
        let shotNumber = try container.decode(Int.self, forKey: .shotNumber)
        let speedAB = try container.decode(Int.self, forKey: .speedAB)
        let delayE = try container.decode(Int.self, forKey: .delayE)
        let targetD = try container.decode(Int.self, forKey: .targetD)
        let targetC = try container.decode(Int.self, forKey: .targetC)
        let targetF = try container.decode(Int.self, forKey: .targetF)
        let targetG = try container.decode(Int.self, forKey: .targetG)
        let targetH = try container.decode(Int.self, forKey: .targetH)
        let shots = try container.decode(Int.self, forKey: .shots)
        let interval = try container.decode(Int.self, forKey: .interval)
        let isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false

        self.init(
            id: id,
            shotNumber: shotNumber,
            speedAB: speedAB,
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
        try container.encode(self.speedAB, forKey: .speedAB)
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


// MARK: - Tema de Colores (Simulación de DragonBotTheme)

extension Color {
    static let dragonBotPrimary = Color(red: 0.1, green: 0.9, blue: 0.1) // Verde Neón
    static let dragonBotSecondary = Color(red: 0.9, green: 0.9, blue: 0.2) // Amarillo-Verde
    static let dragonBotError = Color(red: 1.0, green: 0.4, blue: 0.4) // Rojo Suave
    static let dragonBotBackground = Color.black
    static let dragonBotSurface = Color(white: 0.1)
}

