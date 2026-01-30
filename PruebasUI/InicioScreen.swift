import SwiftUI
import AVFoundation

// MARK: - AUDIO MANAGER
class AudioManager {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?

    func playSound(named name: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            print("❌ Error: Archivo de audio \(name) no encontrado.")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("❌ Error: No se pudo reproducir el audio: \(error.localizedDescription)")
        }
    }
}

// MARK: - TEMA DE COLORES
struct ToothlessTheme {
    static let deepBlack = Color(red: 0.0, green: 0.0, blue: 0.04)
    static let plasmaBlue = Color(red: 0.0, green: 0.8, blue: 1.0)
    static let dragonEyeGreen = Color(red: 0.4, green: 1.0, blue: 0.1)
    static let glassWhite = Color.white.opacity(0.7)
}

struct InicioScreen: View {
    var onStartClick: () -> Void
    
    @State private var animatedText: String = ""
    @State private var buttonOpacity: Double = 0.0
    @State private var showIntro = true
    
    @State private var solderingProgress: CGFloat = 0.0
    @State private var introOpacity: Double = 1.0
    @State private var logoOpacity: Double = 0.0
    @State private var sparkOpacity: Double = 0.0
    
    @State private var robotRotationY: Double = 0
    @State private var gridPhase: CGFloat = 0
    @State private var currentSubtitleIndex = 0
    @State private var subtitleOpacity: Double = 0.0
    @State private var scanLineY: CGFloat = 0
    
    @State private var targetBasePos: CGPoint = .zero
    @State private var isTargetDetected = false
    @State private var currentLabel: String = "TARGET_BOT"
    @State private var jitterPos: CGSize = .zero
    @State private var jitterScale: CGFloat = 1.0
    @State private var confidence: Double = 0.98

    let brandName = "REMSTEC"
    let fullTitle = "DRAGONBOT"
    let dynamicSubtitles = ["REMSTEC", "TECNOLOGÍA e INNOVACIÓN", "REMSTEC.COM", "EL FUTURO ES AHORA"]

    var body: some View {
        ZStack {
            (showIntro ? Color.white : ToothlessTheme.deepBlack)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: showIntro)
            
            if showIntro {
                // MARK: - CAPA DE INTRO (LOGO GRANDE Y CERCA DEL TEXTO)
                VStack(spacing: 0) { // Spacing en 0 para pegar el texto al logo
                    // Logo aumentado a 400
                    Image("Rems2")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 300)
                        .grayscale(1.0)
                        .opacity(logoOpacity)
                        .scaleEffect(0.85 + (logoOpacity * 0.15))
                        .offset(y: 20) // Ajuste fino opcional si la imagen tiene mucho aire abajo
                    
                    ZStack {
                        // Texto base gris tenue
                        Text(brandName)
                            .font(.system(size: 42, weight: .light, design: .monospaced))
                            .tracking(12)
                            .foregroundColor(.black.opacity(0.05))
                        
                        // Texto que se "suelda"
                        SolderingText(text: brandName, progress: solderingProgress)
                        
                        // Punto de chispa
                        SparkPoint(progress: solderingProgress, textWidth: 320)
                            .opacity(sparkOpacity)
                    }
                    .frame(width: 320)
                }
                .opacity(introOpacity)
                
            } else {
                mainContent
            }
            
