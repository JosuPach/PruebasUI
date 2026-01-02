import SwiftUI

struct InicioScreen: View {
    var onStartClick: () -> Void

    var body: some View {
        ZStack {
            DragonBotTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()

                SimpleHSStyledText(text: "DRAGONBOT", size: 60, weight: .bold)
                    .padding(.top, 50)
            
                SimpleHSStyledText(text: "REMSTEC", size: 30, weight: .semibold)
                    .padding(.bottom, 120)

                Button(action: onStartClick) {
                    Text("INICIAR")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: 300)
                        .padding()
                        .background(DragonBotTheme.primary)
                        .foregroundColor(DragonBotTheme.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DragonBotTheme.secondary, lineWidth: 2)
                        )
                }
                .frame(height: 60)
                
                Spacer()
                Spacer()

                Text("Versión 1.0.1 BETA")
                    .foregroundColor(DragonBotTheme.onBackground.opacity(0.5))
                    .font(.caption)
                    .padding(.bottom, 20)
            }
        }
    }
}

// Sub-vista auxiliar (Debe estar definida en Models.swift o Styles.swift)
struct SimpleHSStyledText: View {
    var text: String
    var size: CGFloat
    var weight: Font.Weight
    
    var body: some View {
        Text(text)
            .font(.custom("Menlo", size: size))
            .fontWeight(weight)
            .foregroundColor(.neonGreen)
    }
}
