import SwiftUI

// MARK: - 1. Definición de Constantes y Temas (Colors & Typography)

// Colores base
let DarkBlack = Color(hex: 0xFF000000)
let NeonGreen = Color(hex: 0xFF39FF14)      // Primary
let YellowishGreen = Color(hex: 0xFFBFFF00) // Secondary
let LightBlue = Color(hex: 0xFF89CFF0)      // Tertiary
let DeepBlue = Color(hex: 0xFF0A0014)      // Background

// Paleta DragonBot (Uso semántico)
struct DragonBotTheme {
    static let primary = NeonGreen
    static let secondary = YellowishGreen
    static let tertiary = LightBlue
    static let background = DeepBlue
    static let onBackground = LightBlue
    static let error = Color(hex: 0xFFFF6B6B)
    static let surface = DarkBlack
    static let onPrimary = DarkBlack
    static let darkBlack = Color(red: 0, green: 0, blue: 0, opacity: 1.0)
}

// MARK: - 2. Extensiones y Utilidades

// Extension para inicializar Color desde un valor hexadecimal
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
    
    // Propiedades de acceso directo (para usarlas como .neonGreen)
    static var darkBlack: Color { DarkBlack }
    static var neonGreen: Color { NeonGreen }
    static var yellowishGreen: Color { YellowishGreen }
    static var lightBlue: Color { LightBlue }
    static var deepBlue: Color { DeepBlue }
}

// Extension para rellenar con ceros (padStart en Compose/JS)
extension String {
    func paddingLeading(toLength: Int, withPad: Character) -> String {
        let length = self.count
        if length >= toLength {
            return self
        }
        return String(repeatElement(withPad, count: toLength - length)) + self
    }
}