            HUDCorners()
                .stroke((showIntro ? Color.black.opacity(0.1) : Color.white.opacity(0.15)), lineWidth: 1.0)
                .ignoresSafeArea()
        }
        .onAppear { runSolderingSequence() }
    }

    func runSolderingSequence() {
        // Asegúrate de que la extensión sea la correcta (.mp4) si así es tu archivo
        AudioManager.shared.playSound(named: "RemsAud.mp4")

        withAnimation(.easeIn(duration: 0.5)) {
            sparkOpacity = 1.0
        }
        
        withAnimation(.linear(duration: 2.5)) {
            solderingProgress = 1.0
        }
        
        // El logo aparece un poco antes de que termine la soldadura para un efecto fluido
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoOpacity = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                sparkOpacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(.easeInOut(duration: 1.5)) {
                introOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showIntro = false
                startMainAppAnimations()
            }
        }
    }

    func startMainAppAnimations() {
        for (index, character) in fullTitle.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                animatedText.append(character)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.8)) { buttonOpacity = 1.0 }
        }
        startYOLOSimulation()
        startSubtitleCycle()
    }

    var mainContent: some View {
        ZStack {
            StarFieldView()
            InfinitePerspectiveGrid(phase: gridPhase)
                .stroke(LinearGradient(colors: [ToothlessTheme.plasmaBlue.opacity(0.6), .clear], startPoint: .bottom, endPoint: .top), lineWidth: 1.2)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { gridPhase = 1.0 }
                }

            Rectangle()
                .fill(LinearGradient(colors: [.clear, ToothlessTheme.plasmaBlue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                .frame(height: 2)
                .offset(y: scanLineY - (UIScreen.main.bounds.height / 2.0))
                .onAppear {
                    withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) { scanLineY = UIScreen.main.bounds.height }
                }

            if isTargetDetected {
                YOLOBoundingBox(basePos: targetBasePos, label: currentLabel, jitterPos: jitterPos, jitterScale: jitterScale, confidence: confidence)
            }
            
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(animatedText)
                        .font(.system(size: 55, weight: .black, design: .monospaced)).italic()
                        .foregroundColor(ToothlessTheme.dragonEyeGreen)
                        .shadow(color: ToothlessTheme.dragonEyeGreen.opacity(0.5), radius: 15)
                    Text(dynamicSubtitles[currentSubtitleIndex])
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(4)
                        .foregroundColor(ToothlessTheme.plasmaBlue).opacity(subtitleOpacity)
                }.padding(.top, 60)
                
                ZStack {
                    Ellipse().fill(Color.black.opacity(0.7)).blur(radius: 12).frame(width: 160, height: 35).offset(y: 135)
                    RobotPhysicalView(imageName: "Rems", rotationY: robotRotationY)
                }
                .frame(height: 300).padding(.top, 20)
                .onAppear {
                    withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) { robotRotationY = 360 }
                }
                
                Spacer()
                
                Button(action: onStartClick) {
                    Text("INICIAR ENTRENAMIENTO")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white).padding(.vertical, 18).padding(.horizontal, 45)
                        .background(ZStack { Color.black.opacity(0.6); RoundedRectangle(cornerRadius: 2).stroke(ToothlessTheme.plasmaBlue, lineWidth: 2) })
                }.opacity(buttonOpacity).padding(.bottom, 40)
                
                footerLinks.opacity(buttonOpacity)
            }
        }.transition(.opacity)
    }

    var footerLinks: some View {
        VStack(spacing: 20) {
            HStack(spacing: 35) {
                SocialLinkView(icon: "safari.fill", title: "REMSTEC.COM", url: "https://remstec.com")
                SocialLinkView(icon: "play.rectangle.fill", title: "YOUTUBE", url: "https://youtube.com/@remstec")
                SocialLinkView(icon: "music.note", title: "TIKTOK", url: "https://tiktok.com/@remstec")
            }
            Text("© 2026 REMSTEC · TODOS LOS DERECHOS RESERVADOS")
                .font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(ToothlessTheme.glassWhite.opacity(0.5))
        }.padding(.bottom, 30)
    }
    
    func startSubtitleCycle() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) { subtitleOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentSubtitleIndex = (currentSubtitleIndex + 1) % dynamicSubtitles.count
                withAnimation(.easeInOut(duration: 0.5)) { subtitleOpacity = 1.0 }
            }
        }
    }

    func startYOLOSimulation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if !isTargetDetected {
                targetBasePos = CGPoint(x: CGFloat.random(in: 100...300), y: CGFloat.random(in: 250...500))
                isTargetDetected = true
            }
            jitterPos = CGSize(width: CGFloat.random(in: -5...5), height: CGFloat.random(in: -5...5))
            jitterScale = CGFloat.random(in: 0.98...1.02)
            confidence = Double.random(in: 0.95...0.99)
        }
    }
}

// MARK: - COMPONENTES AUXILIARES
struct SolderingText: View {
    let text: String
    let progress: CGFloat
    var body: some View {
        Text(text)
            .font(.system(size: 42, weight: .light, design: .monospaced))
            .tracking(12)
            .foregroundColor(.black)
            .mask(
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 320 * progress)
                    Rectangle()
                        .fill(Color.clear)
                }
                .frame(width: 320, alignment: .leading)
            )
    }
}

struct SparkPoint: View {
    let progress: CGFloat
    let textWidth: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color.black).frame(width: 4, height: 4).blur(radius: 1)
            ForEach(0..<6) { i in
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: CGFloat.random(in: 1...3))
                    .offset(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: -10...10))
                    .scaleEffect(progress == 1.0 ? 0 : 1.0)
            }
        }
        .offset(x: -textWidth/2 + (textWidth * progress))
    }
}

struct YOLOBoundingBox: View {
    var basePos: CGPoint
    var label: String
    var jitterPos: CGSize
    var jitterScale: CGFloat
    var confidence: Double
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().stroke(ToothlessTheme.dragonEyeGreen, lineWidth: 2).background(ToothlessTheme.dragonEyeGreen.opacity(0.1))
            HStack(spacing: 4) {
                Text(label); Text(String(format: "%.2f", confidence))
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(ToothlessTheme.dragonEyeGreen).foregroundColor(.black).offset(y: -18)
            BoxCorners().stroke(ToothlessTheme.dragonEyeGreen, lineWidth: 1)
        }
        .frame(width: 130, height: 130).scaleEffect(jitterScale).offset(jitterPos).position(x: basePos.x, y: basePos.y)
    }
}

struct BoxCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l: CGFloat = 15.0
        path.move(to: CGPoint(x: 0, y: l)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: l, y: 0))
        path.move(to: CGPoint(x: rect.width - l, y: 0)); path.addLine(to: CGPoint(x: rect.width, y: 0)); path.addLine(to: CGPoint(x: rect.width, y: l))
        path.move(to: CGPoint(x: 0, y: rect.height - l)); path.addLine(to: CGPoint(x: 0, y: rect.height)); path.addLine(to: CGPoint(x: l, y: rect.height))
        path.move(to: CGPoint(x: rect.width - l, y: rect.height)); path.addLine(to: CGPoint(x: rect.width, y: rect.height)); path.addLine(to: CGPoint(x: rect.width, y: rect.height - l))
        return path
    }
}

struct SocialLinkView: View {
    let icon: String; let title: String; let url: String
    var body: some View {
        Button(action: { if let link = URL(string: url) { UIApplication.shared.open(link) } }) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(ToothlessTheme.plasmaBlue)
                Text(title).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundColor(ToothlessTheme.plasmaBlue)
                    .padding(.bottom, 2).overlay(Rectangle().fill(ToothlessTheme.plasmaBlue.opacity(0.3)).frame(height: 1), alignment: .bottom)
            }
        }
    }
}

struct RobotPhysicalView: View {
    var imageName: String; var rotationY: Double
    var body: some View {
        Image(imageName).resizable().aspectRatio(contentMode: .fit).frame(width: 270, height: 270)
            .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .shadow(color: ToothlessTheme.plasmaBlue.opacity(0.3), radius: 25)
    }
}

struct StarFieldView: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<75 {
                let x = CGFloat.random(in: 0...size.width); let y = CGFloat.random(in: 0...size.height)
                let starSize = CGFloat.random(in: 1.2...2.5)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: starSize, height: starSize)), with: .color(.white.opacity(Double.random(in: 0.5...1.0))))
            }
        }
    }
}

struct InfinitePerspectiveGrid: Shape {
    var phase: CGFloat
    var animatableData: CGFloat { get { phase } set { phase = newValue } }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.width / 2.0; let horizonY = rect.height * 0.45; let step: CGFloat = 80.0
        for i in stride(from: -rect.width * 2, to: rect.width * 3, by: step) {
            path.move(to: CGPoint(x: i, y: rect.height)); path.addLine(to: CGPoint(x: centerX + (i - centerX) * 0.02, y: horizonY))
        }
        for i in 0...15 {
            let progress = CGFloat(i) / 15.0
            let yPos = horizonY + (rect.height - horizonY) * pow(progress + (phase * 0.06), 2)
            if yPos <= rect.height { path.move(to: CGPoint(x: 0, y: yPos)); path.addLine(to: CGPoint(x: rect.width, y: yPos)) }
        }
        return path
    }
}

struct HUDCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s: CGFloat = 35.0; let p: CGFloat = 20.0
        path.move(to: CGPoint(x: p, y: p+s)); path.addLine(to: CGPoint(x: p, y: p)); path.addLine(to: CGPoint(x: p+s, y: p))
        path.move(to: CGPoint(x: rect.width-p-s, y: p)); path.addLine(to: CGPoint(x: rect.width-p, y: p)); path.addLine(to: CGPoint(x: rect.width-p, y: p+s))
        path.move(to: CGPoint(x: p, y: rect.height-p-s)); path.addLine(to: CGPoint(x: p, y: rect.height-p)); path.addLine(to: CGPoint(x: p+s, y: rect.height-p))
        path.move(to: CGPoint(x: rect.width-p-s, y: rect.height-p)); path.addLine(to: CGPoint(x: rect.width-p, y: rect.height-p)); path.addLine(to: CGPoint(x: rect.width-p, y: rect.height-p-s))
        return path
    }
}
